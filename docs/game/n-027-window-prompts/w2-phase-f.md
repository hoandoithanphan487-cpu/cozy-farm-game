# 窗口 2 — Phase F：完成 N027JourneyTests（Q08 无损远行）全绿

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **Phase F（Q08 无损远行测试）**。领域服务（JourneyService / CampaignSaveCoordinator）已实现；本会话已修掉 4 处生产 bug 并写好了 `N027JourneyTests.swift`（12 例，当前 9 失败）。你的任务：把剩余失败修绿、删除临时探针、交付证据。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖、不接 LLM；不 spawn 子代理。
3. 工程是 PBXFileSystemSynchronizedRootGroup（objectVersion 77），新增 .swift 自动入 target；`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。
4. 测试命令（每次用全新 DerivedData）：`xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <fresh DD> [-only-testing:CreekSproutTests/<Class>] test CODE_SIGNING_ALLOWED=NO`
5. **多窗口并发**：编辑前先 `ls -lt` 查 mtime 并重读目标区域；只编辑本窗口“文件所有权”文件；以磁盘为准，绝不覆盖他窗改动；不要 git add/commit。
6. 编译警告冻结：只允许 2 条既有警告键（`N015MapLayoutContractTests.swift|farmNpcs`、`N015RuntimeConsumerMatrixTests.swift|document`），不得引入新警告。
7. 已定案决策（不重新争论）：近景说话人 ≤3 语义（npcStartAnchors 实体演员）；`selectIntent` guard 顺序（先 selectedChoiceID）；warning 夹具四要素（benefitOfferID/benefitBaselineDay==enteredDay(benefit)/benefitBaseline）+ q01 warning_1 后 `m3OffersPaused==true`；每段 completedActionIDs 要配 actionReceipts。
8. 台账只由窗口 8 汇总更新，本窗口不改台账。

## 1. 现状（已确认）

- 测试文件 `N027JourneyTests.swift` 已写好：12 例。2 通过（`testMissionAndPrecedingStagesAreMutuallyExclusive`、`testJourneyScenesLiveOnlyInAnchorCatalog`），9 失败，失败信息都是 `missionWriteFailed`——即 `prepareMission` 里武装 mission 候选（mission + frontstageLease(journey) + cursor + preMistRidgeVerified）在 `SaveStore.save` 时被 `SaveValidation.validate` 拒绝。
- 临时探针 `N027ProbeMissionTests.swift` 已写好但**未运行**。第一步直接跑它：
  `-only-testing:CreekSproutTests/N027ProbeMissionTests`
  它按 5 个检查点二分（ready / snapshot built / mission attached / protection verified / full armed candidate），失败点会以 `PROBE-FAIL: <label>` 报告。定位到哪一步被拒后，修对应内容（修领域校验或修测试夹具，判断依据见下）。

## 2. 本会话已落盘的生产修复（视为已定案，不要重做或回退）

1. `JourneyService.buildMissionSnapshot`：`missionInstanceID = brookseed.story.journey.mission.<campaignID>`、`settlementReceiptID = brookseed.story.receipt.q08.homecoming.<campaignID>`。原因：原拼接（内嵌 campaignID + .day_N）使 settlementReceiptID 超 120 字符，`ContentID.isValid` 恒失败 → buildMissionSnapshot 恒 notEligible。
2. `JourneyService.completeHomecoming`：结算记录 ID 改为 `<scenarioID>.journey_homecoming.<campaignID>`；并在保存 `campaignAuto` **之前**先覆盖写 `missionCurrent`（completed 态）。原因：原 settlementID 不符合 `SettlementRecord.makeID` 格式会被校验拒绝；若只写 campaignAuto，磁盘上旧的 travelling mission_current 会让 Continue 重选任务造成重复结算。exactly-once 顺序：missionCurrent(completed) → campaignAuto → 内存提交；receipt 双写阻止重发。
3. `SaveValidation.validateEconomy`：结算历史接受 `journey_homecoming.` 前缀的返乡结算 ID（≤120、ContentID 形状）。
4. `StoryRuntimeService.swift` 新增 `validMissionShippingEntryID`：mission 托运快照条目 ID 是真实 `ShippingEntry.mergeKey`（`<itemID>#<quality>#day<N>`），含 `#` 不是 ContentID 字符，原 `ContentID.isValid(entry.entryID)` 会拒绝一切带待售物的任务。校验改为结构校验（3 段、首段 ContentID、次段 normal/good/excellent、尾段 day+数字）。

