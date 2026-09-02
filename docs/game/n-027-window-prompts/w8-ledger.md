# 窗口 8 — 台账汇总更新与最终交接报告（收尾）

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **收尾**：汇总窗口 1–7 的交付与门禁，更新台账 `docs/game/project-ledger.md`（N-027 行），补齐证据根下的汇总文件，给 Product Owner 出最终交接报告。本窗口**不写实现代码、不跑全量测试**（只引用既有证据；如需复核用只读命令）。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`（尤其 ledger 规则与 Completion report）、`docs/game/project-ledger.md` 全文、`docs/game/n-027-main-story-runtime-brief.md` 与 `-prompt.md`。
2. 禁止 git reset/restore/checkout/clean/commit；不联网；不 spawn 子代理；不改任何 Swift 源码、测试或既有证据（`phase-a-tech-gate.md`、`phase-b-integration.md`、`tests/baseline-*.txt` 等不得覆盖）。
3. 多窗口并发：本窗口只写台账 + 证据根下汇总 md；写台账前重读 N-027 行与 change log 最新内容，以磁盘为准。

## 1. 前置

- 窗口 1–7 全部完成：Phase D/F/G/H 测试全绿、呈现层与真实 App 证据落盘、相邻回归 225/0、全量无新增失败/警告、tech 门禁给出 `APPROVED`。
- 若任一窗口交付缺失或 tech 结论为 REVISE/BLOCKED：不得虚报，按实际状态写入台账并明确剩余缺口与返工窗口。

## 2. 台账更新（docs/game/project-ledger.md）

- N-027 保持 `active / PENDING`：追加实施记录、证据路径（artifacts/integration/n-027-main-story-runtime/ 各文件）、部门门禁结论（gameplay SUBMITTED、tech、design/economy、content/world、ux、quality 各自结论来源）、下一负责人 = **Product Owner 最终自然计时试玩签核**（完整 5–6 小时判断）。
- **不得**自行标记 `accepted`；**不得**改变 N-016/17/18/19/012 状态；不得改 N-027 的 Task ID 与依赖列。
- 追加一条 change log 条目（日期、结论、证据、下一负责人）。

## 3. 证据根汇总文件（补齐或聚合，不覆盖既有）

在 `artifacts/integration/n-027-main-story-runtime/` 下：
- `gameplay-handoff.md`：玩家现在能做什么、Q01–Q10 是否全部接通、正式新游戏/保苗/Q08/毕业是否可运行、改动文件清单、已知限制。
- `design-review.md`、`content-review.md`、`ux-review.md`、`quality-review.md`：聚合窗口 1–6 证据给出对应部门视角结论（明确 `APPROVED / REVISE / BLOCKED`；缺证据的项写「证据待补」，不得编造结论）。
- `tech-review.md`：直接引用窗口 7 的结论（不要重写）。
- `file-boundary-audit.txt`：十段剧情相关文件的职责清单与边界检查（对白/坐标/状态机/呈现分层，不塞 FarmScene/GossipEventStatus）。

## 4. 最终回复格式（给 Product Owner，中文，简洁可核查）

### 结果（玩家现在能做什么；Q01–Q10 接通情况；正式新游戏、保苗、Q08、毕业可运行性）
### 关键实现（状态机、指标、v10、灌溉、对话、动线、Q08、保护存档、画廊 + 关键文件链接）
### 验证（专项数、相邻 225/0、全量 464/450/14/2 与 diff、两条时间线、真实 App 证据）
### 门禁（gameplay/tech/design-economy/content-world/ux/quality 各结论与证据）
### 状态与下一步（N-027 保持 active / PENDING；唯一下一负责人 = Product Owner 最终自然计时试玩；列出任何范围内缺口）

## 5. 完成标准

- 台账 N-027 行为 `active / PENDING` 且记录完整；N-016/17/18/19/012 未变。
- 证据根汇总文件齐全；无编造的门禁结论或测试数字。
- 最终报告可直接转给 Product Owner。

窗口结束时把最终报告全文输出给用户。
