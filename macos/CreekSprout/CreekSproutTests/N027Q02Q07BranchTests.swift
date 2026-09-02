import Foundation
import XCTest
@testable import CreekSprout

/// Phase D: every fixed branch of Q02–Q07 completes through the unified
/// dialogue/intent/aftermath machinery with the fixed +6 standing award,
/// support tiers, repair commissions and Q07 celebration inventory.
final class N027Q02Q07BranchTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let storyCatalog = StoryContentCatalog.shared

    private struct BranchRun {
        var arcID: StoryArcID
        var choice: StoryChoiceID
        var state: GameState
        var standing: Int
        var resolved: Bool
    }

    /// Drives one arc from an eruption-phase fixture through dialogue,
    /// branch intent, aftermath and resolution.
    private func runBranch(
        arcID: StoryArcID,
        choice: StoryChoiceID,
        standing: Int,
        day: Int
    ) throws -> BranchRun {
        var state = N027StoryFixtures.targetFixture(
            target: arcID,
            phase: .eruption,
            baseDay: day,
            standing: standing,
            q06CaresCompleted: !(arcID == .q06 && choice == .friend)
        )
        // The fixture itself must be a save-valid state. Q06 care actions are
        // completed inside the fixture: `recordAction` only accepts them
        // during benefit, not at eruption.
        try SaveValidation.validateN027(state, catalog: catalog)

        // Q06 stable branches span both intent slots: love/tender/friend
        // derive their eruption intent from the target outcome.
        var eruptionIntent = choice
        if arcID == .q06 {
            switch choice {
            case .love, .friend:
                eruptionIntent = .talk
            case .tender:
                eruptionIntent = .pause
            default:
                break
            }
        }

        // Eruption dialogue: two lines, intent, response, remainder.
        let armed = try StoryCommandService.beginBlockingSession(
            state: state,
            arcID: arcID,
            phase: .eruption,
            cueID: "brookseed.story.\(arcID.shortCode).cue.blk_03",
            catalog: storyCatalog
        ).get()
        var session = try StoryDialogueService.openSession(state: armed, catalog: storyCatalog).get()
        while true {
            let result = StoryDialogueService.advance(state: session, catalog: storyCatalog)
            guard case .success(let outcome) = result else { break }
            session = outcome.state
            if outcome.reachedEnd { break }
        }
        session = try StoryDialogueService.selectIntent(
            state: session,
            choice: eruptionIntent,
            catalog: storyCatalog
        ).get()
        while true {
            let result = StoryDialogueService.advance(state: session, catalog: storyCatalog)
            guard case .success(let outcome) = result else { break }
            session = outcome.state
            if outcome.reachedEnd { break }
        }
        session = try StoryDirector.closeDialogue(
            state: session,
            arcID: arcID,
            completedPhase: .eruption
        ).get()
        XCTAssertEqual(session.storyCampaign.segment(arcID)?.phase, .aftermath)
        let aftermathStartDay = try XCTUnwrap(
            session.storyCampaign.segment(arcID)?.aftermathStartDay
        )

        // Q06 aftermath intent must follow the derived outcome. The intent
        // is recorded through the real selectChoice transaction; pause →
        // tender requires a strictly later day than the eruption intent.
        if arcID == .q06 {
            var aftermathChoice: StoryChoiceID
            if choice == .love || choice == .tender || choice == .friend {
                aftermathChoice = choice
            } else if session.storyCampaign.q06Outcome == .love {
                aftermathChoice = .love
            } else if session.storyCampaign.q06Outcome == .tender {
                aftermathChoice = .tender
            } else {
                aftermathChoice = .friend
            }
            if eruptionIntent == .pause {
                session.clock = GameClock(
                    day: session.clock.day + 1,
                    minute: GameClock.dayStartMinute
                )
            }
            session = try StoryCommandService.selectChoice(
                state: session,
                arcID: .q06,
                choice: aftermathChoice
            ).get()
            XCTAssertNotNil(session.storyCampaign.q06Outcome)
        }

        // Two-day aftermath then responsible resolution.
        state = session
        state.clock = GameClock(
            day: aftermathStartDay + 2,
            minute: GameClock.dayStartMinute
        )
        let resolved = try StoryDirector.resolveResponsibleAftermath(
            state: state,
            arcID: arcID
        ).get()
        try SaveValidation.validateN027(resolved, catalog: catalog)
        XCTAssertEqual(
            resolved.storyCampaign.segment(arcID)?.phase,
            .resolved
        )
        XCTAssertEqual(
            resolved.storyCampaign.segment(arcID)?.standingAwardReceiptID,
            "brookseed.story.receipt.\(arcID.shortCode).standing"
        )
        return BranchRun(
            arcID: arcID,
            choice: choice,
            state: resolved,
            standing: resolved.community.standing,
            resolved: true
        )
    }

    func testAllQ02Q07FixedBranchesCompleteWithFixedPlusSix() throws {
        let standing = 50
        let cases: [(StoryArcID, [StoryChoiceID])] = [
            (.q02, [.harvest, .sandbag, .patrol, .livestock]),
            (.q03, [.cutTest, .traceRumor, .protectInventory]),
            (.q04, [.regroup, .parallelCrop, .publishMissingPage]),
            (.q05, [.publicOrder, .coop, .delay]),
            (.q06, [.talk, .noSide, .pause, .love, .tender, .friend]),
            (.q07, [.menu, .inventory, .harvest, .livestock]),
        ]
        var priorStanding = standing
        var runs: [BranchRun] = []
        for (arcID, choices) in cases {
            for choice in choices {
                let run = try runBranch(
                    arcID: arcID,
                    choice: choice,
                    standing: priorStanding,
                    day: 14 + arcID.sequence * 2
                )
                runs.append(run)
                XCTAssertEqual(run.standing, priorStanding + 6, "\(arcID.rawValue) \(choice.rawValue)")
                XCTAssertTrue(run.resolved)
            }
            priorStanding += 6
        }
        XCTAssertEqual(runs.count, 23)
        XCTAssertEqual(runs.filter(\.resolved).count, 23)
        // Fixed +6 is the only story standing change: 50 + 6×6 = 86 for Q07.
        XCTAssertEqual(priorStanding, 86)
    }

    func testQ06ThreeOutcomesAreMutuallyExclusiveAndPersist() throws {
        // pause → tender
        var paused = GameState.vs0NewGame(catalog: catalog)
        paused.clock = GameClock(day: 14, minute: GameClock.dayStartMinute)
        var segment = StorySegmentState.locked(.q06)
        segment.enter(.benefit, day: 10)
        segment.warningOneEvidenceSerial = 0
        segment.warningOneEvidenceCheckSerial = 0
        segment.warningOneSleepEpoch = 1
        segment.enter(.warningOne, day: 11)
        segment.enter(.warningTwo, day: 12)
        segment.warningTwoEvidenceSerial = 1
        segment.warningTwoSleepEpoch = 1
        segment.enter(.eruption, day: 14)
        segment.lastRelatedActionSerial = 2
        segment.completedActionIDs = [
            "brookseed.story.q06.action.between_warnings",
            "brookseed.story.q06.action.pre_eruption",
        ]
        paused.storyCampaign.updateSegment(segment)
        paused.storyMetrics.relatedActionSerials[StoryArcID.q06.rawValue] = 2
        paused.storyMetrics.canonicalize()

        let armed = try StoryCommandService.beginBlockingSession(
            state: paused,
            arcID: .q06,
            phase: .eruption,
            cueID: "brookseed.story.q06.cue.blk_03",
            catalog: storyCatalog
        ).get()
        var session = try StoryDialogueService.openSession(state: armed, catalog: storyCatalog).get()
        while true {
            let result = StoryDialogueService.advance(state: session, catalog: storyCatalog)
            guard case .success(let outcome) = result else { break }
            session = outcome.state
            if outcome.reachedEnd { break }
        }
        session = try StoryDialogueService.selectIntent(
            state: session,
            choice: .pause,
            catalog: storyCatalog
        ).get()
        XCTAssertEqual(session.storyCampaign.q06Outcome, .tender)
        // Aftermath intent cannot rewrite pause → tender.
        let saved = try JSONDecoder().decode(
            StoryCampaignState.self,
            from: JSONEncoder().encode(session.storyCampaign)
        )
        XCTAssertEqual(saved.q06Outcome, .tender)
        XCTAssertFalse(saved.romanceTender)
    }

    func testSupportTierBoundariesAndSnapshotsCoverAllFourTiers() throws {
        XCTAssertEqual(StorySupportTier.resolve(standing: 0), .careful)
        XCTAssertEqual(StorySupportTier.resolve(standing: 39), .careful)
        XCTAssertEqual(StorySupportTier.resolve(standing: 40), .standard)
        XCTAssertEqual(StorySupportTier.resolve(standing: 69), .standard)
        XCTAssertEqual(StorySupportTier.resolve(standing: 70), .trusted)
        XCTAssertEqual(StorySupportTier.resolve(standing: 89), .trusted)
        XCTAssertEqual(StorySupportTier.resolve(standing: 90), .full)
        XCTAssertEqual(StorySupportTier.resolve(standing: 100), .full)

        for arcID in [StoryArcID.q02, .q07, .q08] {
            let snapshots = StorySupportTier.allCases.map { $0.snapshot(for: arcID) }
            XCTAssertEqual(Set(snapshots).count, 4, arcID.rawValue)
            for snapshot in snapshots {
                // Every tier keeps a completable manual fallback; nothing is
                // confiscated or locked.
                XCTAssertFalse(snapshot.contains("扣"), snapshot)
                XCTAssertFalse(snapshot.contains("锁"), snapshot)
                XCTAssertFalse(snapshot.contains("没收"), snapshot)
            }
        }
    }

    func testRepairCommissionsThreeMaxEachPlusSixOnlyBelowNinety() throws {
        // Start from a legally resolved Q07 produced by the branch machinery.
        // Standing 71 → 77 after resolution: three commissions then run at
        // 83, 89 and 95, so every award lands below 90 and the path closes
        // only after the third.
        let state = try runBranchState(arcID: .q07, choice: .menu, standing: 71, day: 18)
        XCTAssertEqual(state.storyCampaign.segment(.q07)?.phase, .resolved)
        XCTAssertEqual(state.community.standing, 77)
        let commissions = [
            "brookseed.story.commission.missing_page",
            "brookseed.story.commission.trail_markers",
            "brookseed.story.commission.record_ledger",
        ]
        var current = state
        for (index, commissionID) in commissions.enumerated() {
            current = try StoryDirector.completeRepairCommission(
                state: current,
                commissionID: commissionID
            ).get()
            XCTAssertEqual(current.community.standing, 77 + (index + 1) * 6)
            XCTAssertEqual(current.storyCampaign.repairCommissionIDs.count, index + 1)
        }
        XCTAssertEqual(current.community.standing, 95)
        // Standing ≥ 90 closes the commission path.
        XCTAssertEqual(
            StoryDirector.completeRepairCommission(
                state: current,
                commissionID: "brookseed.story.commission.fourth"
            ),
            .failure(.illegalTransition)
        )
        // Duplicates are rejected even while below 90.
        var below = try runBranchState(arcID: .q07, choice: .menu, standing: 74, day: 20)
        below = try StoryDirector.completeRepairCommission(
            state: below,
            commissionID: commissions[0]
        ).get()
        XCTAssertEqual(
            StoryDirector.completeRepairCommission(
                state: below,
                commissionID: commissions[0]
            ),
            .failure(.duplicateReceipt)
        )
        try SaveValidation.validateN027(below, catalog: catalog)
    }

    private func runBranchState(
        arcID: StoryArcID,
        choice: StoryChoiceID,
        standing: Int,
        day: Int
    ) throws -> GameState {
        let run = try runBranch(
            arcID: arcID,
            choice: choice,
            standing: standing,
            day: day
        )
        return run.state
    }

    func testQ07CelebrationReservationHoldsInventoryUntilResolved() throws {
        // q01–q06 legally resolved, q07 at benefit with a real offer and
        // baseline; the reservation machinery needs a save-valid base.
        var state = N027StoryFixtures.targetFixture(
            target: .q07,
            phase: .benefit,
            baseDay: 10,
            standing: 50
        )
        state.inventory = [
            InventoryQuantity(itemID: ContentID.bellBerryItem, quantity: 6),
            InventoryQuantity(itemID: ContentID.honeyMelonItem, quantity: 6),
        ]
        guard let benefitDay = state.storyCampaign.segment(.q07)?.benefitBaselineDay else {
            return XCTFail("missing q07 benefit")
        }
        state = try StoryCommandService.reserveCelebrationInventory(
            state: state,
            itemID: ContentID.bellBerryItem,
            quantity: 6,
            requestID: "brookseed.story.q07.reservation.berry_day_\(benefitDay)"
        ).get()
        XCTAssertEqual(
            state.storyCampaign.segment(.q07)?.reservedInventoryByItemID[ContentID.bellBerryItem],
            6
        )
        // The reserved stack cannot be spent while the celebration offer is
        // active (shipping, farming, crafting, cat-shop all guard it).
        let preserved = StoryInventoryReservation.isPreserved(
            state: state,
            candidateInventory: state.inventory.filter { $0.itemID != ContentID.bellBerryItem }
        )
        XCTAssertFalse(preserved, "dropping the reserved stack must be rejected")
        // Re-reserving above the held quantity is rejected.
        XCTAssertEqual(
            StoryCommandService.reserveCelebrationInventory(
                state: state,
                itemID: ContentID.bellBerryItem,
                quantity: 1,
                requestID: "brookseed.story.q07.reservation.overflow"
            ),
            .failure(.insufficientQuantity)
        )

        // Complete the arc honestly so the resolution path clears the hold.
        // Phase days stay anchored to the benefit day and the clock never
        // regresses past the reservation receipt day.
        var segment = state.storyCampaign.segment(.q07)!
        segment.enter(.warningOne, day: benefitDay + 1)
        segment.warningOneEvidenceSerial = 0
        segment.warningOneEvidenceCheckSerial = 0
        segment.warningOneSleepEpoch = 1
        segment.enter(.warningTwo, day: benefitDay + 2)
        segment.warningTwoEvidenceSerial = 1
        segment.warningTwoSleepEpoch = 2
        segment.enter(.eruption, day: benefitDay + 3)
        state.storyCampaign.updateSegment(segment)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q07,
            choice: .menu
        ).get()
        segment = state.storyCampaign.segment(.q07)!
        segment.enter(.aftermath, day: benefitDay + 3)
        state.storyCampaign.updateSegment(segment)
        // Warning evidence needs two related actions on record: one between
        // the warnings and one before eruption.
        state.storyMetrics.relatedActionSerials[StoryArcID.q07.rawValue] = 2
        state.storyMetrics.anchorReentrySerials[StoryArcID.q07.rawValue] = 2
        state.storyMetrics.canonicalize()
        state.storyCampaign.canonicalize()
        state = try StoryDirector.resolveResponsibleAftermath(
            state: state,
            arcID: .q07
        ).get()
        XCTAssertEqual(state.storyCampaign.segment(.q07)?.phase, .resolved)
        XCTAssertTrue(
            state.storyCampaign.segment(.q07)?.reservedInventoryByItemID.isEmpty == true,
            "resolution releases the reservation"
        )
        XCTAssertEqual(state.community.standing, 56)
        try SaveValidation.validateN027(state, catalog: catalog)
    }
}
