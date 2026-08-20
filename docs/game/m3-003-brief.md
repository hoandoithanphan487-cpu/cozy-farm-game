# Studio task: M3-003 社区事件五行动状态机、风评、信任定点计算与存档回放

**Status:** accepted / APPROVED（2026-08-18；🧱 tech 与 🛡️ quality 双门禁通过；本文件为验收后补档合同，任务实际交付以 `artifacts/integration/m3-003-xcode/cursor-handoff.md` 为准）  
**Role contract:** 专项负责人 🎮 gameplay；部门质量负责人 🧱 tech；下游独立复核 🛡️ quality（🛡️ 门禁由 Hermes 只读执行，未修改源码）。  
**合同来源:** 任务登记表 M3-003 行（验收要点：三条互斥夹具、边界恢复路径、主线不软锁）+ PRD 6.9.2–6.9.4、6.10、6.12 + TDD 7.9 + PRD 第 14 节第 5/6 项夹具定义。

## 1. 玩家结果

第 2 个脚本化游戏日，溪岸集市触发一次"闸板传闻"社区消息事件（截止第 3 天 23:30）。玩家可在涧麦婶处用 **Y/B** 键选择三种初始应对之一：未经核实便转述（风评 50→42，波及角色当日信任增长归零、次日首次交谈加成减半）、暂不判断（风评不变，截止后无惩罚到期）、开始核实（携带证据与青砚交谈核实，再与絮宁交谈纠正，风评 50→58，水脉 +2 或职能角色信任 +3，仅结算一次）。风评 39 的合成边界下可选奖励节点在 31 暂停、纠正后 47 恢复；无论走哪条社交分支，水渠主线 12+8=20 始终可达、不软锁。所有状态变化、行动历史与信任子点余数随存档保存，完全退出并重启后逐项一致，同一存档与选择序列可重复复现。

## 2. 责任与交付顺序

1. **🎮 gameplay（唯一实现负责人，Cursor）**：实现数据模型、五行动状态机、风评与信任定点领域服务、存档 schema v6 与迁移、SpriteKit HUD 反馈与聚焦测试；遵守现有 Swift 分层、稳定 ID 与内容验证。
2. **🧱 tech（部门质量负责人）**：审查事务原子性、幂等、状态所有权、内容验证、存档兼容、失败回滚与测试证据，返回 `APPROVED | REVISE | BLOCKED`。
3. **🛡️ quality（独立复核，Hermes 只读）**：对同一候选构建独立核验 xcresult 计数、原始日志、截图 OCR、存档 JSON 与跨进程存读，返回明确质量门禁。
4. **🎬 director**：仅在 🧱 tech 与 🛡️ quality 均 `APPROVED` 后登记验收；实现者不得自行将 M3-003 标为 accepted。本任务因历史无合同开工，补档合同与台账登记由 director 在双门禁后完成。

## 3. In scope

- **社区事件五行动状态机**：稳定行动 `relay_unverified` / `defer_judgment` / `start_verification` / `verify_with_c` / `correct_d`；七状态 `offered → deferred / investigating → verified → resolved_relay / resolved_corrected / expired`；数据驱动迁移表，ContentValidator 校验合法迁移、终态不可再迁移、所有状态从 `offered` 可达。
- **事件调度与截止**：第 2 天开始 `offered`、截止第 3 天 23:30；截止先于同一分钟提交的行动结算；到期事件进入历史且不重复到期。
- **社区风评**：0–100、新游戏 50、与职能角色信任分离存储；转述 −8、纠正 +8、暂不判断/到期 0；普通交谈不扣风评/信任；日结摘要、角色对白或邻居行为可见反馈，不使用说教文本。
- **信任定点计算**：1 显示点 = 100 信任子点，`Int64` 定点运算保留余数并随存档保存；每日首次交谈基线 +300 子点，高风评 +330、低风评 +255；转述波及当日归零、次日首次交谈 ×0.50 仅一次；`correct_d` 一次性 +300 平额不参与倍率。
- **风评区间与可选门槛**：70–100 → +10%、41–69 无修正、0–40 → −15%；`min_standing` 仅允许可选奖励节点（边界固定 41），未达标暂停而非失败，必须配置不受同一门槛限制的恢复路径（"纠正絮宁 +8"与"青砚一步核实 +5"）；内容验证拒绝主线关键路径配置 `min_standing`。
- **correct_d 奖励策略**：`watershedElseRelationship` —— 水渠主线未完成时水脉 +2（一次性，不进入 12+8 主线保底），已完成则对应职能角色信任 +300；`grantedEffectIDs` 防重。
- **存档 schema v6**：携带 `community`（事件、行动历史、standing、effect 记录）与 `relationships`（信任子点、余数、效果）；v5 存档迁移到合法默认；非法写入保留最近有效存档；行动历史断序/重复/非法枚举安全拒绝。
- **最终角色名**：邻居 C/D 采用最终名"青砚/絮宁"（`ContentID.requiredNeighborDisplayNames` 强制，旧名"老耿/阿棉"被验证拒绝）；事件触发邻居使用"涧麦婶"。
- **最小 HUD 与反馈**：风评、事件状态/截止、信任明细、可选节点暂停/恢复、可用行动提示；Y/B/V 键提交（转述/纠正/青砚一步核实）；文字反馈非仅颜色；沿用原创占位表现，不要求正式美术或音频资产。

## 4. Out of scope

