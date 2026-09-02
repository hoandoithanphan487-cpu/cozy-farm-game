#!/usr/bin/env python3
"""N-019 player-build art inventory.

Scan each canonical in-app PNG exactly once. Source artifacts and superseded
ConceptArt are intentionally excluded so the manifest answers the operational
question: which approved images are bundled for a player-visible consumer?

Usage: python3 scripts/n019-art-inventory.py
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

try:
    from PIL import Image
except ImportError:
    print("PIL required: pip3 install pillow")
    sys.exit(1)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def png_info(path: Path) -> dict:
    with Image.open(path) as im:
        info = {
            "width": im.width,
            "height": im.height,
            "mode": im.mode,
            "format": im.format,
        }
        if "A" in im.mode:
            alpha = im.getchannel("A")
            hist = alpha.histogram()
            opaque = hist[255] if len(hist) > 255 else 0
            total = im.width * im.height
            info["alpha_opaque_pct"] = round(opaque / total * 100, 2)
        return info


def scan(dir_path: Path, status: str, task: str, runtime_path: str | None) -> list[dict]:
    items = []
    if not dir_path.exists():
        return items
    for path in sorted(dir_path.glob("*.png")):
        info = png_info(path)
        items.append({
            "stable_name": path.stem,
            "filename": path.name,
            "source_task": task,
            "original_path": str(path.relative_to(ROOT)),
            "runtime_path": runtime_path,
            "native_width": info["width"],
            "native_height": info["height"],
            "alpha": info.get("alpha_opaque_pct", 100),
            "color_mode": info["mode"],
            "sha256": sha256(path),
            "status": status,
            "map_or_ui": "",
            "trigger": "",
            "player_visible_evidence": "",
        })
    return items


def main() -> None:
    assets = ROOT / "macos/CreekSprout/CreekSprout/Assets"
    portraits = ROOT / "macos/CreekSprout/CreekSprout/Presentation/Portraits"
    buildings = ROOT / "macos/CreekSprout/CreekSprout/Presentation/Buildings"
    world_life = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"

    manifest = []
    manifest += scan(assets, "approved-final", "N-006/N-015", "Assets/")
    manifest += scan(portraits, "approved-final", "N-009", "Presentation/Portraits/")
    manifest += scan(buildings, "approved-final", "N-013", "Presentation/Buildings/")
    world_items = scan(
        world_life,
        "approved-final",
        "N-005/N-006/N-014/N-019",
        "Presentation/WorldLife/",
    )
    # The original flat shop sprite is retained only as a recoverable fallback;
    # the R2 sprite is the one shown to players and is counted once.
    if any(item["stable_name"] == "wl_cat_bbq_shop_r2" for item in world_items):
        world_items = [
            item for item in world_items
            if item["stable_name"] != "wl_cat_bbq_shop"
        ]
    for item in world_items:
        stem = item["stable_name"]
        if stem.startswith("cat_"):
            item["source_task"] = "N-014"
            item["map_or_ui"] = "猫食铺美术巡礼"
            item["trigger"] = "溪岸集市店前点击提示卡或按 J"
            item["player_visible_evidence"] = "CatBbqArtTourView"
        elif stem.startswith("wl_cat_"):
            item["source_task"] = "N-005/N-006/N-014"
            item["map_or_ui"] = "溪岸集市"
            item["trigger"] = "进入集市"
            item["player_visible_evidence"] = "WorldLifeCatalog.marketPlacements"
        elif stem.startswith("wl_tree_") or stem.startswith("wl_farm_"):
            item["source_task"] = "N-019"
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入地图"
            item["player_visible_evidence"] = "WorldLifeCatalog.placements"
        else:
            item["source_task"] = "N-005/N-006"
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入地图"
            item["player_visible_evidence"] = "WorldLifeCatalog.placements / edgeBand"
    manifest += world_items

    for item in manifest:
        if item["player_visible_evidence"]:
            continue
        path = item["original_path"]
        stem = item["stable_name"]
        if "/Portraits/" in path:
            item["map_or_ui"] = "对话与角色信息"
            item["trigger"] = "与对应角色交谈"
            item["player_visible_evidence"] = "PortraitPresentationCatalog / ConceptPortraitCard"
        elif "/Buildings/" in path:
            item["map_or_ui"] = "建筑详情卡"
            item["trigger"] = "靠近对应建筑后按 E"
            item["player_visible_evidence"] = "BuildingPresentationCatalog / BuildingPresentationCard"
        elif stem.startswith("building_"):
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入对应地图"
            item["player_visible_evidence"] = "BuildingVisualPresenter"
        elif stem.startswith("ui_") or stem.startswith("tool_"):
            item["map_or_ui"] = "HUD"
            item["trigger"] = "进入游戏"
            item["player_visible_evidence"] = "CompactFarmHudView"
        elif stem.startswith("char_"):
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入地图 / 移动 / 使用工具"
            item["player_visible_evidence"] = "CharacterVisualNode"
        elif stem.startswith("crop_"):
            item["map_or_ui"] = "农田与 HUD"
            item["trigger"] = "播种、生长或选择种子"
            item["player_visible_evidence"] = "FarmScene.makeCropNode / CompactFarmHudView"
        elif stem.startswith("tile_"):
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入地图"
            item["player_visible_evidence"] = "FarmScene.addPixelTileIfAvailable"
        elif stem.startswith("prop_"):
            item["map_or_ui"] = "农场"
            item["trigger"] = "演示场景或放置物件"
            item["player_visible_evidence"] = "FarmScene.makePlacedObjectGlyph"
        elif stem.startswith("gather_"):
            item["map_or_ui"] = "农场与溪岸集市"
            item["trigger"] = "进入未采集节点所在地图"
            item["player_visible_evidence"] = "FarmScene.makeCellNode"
        elif stem.startswith("fx_"):
            item["map_or_ui"] = "世界特效"
            item["trigger"] = "浇水、收获、目标预览或水渠流动"
            item["player_visible_evidence"] = "WorldEffectPresenter"

    by_status: dict[str, list[dict]] = {}
    for item in manifest:
        by_status.setdefault(item["status"], []).append(item)

    out = {
        "generated_at": "2026-08-25",
        "task": "N-019",
        "counts": {k: len(v) for k, v in sorted(by_status.items())},
        "total": len(manifest),
        "assets": manifest,
    }
    out_dir = ROOT / "artifacts/integration/n-019-demo-visual"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "all-approved-art-manifest.json"
    manifest_path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [
        "# N-019 玩家构建内美术资产权威清单",
        "",
        f"> 生成时间：2026-08-25 · 任务：N-019 · 总量：{len(manifest)}",
        "",
        "| 状态 | 数量 |",
        "|---|---|",
    ]
    for status in sorted(by_status):
        lines.append(f"| {status} | {len(by_status[status])} |")
    lines += [
        "",
        "## 分类规则",
        "",
        "- 每个玩家构建内 PNG 只登记一次；源工件副本不重复计数。",
        "- `approved-final`：已经进入 App 构建，并有运行地图、HUD 或展示页消费者。",
        "- `Assets/ConceptArt` 为已被 N-009 肖像替代的旧展示层，不计入本次玩家可见清单。",
        "",
        "## 逐项清单",
        "",
        "| 稳定名称 | 来源任务 | 原始路径 | 尺寸 | 状态 | 地图/UI | 触发 | 玩家可见消费者 |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for item in manifest:
        lines.append(
            f"| {item['stable_name']} | {item['source_task']} | {item['original_path']} "
            f"| {item['native_width']}×{item['native_height']} | {item['status']} "
            f"| {item['map_or_ui']} | {item['trigger']} | {item['player_visible_evidence']} |"
        )
    doc_path = ROOT / "docs/game/n-019-approved-art-inventory.md"
    doc_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(out["counts"], ensure_ascii=False))
    print(f"total={len(manifest)} manifest={manifest_path} doc={doc_path}")


if __name__ == "__main__":
    main()
