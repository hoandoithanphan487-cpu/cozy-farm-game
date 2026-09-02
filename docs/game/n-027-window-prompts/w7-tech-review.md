# 窗口 7 — 独立 🧱 tech 审查（防自批，只读；Phase C–H 中间门禁）

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 以 **独立 🧱 tech 审查者** 身份（与 🎮 gameplay 实现者不同的部门视角）执行 N-027 的 Phase C–H 技术门禁审查。**只读**：不改任何源码、测试、台账；唯一允许写的是 `artifacts/integration/n-027-main-story-runtime/tech-review.md`（结论只能是 `APPROVED` / `REVISE` / `BLOCKED`）。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖；不 spawn 子代理；禁止修改代码文件。
3. 若需复核测试结果，用全新 DerivedData 跑指定类（只读验证）。
4. 多窗口并发：只读审查，不与他窗冲突；若证据目录文件仍在变动，等待稳定后复核。
5. 台账只由窗口 8 汇总更新；本窗口结论写进 `tech-review.md`，供窗口 8 引用。

## 1. 审查对象与证据

- 实现：`Domain/StoryRuntimeService.swift`（状态机/成熟度/StoryStateValidation）、`StoryDialogueSession.swift`、`StoryBlockingResolver.swift`、`StoryCommandService.swift`、`JourneyService.swift`、`FinaleService.swift`、`Content/Story*Catalog*.swift`、`Persistence/CampaignSaveCoordinator.swift`、`Persistence/N027SaveValidation.swift`、`Persistence/SaveValidation.swift`、呈现层（窗口 5 交付）。
- 测试：全部 N027 测试类 + 窗口 1–6 的 handoff 与 `artifacts/integration/n-027-main-story-runtime/` 证据（phase-a-tech-gate.md / phase-b-integration.md / phase-c-tech-gate.md / phase-d..h-integration.md / tests/ / runtime/ / timeline-normal.json / timeline-recovery.json / story-content-audit.json / path-clearance.json / save-migration/）。

## 2. 必查清单（attachment §9）

1. **状态机原子性**：所有变更先构造候选 GameState 再整体提交；源事务与 StoryMetrics 同候选写入；重复触发/存读/强退不重复计指标、声誉、奖励、收据、日结。
2. **v10 迁移**：v0…v9 链式到 v10；迁移只注入中性默认，不追溯补发历史剧情指标；旧作物 dryStreak=0；二次保存字节/语义稳定。
3. **跨会话恢复**：line checkpoint + cursor + lease 一致；崩溃后先恢复已持久化会话；SaveValidation 拒绝互相矛盾的双活动状态（含 story/journey/finale/communityEvent 租约互斥）。
4. **文件边界**：十段剧情不塞进 FarmScene/GossipEventStatus/旧 DialogueDefinition；对白不解析 Markdown；50 cue 坐标只在 StoryAnchorCatalog。
5. **warning_2 与 eruption 不同会话连播**：warning_2 结束必须关闭会话归还控制；无相关可观察操作/锚点重进时 eruption 不得触发（测试与实现双向核对）。
6. **因果基线不重复计数**：benefit/offer 基线快照独立、只认快照后增量；通用劳动历史可提前累计但不提前触发。
7. **Q08 事务**（本会话已修的四处，重点复核正确性）：buildMissionSnapshot 的 ID 缩短（原 settlementReceiptID 超 120 字符）；completeHomecoming 结算记录 ID 改为 journey_homecoming 形态 + SaveValidation 接受；mission 托运快照条目 ID 用 validMissionShippingEntryID（mergeKey 含 #）；exactly-once 顺序「先覆盖 missionCurrent(completed) → 再写 campaignAuto → 内存提交」，以及 Continue 对 completed mission 的排除逻辑。
8. **Q09/Q10**：pre_reveal 在 Q09_DIS_001 前原子写成并复读、失败停留揭露外、永不自动 Continue；Q09 前 reveal_callback 零泄露；共谋名册完整（代表≠农场主）。
9. **警告冻结**：fresh DD 构建 warning 集合 == 2 条冻结键；Release 不含 DEBUG fixture。
10. 抽查相邻回归与全量 diff（窗口 6 证据）无新增失败/warning 标识。

## 3. 结论规则

- 全部通过 → `APPROVED`（写明证据路径）。
- 发现缺陷 → `REVISE`（逐条列缺陷、责任文件/窗口、修复后需重跑的验证），实现窗口返工后本窗口**必须重跑复闸**再给结论。
- 存在无法就地解决的依赖/产品决策 → `BLOCKED`（写明阻断项与所需决策）。
- 防自批：本窗口身份与 gameplay 实现者分离；最终结论仅供窗口 8 汇总，不得自行宣布任务 accepted。

## 4. 交接输出

`artifacts/integration/n-027-main-story-runtime/tech-review.md`：审查范围、逐项结论、复核命令与 DD 路径、最终门禁结论。窗口结束时用中文给出一句结论 + 该文件路径。
