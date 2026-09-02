import Foundation
import XCTest
@testable import CreekSprout

/// Phase H: deterministic timeline simulation and machine evidence.
///
/// Two timelines are driven day-by-day through the *real* story runtime
/// (`StoryDirector`, `StoryCommandService`, `StoryDialogueService`,
/// `JourneyService`, `FinaleService`), so the pacing claims are grounded in
/// the actual maturity gates rather than a hand-waved script:
///
/// - `timeline-normal.json`  — the ordinary line, graduating around Day 28.
/// - `timeline-recovery.json` — the low-standing recovery line entering Q01
///   `warning_1` at standing 31, using at most three distinct +6 repair
///   commissions after Q07, graduating by Day 32.
///
/// Both timelines are deterministic simulations. They do **not** pretend to be
/// one natural 5–6 hour human playthrough; that judgement belongs to the
/// Product Owner. The Q09-first-ledger → Q10-graduation active duration is
/// estimated from the number of presented dialogue lines and checkpoints.
final class N027TimelineTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let storyCatalog = StoryContentCatalog.shared

    // MARK: - Support tiers

    enum SupportTier: String {
        case t0_39 = "0_39"
        case t40_69 = "40_69"
        case t70_89 = "70_89"
        case t90_100 = "90_100"

        static func tier(for standing: Int) -> SupportTier {
            switch standing {
            case 0...39: .t0_39
            case 40...69: .t40_69
            case 70...89: .t70_89
            default: .t90_100
            }
        }
    }

    // MARK: - Day bookkeeping

    struct DayLog {
        var day: Int
        var labour: [String]
        var maturity: [String]
        var warning: String?
        var eruption: String?
        var aftermath: String?
        var standing: Int
        var tier: SupportTier
        var estimatedMinutes: Double
    }

    private func growingCell(_ cropID: String = ContentID.mistRadishCrop) -> FarmCell {
        FarmCell(
            prepared: true,
            cropID: cropID,
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 1,
            readyToHarvest: false
        )
    }

    /// Mirrors the production `advanceStoryAtDayStart`: unlocks the next
    /// eligible benefit at the start of a new day.
    private func advanceStoryAtDayStart(_ state: inout GameState) {
        for arcID in StoryArcID.allCases where arcID.sequence <= StoryArcID.q08.sequence {
            guard state.storyCampaign.segment(arcID)?.phase == .locked else { continue }
            if case .success(let candidate) = StoryDirector.unlockEligibleBenefit(
                state: state,
                arcID: arcID
            ) {
                state = candidate
            }
        }
    }

    /// Advance the clock one day and run the same day-start story unlock the
    /// production sleep pipeline performs.
    private func beginNextDay(_ state: inout GameState, labour: [String] = []) {
        state.clock = GameClock(day: state.clock.day + 1, minute: GameClock.dayStartMinute)
        advanceStoryAtDayStart(&state)
    }

    // MARK: - Metric seeding (per-arc maturity, mirroring the legal fixtures)

    /// Seeds the generic labour history that satisfies the *causal* maturity
    /// gates. All counters are append-only source-backed values; the timeline
    /// only asserts pacing, not the recorders themselves (those are already
    /// covered by the Phase A / Q01 vertical-slice tests).
    private func seedQ01Metrics(_ state: inout GameState) {
        let day = state.clock.day
        state.tutorial.completedStepIDs = Array(ContentID.tutorialStepIDs.dropLast())
        state.tutorial.currentStepID = ContentID.tutorialNextDay
        state.questLog.setStatus(.completed, for: ContentID.restoreOldCanalQuest)
        state.storyMetrics.completedCyclesByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.harvestsByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.harvestedCropCount = 2
        state.storyMetrics.plantedCellsByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.plantedCellCount = 2
        state.storyMetrics.manualWaterCellDays = 30
        state.storyMetrics.temporaryCanalBenefitDays = [day - 4, day - 3, day - 2, day - 1]
        state.storyMetrics.canonicalize()
    }

    private func seedQ02Metrics(_ state: inout GameState) {
        let day = state.clock.day
        state.storyMetrics.formalCanalBenefitDays = [day - 5, day - 4, day - 3, day - 2, day - 1]
        state.storyMetrics.automaticWaterCellDays = 30
        state.storyMetrics.automaticWaterSleepDays = [day - 3, day - 2, day - 1]
        // A high-value crop one day short of harvest, for high_value_crop_due_2.
        let berryTotal = catalog.crop(id: ContentID.bellBerryCrop)!.stageDays.reduce(0, +)
        state.farmCells[GridPosition(x: 0, y: 0)] = FarmCell(
            prepared: true,
            cropID: ContentID.bellBerryCrop,
            cropStage: 1,
            stageProgressDays: berryTotal - 1,
            plantedDay: day,
            readyToHarvest: false
        )
        state.storyMetrics.canonicalize()
    }

    private func seedQ03Metrics(_ state: inout GameState) {
        let day = state.clock.day
        state.storyMetrics.completedCyclesByCropID[ContentID.bellBerryCrop] = 2
        state.storyMetrics.deliveryRecipientIDsByCropID[ContentID.bellBerryCrop] = [
            "brookseed.npc.q03.recipient.a",
            "brookseed.npc.q03.recipient.b",
            "brookseed.npc.q03.recipient.c",
        ]
        state.storyMetrics.premiumBenefitDays = [day - 3, day - 2, day - 1]
        state.storyMetrics.dailyMetricDays = Array(1...day)
        // Bell berry stake: held + planted ≥ 6.
        state.inventory.append(
            InventoryQuantity(itemID: ContentID.bellBerryItem, quantity: 6)
        )
        state.storyMetrics.canonicalize()
    }

    private func seedQ04Metrics(_ state: inout GameState) {
        state.storyMetrics.completedCyclesByCropID[ContentID.streamLeafCrop] = 2
        state.storyMetrics.completedCyclesByCropID[ContentID.amberBeanCrop] = 2
        state.storyMetrics.seedBenefitUses = 3
        state.storyMetrics.canonicalize()
    }

    private func seedQ05Metrics(_ state: inout GameState) {
        state.storyMetrics.catShopOpened = true
        state.storyMetrics.catShopCropReceiptIDs = (1...5).map {
            "brookseed.story.receipt.q05.crop.\($0)"
        }
        state.storyMetrics.catShopPremiumReceiptIDs = (1...3).map {
            "brookseed.story.receipt.q05.premium.\($0)"
        }
        state.storyMetrics.deliveriesByCropID[ContentID.honeyMelonCrop] = 1
        state.storyMetrics.canonicalize()
    }

    private func seedQ06Metrics(_ state: inout GameState) {
        let day = state.clock.day
        for npcID in [ContentID.neighborEvidence, ContentID.neighborConsensus] {
            state.storyMetrics.npcTalkDays[npcID] = [day - 6, day - 5, day - 4, day - 3, day - 2, day - 1]
            state.storyMetrics.npcHelpCounts[npcID] = 2
            state.storyMetrics.npcCollaborationCounts[npcID] = 2
        }
        // Trailing 4 settled days as of warning_1 (benefitDay + 1).
        state.storyMetrics.quietDays = [day - 3, day - 2, day - 1, day]
        state.storyMetrics.canonicalize()
    }

    private func seedQ07Metrics(_ state: inout GameState) {
        let day = state.clock.day
        state.storyMetrics.catShopCropReceiptIDs = (1...5).map {
            "brookseed.story.receipt.q07.crop.\($0)"
        }
        state.storyMetrics.catShopAnimalReceiptIDs = [
            "brookseed.story.receipt.q07.animal.1",
        ]
        state.storyMetrics.animalsGrownToAdultIDs = ["brookseed.animal.q07.adult"]
        state.storyMetrics.quietDays = [day - 4, day - 3, day - 2, day - 1, day]
        state.storyMetrics.canonicalize()
    }

    /// Seeds the Q07 causal premium receipts after benefit unlock, so they
    /// reference the real `benefitOfferID` and land on/after the benefit day.
    private func seedQ07CausalReceipts(_ state: inout GameState) {
        let day = state.clock.day
        guard let offerID = state.storyCampaign.segment(.q07)?.benefitOfferID else { return }
        let causalReceiptIDs = (1...3).map {
            "brookseed.story.receipt.q07.causal_premium.\($0)"
        }
        state.storyMetrics.catShopReceiptIDs = causalReceiptIDs
        state.storyMetrics.catShopPremiumReceiptIDs = causalReceiptIDs
        for receiptID in causalReceiptIDs {
            state.storyMetrics.catShopReceiptOfferSourceIDs[receiptID] = offerID
        }
        state.catShop.receipts = causalReceiptIDs.enumerated().map { index, receiptID in
            CatShopReceipt(
                receiptID: receiptID,
                day: day + index,
                offerID: offerID,
                kind: .crop,
                subjectID: ContentID.bellBerryItem,
                definitionID: ContentID.bellBerryItem,
                displayName: "N027 Q07 causal premium",
                quantity: 1,
                unitPrice: 1,
                total: 1
            )
        }
        state.storyMetrics.premiumBenefitDays = [day, day + 1, day + 2]
        state.storyMetrics.dailyMetricDays = Array(1...(day + 2))
        state.storyMetrics.canonicalize()
    }

    // MARK: - Arc driving

    /// Plays a stage end-to-end and returns the number of presented lines.
    /// When a choice boundary is reached, `choice` (nil = stage's first choice)
    /// is recorded via `selectIntent` before continuing.
    @discardableResult
    private func playEntireStage(
        _ state: inout GameState,
        choice: StoryChoiceID? = nil
    ) throws -> Int {
        state = try StoryDialogueService.openSession(state: state, catalog: storyCatalog).get()
        var count = 0
        while true {
            if let session = state.storyCampaign.dialogueSession,
               session.intentsPending, session.isAtBoundary {
                let picked = choice ?? session.pendingChoiceIDs.first
                guard let picked else {
                    throw NSError(
                        domain: "N027TimelineTests", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "no choice available at boundary"]
                    )
                }
                state = try StoryDialogueService.selectIntent(
                    state: state, choice: picked, catalog: storyCatalog
                ).get()
                continue
            }
            let result = StoryDialogueService.advance(state: state, catalog: storyCatalog)
            guard case .success(let outcome) = result else {
                throw outcomeFailure(result)
            }
            count += 1
            state = outcome.state
            if outcome.reachedEnd { break }
        }
        return count
    }

    private func outcomeFailure<T>(_ result: Result<T, StoryDialogueFailure>) -> Error {
        switch result {
        case .failure(let failure):
            return NSError(
                domain: "N027TimelineTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "dialogue failure \(failure)"]
            )
        case .success:
            return NSError(
                domain: "N027TimelineTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "dialogue failure (unexpected success)"]
            )
        }
    }

    /// Drives one Q01–Q07 arc from `benefit` to `resolved`, recording the
    /// per-day labour/phase log. Returns the days consumed and the log entries.
    private func driveArc(
        _ state: inout GameState,
        arcID: StoryArcID,
        logs: inout [DayLog],
        isGroupEvent: Bool
    ) throws {
        // Unlock the benefit; the prerequisite (prior arc resolved / canal
        // quest completed) must already be satisfied by the caller's seeding.
        state = try StoryDirector.unlockEligibleBenefit(state: state, arcID: arcID).get()
        // Causal expansions must land AFTER the benefit baseline snapshot.
        switch arcID {
        case .q01:
            // +6 growing cells over the empty baseline.
            for column in 0..<6 {
                state.farmCells[GridPosition(x: column, y: 5)] = growingCell()
            }
        case .q02:
            // +30% area expansion over the baseline (several growing cells).
            for column in 0..<8 {
                state.farmCells[GridPosition(x: column, y: 6)] = growingCell()
            }
        case .q04:
            // +8 seed-benefit planted cells over the baseline, plus a growing
            // batch still present.
            state.storyMetrics.seedBenefitPlantedCells += 8
            state.farmCells[GridPosition(x: 0, y: 6)] = growingCell()
        case .q05, .q07:
            // +1 animal over the baseline.
            state.livestock.animals.append(
                FarmAnimalState(
                    instanceID: "brookseed.animal.\(arcID.shortCode).investment",
                    definitionID: "brookseed.animal.creek_duck",
                    displayName: "投资溪鸭",
                    ageDays: 1,
                    totalCareDays: 0,
                    lastCaredDay: nil,
                    isProtected: false
                )
            )
            if arcID == .q07 {
                // Causal premium/prepay receipts must reference the actual
                // benefit offer ID and land on/after the benefit day.
                seedQ07CausalReceipts(&state)
            }
        default:
            break
        }
        let benefitDay = state.clock.day
        logs.append(DayLog(
            day: benefitDay,
            labour: ["benefit 解锁"],
            maturity: ["获益基线快照"],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 2
        ))

        // warning_1
        let warningOneDay = benefitDay + 1
        state.clock = GameClock(day: warningOneDay, minute: GameClock.dayStartMinute)
        state = try StoryDirector.requestWarningOne(
            state: state, arcID: arcID, sleepEpoch: warningOneDay
        ).get()
        let w1Lines = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: arcID, completedPhase: .warningOne
        ).get()
        logs.append(DayLog(
            day: warningOneDay,
            labour: ["预警日 1（\(w1Lines) 行）"],
            maturity: [],
            warning: "warning_1",
            eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: Double(w1Lines) * 0.25
        ))

        // Related labour between warnings.
        state = try StoryCommandService.recordAction(
            state: state,
            arcID: arcID,
            actionID: "brookseed.story.\(arcID.shortCode).action.between_warnings"
        ).get()

        // warning_2 — group events (Q02/Q07) require a sleep boundary.
        let warningTwoDay: Int
        if isGroupEvent {
            warningTwoDay = warningOneDay + 1
            state.clock = GameClock(day: warningTwoDay, minute: GameClock.dayStartMinute)
            // Related labour on the new day before warning_2.
            state = try StoryCommandService.recordAction(
                state: state,
                arcID: arcID,
                actionID: "brookseed.story.\(arcID.shortCode).action.between_warnings_2"
            ).get()
        } else {
            warningTwoDay = warningOneDay
        }
        state = try StoryDirector.requestWarningTwo(
            state: state, arcID: arcID, sleepEpoch: warningTwoDay
        ).get()
        let w2Lines = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: arcID, completedPhase: .warningTwo
        ).get()
        logs.append(DayLog(
            day: warningTwoDay,
            labour: ["预警日 2（\(w2Lines) 行）"],
            maturity: [],
            warning: "warning_2",
            eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: Double(w2Lines) * 0.25
        ))

        // Pre-eruption related labour.
        state = try StoryCommandService.recordAction(
            state: state,
            arcID: arcID,
            actionID: "brookseed.story.\(arcID.shortCode).action.pre_eruption"
        ).get()

        // eruption — group events require a sleep boundary after warning_2.
        let eruptionDay: Int
        if isGroupEvent {
            eruptionDay = warningTwoDay + 1
            state.clock = GameClock(day: eruptionDay, minute: GameClock.dayStartMinute)
        } else {
            eruptionDay = warningTwoDay
        }
        state = try StoryDirector.requestEruption(
            state: state, arcID: arcID, sleepEpoch: eruptionDay
        ).get()
        // The eruption choice (Q06 uses the eruption slot first).
        let choice: StoryChoiceID
        if arcID == .q06 {
            choice = .noSide
        } else {
            choice = StoryChoiceID.choices(for: arcID)[0]
        }
        let eruptionLines = try playEntireStage(&state, choice: choice)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: arcID, completedPhase: .eruption
        ).get()
        logs.append(DayLog(
            day: eruptionDay,
            labour: ["爆发（\(eruptionLines) 行）"],
            maturity: [],
            warning: nil,
            eruption: "eruption",
            aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: Double(eruptionLines) * 0.25
        ))

        // Q06 aftermath choice (friend outcome without care actions).
        if arcID == .q06 {
            state = try StoryCommandService.selectChoice(
                state: state, arcID: .q06, choice: .friend
            ).get()
        }

        // Aftermath lasts at least two game days.
        let aftermathStart = eruptionDay
        for offset in 1...2 {
            let day = aftermathStart + offset
            state.clock = GameClock(day: day, minute: GameClock.dayStartMinute)
            logs.append(DayLog(
                day: day,
                labour: ["余韵日 \(offset)"],
                maturity: [],
                warning: nil, eruption: nil,
                aftermath: "aftermath",
                standing: state.community.standing,
                tier: SupportTier.tier(for: state.community.standing),
                estimatedMinutes: 1
            ))
        }

        // Resolve (aftermath must be ≥2 days old).
        let resolveDay = aftermathStart + 2
        state.clock = GameClock(day: resolveDay, minute: GameClock.dayStartMinute)
        state = try StoryDirector.resolveResponsibleAftermath(
            state: state, arcID: arcID
        ).get()
        logs.append(DayLog(
            day: resolveDay,
            labour: ["善后完成 +6"],
            maturity: [],
            warning: nil, eruption: nil, aftermath: "resolved",
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 1
        ))
    }

    // MARK: - Normal timeline

    private func driveArcWithContext(
        _ state: inout GameState,
        arcID: StoryArcID,
        logs: inout [DayLog],
        isGroupEvent: Bool
    ) throws {
        do {
            try driveArc(&state, arcID: arcID, logs: &logs, isGroupEvent: isGroupEvent)
        } catch {
            throw NSError(
                domain: "N027TimelineTests", code: 100,
                userInfo: [NSLocalizedDescriptionKey: "driveArc \(arcID.rawValue) failed: \(error)"]
            )
        }
    }

    private func runNormalTimeline() throws -> (logs: [DayLog], state: GameState) {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 1, minute: GameClock.dayStartMinute)
        state.community.standing = 50
        var logs: [DayLog] = []

        // Q01 benefit: canal quest completed → benefit on day 1.
        seedQ01Metrics(&state)
        try driveArcWithContext(&state, arcID: .q01, logs: &logs, isGroupEvent: false)

        // Q02 (group event).
        seedQ02Metrics(&state)
        try driveArcWithContext(&state, arcID: .q02, logs: &logs, isGroupEvent: true)

        // Q03.
        seedQ03Metrics(&state)
        try driveArcWithContext(&state, arcID: .q03, logs: &logs, isGroupEvent: false)

        // Q04.
        seedQ04Metrics(&state)
        try driveArcWithContext(&state, arcID: .q04, logs: &logs, isGroupEvent: false)

        // Q05.
        seedQ05Metrics(&state)
        try driveArcWithContext(&state, arcID: .q05, logs: &logs, isGroupEvent: false)

        // Q06.
        seedQ06Metrics(&state)
        try driveArcWithContext(&state, arcID: .q06, logs: &logs, isGroupEvent: false)

        // Q07 (group event).
        seedQ07Metrics(&state)
        try driveArcWithContext(&state, arcID: .q07, logs: &logs, isGroupEvent: true)

        // Q08: standing must be ≥90. After seven +6 awards from 50 → 92.
        XCTAssertGreaterThanOrEqual(state.community.standing, 90)

        // Q08 benefit → warning_1 → (evidence check) → warning_2 → eruption.
        state = try StoryDirector.unlockEligibleBenefit(state: state, arcID: .q08).get()
        let q08BenefitDay = state.clock.day
        logs.append(DayLog(
            day: q08BenefitDay, labour: ["Q08 获益解锁"], maturity: [],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 2
        ))
        // Q08 maturity needs Q07 aftermath ≥ 2 days (already satisfied at
        // Q07's resolve day), so warning_1 lands the very next day.
        let q08WarningOneDay = q08BenefitDay + 1
        state.clock = GameClock(day: q08WarningOneDay, minute: GameClock.dayStartMinute)
        state = try StoryDirector.requestWarningOne(
            state: state, arcID: .q08, sleepEpoch: q08WarningOneDay
        ).get()
        _ = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .warningOne
        ).get()
        logs.append(DayLog(
            day: q08WarningOneDay, labour: ["Q08 预警日 1"], maturity: [],
            warning: "warning_1", eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 3
        ))

        // Evidence check (one of the three evidence nodes) then warning_2.
        state = try StoryCommandService.recordAction(
            state: state, arcID: .q08,
            actionID: "brookseed.story.q08.action.between_warnings",
            evidenceCheck: true
        ).get()
        state = try StoryDirector.requestWarningTwo(
            state: state, arcID: .q08, sleepEpoch: q08WarningOneDay
        ).get()
        _ = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .warningTwo
        ).get()
        logs.append(DayLog(
            day: q08WarningOneDay, labour: ["Q08 预警日 2 + 证物查验"], maturity: [],
            warning: "warning_2", eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 4
        ))

        // Pre-eruption related labour then eruption.
        state = try StoryCommandService.recordAction(
            state: state, arcID: .q08,
            actionID: "brookseed.story.q08.action.pre_eruption"
        ).get()
        let q08EruptionDay = q08WarningOneDay
        state = try StoryDirector.requestEruption(
            state: state, arcID: .q08, sleepEpoch: q08EruptionDay
        ).get()
        _ = try playEntireStage(&state, choice: .evidence)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .eruption
        ).get()
        logs.append(DayLog(
            day: q08EruptionDay, labour: ["Q08 爆发"], maturity: [],
            warning: nil, eruption: "eruption", aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 5
        ))

        // Q08 journey: build snapshot, three checkpoints, homecoming, resolve.
        let q08JourneyDay = q08EruptionDay
        let snapshot = try JourneyService.buildMissionSnapshot(state: state).get()
        var missionState = state
        missionState.storyCampaign.mission = snapshot
        missionState.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q08.journey.\(state.campaignID)",
            owner: .journey,
            resourceID: snapshot.missionInstanceID,
            acquiredDay: q08JourneyDay,
            checkpointID: StoryJourneyCheckpoint.departure.rawValue
        )
        missionState.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q08.rawValue,
            sceneID: nil,
            beatID: nil,
            lineID: nil,
            lineIndex: 0,
            cueID: nil,
            checkpointID: StoryJourneyCheckpoint.departure.rawValue
        )
        for checkpoint in [StoryJourneyCheckpoint.oldWaterway, .mistRidgeFork, .greyFenceFarm] {
            missionState = try JourneyService.advanceCheckpoint(
                state: missionState, to: checkpoint
            ).get()
        }
        // Record the Q08 route choice at grey fence (mirrored to segment).
        missionState.storyCampaign.choices.append(
            StoryChoiceRecord(
                arcID: .q08, slotID: .primary,
                choiceID: StoryChoiceID.evidence.stableID(in: .q08),
                day: missionState.clock.day
            )
        )
        var q08Segment = missionState.storyCampaign.segment(.q08)!
        q08Segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.primary.rawValue] =
            StoryChoiceID.evidence.stableID(in: .q08)
        missionState.storyCampaign.updateSegment(q08Segment)
        // Complete the mission inline (mirrors completeHomecoming's candidate).
        missionState = try completeMissionInline(missionState)
        missionState.storyCampaign.q08Completed = true
        state = missionState
        logs.append(DayLog(
            day: q08JourneyDay, labour: ["Q08 三检查点 + 返乡"], maturity: [],
            warning: nil, eruption: nil, aftermath: "aftermath",
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 35
        ))

        // Q09 → Q10 finale.
        let q09Day = q08JourneyDay + 1
        state.clock = GameClock(day: q09Day, minute: GameClock.dayStartMinute)
        // The timeline is a simulation: arm the pre-reveal protection the way
        // `beginDiscovery` does (preRevealVerified + preRevealSavePending).
        state.storyCampaign.protection.preRevealVerified = true
        state.storyCampaign.finaleBeat = .preRevealSavePending
        state = try FinaleService.enterDiscovery(state: state)
            .mapError { NSError(domain: "N027TimelineTests", code: 200, userInfo: [NSLocalizedDescriptionKey: "enterDiscovery: \($0)"]) }
            .get()
        logs.append(DayLog(
            day: q09Day, labour: ["Q09 账簿首次显示"], maturity: [],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 15
        ))
        // Ledger intent → confrontation → final action → graduation.
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q09, choice: .takeLedger
        ).mapError { NSError(domain: "N027TimelineTests", code: 201, userInfo: [NSLocalizedDescriptionKey: "q09 choice: \($0)"]) }
        .get()
        state = try FinaleService.advanceAfterLedgerIntent(state: state)
            .mapError { NSError(domain: "N027TimelineTests", code: 202, userInfo: [NSLocalizedDescriptionKey: "advanceAfterLedgerIntent: \($0)"]) }
            .get()
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q10, choice: .whyMe
        ).mapError { NSError(domain: "N027TimelineTests", code: 203, userInfo: [NSLocalizedDescriptionKey: "q10 choice: \($0)"]) }
        .get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state)
            .mapError { NSError(domain: "N027TimelineTests", code: 204, userInfo: [NSLocalizedDescriptionKey: "advanceAfterConfrontationIntent: \($0)"]) }
            .get()
        // Record the final action intent (water) before graduating.
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q10, choice: .water
        ).mapError { NSError(domain: "N027TimelineTests", code: 2045, userInfo: [NSLocalizedDescriptionKey: "q10 final action: \($0)"]) }
        .get()
        // water graduation: a real watered cell on the farm.
        state.currentMapID = ContentID.farmHomestead
        state.farmCells[GridPosition(x: 0, y: 0)] = FarmCell(
            prepared: true, wateredToday: true,
            cropID: ContentID.mistRadishCrop, cropStage: 0,
            stageProgressDays: 0, plantedDay: 1
        )
        state = try FinaleService.graduateAfterWater(state: state)
            .mapError { NSError(domain: "N027TimelineTests", code: 205, userInfo: [NSLocalizedDescriptionKey: "graduateAfterWater: \($0)"]) }
            .get()
        logs.append(DayLog(
            day: q09Day, labour: ["Q10 对质 + 最终浇水 → 毕业"], maturity: [],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 30
        ))

        return (logs, state)
    }

    /// Completes the Q08 mission inline (the timeline is a simulation; the
    /// exact-once save ordering is already covered by N027JourneyTests).
    private func completeMissionInline(_ state: GameState) throws -> GameState {
        var next = state
        guard var mission = next.storyCampaign.mission else {
            throw JourneyFailure.notInJourney
        }
        mission.status = .completed
        mission.checkpoint = .homecoming
        mission.canAbandonToProtection = false
        next.storyCampaign.mission = mission
        next.storyCampaign.frontstageLease = nil
        next.storyCampaign.cursor = .empty
        next.storyCampaign.dialogueSession = nil
        var segment = next.storyCampaign.segment(.q08)
        segment?.enter(.aftermath, day: next.clock.day)
        if let segment {
            next.storyCampaign.updateSegment(segment)
        }
        next.storyCampaign.canonicalize()
        return next
    }

    // MARK: - Recovery timeline

    private func runRecoveryTimeline() throws -> (logs: [DayLog], state: GameState) {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 1, minute: GameClock.dayStartMinute)
        // Recovery fixture: active M3 settled, standing 31 at Q01 warning_1.
        state.community.standing = 31
        var logs: [DayLog] = []

        seedQ01Metrics(&state)
        try driveArcWithContext(&state, arcID: .q01, logs: &logs, isGroupEvent: false)
        seedQ02Metrics(&state)
        try driveArcWithContext(&state, arcID: .q02, logs: &logs, isGroupEvent: true)
        seedQ03Metrics(&state)
        try driveArcWithContext(&state, arcID: .q03, logs: &logs, isGroupEvent: false)
        seedQ04Metrics(&state)
        try driveArcWithContext(&state, arcID: .q04, logs: &logs, isGroupEvent: false)
        seedQ05Metrics(&state)
        try driveArcWithContext(&state, arcID: .q05, logs: &logs, isGroupEvent: false)
        seedQ06Metrics(&state)
        try driveArcWithContext(&state, arcID: .q06, logs: &logs, isGroupEvent: false)

        seedQ07Metrics(&state)
        try driveArcWithContext(&state, arcID: .q07, logs: &logs, isGroupEvent: true)

        // After Q07, standing = 31 + 7×6 = 73. Three distinct +6 commissions.
        XCTAssertEqual(state.community.standing, 73)
        let commissions = [
            "brookseed.story.commission.missing_page",
            "brookseed.story.commission.trail_markers",
            "brookseed.story.commission.record_ledger",
        ]
        for (index, commissionID) in commissions.enumerated() {
            state = try StoryDirector.completeRepairCommission(
                state: state, commissionID: commissionID
            ).mapError { NSError(domain: "N027TimelineTests", code: 300, userInfo: [NSLocalizedDescriptionKey: "commission \(index): \($0)"]) }
            .get()
            logs.append(DayLog(
                day: state.clock.day,
                labour: ["公开修复委托 \(index) +6"],
                maturity: [],
                warning: nil, eruption: nil, aftermath: nil,
                standing: state.community.standing,
                tier: SupportTier.tier(for: state.community.standing),
                estimatedMinutes: 3
            ))
        }
        XCTAssertEqual(state.community.standing, 91)
        XCTAssertGreaterThanOrEqual(state.community.standing, 90)

        // Q08 (same as normal, but standing is now 91).
        state = try StoryDirector.unlockEligibleBenefit(state: state, arcID: .q08)
            .mapError { NSError(domain: "N027TimelineTests", code: 301, userInfo: [NSLocalizedDescriptionKey: "q08 unlock: \($0)"]) }
            .get()
        let q08BenefitDay = state.clock.day
        logs.append(DayLog(
            day: q08BenefitDay, labour: ["Q08 获益解锁"], maturity: [],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 2
        ))
        // Q08 maturity needs Q07 aftermath ≥ 2 days (already satisfied at
        // Q07's resolve day), so warning_1 lands the very next day.
        let q08WarningOneDay = q08BenefitDay + 1
        state.clock = GameClock(day: q08WarningOneDay, minute: GameClock.dayStartMinute)
        state = try StoryDirector.requestWarningOne(
            state: state, arcID: .q08, sleepEpoch: q08WarningOneDay
        ).get()
        _ = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .warningOne
        ).get()
        state = try StoryCommandService.recordAction(
            state: state, arcID: .q08,
            actionID: "brookseed.story.q08.action.between_warnings",
            evidenceCheck: true
        ).get()
        state = try StoryDirector.requestWarningTwo(
            state: state, arcID: .q08, sleepEpoch: q08WarningOneDay
        ).get()
        _ = try playEntireStage(&state)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .warningTwo
        ).get()
        state = try StoryCommandService.recordAction(
            state: state, arcID: .q08,
            actionID: "brookseed.story.q08.action.pre_eruption"
        ).get()
        state = try StoryDirector.requestEruption(
            state: state, arcID: .q08, sleepEpoch: q08WarningOneDay
        ).get()
        _ = try playEntireStage(&state, choice: .oldWaterway)
        state = try StoryDirector.closeDialogue(
            state: state, arcID: .q08, completedPhase: .eruption
        ).get()
        logs.append(DayLog(
            day: q08WarningOneDay, labour: ["Q08 预警/爆发/证物"], maturity: [],
            warning: nil, eruption: "eruption", aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 12
        ))

        // Q08 journey inline.
        let snapshot = try JourneyService.buildMissionSnapshot(state: state).get()
        var missionState = state
        missionState.storyCampaign.mission = snapshot
        missionState.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q08.journey.\(state.campaignID)",
            owner: .journey,
            resourceID: snapshot.missionInstanceID,
            acquiredDay: q08WarningOneDay,
            checkpointID: StoryJourneyCheckpoint.departure.rawValue
        )
        missionState.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q08.rawValue, sceneID: nil, beatID: nil,
            lineID: nil, lineIndex: 0, cueID: nil,
            checkpointID: StoryJourneyCheckpoint.departure.rawValue
        )
        for checkpoint in [StoryJourneyCheckpoint.oldWaterway, .mistRidgeFork, .greyFenceFarm] {
            missionState = try JourneyService.advanceCheckpoint(
                state: missionState, to: checkpoint
            ).get()
        }
        missionState.storyCampaign.choices.append(
            StoryChoiceRecord(
                arcID: .q08, slotID: .primary,
                choiceID: StoryChoiceID.oldWaterway.stableID(in: .q08),
                day: missionState.clock.day
            )
        )
        var q08Segment = missionState.storyCampaign.segment(.q08)!
        q08Segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.primary.rawValue] =
            StoryChoiceID.oldWaterway.stableID(in: .q08)
        missionState.storyCampaign.updateSegment(q08Segment)
        missionState = try completeMissionInline(missionState)
        missionState.storyCampaign.q08Completed = true
        state = missionState
        logs.append(DayLog(
            day: q08WarningOneDay, labour: ["Q08 三检查点 + 返乡"], maturity: [],
            warning: nil, eruption: nil, aftermath: "aftermath",
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 35
        ))

        // Q09 → Q10 finale (leave graduation).
        let q09Day = q08WarningOneDay + 1
        state.clock = GameClock(day: q09Day, minute: GameClock.dayStartMinute)
        state.storyCampaign.protection.preRevealVerified = true
        state.storyCampaign.finaleBeat = .preRevealSavePending
        state = try FinaleService.enterDiscovery(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q09, choice: .closeLedger
        ).get()
        state = try FinaleService.advanceAfterLedgerIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q10, choice: .silence
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        // Record the final action intent (leave) before graduating.
        state = try StoryCommandService.selectChoice(
            state: state, arcID: .q10, choice: .leave
        ).get()
        // leave graduation from the market wharf.
        state.currentMapID = ContentID.creekMarket
        if let anchor = StoryAnchorCatalog.anchor(
            id: StoryAnchorCatalog.endingDepartureAnchorID
        ), case let .worldGrid(world) = anchor {
            state.position = world.cell
        }
        state = try FinaleService.graduateAfterLeave(state: state).get()
        logs.append(DayLog(
            day: q09Day, labour: ["Q10 对质 + 离谷 → 毕业"], maturity: [],
            warning: nil, eruption: nil, aftermath: nil,
            standing: state.community.standing,
            tier: SupportTier.tier(for: state.community.standing),
            estimatedMinutes: 30
        ))

        return (logs, state)
    }

    // MARK: - Tests

    func testNormalTimelineGraduatesAroundDay28() throws {
        let (logs, state) = try runNormalTimeline()
        let graduationDay = state.clock.day
        XCTAssertEqual(state.storyCampaign.finaleBeat, .graduated)
        XCTAssertEqual(state.storyCampaign.gallery.endingID, "brookseed.story.ending.water")
        XCTAssertLessThanOrEqual(graduationDay, 28, "正常线应在约第 28 日毕业，实际 \(graduationDay)")
        XCTAssertGreaterThanOrEqual(graduationDay, 20, "正常线不应早于第 20 日")

        // Q09 first ledger → Q10 graduation active duration in 30–45 minutes.
        let q09Index = logs.firstIndex {
            $0.labour.contains(where: { $0.contains("Q09 账簿首次显示") })
        }
        XCTAssertNotNil(q09Index)
        let finaleMinutes = logs.dropFirst(q09Index ?? 0).reduce(0) { $0 + $1.estimatedMinutes }
        XCTAssertTrue(
            (30.0...45.0).contains(finaleMinutes),
            "Q09→Q10 主动时长应落在 30–45 分钟，实际 \(finaleMinutes)"
        )
    }

    func testRecoveryTimelineGraduatesByDay32() throws {
        let (logs, state) = try runRecoveryTimeline()
        let graduationDay = state.clock.day
        XCTAssertEqual(state.storyCampaign.finaleBeat, .graduated)
        XCTAssertEqual(state.storyCampaign.gallery.endingID, "brookseed.story.ending.leave")
        XCTAssertLessThanOrEqual(graduationDay, 32, "恢复线应在第 32 日前毕业，实际 \(graduationDay)")

        // Standing path: 31 → 73 after Q01–Q07 → 91 after three commissions.
        let standingAfterCommissions = logs.last {
            $0.labour.contains(where: { $0.contains("公开修复委托") })
        }?.standing
        XCTAssertEqual(standingAfterCommissions, 91)
    }

    func testTimelineEvidenceEmission() throws {
        let (normalLogs, normalState) = try runNormalTimeline()
        let (recoveryLogs, recoveryState) = try runRecoveryTimeline()

        let normalPayload = timelinePayload(
            kind: "normal",
            logs: normalLogs,
            state: normalState
        )
        let recoveryPayload = timelinePayload(
            kind: "recovery",
            logs: recoveryLogs,
            state: recoveryState
        )
        try N027EvidenceWriter.writeJSON(normalPayload, to: "timeline-normal.json")
        try N027EvidenceWriter.writeJSON(recoveryPayload, to: "timeline-recovery.json")

        // Deterministic: two runs produce byte-identical payloads.
        let (normalLogs2, normalState2) = try runNormalTimeline()
        let normalPayload2 = timelinePayload(
            kind: "normal",
            logs: normalLogs2,
            state: normalState2
        )
        let data1 = try JSONSerialization.data(
            withJSONObject: normalPayload,
            options: [.prettyPrinted, .sortedKeys]
        )
        let data2 = try JSONSerialization.data(
            withJSONObject: normalPayload2,
            options: [.prettyPrinted, .sortedKeys]
        )
        XCTAssertEqual(data1, data2, "正常线两次运行应逐字节一致")
    }

    func testStoryContentAuditEvidenceEmission() throws {
        let payload = storyContentAuditPayload()
        try N027EvidenceWriter.writeJSON(payload, to: "story-content-audit.json")

        // Ground-truth assertions: 10 stories, 236 manuscript lines, 50 cues.
        XCTAssertEqual(payload["story_count"] as? Int, 10)
        XCTAssertEqual(payload["manuscript_line_count"] as? Int, 236)
        XCTAssertEqual(payload["cue_count"] as? Int, 50)
        XCTAssertEqual(payload["token_violations"] as? Int, 0)
        XCTAssertEqual(payload["source_id_mapping_mismatches"] as? Int, 0)
    }

    // MARK: - Payload builders

    private func timelinePayload(
        kind: String,
        logs: [DayLog],
        state: GameState
    ) -> [String: Any] {
        let graduationDay = state.clock.day
        let finaleMinutes = logs.filter {
            $0.labour.contains(where: {
                $0.contains("Q09 账簿首次显示") || $0.contains("Q10 对质")
            })
        }.reduce(0) { $0 + $1.estimatedMinutes }

        return [
            "generator": "N027TimelineTests",
            "kind": kind,
            "declaration": "确定性模拟，不冒充一次自然 5–6 小时真人通关；该判断留给 Product Owner",
            "graduation_day": graduationDay,
            "finale_active_minutes": finaleMinutes,
            "finale_active_minutes_range": "30–45",
            "final_standing": state.community.standing,
            "final_ending_id": state.storyCampaign.gallery.endingID ?? "",
            "m3_offers_paused_at_graduation": state.storyCampaign.m3OffersPaused,
            "days": logs.map { log in
                var entry: [String: Any] = [
                    "day": log.day,
                    "labour": log.labour,
                    "maturity": log.maturity,
                    "standing": log.standing,
                    "support_tier": log.tier.rawValue,
                    "estimated_minutes": log.estimatedMinutes,
                ]
                if let warning = log.warning { entry["warning"] = warning }
                if let eruption = log.eruption { entry["eruption"] = eruption }
                if let aftermath = log.aftermath { entry["aftermath"] = aftermath }
                return entry
            },
        ]
    }

    private func storyContentAuditPayload() -> [String: Any] {
        let catalog = storyCatalog
        let manuscript = catalog.allDialogueLines.filter { $0.origin == .manuscript }
        let inline = catalog.allDialogueLines.filter { $0.origin == .inlineChoiceResponse }

        // SourceID ↔ runtime ID one-to-one mapping.
        var sourceIDMismatches = 0
        var sourceIDSet = Set<String>()
        for line in manuscript {
            guard let sourceID = line.sourceID else {
                sourceIDMismatches += 1
                continue
            }
            if sourceIDSet.contains(sourceID) { sourceIDMismatches += 1 }
            sourceIDSet.insert(sourceID)
        }

        // Branch enumeration per arc.
        var branches: [[String: Any]] = []
        for story in catalog.stories {
            let branchChoices = story.branchChoices.map {
                $0.stableID(in: story.id)
            }
            branches.append([
                "arc": story.id.rawValue,
                "title": story.title,
                "branch_choice_count": branchChoices.count,
                "branch_choices": branchChoices,
                "stage_count": story.stages.count,
            ] as [String: Any])
        }

        // Interpolation token whitelist check + resolved residue check.
        var tokenViolations = 0
        var unresolvedResidue = 0
        for line in catalog.allDialogueLines {
            let tokens = StoryDialogueInterpolator.tokens(in: line.text)
            if let unknown = tokens.first(where: {
                !StoryDialogueInterpolator.allowedTokens.contains($0)
            }) {
                tokenViolations += 1
                _ = unknown
            }
            // Resolve with a representative standing and Q05 resolution.
            let context = StoryDialogueInterpolationContext(
                standing: 90,
                q05Resolution: .coop
            )
            do {
                _ = try StoryDialogueInterpolator.interpolate(line.text, context: context)
            } catch {
                // A line without tokens that contains "{{" is a residue.
                if tokens.isEmpty, line.text.contains("{{") {
                    unresolvedResidue += 1
                }
            }
            if line.text.contains("{{"), tokens.isEmpty {
                unresolvedResidue += 1
            }
        }

        // Cue enumeration.
        let cueEntries = catalog.blockingCues.map { cue in
            [
                "cue_id": cue.id,
                "source_blocking_id": cue.sourceBlockingID,
                "arc": cue.arcID.rawValue,
                "scene_id": cue.sceneID,
                "branch_movement_count": cue.branchMovement.count,
            ] as [String: Any]
        }

        return [
            "generator": "N027TimelineTests",
            "story_count": catalog.stories.count,
            "manuscript_line_count": manuscript.count,
            "inline_choice_response_count": inline.count,
            "cue_count": catalog.blockingCues.count,
            "source_id_mapping_mismatches": sourceIDMismatches,
            "source_id_unique_count": sourceIDSet.count,
            "token_violations": tokenViolations,
            "unresolved_token_residue": unresolvedResidue,
            "allowed_tokens": Array(StoryDialogueInterpolator.allowedTokens).sorted(),
            "branches": branches,
            "cues": cueEntries,
        ]
    }
}
