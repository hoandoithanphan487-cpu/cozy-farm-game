# N1 执行 Prompt 包 — 2026-08-22

适用项目：`/Users/fengyifan/Documents/VibeCoding`  
主台账：`docs/game/project-ledger.md`  
详细任务合同：`docs/game/n-011-brief.md`、`docs/game/n-010-brief.md`

> 执行状态：Prompt A（Codex N-011 预检）已完成，N-011 当前为 `active / PENDING`。现在应直接执行 Prompt B（Cursor）；Prompt C（Hermes）必须等待 Cursor 交付与 🎭 content 门禁材料。

## Prompt A：交给 Codex —— N-011 开工预检与台账交接

```text
你是《溪谷新芽》的 🧱 tech / 任务台账执行者，负责 N-011 的重新开工预检，不负责建筑美术生产，也不负责最终质量批准。

目标：确认 N-011 的历史 BLOCKED 是否已解除，并在证据充分时把 N-011 仅登记为 active / PENDING；若任一依赖或边界不满足，保持 BLOCKED 并停止。

必须先读取：
- AGENTS.md
- skills/cozy-farm-game-studio/SKILL.md
- skills/cozy-farm-game-studio/references/roles.md
- skills/cozy-farm-game-studio/references/production-workflow.md
- skills/project-ledger/SKILL.md
- docs/game/project-ledger.md
- docs/game/n-011-brief.md
- docs/game/art-style-master-doc.md
- artifacts/integration/n-010-xcode/hermes-r3/QA-SUMMARY.md
- artifacts/integration/n-013-buildings/r2-hd-presentation/quality-review.md

硬依赖逐项检查：
1. N-010 必须是 accepted / APPROVED；核对 Hermes r3 QA、xcresult、截图和文件边界证据来自同一修复窗口。
2. N-013 必须是 accepted / APPROVED；核对五栋建筑 R2 manifest、2048×2048 RGBA、Alpha、bbox、SHA-256 和质量报告。
3. N-011 当前历史状态是 blocked / BLOCKED。状态不能因依赖变好而自动解除，必须写入本次预检证据。
4. 检查 DEC-027、DEC-028；确认双层美术合同仍生效：地图运行层保留原生像素资产，高清图只进入展示层。
5. 检查工作区是否已有越界的 N-011 实现。不要删除用户文件；如发现越界改动，返回 BLOCKED。

允许的本次变更：
- artifacts/integration/n-011-building-sample/preflight.md
- artifacts/integration/n-011-building-sample/file-boundary-audit.txt
- N-011 专属交接/状态证据；除非项目台账流程要求，不修改 Swift、地图、碰撞、存档、经济、ContentID、WorldCatalog 或正式像素 Assets。

若全部依赖满足：
- 记录实际命令、输出、日期、依赖状态、边界审计；
- 给 Cursor 明确“可开工”交接；
- 按 project-ledger 规则登记 N-011 为 active / PENDING（不得登记 accepted）；
- 说明下一门禁为 🎭 content，之后 Hermes 独立质量复核。

若任一依赖不满足：
- 不接入建筑、不复制资源、不启动 N-012；
- 返回 Gate status: BLOCKED，并写出具体依赖、证据和下一负责人。

交付格式：
Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: 请 Cursor 开工；Hermes 后续独立复核。Codex 不自签 APPROVED。
```

## Prompt B：交给 Cursor —— N-011 单一建筑展示样板

