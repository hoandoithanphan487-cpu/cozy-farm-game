# N-021 — 猫猫烧烤店供货商规则

## Player outcome

玩家可以把自己收获的作物，以及农场内符合条件的圈养动物，交给猫猫烧烤店换取溪票；玩家因此成为店铺的供货商，并在出售箱之外获得一个更有选择感的定向销售渠道。

## Current context and assumptions

- Product Owner 于 2026-08-27 明确猫猫烧烤店的核心身份是收购商，玩家是供货商（DEC-043）。
- 当前已实现出售箱的次日幂等结算，但猫店收购、畜牧、动物名册和即时供货尚未实现。
- 店铺正式名为“溪火猫食铺”，社区常用名为“猫猫烧烤店”。
- 活体动物供货采用抽象交接，不出现屠宰、受伤或痛苦画面。

## Ownership

- Department: 🌱 Design & Player Experience
- Department quality owner: 🌱 `design`
- Specialist owner: ⚖️ `economy`
- Consulted: 📖 `narrative`、🎭 `content`
- Downstream reviewer: 🛡️ `quality`
- 防自我批准：经济规则由设计门复核，叙事一致性由内容角色咨询，最终由质量角色跨部门检查。

## Dependencies and preflight

- M0-004: `accepted / APPROVED`
- M2-001: `accepted / APPROVED`
- N-014: `accepted / APPROVED`
- N-020: `accepted / APPROVED`
- DEC-043: 已登记
- Preflight: `PASS`

## In scope

- 在 `game-rules.md` 定义猫店的作物与动物供货、公开收购板、即时付款、交易保护及与出售箱的区别。
- 在 `story-bible.md` 定义猫店的多农场采购立场，并把它连接到灰栅农场的独家供货矛盾。
- 明确未完成每日供货无惩罚，隐藏任务不要求刷供货次数。

## Out of scope

- 不实现畜牧系统、动物 AI、猫店商店界面、收购数据、稳定 ID、存档 schema 或即时交易代码。
- 不锁定作物/动物的实际价格、需求倍率、数量上限和营业时间。
- 不修改 PRD、TDD、Swift、Xcode 工程、美术资产或既有任务状态。

## Acceptance criteria

1. Given 猫店开放，When 玩家查看收购板，Then 每项供货的名称、条件、单价、数量上限、剩余名额和预计收入均可见。
2. Given 玩家出售作物，When 交易成功，Then 作物扣除与溪票到账为同一原子交易，并生成唯一收据。
3. Given 玩家转让动物，When 进入确认页，Then 显示身份、状态、价格与离场后果，并要求二次确认。
4. Given 动物是幼年、任务、托管、受保护或伙伴动物，When 打开供货名册，Then 它不可被出售。
5. Given 玩家取消或交易失败，When 返回游戏，Then 作物、动物、溪票与关系状态均不改变。
6. Given 同一件货物，When 它已进入出售箱、猫店供货或其他订单，Then 不能再次进入另一渠道或重复到账。
7. Given 玩家错过当日收购，When 日期推进，Then 不扣声誉、不伤害作物或动物、不阻断主线或隐藏任务。

## Required evidence and gates

- 两份设计文档术语、供货范围、结算时点和隐藏任务动机一致。
- 静态检查覆盖“玩家是供货商”“作物和动物”“立即到账”“二次确认”“无每日惩罚”和“未实现声明”。
- `git diff --check` 通过。
- 🌱 design: 经济渠道、反馈、保护与反重复规则 `APPROVED`。
- 🎭 content consultation: 店铺身份、温暖调性与灰栅动机 `APPROVED`。
- 🛡️ quality cross-department: 取消安全、误售保护、无强迫留存与实现状态诚实性 `APPROVED`。

## Specialist handoff and gates

### ⚖️ economy handoff

- Outcome: 猫店成为定向收购商；出售箱保留为通用保底渠道；作物和合格动物均可供货并即时获得溪票。
- Changed artifacts: `docs/game/game-rules.md`、`docs/game/story-bible.md`、`docs/game/n-021-brief.md`。
- Decisions: 价格和数量在收购板提前公开；交易原子化；动物二次确认；每日供货不构成强制任务。
- Risks: 实现前仍需完整畜牧设计、经济模拟、存档迁移与唯一交易 ID 合同。

### 🌱 design gate

- Gate status: `APPROVED`
- Scope reviewed: 供货输入、定向需求、即时结算、渠道差异、取消安全、动物保护和留存压力边界。
- Evidence inspected: `game-rules.md` 第 4 节及第 6–10 节关联规则。
- Acceptance gaps: 无。玩家有赚钱机会和每日选择，但错过不会造成严厉惩罚或永久损失。

### 🎭 content consultation

- Gate status: `APPROVED`
- Scope reviewed: 猫店名称、供货商身份、动物交接调性、绒铃与灰栅的商业动机。
- Evidence inspected: `story-bible.md` 第 3–12 节。
- Acceptance gaps: 无。商业矛盾从抽象垄断变为对多农场供货权的直接威胁，且没有暴力加工展示。

### 🛡️ quality cross-department gate

- Gate status: `APPROVED`
- Scope reviewed: 原子交易、重复到账防护、动物误售防护、取消/失败回滚、无每日惩罚和当前未实现声明。
- Evidence inspected: 两份文档与本任务七条验收标准。
- Acceptance gaps: 无。
