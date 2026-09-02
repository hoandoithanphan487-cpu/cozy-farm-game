# N-022 — 猫店收购与畜牧可玩切片

## Player outcome

玩家可以在农场查看并照料自己的动物，让幼年动物随日结成长；到溪岸集市的猫猫烧烤店查看当日公开收购板，出售指定作物或符合条件的成年动物，并立即收到溪票。保存、退出和读取后，动物、当日照料、收购名额、收据与货币保持一致。

## Current context and assumptions

- Product Owner 于 2026-08-27 指示开始开发猫店收购和畜牧玩法（DEC-044）。
- N-021 已批准供货规则；现有 SpriteKit 游戏已有背包、出售箱、经济账本、日结、存档迁移、猫店与农场动物像素展示。
- 第一版采用可调试的垂直切片，不一次实现完整繁殖、购买、动物产品或建筑升级。
- 试点畜牧为牛、羊、山羊三种；新档与旧存档各获得一只确定性的起始动物。牛与羊初始成年，山羊初始幼年并在日结后成长。
- 每只动物每日可照料一次，消耗 2 点体力；漏照料不会生病、死亡或逃走。成年且当日已照料、非保护状态的动物才可供货。
- 猫店每日轮换两种作物，以基础售价 110% 的试点单价、每种最多 6 件收购；三类合格动物各有公开固定试点价且每天最多收购 1 只。所有数值数据化，后续可平衡调整。

## Ownership

- Department: 🧱 Engineering & Pipeline
- Department quality owner: 🧱 `tech`
- Specialist owner: 🎮 `gameplay`
- Consulted: 🌱 `design`、⚖️ `economy`、🎭 `content`、✨ `ux`
- Downstream reviewer: 🛡️ `quality`
- 防自我批准：玩法实现后由技术角色审查架构和存档，再由设计、内容与质量角色依次复核玩家规则、调性和运行证据。

## Dependencies and preflight

- M0-002: `accepted / APPROVED`
- M0-003: `accepted / APPROVED`
- M2-001: `accepted / APPROVED`
- N-014: `accepted / APPROVED`
- N-015: `accepted / APPROVED`
- N-021: `accepted / APPROVED`
- DEC-044: 已登记
- Preflight: `PASS`

## In scope

- 数据驱动的三种畜牧定义、三只确定性起始动物和持久化动物名册。
- 每日一次的动物照料、2 体力消费、幼年成长和温和的漏照料规则。
- 数据驱动的每日猫店收购板、作物定向溢价、动物公开价格和每日数量上限。
- 作物与动物的即时原子交易、唯一请求 ID、唯一收据、经济账本和失败回滚。
- 存档 schema 增量、旧存档迁移、内容与存档验证。
- 农场动物名册界面、猫店供货界面、动物二次确认，以及卖出后场景动物同步消失。
- 定向 XCTest、存读/迁移/重复交易回归和可构建证据。

## Out of scope

- 不实现繁殖、动物购买、蛋奶毛产品、饲料库存、疾病、死亡、逃跑、怀孕或多圈舍管理。
- 不新增美术资产，不改变猫店、围栏或地图拓扑。
- 不实现隐藏任务《雾岭失踪的猫猫公主》。
- 不改变出售箱的次日结算和 174/894 教学基线。
- 不把 N-016、N-017、N-018、N-019 或 N-012 自动标记完成。

## Playable path

`农场按 M 打开动物名册 → 照料动物 → 睡眠观察幼年成长 → 前往集市猫店 → 按 J 打开收购板 → 出售指定作物或二次确认出售合格动物 → 溪票立即到账并显示收据 → 保存、退出、读取 → 状态一致`

## Acceptance criteria

1. Given 新档或 v8 旧档，When 进入游戏，Then 牛、羊、山羊三只稳定动物存在且实例 ID 唯一。
2. Given 动物今日未照料且体力≥2，When 玩家照料，Then 只扣 2 体力、记录当日照料；重复照料和体力不足均不改变状态。
3. Given 幼年山羊，When 完成有效日结，Then 年龄增加且达到门槛后成为成年；漏照料不会死亡或丢失。
4. Given 玩家在猫店，When 查看收购板，Then 两种当日作物及合格动物显示单价、上限、剩余名额和预计收入。
5. Given 玩家供货作物，When 原子交易成功，Then 背包扣除、溪票立即到账、账本与唯一收据同时产生；失败时四者均不改变。
6. Given 玩家选择动物，When 未完成二次确认，Then 动物与溪票不变；确认后仅成年、当日已照料、非保护动物可离场并立即到账。
7. Given 相同请求 ID 重试，When 服务再次执行，Then 不重复扣货、不重复移除动物、不重复支付。
8. Given 保存并完全退出，When 读取，Then 动物、照料日、年龄、收据、名额消耗和余额逐项一致。
9. Given 既有出售箱教学，When 完成投入、睡眠和重读，Then 174/894 与只结算一次的行为不回归。
10. Given 玩家卖出牛、羊或山羊，When 农场重新渲染，Then对应场景动物不再显示，未卖出的动物保持可见。

## Required gates and evidence

- 🎮 gameplay specialist handoff：`SUBMITTED`。领域服务、界面、迁移、验证与测试已交付；详细文件清单和已知限制见 `artifacts/integration/n-022-livestock-cat-shop/handoff.md`。
- 🧱 tech：`APPROVED`。原子交易、重复请求保护、schema v9、验证与回滚证据通过。
- 🌱 design / ⚖️ economy：`APPROVED`。每日照料为温和压力，猫店轮换和公开溢价与出售箱形成清晰渠道差异。
- 🎭 content：`APPROVED`。猫店身份、动物名称、交接文案与原创调性通过。
- 🛡️ quality：`APPROVED`（N-022 范围）。构建成功，专项 11/11、相邻回归 73/73；全量 450/463，13 项失败均属于既有 N-015 素材审计/像素资产/性能基线类别，N-022 与相关种植、出货、存档、社区、地图测试零失败。

## Handoff outcome

- Status: `accepted`
- Gate: `APPROVED`
- Evidence: `artifacts/integration/n-022-livestock-cat-shop/handoff.md`
- Next owner: Product Owner 试玩并决定下一增量优先做动物补充渠道，还是先调猫店价格与每日上限。

## Originality boundary

- 使用通用的畜牧照料与定向收购功能，但动物名称、猫店收购规则、界面文案、数据结构和交互组合均为《溪谷新芽》原创。
- 不复刻其他农场游戏的角色、动物名字、商店布局、对白、音效、价格曲线或任务顺序。