## 3. 测试夹具已知要求（写夹具/修测试时遵守）

- `ShippingEntry.entryID` 必须等于 `ShippingEntry.mergeKey(...)`，且 `pendingEntries` 按 entryID 排序（creek_greens 在 mist_radish 前）。
- 农场格必须在 10×6（x 0–9, y 0–5）或 rearCultivableCells 内。
- q08 段：`evidenceCheckSerials[q08] > warningOneEvidenceCheckSerial`；q08 的 completedActionIDs 要配 actionReceipts；`relatedActionSerials[q08] > warningTwoEvidenceSerial`。
- q01–q07 resolved 链：每段 benefitOfferID/baselineDay/baseline、warning 序列、choice（q06 双槽：aftermath 槽记录排在 eruption 槽记录前）、standing receipt + effectReceipts + campaign.effectReceipts、care 收据日 ∈ [benefitDay, warningOneDay]。

## 4. 文件所有权

- 可编辑：`N027JourneyTests.swift`、`N027ProbeMissionTests.swift`（临时，用完删除）、`JourneyService.swift`、`SaveValidation.swift`、`StoryRuntimeService.swift`（后三者的上述 4 处修复已定案，只允许追加最小修复）。
- 禁止编辑：`N027Q02Q07BranchTests.swift`、`N027FosterSupplyTests.swift`、`N027StoryFixtures.swift`、`N027EndingTests.swift`、`N027TimelineTests.swift`、`ContentView.swift`、`FarmScene.swift`、`docs/game/project-ledger.md`。

## 5. 完成标准（对应 attachment Phase F 全部要求）

1. `N027JourneyTests` 12/12 全绿，0 failed；删除探针文件；无新警告。
2. 覆盖断言齐全：standing 90 才可 buildMissionSnapshot（89 拒绝）；mission 与 Q08 前置阶段互斥（SaveValidation 正反例）；两阶段提交（pre_mist_ridge 原子写成并复读 → mission_current；保护写失败时盘/内存不变；孤儿保护档被 Continue 忽略；mission 写成后 Continue 优先恢复活动任务）；三检查点 old_waterway→mist_ridge_fork→grey_fence_farm 顺序推进、强退后从最近写成的检查点恢复；有 pre_mist_ridge 时 abandon 回滚到保护档且幂等、缺保护档时 canAbandonToProtection=false + 诊断；返乡 exactly-once（候选内冻结待售结算 entry ID/数量/出发单价、作物安全推进一日且成熟保持可收、动物安全照料、唯一 settlement receipt、保存前崩溃不结算、保存后 receipt 阻止重发）；托管清单字段 coveredCropCellIDs/protectedAnimalIDs/frozenOrderIDs/shippingEntries 快照；三旅程场景只存在于 StoryAnchorCatalog.journeyScenes（不改 N-015 两图拓扑）。
3. 若发现第 2 条中某个行为与当前领域实现冲突，先跑最小复现（类似探针模式）证明是领域 bug，再最小修复并写进交接文件。

## 6. 交接输出

写 `artifacts/integration/n-027-main-story-runtime/phase-f-integration.md`：修复点、测试数（fresh DD 路径）、warning 集合、exactly-once 顺序说明、剩余风险。窗口结束时用中文给出一句结果 + 该文件路径。
