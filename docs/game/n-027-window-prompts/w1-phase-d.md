# 窗口 1 — Phase D：修复 Q02–Q07 分支与代养单 9 个失败测试

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **Phase D（Q02–Q07 装填验证）**：把并发会话遗留的 9 个失败测试修绿。领域实现（StoryRuntimeService / FosterSupplyService / CatShopSupplyService）已经过 Phase C/E tech 门禁，本次**只修测试与测试夹具**，除非能证明领域 bug（必须记录证据）。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`。
2. 禁止 git reset/restore/checkout/clean/commit；保留工作树全部用户改动；不联网、不装依赖、不接 LLM；不 spawn 子代理。
3. 工程是 PBXFileSystemSynchronizedRootGroup（objectVersion 77），新增 .swift 自动入 target；`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，跨隔离传函数值需 nonisolated。
4. 测试命令（每次用全新 DerivedData，不要复用其它窗口的 DD）：
   `xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <fresh DD> [-only-testing:CreekSproutTests/<Class>] test CODE_SIGNING_ALLOWED=NO`
5. **多窗口并发**：本仓库正被多个窗口并行使用。每次编辑前先 `ls -lt` 查看目标文件 mtime 并重读目标区域最新内容；**只编辑本窗口“文件所有权”列出的文件**；发现他窗改动以磁盘为准，绝不覆盖。N-027 文件大多未跟踪（git status 显示 ??），不要 git add/commit。
6. 编译警告冻结：全工程只允许 2 条既有警告键（`N015MapLayoutContractTests.swift|farmNpcs`、`N015RuntimeConsumerMatrixTests.swift|document`），不得引入任何新警告。
7. 已定案决策（不得重新争论）：
   - 近景说话人 ≤3 统计该 cue 站位计划（npcStartAnchors）中的实体演员，排除 system/ledger。
   - `selectIntent` guard 顺序：先 `selectedChoiceID`，再 `intentsPending`/`pendingChoiceIDs`。
   - 构造 warning 阶段夹具必须带 `benefitOfferID` / `benefitBaselineDay(==enteredDay(benefit))` / `benefitBaseline`；q01 进入 warning_1 后 `m3OffersPaused == true`。
   - 每段 `completedActionIDs` 都要有对应 `actionReceipts`（receiptID = `brookseed.story.receipt.action.<shortCode>.<actionID>`），且 `lastRelatedActionSerial == completedActionIDs.count`。
   - 所有经 SaveStore 的保存都过 `SaveValidation.validate`（含 validateN027）；夹具必须整体合法。
8. 台账 `docs/game/project-ledger.md` 只由窗口 8 汇总更新，本窗口**不要改台账**。

## 1. 现状（已复验，勿推翻）

- Phase A/B/C 全部通过：PhaseATests 41、CropIrrigation 13、MorningCropReport 9、FormalSession 9、StoryDialogue 12、StoryBlocking 8、Q01VerticalSlice 2。
- Phase D 当前 9 个失败（fresh DD 复验，2026-08-31 00:37）：
  - `N027Q02Q07BranchTests`：`testAllQ02Q07FixedBranchesCompleteWithFixedPlusSix`、`testQ07CelebrationReservationHoldsInventoryUntilResolved`、`testRepairCommissionsThreeMaxEachPlusSixOnlyBelowNinety` → `invalidContents`。
  - `N027FosterSupplyTests`：`testAcceptAddsAnimalWithoutMoney`、`testCancelAtomicallyReturnsAnimalWithoutMoney`、`testConvertToPartnerOncePerCampaignAndPermanentlyBlocksSupply`、`testIssueRequiresQ05ResolvedAndSingleActivePerCampaign`、`testReplacementAfterCloseAndOriginalAnimalNeverRequalifies` → `invalidContents`；`testFulfilmentOnlyThroughFinalSuccessfulCatShopReceipt` → 期望 `animalNotFound` 实得 `duplicateRequest`。
