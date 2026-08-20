#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""N-002 B-2: 溪谷新芽 7 天作物经济模拟（PRD 6.8 数值基线）。

合同: docs/game/n-002-prompt.md（DEC-019 B-2；PRD 6.8.1/6.8.4 验证 + IDEA-001 加工利润前置）。
独立运行，零游戏源码改动，仅 Python 3.11 标准库，确定性（无随机）。

输入基线（PRD 6.8.2/6.8.3，已与游戏源码核对）:
  - 起始货币 720 溪票；雾萝卜种子 ×8、溪叶菜种子 ×4（背包内）；
  - 教学地块 3 株成熟雾萝卜，第 1 日可收获（3×58=174，PRD 6.8.1 首日目标）；
  - 体力 100/天；每次成功动作（翻土/播种/浇水/收获/加工）耗 2 点（PRD 6.3）；
  - 背包 16 格；农场 10×6 = 60 格；
  - 第 2 天固定雨天（自动浇水）；其余天人工浇水每格 2 点。
  - 品质：确定性全普通（1.00），合同 §2 方案 a。

简化声明（写入报告）:
  1) 背包按「单件占 1 格」保守建模（合同 §3.3 口径），收获即投出售箱清空背包；
  2) 作物生长不受跳过浇水影响（浇水仅计体力成本）；
  3) 再投资规则 = 早晨按策略用当前现金回购种子，受背包/空地/可负担量约束；
  4) 加工（+20%/+40%）每件耗 2 体力，加工后当日即售；
  5) 琥珀豆/铃花莓/蜜穗瓜在模拟中第 1 日即可购种（PRD 6.8.3 注：VS-1 内琥珀豆实际第 2 天起由
     种源管理员出售——模拟允许为数据验证口径，报告声明）。