- 赠礼系统、角色日程表、完整社交支线任务链、独立任务系统扩展（PRD 6.9 其余部分未含项）。
- D0 的 45–60 分钟完整 Demo、正式像素美术/音乐、完整音频混音、性能优化、手柄专项、HUD 排版打磨与发行打包。
- 新经济曲线、额外社区事件、随机事件调度（VS-1 仅一次固定事件）。
- Godot 文件、PRD、TDD、项目台账以外的计划基线；不得删除既有 M1–M3 证据或重写稳定内容 ID；M3-002 的 12+8=20 主路径不得被社交奖励改变或回退。

## 5. 最小可观察验收

1. 新游戏与既有 M1/M2/M3-001/M3-002 路径不回归；两张地图与七名角色（涧麦婶、青砚、絮宁等）仍可达且名称正确（无"老耿/阿棉"）。
2. 第 2 天事件 `offered`、风评 50、截止第 3 天 23:30；截止同一分钟提交行动返回无活动事件且事件已过期。
3. 转述夹具：风评 50→42，行动历史 1 条，波及角色当日后续信任增长归零、次日首次交谈 +1.50 只应用一次、再日恢复 +3.00；重复提交幂等。
4. 暂不判断夹具：保存→完全退出→重启→读取仍 `deferred`、风评 50；截止后无惩罚 `expired`、不重复到期。
5. 核实+纠正夹具：`investigating → verified → resolved_corrected`，行动历史 3 条连续，风评 50→58，水脉 +2（主线未完成时）或信任 +300（主线已完成时），重复纠正不重复发奖。
6. 合成边界夹具：初始风评 39 → 转述后 31 可选节点暂停（`min_standing=41`）、纠正后 47 恢复；两条分支水渠主线均不暂停、可继续 12+8。
7. 主线不软锁：内容验证拒绝主线关键节点配置 `min_standing`；所有可选门槛声明无门槛恢复路径；水渠 0→12→20 在任何社交分支下可达且不回退。
8. 普通交谈（邻居/职能角色）只可能影响每日首次交谈信任，不改变风评、水脉、任务或事件状态。
9. 信任定点：+300/+330/+255 与余数保留符合 TDD 7.9；64 位上限值无溢出；schema v6 存读、v5→v6 迁移、非法存档拒绝（断序、重复、越界、非法枚举）后最近有效存档保持。
10. 既有 XCTest 全绿（含 M3-002 回归 127 项），新增 53 项覆盖上述正反例；未复制任何受保护任务、地图、对白、视觉或音频表达。

## 6. 文件边界与证据

实现文件：`macos/CreekSprout/CreekSprout/Content/CommunityCatalog.swift`、`GossipDefinitions.swift`、`ContentValidator.swift`、`ContentID.swift`、`ContentCatalog.swift`；`Domain/CommunityState.swift`、`RelationshipState.swift`、`GossipService.swift`、`RelationshipService.swift`、`ResolveGossipActionUseCase.swift`、`CommunityCommandService.swift`、`GameState.swift`、`DayCycleService.swift`、`QuestService.swift`；`Persistence/SaveGameDTO.swift`、`SaveMigrator.swift`、`SaveValidation.swift`、`SaveStore.swift`；`FarmScene.swift`、`ContentView.swift`；测试 `CreekSproutTests/CommunityEventTests.swift`、`CommunitySaveTests.swift`、`CommunityContentTests.swift`、`WatershedSaveTests.swift`（schema 断言）。未修改 `project.pbxproj`（同步文件组自动收录）、Godot 文件、PRD、TDD、台账。

最小证据（全部在 `artifacts/integration/m3-003-xcode/`）：`cursor-handoff.md`；`xcode-evidence/` 下 `build-test-raw.log`、`TestResults-M3-003.xcresult`、`test-summary.json`（180/180/0/0）、`environment.txt`、`git-status-before.txt`、`m3-003-files.txt`、`runtime-smoke.md`、`lifecycle-smoke.md`、`XCODE-RESULT.md`、10 张运行截图、7 个存档 JSON 样本；`cursor-static-check/`（180/180 逻辑包 + 领域 harness）；`hermes-review.md`（双门禁报告，含 SHA-256 一致性核对与独立 xcresult 查询）。

## 7. 合同门禁

- 🎬 Direction & Production：合同补档 `APPROVED`。范围、唯一专项负责人、质量负责人、文件边界与最小证据符合 DEC-015；补档不改变已验收事实。
- 🧱 Engineering & Pipeline：`APPROVED`。状态机迁移、截止优先、幂等与原子回滚、信任定点、schema v6/v5→v6、内容验证与 180/180 XCTest 均通过源码复核。
- 🌱 Design & Player Experience（跨部门规则复核）：`APPROVED`（体现于 hermes-review 对 PRD 6.9/6.10 与 TDD 7.9 的一致性逐项核对；主线无社交门槛、可选节点恢复路径、信任数值与边界夹具均符合设计）。
- 🛡️ Quality & Delivery：`APPROVED`。xcresult 独立查询 180/180、0 failed、0 skipped、0 编译警告；10 张截图 OCR 与 7 个存档 JSON 覆盖三夹具、边界 31/47、水渠 20 回归与普通交谈；跨进程存读 B/C/D 全一致；证据树 SHA-256 与主仓库逐字节一致。
- 交付条件（非阻断）：C1 本补档合同；C2 `lifecycle-smoke.md` 中 defer 存档文件名引用 `fixture-b-defer-initial.json` 应为 `fixture-c-defer-initial.json`（内容核实为 defer 夹具，建议 director 顺手修正）；C3 可选补 pgrep 转储。
- 当前交付门禁：`APPROVED`；M3-003 已由 🎬 director 于 2026-08-18 依双门禁证据登记 `accepted / APPROVED`，M3 阶段关闭为 `accepted`（G3 退出门禁达成）。
- 下一负责人：D0-001 的 🧱 tech / 🛡️ quality。