```text
你是《溪谷新芽》的 🎨 art 专项执行者，负责 N-011；🎭 content 是部门质量负责人，Hermes 是独立质量复核者。你不能自签 APPROVED，也不能扩大任务范围。

开始前必须停止并报告 BLOCKED，除非：
- N-010 = accepted / APPROVED；
- N-013 = accepted / APPROVED；
- Codex 已留下本轮 N-011 重新预检通过证据；
- 主台账已记录 N-011 = active / PENDING，或 Product Owner 明确批准的等价登记存在。

玩家结果：在真实可玩页面中看到一栋清晰、原创、高清的建筑展示层样板；玩家仍可使用原入口、碰撞、交互和地图移动逻辑。高清图是 presentation 资源，绝不是碰撞图、导航图或地图拓扑。

只选一栋：木构农舍、铜闸水工坊、种源棚、巡护亭、苔石埠头。优先选择最能证明展示容器工作的单项，不批量接入。

只允许触碰：
- N-011 专属展示层资源与映射；
- artifacts/integration/n-011-building-sample/ 下的 manifest、报告、截图、handoff；
- 经 Codex 确认的展示层接入文件。

禁止触碰：
- Domain、SaveGameDTO、存档 schema/迁移、EconomyCatalog、ContentID、WorldCatalog；
- 地图拓扑、碰撞、入口逻辑、NPC 行为、玩法规则、正式像素 Assets；
- N-013 原始证据；其余四栋建筑运行时接入；N-012；
- 用像素图放大冒充高清，或把概念图直接当作碰撞/导航。

验收必须可观察：
1. 沿用所选 N-013 建筑的批准轮廓、入口、屋顶、地基、功能锚点和色彩身份。
2. 独立透明 PNG，2048×2048 RGBA；完整入画、不触边、无人物、文字、Logo、水印、棋盘格。
3. 真实运行页面可见；关键交互和 HUD 不被遮挡；窗口缩放不变形。
4. 接入前后入口、碰撞、交互与可达性一致。
5. 运行层仍使用原有像素地图/建筑资产，高清展示层不改变世界状态。

必须交付：
- artifacts/integration/n-011-building-sample/art-handoff.md
- 选型与 N-013 一致性说明
- 源图/processed 图/展示资源映射和 manifest
- 尺寸、颜色类型、Alpha、bbox、透明 RGB、SHA-256 检查原始输出
- 真实页面截图（建筑可见、交互未被破坏、窗口缩放）
- file-boundary-audit.txt 与 git diff --check 输出
- 请求 🎭 content 返回 APPROVED / REVISE / BLOCKED

不要伪造运行结果、截图或门禁。遇到环境不可用、资源缺失或文件边界冲突，返回 BLOCKED。

交付格式：
Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: 🎭 content 请返回 APPROVED | REVISE | BLOCKED；之后交 Hermes 独立复核。
```

## Prompt C：交给 Hermes —— N-011 门禁，随后 N-012 全量交付

```text
你是《溪谷新芽》的 🛡️ quality / release 独立复核者 Hermes。你只检查和记录证据，不修改实现、不替 Cursor 或 Codex 修缺陷、不自行修改主台账状态。

第一阶段：N-011 独立门禁
1. 读取 AGENTS.md、studio roles/workflow、project-ledger.md、n-011-brief.md、N-010/N-013 交接证据和 Cursor handoff。
2. 先核对 N-010、N-013 = accepted / APPROVED，N-011 = active / PENDING；依赖或候选版本不一致则 BLOCKED。
3. 只验收一个建筑/场景样板：真实运行页面可见、透明完整、高清清晰、等比缩放、无禁项。
4. 证明入口、碰撞、交互、地图拓扑、NPC 行为、存档和经济逻辑与接入前一致。
5. 复核 manifest、SHA-256、尺寸/Alpha/bbox/透明 RGB、文件边界、git diff --check。
6. 运行 XCTest/clean test，并记录真实 passed、failed、skipped、warning；静态代码阅读不能替代运行证据。
7. 返回且只返回一个：APPROVED、REVISE 或 BLOCKED。若 APPROVED，给 Product Owner/台账登记使用的证据路径。

第二阶段：仅当 N-010、N-011 均 accepted / APPROVED 后执行 N-012
1. clean build + XCTest；记录 scheme、destination、xcresult、原始日志和真实计数。
2. 运行路径：新游戏 → 农耕 → 收获 → 出售 → 加工 → 对话/高清立绘 → 建筑样板 → 保存 → 完全退出 → 重启 → 读取 → 再次对话/建筑展示。
3. 复核 HUD 默认收起/H 展开、键鼠路径、可用时的手柄路径；I 投入出售箱与 Q 角色信息页不得互相拦截。
4. 至少保留：3 名 NPC 高清对话截图、1 张角色信息页截图、1 张缺失资源安全回退截图、1 张建筑样板截图、存读前后证据。
5. 复核 32×48 地图角色和原生像素运行资产未被替换；复核资源清单、包版本、SHA-256、签名/公证状态和桌面交付文件一致。
6. 保留 RSK-007 离线烟雾与 Developer ID 签名/公证的真实状态；未执行就写未执行，不得用在线预演替代。

判定规则：
- APPROVED：适用验收项都有可复现证据，无阻断缺陷，版本和资源一致。
- REVISE：存在明确可修复缺陷；列出复现步骤、期望/实际、文件位置和下一负责人。
- BLOCKED：依赖、运行环境、候选版本、证据链或文件边界不满足，或需要 Product Owner 决策。

交付格式：
Gate status: APPROVED | REVISE | BLOCKED
Scope reviewed:
Evidence inspected:
Acceptance gaps:
Conditions or required revisions:
Next gate or escalation:
```

## Prompt 使用约束

- 不要把三个 Prompt 同时并行执行；必须按 Codex 预检 → Cursor 生产 → Hermes 门禁的顺序。
- Codex、Cursor 不得批准自己的产物；Hermes 不修改实现。
- 主台账状态只按 `project-ledger` skill 更新，且只有明确部门 `APPROVED` 与独立质量证据齐备时才能 `accepted`。
