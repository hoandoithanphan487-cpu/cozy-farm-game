# 窗口 3 — Phase G：新增 N027EndingTests（Q09/Q10、毕业与画廊）

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **Phase G（Q09/Q10 终局测试）**。领域实现（FinaleService + FinaleBeat：locked→pre_reveal_save_pending→discovery→confrontation→final_action_pending→graduated；CampaignSaveCoordinator 的 pre_reveal 保护槽）已完成。你的任务：新增测试类 `N027EndingTests` 并跑绿。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖、不接 LLM；不 spawn 子代理。
3. 工程 PBXFileSystemSynchronizedRootGroup（objectVersion 77），新增 .swift 自动入 target；`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。
4. 测试命令（每次用全新 DerivedData）：`xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <fresh DD> [-only-testing:CreekSproutTests/<Class>] test CODE_SIGNING_ALLOWED=NO`
5. **多窗口并发**：编辑前先 `ls -lt` 查 mtime 并重读目标区域；只新建/编辑本窗口文件；绝不覆盖他窗改动；不要 git add/commit。
6. 编译警告冻结：只允许 2 条既有警告键，不得引入新警告。
7. 已定案决策（不重新争论）：warning 夹具四要素（benefitOfferID/benefitBaselineDay==enteredDay(benefit)/benefitBaseline）+ q01 warning_1 后 `m3OffersPaused==true`；每段 completedActionIDs 配 actionReceipts；q08 需要 primary 槽选择（evidence/tradeUnion/oldWaterway 之一）；Q10 leave 走 world-grid 锚点 `brookseed.story.anchor.ending_departure`（market_wharf 交互位，creek_market (3,5)）。
8. 台账只由窗口 8 汇总更新，本窗口不改台账。

## 1. 现状与夹具

- 领域 API（只读使用）：`FinaleService`（beginDiscovery / enterDiscovery / openStageSession / advanceAfterLedgerIntent / advanceAfterConfrontationIntent / discoverLedgerPage / graduateAfterWater / graduateAfterLeave / recallPreReveal）；`StoryCommandService.selectChoice`（q09→ledgerIntent 槽、q10→confrontationIntent / finalAction 槽）；`StoryDialogueService`（openSession/advance/selectIntent/cancelSession）；`CampaignSaveCoordinator`（preparePreReveal、loadProtection、save、bestContinueGeneration）。
- 夹具：需要 q01–q07 全 resolved + q08 完成旅程后 resolved（q08Completed=true、mission.status==.completed、checkpoint==.homecoming、finaleBeat==.locked、standing 保留）。合法夹具模式参照 `N027JourneyTests.swift`（只读）里的 `resolvedSegment/applyResolvedArc/journeyReadyState` 自建一份（放本测试文件内，保持自包含）。q08 链：journeyReadyState → selectChoice(.q08, .evidence) → prepareJourney → 三次 advanceCheckpoint（每次 coordinator.save missionCurrent）→ completeHomecoming → clock +2 日 → resolveResponsibleAftermath(.q08)。
- 若 `N027JourneyTests` 尚未全绿（窗口 2 进行中），先写测试并等其夹具定稿，或在本文件内自包含夹具（推荐），不依赖窗口 2 的私有 helper。

## 2. 文件所有权

- 新建：`macos/CreekSprout/CreekSproutTests/N027EndingTests.swift`（唯一交付文件）。
- 仅当能证明领域 bug 时（用最小复现）：可最小修改 `FinaleService.swift` / `CampaignSaveCoordinator.swift` 并记录证据；否则禁止碰领域代码。
- 禁止编辑：窗口 1/2 的测试文件、`SaveValidation.swift`、`StoryRuntimeService.swift`、`ContentView.swift`、`FarmScene.swift`、`docs/game/project-ledger.md`。

## 3. 必须覆盖的测试（attachment Phase G）

1. **Q09 触发条件**：Q08 返乡 completeHomecoming + 完成返乡日并睡眠（域内体现为 resolveResponsibleAftermath 的 2 日余韵）后，`beginDiscovery` 才可成功；此前（mission 未完成 / q08 未 resolved / finaleBeat != .locked）必须失败。
2. **pre_reveal 原子性**：`beginDiscovery` 在首次显示 Q09_DIS_001 前原子写成并复读（loadProtection 可读、preRevealVerified=true、finaleBeat==.preRevealSavePending）；写失败（如非法 slot）→ preRevealWriteFailed 且 finaleBeat 保持 locked、不进入 Q09；pre_reveal 永不成为自动 Continue 候选；普通 campaignAuto 保存不覆盖 pre_reveal 文件（对比 loadProtection 前后字节/状态）。
3. **Q09 四账簿意图**：take_ledger / keep_reading / close_ledger / return_titles 均可到达（enterDiscovery → openStageSession → advance 到意图边界 → selectIntent）；任一意图完成后 `advanceAfterLedgerIntent` 连续进入 Q10 confrontation。
4. **Q10 四对质意图 + 两最终行动**：why_me / any_truth / silence / break_titles 均可到达（confrontation → openStageSession → selectIntent）；`advanceAfterConfrontationIntent` → finalActionPending；water/leave 均可到达（selectIntent 或 selectChoice，slot=finalAction）。
5. **确认前可取消并立即归还控制**：`graduateAfterWater` 在无 wateredToday 田块时 → `waterActionMissing` 且输入状态不变；`graduateAfterLeave` 在位置不是 ending_departure 锚点时 → `leaveAnchorUnavailable` 且输入状态不变（值类型未变异即归还控制）。`cancelSession` 释放租约回归控制。
6. **water 毕业**：回农场（currentMapID==farmHomestead）且至少一块田当日真实浇水标记（wateredToday==true）才毕业。
7. **leave 毕业**：位于 market_wharf 交互位（ending_departure 锚点 cell）才可进入模态离谷短景（毕业）；不新增谷外开放地图（断言锚点是 world-grid 且解析到现有 landmark）。
8. **毕业保留**：毕业后农场、货币、动物、关系与 standing 不变；`communityEvaluationDisabled==true`、`gallery.isUnlocked==true`、`endingID` 非空；`recallPreReveal` 可读回 pre_reveal 状态（该状态 finaleBeat==locked 且无 reveal 内容）。
9. **终局共谋名册**：`StoryActorCatalog.conspiratorRoster` 包含七名主要 NPC、三名猫店员、绒铃、灰栅代表、灰栅农场主（13 名）；`StoryActorID.greygateRepresentative != .greygateFarmer`；语义断言二者是不同 ID。
10. **Q09 前零泄露**：`storyCatalog.visibleLines(arcID:.q09/.q10, stage:.discovery/..., finaleUnlocked:false)` 为空、`visibleBlockingCue(finaleUnlocked:false)` 对 reveal cue 为空；finaleUnlocked=true 时非空；毕业前 gallery.isUnlocked==false。

## 4. 完成标准

1. `N027EndingTests` 非零全绿（0 failed）；fresh DD 跑一次确认。
2. 不破坏其它 N027 类（若窗口 1/2 已绿，做一次全 N027 回归确认 0 failed）。
3. 无新警告。
4. 每例关键状态点过 `SaveValidation.validateN027`（保存往返等价）。

## 5. 交接输出

写 `artifacts/integration/n-027-main-story-runtime/phase-g-integration.md`：测试数、fresh DD 路径、warning 集合、决策假设、剩余风险。窗口结束时用中文给出一句结果 + 该文件路径。
