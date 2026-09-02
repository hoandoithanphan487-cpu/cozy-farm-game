# N-020 — 专用游戏规则与剧情设定

## Player outcome

玩家和后续开发者可以在独立文档中清晰理解《溪谷新芽》的农作保苗、社交影响、剧情边界，以及隐藏任务《雾岭失踪的猫猫公主》的触发、流程、保护和结局规则。

## Current context and assumptions

- Product Owner 于 2026-08-27 授权先将该剧情写入专用游戏剧情与游戏规则文档（DEC-042）。
- 当前游戏已有农作、水脉、风评、七名社区角色与溪火猫食铺美术呈现；猫食铺正式 NPC、剧情与隐藏任务尚未实现。
- “恋爱”可写暧昧、确认关系、磨合、和好或分开；不写求婚、结婚、育儿或多代家庭。
- “圆满完成”指主要矛盾都得到负责任的善后，不要求唯一对话正解或所有人维持恋爱/友情关系。

## Ownership

- Department: 🎭 World & Content
- Department quality owner: 🎭 `content`
- Specialist owner: 📖 `narrative`
- Consulted: 🌱 `design`
- Downstream reviewer: 🛡️ `quality`
- 防自我批准：叙事产出后由内容门检查世界一致性与原创性，再由玩家体验视角跨部门复核。

## Dependencies and preflight

- M0-004: `accepted / APPROVED`
- M3-003: `accepted / APPROVED`
- N-005: `accepted / APPROVED`
- N-014: `accepted / APPROVED`
- DEC-042: 已登记
- Preflight: `PASS`

## In scope

- 新建 `docs/game/game-rules.md`。
- 新建 `docs/game/story-bible.md`。
- 收录农作保苗、枯萎保护、社区协作与剧情边界。
- 完整定义隐藏任务的触发、远行托管、三段路程、多解法对峙、返乡和纪念奖励。
- 明确当前基线与后续实现合同的区别。

## Out of scope

- 不修改 Swift、Xcode 工程、存档 schema、经济、地图或玩法状态。
- 不创建新稳定 ID，不声称隐藏任务已实现。
- 不覆盖或重做 N-005/N-014/N-019 美术资产。
- 不改变 N-016、N-017、N-018、N-019 或 N-012 的现有状态。

## Acceptance criteria

1. Given 两份专用文档，When 读者检索隐藏任务，Then 规则与剧情双向链接且无互相矛盾。
2. Given 隐藏任务触发，When 任一主要剧情以负责任结局收束且声誉≥90，Then 不因非唯一“最佳结局”而被拒绝。
3. Given 玩家开始远行，When 任务中断、失败或完成，Then 货币、物品、作物、订单和主要关系无损失。
4. Given 灰栅农场对峙，When 玩家选择证据、商业联合或营救路线，Then 均可无战斗完成。
5. Given 任务未触发，When 玩家继续游戏，Then 声誉、剧情善后与任务本身均无不可逆截止期。
6. Given 剧情边界，When 审查角色关系，Then 仅含恋爱而不含求婚、结婚、育儿或多代系统。

## Required evidence and gates

- 文档存在、非空、双向链接。
- 关键规则静态检索通过。
- `git diff --check` 通过。
- 🎭 content: 原创性、调性、人物边界 `APPROVED`。
- 🌱 design: 触发、保护、恢复和奖励规则 `APPROVED`。
- 🛡️ quality: 无永久错过、无经济损失、无不可见惩罚 `APPROVED`。

## Originality boundary

- 猫群、溪火猫食铺、绒铃、灰栅农场、雾岭路线、对白、地标和任务顺序均为本项目原创表达。
- 仅使用“远行营救、证据对峙、商业垄断”等通用叙事功能，不复刻任何现有作品的角色、地图、台词或事件顺序。

## Specialist handoff and gates

### 📖 narrative handoff

- Outcome: 两份专用文档已建立，隐藏任务从触发到谢幕的完整路径已写明。
- Changed artifacts: `docs/game/game-rules.md`、`docs/game/story-bible.md`、`docs/game/n-020-brief.md`。
- Decisions: “公主”为猫群尊称；反派以商业垄断和扣留构成威胁；三条无战斗路线共享正面完成状态。
- Risks: 正式实现前仍需锁定稳定 ID、存档 schema、地图、猫食铺 NPC 和主要剧情状态。

### 🎭 content gate

- Gate status: `APPROVED`
- Scope reviewed: 人物动机、恋爱边界、轻冒险调性、原创性与前置剧情回响。
- Evidence inspected: `story-bible.md` 全文、`game-rules.md` 第 3–8 节。
- Acceptance gaps: 无。绑架只作为非暴力扣留和商业胁迫前提，未跨入战斗或不可逆悲剧。

### 🌱 design gate

- Gate status: `APPROVED`
- Scope reviewed: 触发条件、“负责任善后”判定、远行托管、日结、三路线完成与奖励平衡。
- Evidence inspected: `game-rules.md` 第 5–9 节。
- Acceptance gaps: 无。基础产量不受社交惩罚；远行日出售仅依价格快照结算一次；奖励不可出售且不引入强力经济优势。

### 🛡️ quality cross-department gate

- Gate status: `APPROVED`
- Scope reviewed: 可理解性、无永久错过、无不可见惩罚、中断/重试安全和当前实现状态诚实性。
- Evidence inspected: 两文档双向链接；声誉≥90；无截止期；作物、货币、物品、订单保护；当前未实现声明。
- Acceptance gaps: 无。
