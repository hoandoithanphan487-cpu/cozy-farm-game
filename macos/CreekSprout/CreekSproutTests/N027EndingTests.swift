import Foundation
import XCTest
@testable import CreekSprout

/// Phase G: Q09/Q10 finale. Ledger discovery, all-evil confrontation, the two
/// final actions (water / leave) and graduation. Every fixture is a legal
/// `GameState` (passes `SaveValidation.validateN027`) reached through the real
/// Q08 journey chain, so no invalid intermediate states are constructed.
final class N027EndingTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let slot = SaveSlotCatalog.manualSlotNames[0]

    // MARK: - Legal fixtures (hand-built but save-validated in each test)

    /// One legally resolved Q01–Q07 arc: full phase chain, standing receipt,
    /// choice, action receipts and monotonic evidence serials.
    private func resolvedSegment(arcID: StoryArcID, baseDay: Int) -> StorySegmentState {
        var segment = StorySegmentState.locked(arcID)
        segment.enter(.benefit, day: baseDay)
        segment.benefitOfferID = "brookseed.story.offer.\(arcID.shortCode).day_\(baseDay)"
        segment.benefitBaselineDay = baseDay
        segment.benefitBaseline = StoryMetricBaseline.zero
        segment.enter(.warningOne, day: baseDay + 1)
        segment.warningOneEvidenceSerial = 0
        segment.warningOneEvidenceCheckSerial = 0
        segment.warningOneSleepEpoch = 1
        segment.enter(.warningTwo, day: baseDay + 2)
        segment.warningTwoEvidenceSerial = 1
        segment.warningTwoSleepEpoch = (arcID == .q02 || arcID == .q07) ? 2 : 1
        segment.enter(.eruption, day: baseDay + 3)
        segment.enter(.aftermath, day: baseDay + 3)
        segment.enter(.resolved, day: baseDay + 5)
        segment.aftermathQuality = .responsible
        let standingID = "brookseed.story.receipt.\(arcID.shortCode).standing"
        segment.standingAwardReceiptID = standingID
        segment.effectReceiptIDs = [standingID]
        var actionIDs = [
            "brookseed.story.\(arcID.shortCode).action.between_warnings",
            "brookseed.story.\(arcID.shortCode).action.pre_eruption",
        ]
        if arcID == .q06 {
            actionIDs.append(contentsOf: [
                "brookseed.story.q06.care.shared_log",
                "brookseed.story.q06.care.tea_and_roster",
            ])
        }
        segment.completedActionIDs = actionIDs.sorted()
        segment.lastRelatedActionSerial = actionIDs.count
        if arcID == .q06 {
            segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.aftermath.rawValue] =
                StoryChoiceID.love.stableID(in: .q06)
            segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.eruption.rawValue] =
                StoryChoiceID.talk.stableID(in: .q06)
        } else {
            let choice = StoryChoiceID.choices(for: arcID)[0]
            segment.selectedChoiceIDsBySlot[choice.slot(in: arcID).rawValue] =
                choice.stableID(in: arcID)
        }
        return segment
    }

    private func applyResolvedArc(
        _ state: inout GameState,
        arcID: StoryArcID,
        baseDay: Int
    ) {
        let segment = resolvedSegment(arcID: arcID, baseDay: baseDay)
        state.storyCampaign.updateSegment(segment)
        let standingID = "brookseed.story.receipt.\(arcID.shortCode).standing"
        state.storyCampaign.effectReceipts.append(
            StoryReceiptRecord(receiptID: standingID, sourceID: arcID.rawValue, day: baseDay + 5)
        )
        for (offset, actionID) in segment.completedActionIDs.enumerated() {
            let day: Int
            if arcID == .q06, actionID.hasPrefix("brookseed.story.q06.care.") {
                day = baseDay
            } else {
                day = baseDay + min(offset, 1)
            }
            state.storyCampaign.actionReceipts.append(
                StoryReceiptRecord(
                    receiptID: "brookseed.story.receipt.action.\(arcID.shortCode).\(actionID)",
                    sourceID: actionID,
                    day: day
                )
            )
        }
        if arcID == .q06 {
            state.storyCampaign.choices.append(
                StoryChoiceRecord(
                    arcID: .q06,
                    slotID: .aftermath,
                    choiceID: StoryChoiceID.love.stableID(in: .q06),
                    day: baseDay + 4
                )
            )
            state.storyCampaign.choices.append(
                StoryChoiceRecord(
                    arcID: .q06,
                    slotID: .eruption,
                    choiceID: StoryChoiceID.talk.stableID(in: .q06),
                    day: baseDay + 3
                )
            )
            state.storyCampaign.romanceTender = true
            state.storyCampaign.q06Outcome = .love
        } else {
            let choice = StoryChoiceID.choices(for: arcID)[0]
            state.storyCampaign.choices.append(
                StoryChoiceRecord(
                    arcID: arcID,
                    slotID: choice.slot(in: arcID),
                    choiceID: choice.stableID(in: arcID),
                    day: baseDay + 3
                )
            )
        }
        state.storyMetrics.relatedActionSerials[arcID.rawValue] = segment.lastRelatedActionSerial
        state.storyMetrics.canonicalize()
    }

    /// Q01–Q07 resolved, Q08 at eruption with the evidence check recorded,
    /// M3 offers paused, standing as requested. Ready for `prepareJourney`.
    private func endingReadyState(standing: Int) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        let bases: [(StoryArcID, Int)] = [
            (.q01, 2), (.q02, 10), (.q03, 18), (.q04, 26), (.q05, 34), (.q06, 42), (.q07, 50),
        ]
        for (arcID, baseDay) in bases {
            applyResolvedArc(&state, arcID: arcID, baseDay: baseDay)
        }
        var q08 = StorySegmentState.locked(.q08)
        q08.enter(.benefit, day: 58)
        q08.benefitOfferID = "brookseed.story.offer.q08.day_58"
        q08.benefitBaselineDay = 58
        q08.benefitBaseline = StoryMetricBaseline.zero
        q08.enter(.warningOne, day: 59)
        q08.warningOneEvidenceSerial = 0
        q08.warningOneEvidenceCheckSerial = 0
        q08.warningOneSleepEpoch = 1
        q08.enter(.warningTwo, day: 60)
        q08.warningTwoEvidenceSerial = 1
        q08.warningTwoSleepEpoch = 1
        q08.enter(.eruption, day: 61)
        q08.lastRelatedActionSerial = 2
        q08.completedActionIDs = [
            "brookseed.story.q08.action.between_warnings",
            "brookseed.story.q08.action.pre_eruption",
        ]
        state.storyCampaign.updateSegment(q08)
        for (offset, actionID) in q08.completedActionIDs.enumerated() {
            state.storyCampaign.actionReceipts.append(
                StoryReceiptRecord(
                    receiptID: "brookseed.story.receipt.action.q08.\(actionID)",
                    sourceID: actionID,
                    day: 60 + min(offset, 1)
                )
            )
        }
        state.storyMetrics.relatedActionSerials[StoryArcID.q08.rawValue] = 2
        state.storyMetrics.evidenceCheckSerials[StoryArcID.q08.rawValue] = 1
        state.storyCampaign.m3OffersPaused = true
        state.community.standing = standing
        state.clock = GameClock(day: 63, minute: GameClock.dayStartMinute)
        // Two growing cells so the journey covers real crops.
        let berryTotal = catalog.crop(id: ContentID.bellBerryCrop)!.stageDays.reduce(0, +)
        state.farmCells = [
            GridPosition(x: 5, y: 5): FarmCell(
                prepared: true,
                cropID: ContentID.mistRadishCrop,
                cropStage: 0,
                stageProgressDays: 1,
                plantedDay: 58,
                readyToHarvest: false
            ),
            GridPosition(x: 6, y: 5): FarmCell(
                prepared: true,
                cropID: ContentID.bellBerryCrop,
                cropStage: 1,
                stageProgressDays: berryTotal - 1,
                plantedDay: 58,
                readyToHarvest: false
            ),
        ]
        state.economy.shipping.pendingEntries = [
            ShippingEntry(
                entryID: ShippingEntry.mergeKey(
                    itemID: ContentID.creekGreensItem,
                    quality: .normal,
                    depositedDay: 62
                ),
                itemID: ContentID.creekGreensItem,
                quantity: 5,
                quality: .normal,
                depositedDay: 62,
                unitPriceSnapshot: 6
            ),
            ShippingEntry(
                entryID: ShippingEntry.mergeKey(
                    itemID: ContentID.mistRadishItem,
                    quality: .normal,
                    depositedDay: 62
                ),
                itemID: ContentID.mistRadishItem,
                quantity: 3,
                quality: .normal,
                depositedDay: 62,
                unitPriceSnapshot: 10
            ),
        ]
        state.storyCampaign.canonicalize()
        state.storyMetrics.canonicalize()
        return state
    }

    private func makeCoordinator() throws -> (CampaignSaveCoordinator, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("n027-ending-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return (CampaignSaveCoordinator(rootDirectory: root, catalog: catalog), root)
    }

    /// Creates a campaign, runs the full Q08 journey, and returns the state
    /// after `resolveResponsibleAftermath(.q08)` with the clock advanced two
    /// days. `finaleBeat` is still `.locked`.
    private func endingReady(
        coordinator: CampaignSaveCoordinator,
        standing: Int = 90
    ) throws -> GameState {
        let created = try coordinator.createNewCampaign(manualSlotIndex: 0) { campaignID in
            var state = self.endingReadyState(standing: standing)
            state.campaignID = campaignID
            return state
        }
        let ready = created.state
        let generation = try JourneyService.prepareJourney(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        var current = generation.state
        for checkpoint in [StoryJourneyCheckpoint.oldWaterway, .mistRidgeFork, .greyFenceFarm] {
            current = try JourneyService.advanceCheckpoint(
                state: current,
                to: checkpoint
            ).get()
            _ = try coordinator.save(
                current,
                kind: .missionCurrent,
                ownerManualSlot: slot
            )
        }
        // Primary route choice before homecoming.
        current.storyCampaign.choices.append(
            StoryChoiceRecord(
                arcID: .q08,
                slotID: .primary,
                choiceID: StoryChoiceID.evidence.stableID(in: .q08),
                day: current.clock.day
            )
        )
        var q08Segment = current.storyCampaign.segment(.q08)!
        q08Segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.primary.rawValue] =
            StoryChoiceID.evidence.stableID(in: .q08)
        current.storyCampaign.updateSegment(q08Segment)
        current.storyCampaign.canonicalize()

        let home = try JourneyService.completeHomecoming(
            state: current,
            coordinator: coordinator,
            ownerManualSlot: slot
        ).state
        // Two-day aftermath before resolving Q08.
        var after = home
        after.clock = GameClock(day: home.clock.day + 2, minute: GameClock.dayStartMinute)
        let resolved = try StoryDirector.resolveResponsibleAftermath(
            state: after,
            arcID: .q08
        ).get()
        try SaveValidation.validateN027(resolved, catalog: catalog)
        return resolved
    }

    // MARK: - Test 1: Q09 trigger conditions

    func testBeginDiscoveryRequiresCompletedQ08Journey() throws {
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        XCTAssertEqual(ready.storyCampaign.finaleBeat, .locked)
        XCTAssertTrue(ready.storyCampaign.q08Completed)
        XCTAssertEqual(ready.storyCampaign.segment(.q08)?.phase, .resolved)
        XCTAssertEqual(ready.storyCampaign.mission?.status, .completed)
        XCTAssertEqual(ready.storyCampaign.mission?.checkpoint, .homecoming)

        // beginDiscovery succeeds only after the completed journey.
        let generation = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        XCTAssertEqual(generation.state.storyCampaign.finaleBeat, .preRevealSavePending)
        XCTAssertTrue(generation.state.storyCampaign.protection.preRevealVerified)
    }

    func testBeginDiscoveryFailsBeforeJourneyCompletion() throws {
        let (coordinator, _) = try makeCoordinator()
        // Mission not completed: Q08 still at eruption.
        let created = try coordinator.createNewCampaign(manualSlotIndex: 0) { campaignID in
            var state = self.endingReadyState(standing: 90)
            state.campaignID = campaignID
            return state
        }
        let notCompleted = created.state
        XCTAssertThrowsError(
            try FinaleService.beginDiscovery(
                state: notCompleted,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        ) { error in
            XCTAssertEqual(error as? FinaleFailure, .preRevealWriteFailed)
        }
        // finaleBeat already advanced (not .locked) is rejected.
        let ready = try endingReady(coordinator: coordinator)
        let advanced = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        ).state
        XCTAssertThrowsError(
            try FinaleService.beginDiscovery(
                state: advanced,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        ) { error in
            XCTAssertEqual(error as? FinaleFailure, .invalidTransition)
        }
    }

    // MARK: - Test 2: pre_reveal atomicity

    func testPreRevealWrittenBeforeDiscoveryAndNotOverwritten() throws {
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        let generation = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        // pre_reveal is readable and reflects the pre-discovery state.
        let protection = try coordinator.loadProtection(
            campaignID: ready.campaignID,
            kind: .preReveal,
            ownerManualSlot: slot
        )
        XCTAssertEqual(protection.state.storyCampaign.finaleBeat, .locked)
        XCTAssertFalse(protection.state.storyCampaign.gallery.isUnlocked)
        XCTAssertEqual(protection.state.storyCampaign.protection.preRevealVerified, false)

        // A later ordinary campaignAuto save must not overwrite pre_reveal.
        var afterDiscovery = generation.state
        afterDiscovery = try FinaleService.enterDiscovery(state: afterDiscovery).get()
        _ = try coordinator.save(afterDiscovery, kind: .campaignAuto, ownerManualSlot: slot)
        let protectionAfter = try coordinator.loadProtection(
            campaignID: ready.campaignID,
            kind: .preReveal,
            ownerManualSlot: slot
        )
        XCTAssertEqual(protectionAfter.state.storyCampaign.finaleBeat, .locked)
        XCTAssertFalse(protectionAfter.state.storyCampaign.gallery.isUnlocked)
    }

    func testPreRevealNeverBecomesContinueCandidate() throws {
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        _ = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertNotEqual(continued.generation.metadata.generationKind, .preReveal)
        XCTAssertFalse(SaveGenerationKind.preReveal.participatesInAutomaticContinue)
    }

    func testInvalidSlotRejectsPreRevealWrite() throws {
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        XCTAssertThrowsError(
            try FinaleService.beginDiscovery(
                state: ready,
                coordinator: coordinator,
                ownerManualSlot: "not_a_slot"
            )
        ) { error in
            XCTAssertEqual(error as? FinaleFailure, .preRevealWriteFailed)
        }
        // finaleBeat stays locked; no Q09 entry.
        XCTAssertEqual(ready.storyCampaign.finaleBeat, .locked)
    }

    // MARK: - Test 3: Q09 four ledger intents

    private func enterQ09Discovery(
        coordinator: CampaignSaveCoordinator
    ) throws -> GameState {
        let ready = try endingReady(coordinator: coordinator)
        let generation = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        return try FinaleService.enterDiscovery(state: generation.state).get()
    }

    func testQ09FourLedgerIntentsReachConfrontation() throws {
        let (coordinator, _) = try makeCoordinator()
        let discovery = try enterQ09Discovery(coordinator: coordinator)
        XCTAssertEqual(discovery.storyCampaign.finaleBeat, .discovery)
        XCTAssertEqual(discovery.storyCampaign.frontstageLease?.owner, .finale)

        // Discovery text is presentable.
        let session = try FinaleService.openStageSession(state: discovery).get()
        XCTAssertNotNil(session.storyCampaign.dialogueSession)

        for intent in [StoryChoiceID.takeLedger, .keepReading, .closeLedger, .returnTitles] {
            var state = discovery
            // Record the intent through the command service (the domain's
            // q09 intent slot is `.ledgerIntent`).
            state = try StoryCommandService.selectChoice(
                state: state,
                arcID: .q09,
                choice: intent
            ).get()
            XCTAssertTrue(
                state.storyCampaign.choices.contains {
                    $0.arcID == .q09 && $0.slotID == .ledgerIntent
                }
            )
            let confrontation = try FinaleService.advanceAfterLedgerIntent(state: state).get()
            XCTAssertEqual(confrontation.storyCampaign.finaleBeat, .confrontation)
            XCTAssertEqual(confrontation.storyCampaign.frontstageLease?.owner, .finale)
            XCTAssertEqual(confrontation.storyCampaign.cursor.eventID, StoryArcID.q10.rawValue)
        }
    }

    // MARK: - Test 4: Q10 four confrontation intents + two final actions

    private func enterQ10Confrontation(
        coordinator: CampaignSaveCoordinator
    ) throws -> GameState {
        let discovery = try enterQ09Discovery(coordinator: coordinator)
        var state = discovery
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q09,
            choice: .takeLedger
        ).get()
        return try FinaleService.advanceAfterLedgerIntent(state: state).get()
    }

    func testQ10FourConfrontationIntentsReachFinalAction() throws {
        let (coordinator, _) = try makeCoordinator()
        let confrontation = try enterQ10Confrontation(coordinator: coordinator)
        XCTAssertEqual(confrontation.storyCampaign.finaleBeat, .confrontation)

        let session = try FinaleService.openStageSession(state: confrontation).get()
        XCTAssertNotNil(session.storyCampaign.dialogueSession)

        for intent in [StoryChoiceID.whyMe, .anyTruth, .silence, .breakTitles] {
            var state = confrontation
            state = try StoryCommandService.selectChoice(
                state: state,
                arcID: .q10,
                choice: intent
            ).get()
            XCTAssertTrue(
                state.storyCampaign.choices.contains {
                    $0.arcID == .q10 && $0.slotID == .confrontationIntent
                }
            )
            let pending = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
            XCTAssertEqual(pending.storyCampaign.finaleBeat, .finalActionPending)
        }
    }

    func testQ10TwoFinalActionsReachable() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        let pending = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        XCTAssertEqual(pending.storyCampaign.finaleBeat, .finalActionPending)

        // water and leave are both valid `finalAction` slot choices.
        for action in [StoryChoiceID.water, .leave] {
            let recorded = try StoryCommandService.selectChoice(
                state: pending,
                arcID: .q10,
                choice: action
            ).get()
            XCTAssertTrue(
                recorded.storyCampaign.choices.contains {
                    $0.arcID == .q10 && $0.slotID == .finalAction
                }
            )
        }
    }

    // MARK: - Test 5: cancel before confirmation returns control

    func testGraduateAfterWaterMissingWateredCellReturnsControl() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        // On the farm but no watered cell.
        state.currentMapID = ContentID.farmHomestead
        let before = state
        let result = FinaleService.graduateAfterWater(state: state)
        guard case .failure(let error) = result else {
            return XCTFail("graduateAfterWater must fail without a watered cell")
        }
        XCTAssertEqual(error, .waterActionMissing)
        XCTAssertEqual(state, before, "a rejected graduation must not mutate state")
    }

    func testGraduateAfterLeaveWrongAnchorReturnsControl() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .leave
        ).get()
        // Wrong position (not the wharf cell).
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 9, y: 8)
        let before = state
        let result = FinaleService.graduateAfterLeave(state: state)
        guard case .failure(let error) = result else {
            return XCTFail("graduateAfterLeave must fail away from the departure anchor")
        }
        XCTAssertEqual(error, .leaveAnchorUnavailable)
        XCTAssertEqual(state, before, "a rejected graduation must not mutate state")
    }

    func testCancelSessionReleasesLease() throws {
        let (coordinator, _) = try makeCoordinator()
        let discovery = try enterQ09Discovery(coordinator: coordinator)
        let session = try FinaleService.openStageSession(state: discovery).get()
        XCTAssertNotNil(session.storyCampaign.dialogueSession)
        XCTAssertEqual(session.storyCampaign.frontstageLease?.owner, .finale)
        let cancelled = try StoryDialogueService.cancelSession(state: session).get()
        XCTAssertNil(cancelled.storyCampaign.dialogueSession)
        XCTAssertNil(cancelled.storyCampaign.frontstageLease)
        XCTAssertEqual(cancelled.storyCampaign.cursor, .empty)
        // Phase is unchanged.
        XCTAssertEqual(cancelled.storyCampaign.finaleBeat, .discovery)
    }

    // MARK: - Test 6: water graduation

    func testWaterGraduationRequiresFarmAndWateredCell() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .water
        ).get()
        // On the farm with one watered (prepared, crop-less) cell.
        state.currentMapID = ContentID.farmHomestead
        state.farmCells[GridPosition(x: 5, y: 5)] = FarmCell(
            prepared: true,
            wateredToday: true,
            fertility: 0,
            cropID: "",
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 0,
            readyToHarvest: false,
            dryStreak: 0,
            cropCondition: .healthy
        )
        let graduated = try FinaleService.graduateAfterWater(state: state).get()
        XCTAssertEqual(graduated.storyCampaign.finaleBeat, .graduated)
        XCTAssertEqual(graduated.storyCampaign.gallery.endingID, "brookseed.story.ending.water")
        try SaveValidation.validateN027(graduated, catalog: catalog)
    }

    // MARK: - Test 7: leave graduation

    func testLeaveGraduationRequiresDepartureAnchor() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .leave
        ).get()
        // Standing at the wharf interaction cell (3,5).
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 3, y: 5)
        let graduated = try FinaleService.graduateAfterLeave(state: state).get()
        XCTAssertEqual(graduated.storyCampaign.finaleBeat, .graduated)
        XCTAssertEqual(graduated.storyCampaign.gallery.endingID, "brookseed.story.ending.leave")
        try SaveValidation.validateN027(graduated, catalog: catalog)
    }

    func testDepartureAnchorResolvesToExistingLandmark() throws {
        guard let anchor = StoryAnchorCatalog.anchor(id: StoryAnchorCatalog.endingDepartureAnchorID),
              case let .worldGrid(world) = anchor else {
            return XCTFail("ending_departure must be a world-grid anchor")
        }
        XCTAssertEqual(world.mapID, ContentID.creekMarket)
        XCTAssertEqual(world.cell, GridPosition(x: 3, y: 5))
        XCTAssertEqual(world.landmarkID, "brookseed.landmark.market_wharf")
        // The landmark exists on the creek market map.
        let map = try XCTUnwrap(catalog.map(id: ContentID.creekMarket))
        XCTAssertTrue(map.landmarks.contains { $0.id == "brookseed.landmark.market_wharf" })
    }

    // MARK: - Test 8: graduation preservation

    func testGraduationPreservesFarmAndUnlocksGallery() throws {
        let (coordinator, _) = try makeCoordinator()
        var state = try enterQ10Confrontation(coordinator: coordinator)
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .water
        ).get()
        state.currentMapID = ContentID.farmHomestead
        state.farmCells[GridPosition(x: 5, y: 5)] = FarmCell(
            prepared: true,
            wateredToday: true,
            fertility: 0,
            cropID: "",
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 0,
            readyToHarvest: false,
            dryStreak: 0,
            cropCondition: .healthy
        )
        let balanceBefore = state.economy.balance
        let standingBefore = state.community.standing
        let animalsBefore = state.livestock.animals
        let relationshipsBefore = state.relationships
        let cellsBefore = state.farmCells

        let graduated = try FinaleService.graduateAfterWater(state: state).get()

        // Farm, currency, animals, relationships and standing are preserved.
        XCTAssertEqual(graduated.economy.balance, balanceBefore)
        XCTAssertEqual(graduated.community.standing, standingBefore)
        XCTAssertEqual(graduated.livestock.animals, animalsBefore)
        XCTAssertEqual(graduated.relationships, relationshipsBefore)
        XCTAssertEqual(graduated.farmCells, cellsBefore)
        // Finale flags.
        XCTAssertTrue(graduated.storyCampaign.communityEvaluationDisabled)
        XCTAssertTrue(graduated.storyCampaign.gallery.isUnlocked)
        XCTAssertNotNil(graduated.storyCampaign.gallery.endingID)
        XCTAssertEqual(graduated.storyCampaign.finaleBeat, .graduated)
        XCTAssertNil(graduated.storyCampaign.frontstageLease)
        try SaveValidation.validateN027(graduated, catalog: catalog)
    }

    func testRecallPreRevealAfterGraduation() throws {
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        let generation = try FinaleService.beginDiscovery(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        var state = try FinaleService.enterDiscovery(state: generation.state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q09,
            choice: .takeLedger
        ).get()
        state = try FinaleService.advanceAfterLedgerIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .breakTitles
        ).get()
        state = try FinaleService.advanceAfterConfrontationIntent(state: state).get()
        state = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .water
        ).get()
        state.currentMapID = ContentID.farmHomestead
        state.farmCells[GridPosition(x: 5, y: 5)] = FarmCell(
            prepared: true,
            wateredToday: true,
            fertility: 0,
            cropID: "",
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 0,
            readyToHarvest: false,
            dryStreak: 0,
            cropCondition: .healthy
        )
        let graduated = try FinaleService.graduateAfterWater(state: state).get()

        // recallPreReveal reads back the pre-reveal protection (locked, no
        // reveal content).
        let recalled = try FinaleService.recallPreReveal(
            state: graduated,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        XCTAssertEqual(recalled.storyCampaign.finaleBeat, .locked)
        XCTAssertFalse(recalled.storyCampaign.gallery.isUnlocked)
        XCTAssertNil(recalled.storyCampaign.gallery.endingID)
    }

    // MARK: - Test 9: finale conspirator roster

    func testConspiratorRosterHasThirteenDistinctMembers() throws {
        let roster = StoryActorCatalog.conspiratorRoster
        XCTAssertEqual(roster.count, 13)
        XCTAssertEqual(Set(roster).count, 13, "roster must be distinct")
        for expected in [
            StoryActorID.waterApprentice,
            StoryActorID.seedSteward,
            StoryActorID.creekWarden,
            StoryActorID.neighborHearsay,
            StoryActorID.neighborStoryteller,
            StoryActorID.neighborEvidence,
            StoryActorID.neighborConsensus,
            StoryActorID.catShopBlack,
            StoryActorID.catShopCalico,
            StoryActorID.catShopRagdoll,
            StoryActorID.bellPrincess,
            StoryActorID.greygateRepresentative,
            StoryActorID.greygateFarmer,
        ] {
            XCTAssertTrue(roster.contains(expected), "missing \(expected)")
        }
        XCTAssertNotEqual(StoryActorID.greygateRepresentative, StoryActorID.greygateFarmer)
    }

    // MARK: - Test 10: zero reveal leakage before Q09

    func testNoRevealLeakageBeforeFinaleUnlock() throws {
        let storyCatalog = StoryContentCatalog.shared
        // Q01–Q08 reveal callbacks are finale-only: hidden before, visible after.
        for arcID in StoryArcID.allCases where arcID.sequence <= 8 {
            XCTAssertTrue(
                storyCatalog.visibleLines(
                    arcID: arcID,
                    stage: .revealCallback,
                    finaleUnlocked: false
                ).isEmpty,
                "\(arcID.shortCode) reveal callback leaked before finale"
            )
            XCTAssertFalse(
                storyCatalog.visibleLines(
                    arcID: arcID,
                    stage: .revealCallback,
                    finaleUnlocked: true
                ).isEmpty,
                "\(arcID.shortCode) reveal callback missing after finale"
            )
        }
        // Every finale (q09/q10) blocking cue is finale-only: hidden before,
        // visible after.
        for cue in storyCatalog.blockingCues where cue.arcID.sequence >= 9 {
            XCTAssertNil(
                storyCatalog.visibleBlockingCue(id: cue.id, finaleUnlocked: false),
                cue.id
            )
            XCTAssertNotNil(
                storyCatalog.visibleBlockingCue(id: cue.id, finaleUnlocked: true),
                cue.id
            )
        }
        // Gallery is locked before graduation.
        let (coordinator, _) = try makeCoordinator()
        let ready = try endingReady(coordinator: coordinator)
        XCTAssertFalse(ready.storyCampaign.gallery.isUnlocked)
    }
}