"""
import argparse
import json
import sys

# ---------------- 基线常量（PRD 6.8.2/6.8.3；与源码核对项标注） ----------------
DAYS = 7                       # 合同主窗口
STAMINA_DAILY = 100
ACTION_COST = 2                # PRD 6.3：翻土/播种/浇水/收获每次成功动作 2 点
RAIN_DAY = 2                   # VS-1 第 2 天固定雨天（自动浇水）
START_MONEY = 720              # PRD 6.8.2
STARTER_SEEDS = {"mist_radish": 8, "stream_leaf": 4}   # PRD 6.8.2
TEACHING_HARVEST = 3           # 教学地块成熟雾萝卜株数
TEACHING_UNIT_PRICE = 58       # 源码 ContentCatalog.swift: mist_radish baseSellPrice 58
BACKPACK = 16                  # PRD 6.8.2
FARM_TILES = 60                # 10×6 网格（游戏源码 FarmScene）
SEED = 0                       # 确定性：全普通品质（1.00），无随机分支

# 作物表（PRD 6.8.3 原始数值；毛利率 sanity check 见 __main__）
CROPS = {
    "mist_radish": {"name": "雾萝卜", "seed": 28, "grow": 2, "yield": 1, "sell": 58,  "repeat": None},  # 107%
    "stream_leaf": {"name": "溪叶菜", "seed": 46, "grow": 4, "yield": 1, "sell": 92,  "repeat": None},  # 100%
    "amber_bean":  {"name": "琥珀豆", "seed": 62, "grow": 6, "yield": 1, "sell": 48,  "repeat": 3},     # 第二次收获后盈利
    "bell_berry":  {"name": "铃花莓", "seed": 78, "grow": 7, "yield": 2, "sell": 44,  "repeat": 4},     # 首收 13%
    "honey_melon": {"name": "蜜穗瓜", "seed": 96, "grow": 8, "yield": 1, "sell": 205, "repeat": None},  # 114%
}

# 策略集（合同 §3.2：至少三策略；④⑤为 PRD 6.8.3「仅数据验证」长线对照）
STRATEGIES = {
    "s1_radish": {"label": "① 雾萝卜密集（速生周转）",      "crop": "mist_radish", "mix": None},
    "s2_mix":    {"label": "② 溪叶菜+雾萝卜混合（1:2 计数）", "crop": None,          "mix": {"stream_leaf": 1, "mist_radish": 2}},
    "s3_bean":   {"label": "③ 琥珀豆长线（第 6 天后重复收获）", "crop": "amber_bean", "mix": None},
    "s4_berry":  {"label": "④ 铃花莓长线（对照，仅数据）",   "crop": "bell_berry",  "mix": None},
    "s5_melon":  {"label": "⑤ 蜜穗瓜长线（对照，仅数据）",   "crop": "honey_melon", "mix": None},
}

# PRD 6.8.4 收入目标曲线（每日可支配净收入区间）
INCOME_TARGETS = [(1, 3, 90, 180), (4, 7, 220, 420)]


def run_strategy(key, days=DAYS, process_mult=1.0, rational=False):
    """运行一个策略，返回每日明细与合计。process_mult=1.0 为无加工基线。
    rational=True：仅购买能在窗口内收获的种子（d + grow <= days），
    避免窗口末端购买无法收获的种子虚增投入（长线作物口径修正）。"""
    cfg = STRATEGIES[key]
    seeds = dict(STARTER_SEEDS)
    money = START_MONEY
    tiles = []                 # {crop, next_harvest} 已播种地块
    rows: list = []
    totals: dict = {"sales": 0, "seed_spend": 0, "labor": 0, "stamina": 0, "tile_days": 0}

    def seeds_held():
        return sum(seeds.values())

    for d in range(1, days + 1):
        st = STAMINA_DAILY
        labor = 0
        pending = 0            # 当日投箱收入（睡眠结算）
        harvested = 0          # 当日收获件数
        processed = 0

        # 1) 收获成熟地块（教学地块第 1 天；其余按 next_harvest 日）
        unit_prices: list = []
        if d == 1:
            n = min(TEACHING_HARVEST, BACKPACK - seeds_held())
            if n > 0 and st >= ACTION_COST:
                st -= ACTION_COST * n
                labor += n
                harvested += n
                unit_prices.extend([TEACHING_UNIT_PRICE] * n)
        ripe = [t for t in tiles if t["next_harvest"] == d]
        for t in ripe:
            slots = BACKPACK - seeds_held() - harvested
            if st >= ACTION_COST and slots > 0:
                st -= ACTION_COST
                labor += 1
                u = min(t["yield"], slots)
                harvested += u
                unit_prices.extend([CROPS[t["crop"]]["sell"]] * u)
            if t["repeat"]:
                t["next_harvest"] = d + t["repeat"]
            else:
                tiles.remove(t)

        # 2) 加工场景：每件 2 体力，加工后按倍率计价（未加工部分保持原价）
        if process_mult != 1.0:
            for up in unit_prices:
                if st < ACTION_COST:
                    break
                st -= ACTION_COST
                labor += 1
                processed += 1
                pending += round(up * process_mult) - up

        # 3) 投箱（基础售价计入待结算；清空背包；睡眠结算）
        pending += sum(unit_prices)
        totals["sales"] += pending

        # 4) 早晨再投资：按策略规则回购种子（受背包/空地/可负担量约束）
        held = seeds_held()
        free_slots = BACKPACK - held
        free_tiles = FARM_TILES - len(tiles)
        budget = money
        if cfg["crop"]:
            if rational and d + CROPS[cfg["crop"]]["grow"] > days:
                n = 0
            else:
                n = budget // CROPS[cfg["crop"]]["seed"]
                n = min(n, free_slots, free_tiles)
            if n > 0:
                seeds[cfg["crop"]] = seeds.get(cfg["crop"], 0) + n
                totals["seed_spend"] += n * CROPS[cfg["crop"]]["seed"]
                money -= n * CROPS[cfg["crop"]]["seed"]
                budget -= n * CROPS[cfg["crop"]]["seed"]
        else:  # s2 混合：1/3 预算溪叶菜、2/3 预算雾萝卜（计数 1:2 近似）
            n_leaf = (budget // 3) // CROPS["stream_leaf"]["seed"]
            if rational and d + CROPS["stream_leaf"]["grow"] > days:
                n_leaf = 0
            n_leaf = min(n_leaf, free_slots, free_tiles)
            if n_leaf > 0:
                seeds["stream_leaf"] += n_leaf
                totals["seed_spend"] += n_leaf * CROPS["stream_leaf"]["seed"]
                money -= n_leaf * CROPS["stream_leaf"]["seed"]
            budget -= n_leaf * CROPS["stream_leaf"]["seed"]
            n_rad = (budget // 2) // CROPS["mist_radish"]["seed"] if budget >= 28 else 0
            if rational and d + CROPS["mist_radish"]["grow"] > days:
                n_rad = 0
            n_rad = min(n_rad, BACKPACK - seeds_held(), FARM_TILES - len(tiles) - n_leaf)
            if n_rad > 0:
                seeds["mist_radish"] += n_rad
                totals["seed_spend"] += n_rad * CROPS["mist_radish"]["seed"]
                money -= n_rad * CROPS["mist_radish"]["seed"]

        # 5) 播种：翻土+播种+浇水 = 3 次动作 = 6 体力/格
        plant_order = ["stream_leaf", "mist_radish"] if cfg["mix"] else [cfg["crop"]]
        while st >= ACTION_COST * 3 and len(tiles) < FARM_TILES:
            chosen = None
            for c in plant_order:
                if seeds.get(c, 0) > 0:
                    chosen = c
                    break
            if chosen is None:
                break
            st -= ACTION_COST * 3
            labor += 3
            seeds[chosen] -= 1
            tiles.append({"crop": chosen, "next_harvest": d + CROPS[chosen]["grow"], "repeat": CROPS[chosen]["repeat"], "yield": CROPS[chosen]["yield"]})

        # 6) 灌溉既有地块（第 2 天雨天免费；新增地块播种时已浇）
        if d != RAIN_DAY:
            watered = 0
            for t in tiles:
                if st >= ACTION_COST:
                    st -= ACTION_COST
                    labor += 1
                    watered += 1

        # 7) 睡眠：结算 + 记录
        money += pending
        rows.append({
            "day": d, "income": pending, "cum_money": money,
            "labor": labor, "stamina_used": STAMINA_DAILY - st,
            "tiles_planted": len(tiles), "tile_days": len(tiles),
            "harvested": harvested, "processed": processed,
        })
        totals["labor"] += labor
        totals["stamina"] += STAMINA_DAILY - st
        totals["tile_days"] += len(tiles)

    totals["income"] = totals["sales"]
    totals["income_per_labor"] = round(totals["sales"] / totals["labor"], 2) if totals["labor"] else 0.0
    totals["margin"] = ((totals["sales"] - totals["seed_spend"]) / totals["seed_spend"]) if totals["seed_spend"] else 0.0
    totals["end_money"] = rows[-1]["cum_money"] if rows else START_MONEY
    return {"key": key, "label": cfg["label"], "rows": rows, "totals": totals}


def fmt_row(r):
    return (f"  D{r['day']}: 收入 {r['income']:>5}  累计货币 {r['cum_money']:>6}  "
            f"劳动 {r['labor']:>2}  体力 {r['stamina_used']:>3}  占地格·日 {r['tile_days']:>3}  "
            f"收获 {r['harvested']:>2}  加工 {r['processed']:>2}")


def print_totals(s, label=None):
    t = s["totals"]
    print(f"  {s['label']}: 7日总收入 {t['sales']}  期末货币 {t['end_money']}  "
          f"种子投入 {t['seed_spend']}  劳动 {t['labor']}  "
          f"收入/劳动 {t['income_per_labor']}  毛利率 {t['margin'] * 100:.1f}%")


def check_6181(results):
    """PRD 6.8.1：同劳动投入折算（收入/劳动），领先策略不超约 25%。返回 (leader, second, margin, ok)。"""
    by_pl = sorted(results.values(), key=lambda s: s["totals"]["income_per_labor"], reverse=True)
    leader, second = by_pl[0], by_pl[1]
    margin = (leader["totals"]["income_per_labor"] - second["totals"]["income_per_labor"]) / second["totals"]["income_per_labor"] * 100
    return leader, second, margin, margin <= 25.0


def income_curve_report(results):
    print("  收入曲线对照（PRD 6.8.4：第 1–3 天 90–180 / 第 4–7 天 220–420）:")
    for key, s in results.items():
        d13 = [r["income"] for r in s["rows"] if r["day"] <= 3]
        d47 = [r["income"] for r in s["rows"] if 4 <= r["day"] <= 7]
        print(f"    {s['label']}: D1-3 min/max = {min(d13)}/{max(d13)}   D4-7 min/max = {min(d47)}/{max(d47)}")


def run_scenario(process_mult, days=DAYS, verbose=True, rational=False):
    results = {}
    for key in STRATEGIES:
        results[key] = run_strategy(key, days=days, process_mult=process_mult, rational=rational)
    if verbose:
        for s in results.values():
            print_totals(s)
        leader, second, margin, ok = check_6181(results)
        print(f"  PRD 6.8.1（同劳动投入折算）: 领先 = {leader['label']}（收入/劳动 {leader['totals']['income_per_labor']}）"
              f" vs {second['label']}（{second['totals']['income_per_labor']}）→ 领先幅度 {margin:.1f}% "
              f"{'≤25% PASS' if ok else '>25% FAIL'}")
        income_curve_report(results)
    return results, check_6181(results)


def find_cap(rational=False):
    """加工倍率下保持 6.8.1（领先 ≤25%）的最高加价倍率（建议加价上限，扫描范围 +0%~+100%）。"""
    best = 1.0
    for i in range(100, 201):
        mult = i / 100.0
        results, (leader, second, margin, ok) = run_scenario(mult, verbose=False, rational=rational)
        if ok:
            best = mult
    return best


def main():
    ap = argparse.ArgumentParser(description="N-002 7 天作物经济模拟（PRD 6.8）")
    ap.add_argument("--days", type=int, default=DAYS, help="模拟天数（默认 7；PRD 6.8.3 提及 24 天长期对照可用 --days 24）")
    ap.add_argument("--rational-reinvest", action="store_true",
                    help="理性再投资：仅购买窗口内能收获的种子（长线作物口径修正；主 7 天口径默认关闭）")
    ap.add_argument("--json", default="", help="可选：输出摘要 JSON 路径")
    args = ap.parse_args()

    print(f"=== N-002 B-2 经济模拟（{args.days} 天；确定性种子 SEED={SEED}，全普通品质 1.00）===")
    if args.rational_reinvest:
        print("理性再投资护栏：ON（仅购买 d+grow<=窗口末 的种子）")
    print(f"基线: 起始 720 溪票 / 雾萝卜种子×8 + 溪叶菜种子×4 / 背包 {BACKPACK} 格 / 教学 3 株雾萝卜（3×58=174）/ "
          f"体力 100 每天 / 动作 2 点 / 第 2 天雨天 / 农场 {FARM_TILES} 格\n")

    # 作物表毛利率 sanity check（PRD 6.8.3）
    print("作物表首轮毛利率校验（(售价×产量-种子)/种子，PRD 6.8.3 口径）：")
    for c, v in CROPS.items():
        print(f"  {v['name']}: {(v['sell'] * v['yield'] - v['seed']) / v['seed'] * 100:.0f}%")

    print("\n--- 无加工基线（品质 1.00）---")
    results, (leader, second, margin, ok) = run_scenario(1.0, days=args.days, rational=args.rational_reinvest)
    for key in ["s1_radish", "s2_mix", "s3_bean", "s4_berry", "s5_melon"]:
        print(f"\n{results[key]['label']} 逐日明细：")
        for r in results[key]["rows"]:
            print(fmt_row(r))

    # 断言 AC-3：首日 174 复现（3×58）
    day1 = {k: v["rows"][0]["income"] for k, v in results.items()}
    assert all(v == 174 for v in day1.values()), f"首日结算断言失败: {day1}"
    print(f"\n[断言] 首日 174 复现: {day1} 全部 == 174 ✓")

    # 加工场景
    print("\n--- 加工场景（IDEA-001 前置基线）---")
    scen = {}
    for mult in (1.2, 1.4):
        print(f"\n加工 +{round((mult - 1) * 100)}%（每件 2 体力）:")
        scen[mult] = run_scenario(mult, days=args.days, rational=args.rational_reinvest)[0]

    cap = find_cap(args.rational_reinvest) if args.days == DAYS else None
    print(f"\n[建议] 加工加价上限（保持 6.8.1 领先 ≤25% 的最高倍率）: +{(cap - 1) * 100:.0f}%" if cap else "")

    # 摘要 JSON
    if args.json:
        summary = {
            "days": args.days, "seed": SEED, "quality": "all normal 1.00",
            "baseline": {"start_money": START_MONEY, "backpack": BACKPACK, "farm_tiles": FARM_TILES},
            "strategies": {
                k: {"label": v["label"], "totals": v["totals"],
                    "daily": [{kk: r[kk] for kk in ("day", "income", "cum_money", "labor", "stamina_used", "tile_days")} for r in v["rows"]]}
                for k, v in results.items()
            },
            "check_6181": {"leader": leader["key"], "margin_pct": round(margin, 2), "ok": ok},
            "processing": {
                str(mult): {k: v["totals"]["income_per_labor"] for k, v in scen[mult].items()}
                for mult in scen
            },
        }
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)
        print(f"[JSON] 摘要写入 {args.json}")

    print("\n=== 完成（exit 0）===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