- 失败根因（已定位，直接照此修）：
  1. 夹具缺 `benefitOfferID` / `benefitBaselineDay` / `benefitBaseline`（validateN027 对非 locked 段强制要求）。
  2. 链式规则：某段非 locked 时，前一段必须 `resolved` 且 `previousResolvedDay <= benefitDay`。runBranch/unlockedState 只构造目标段，q01–q04 却是 locked → 拒绝。
  3. q01 过 warning_1 后 `m3OffersPaused` 必须为 true（`shouldPauseM3` 一致性）。
  4. `completedActionIDs` 缺对应 `actionReceipts`（validateReceiptLinks）。
  5. Q06 特殊：`romanceTender` 必须与两个 care 行动完成度一致；care 收据日须落在 `[benefitDay, warningOneDay]`；choices 按 (arc,slot,choiceID) 排序（aftermath 槽排在 eruption 槽前）；`q06Outcome` 由 eruption 选择 + romanceTender 推导，aftermath 选择 ID 必须等于推导结果。
  6. FosterSupply 的 `testFulfilment...`：第二次 `supplyAnimal` 复用了同一 requestID，命中 exactly-once 的 `duplicateRequest`。第二次调用改用**新的 requestID** 再断言 `animalNotFound` 即可（语义：动物已不在，不是重复请求）。
- 参考（只读）：`N027JourneyTests.swift` 里的合法夹具模式（resolvedSegment / applyResolvedArc / journeyReadyState，已通过 SaveValidation）；`N027Q01VerticalSliceTests.swift` 走真实 StoryDirector 流程的模式。优先用真实服务流（unlockEligibleBenefit → requestWarningOne → recordAction → requestWarningTwo → recordAction(anchorReentry) → requestEruption → 对话 → selectIntent → closeDialogue → +2 日 → resolveResponsibleAftermath）驱动分支，或照 N027JourneyTests 的手工合法夹具修。

## 2. 文件所有权（只改这些）

- `macos/CreekSprout/CreekSproutTests/N027Q02Q07BranchTests.swift`
- `macos/CreekSprout/CreekSproutTests/N027FosterSupplyTests.swift`
- `macos/CreekSprout/CreekSproutTests/N027StoryFixtures.swift`（可修可弃用；其 targetFixture 缺 m3OffersPaused/actionReceipts，同源 bug）
- 仅当（且仅当）能证明领域 bug 时：`FosterSupplyService.swift` / `CatShopSupplyService.swift` 最小修改并记录证据；否则禁止碰领域代码。

**禁止编辑**（他窗所有权）：`N027JourneyTests.swift`、`JourneyService.swift`、`SaveValidation.swift`、`N027SaveValidation.swift`、`StoryRuntimeService.swift`、`N027EndingTests.swift`、`N027TimelineTests.swift`、`ContentView.swift`、`FarmScene.swift`、`docs/game/project-ledger.md`。

## 3. 完成标准

1. `N027Q02Q07BranchTests` 5/5、`N027FosterSupplyTests` 6/6 全绿（0 failed）。
2. Phase A–C 回归不破（上述 7 个类保持 0 failed）；fresh DD 一次跑全 N027 现有类确认。
3. 构建输出无新警告（只有 2 条冻结键）。
4. 分支断言保持不变：Q02 4 分支、Q03 3、Q04 3、Q05 3、Q06 3、Q07 4 共 23 次跑通，每次 `+6` 恰好一次、分支间不额外加减 standing（50→86）；Q06 三结果互斥可存读；Q07 庆典库存保留到 resolved 后释放；修复委托 ≤3、每项 +6、≥90 后关闭；代养单不变量（唯一 issuanceID、单 active、取消原子退还、转伙伴每 campaign 一次且永久不可供货、收入只来自成功猫店收据、原动物不可换新资格）各跑正/反例。

## 4. 交接输出

写 `artifacts/integration/n-027-main-story-runtime/phase-d-integration.md`：修复点、测试数（fresh DD 路径）、warning 集合、剩余风险。窗口结束时用中文给出一句结果 + 该文件路径；不要把本 Prompt 重新解释给用户。
