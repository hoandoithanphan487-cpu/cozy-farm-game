import Foundation
import XCTest
@testable import CreekSprout

/// Phase F: Q08 lossless journey. Two-phase departure commit, checkpoint
/// ordering and crash resume, abandon rollback via `pre_mist_ridge`, and
/// exactly-once homecoming settlement. The three journey scenes live only in
/// `StoryAnchorCatalog`; N-015 map topology is untouched.
final class N027JourneyTests: XCTestCase {
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
                // Care actions must land inside [benefitDay, warningOneDay].
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
            // Aftermath choice sorts before eruption choice; both are needed
            // for a resolved Q06.
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

    /// Q01–Q07 resolved, Q08 at eruption with the Q08 evidence check recorded,
    /// M3 offers paused, standing as requested, growing crops and two pending
    /// shipping entries. The current clock day is day 63.
    private func journeyReadyState(standing: Int) -> GameState {
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
        // Two growing cells; the bell berry is one day short of harvest so the
        // safe crop day can be observed.
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
            .appendingPathComponent("n027-journey-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return (CampaignSaveCoordinator(rootDirectory: root, catalog: catalog), root)
    }

    private func prepareJourney(
        coordinator: CampaignSaveCoordinator,
        standing: Int = 90
    ) throws -> (ready: GameState, generation: SaveGeneration) {
        let created = try coordinator.createNewCampaign(manualSlotIndex: 0) { campaignID in
            var state = self.journeyReadyState(standing: standing)
            state.campaignID = campaignID
            return state
        }
        let ready = created.state
        let generation = try JourneyService.prepareJourney(
            state: ready,
            coordinator: coordinator,
            ownerManualSlot: self.slot
        )
        return (ready, generation)
    }

    private func advanceToGreyFence(
        state: GameState,
        coordinator: CampaignSaveCoordinator
    ) throws -> GameState {
        var current = state
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
        // The player picks a grey-fence route (evidence / trade_union /
        // old_waterway) before homecoming; Q08 aftermath requires the
        // recorded primary choice and the mirrored segment slot.
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
        return current
    }

    // MARK: - Eligibility and mutual exclusion

    func testStandingNinetyRequiredForMissionSnapshot() throws {
        var below = journeyReadyState(standing: 89)
        XCTAssertEqual(
            JourneyService.buildMissionSnapshot(state: below),
            .failure(.notEligible),
            "standing 89 must not trigger Q08"
        )
        below.community.standing = 90
        guard case .success(let snapshot) = JourneyService.buildMissionSnapshot(state: below) else {
            return XCTFail("standing 90 with q08 eruption must build a mission snapshot")
        }
        XCTAssertEqual(snapshot.status, .travelling)
        XCTAssertEqual(snapshot.checkpoint, .departure)
        XCTAssertEqual(snapshot.campaignID, below.campaignID)
        // Covered crops and protected animals come from the real farm state.
        XCTAssertEqual(
            snapshot.coveredCropCellIDs.sorted(),
            below.farmCells.filter { $0.value.isGrowingCrop }
                .map { FarmCellIdentity.id(for: $0.key) }.sorted()
        )
        XCTAssertEqual(
            snapshot.protectedAnimalIDs.sorted(),
            below.livestock.animals.map(\.instanceID).sorted()
        )
        // Frozen shipping entries capture entry ID, quantity and unit price
        // (sorted by entry ID: creek greens before mist radish).
        XCTAssertEqual(
            snapshot.shippingEntries.map(\.entryID),
            below.economy.shipping.pendingEntries.map(\.entryID)
        )
        XCTAssertEqual(snapshot.shippingEntries.map(\.quantity), [5, 3])
        XCTAssertEqual(snapshot.shippingEntries.map(\.unitPrice), [6, 10])
        // A frontstage lease or an existing mission blocks the snapshot.
        var leased = below
        leased.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q08.test",
            owner: .story,
            resourceID: StoryArcID.q08.rawValue,
            acquiredDay: 63,
            checkpointID: nil
        )
        XCTAssertEqual(JourneyService.buildMissionSnapshot(state: leased), .failure(.notEligible))
    }

    func testMissionAndPrecedingStagesAreMutuallyExclusive() throws {
        // A mission cannot exist while Q08 is still before eruption.
        var premature = journeyReadyState(standing: 90)
        var q08 = premature.storyCampaign.segment(.q08)!
        // Rewind Q08 back to benefit: the save validator must reject a mission
        // attached to any pre-eruption stage.
        q08 = StorySegmentState.locked(.q08)
        q08.enter(.benefit, day: 58)
        q08.benefitOfferID = "brookseed.story.offer.q08.day_58"
        q08.benefitBaselineDay = 58
        q08.benefitBaseline = StoryMetricBaseline.zero
        premature.storyCampaign.updateSegment(q08)
        premature.storyCampaign.mission = StoryMissionSnapshot(
            campaignID: premature.campaignID,
            missionInstanceID: "brookseed.story.journey.mission.\(premature.campaignID).day_63",
            startDay: 63,
            status: .travelling,
            coveredCropCellIDs: [],
            protectedAnimalIDs: [],
            frozenOrderIDs: [],
            frozenDeadlineIDs: [],
            frozenOfferIDs: [],
            shippingEntries: [],
            checkpoint: .departure,
            settlementReceiptID: "brookseed.story.receipt.q08.homecoming.\(premature.campaignID).day_63",
            canAbandonToProtection: false
        )
        XCTAssertThrowsError(try SaveValidation.validateN027(premature, catalog: catalog))
    }

    // MARK: - Two-phase commit and crash windows

    func testTwoPhaseCommitWritesProtectionThenMissionAndLeavesMemoryUntouched() throws {
        let (coordinator, _) = try makeCoordinator()
        let (ready, generation) = try prepareJourney(coordinator: coordinator)
        // Memory was not mutated by the two-phase commit.
        XCTAssertNil(ready.storyCampaign.mission)
        XCTAssertFalse(ready.storyCampaign.protection.preMistRidgeVerified)
        // The returned generation carries the armed mission.
        XCTAssertEqual(generation.state.storyCampaign.mission?.status, .travelling)
        XCTAssertEqual(generation.state.storyCampaign.mission?.checkpoint, .departure)
        XCTAssertTrue(generation.state.storyCampaign.protection.preMistRidgeVerified)
        // pre_mist_ridge is written and re-readable; it holds the source state
        // without a mission.
        let protection = try coordinator.loadProtection(
            campaignID: generation.state.campaignID,
            kind: .preMistRidge,
            ownerManualSlot: slot
        )
        XCTAssertNil(protection.state.storyCampaign.mission)
        XCTAssertEqual(protection.state.storyCampaign.segment(.q08)?.phase, .eruption)
        // mission_current is written and re-readable with the armed mission.
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertEqual(continued.generation.metadata.generationKind, .missionCurrent)
        XCTAssertEqual(
            continued.generation.state.storyCampaign.mission?.missionInstanceID,
            generation.state.storyCampaign.mission?.missionInstanceID
        )
        try SaveValidation.validateN027(generation.state, catalog: catalog)
    }

    func testProtectionWriteFailureWritesNothingAndLeavesMemoryUnchanged() throws {
        let (coordinator, root) = try makeCoordinator()
        let (ready, _) = try prepareJourney(coordinator: coordinator)
        // A second preparation with a bogus slot must fail at the protection
        // write and must not create or alter any file.
        let before = try coordinator.bestContinueGeneration().generation.state
        XCTAssertThrowsError(
            try JourneyService.prepareJourney(
                state: ready,
                coordinator: coordinator,
                ownerManualSlot: "slot_manual_9"
            )
        )
        let after = try coordinator.bestContinueGeneration().generation.state
        XCTAssertEqual(after, before, "failed preparation must not change saved generations")
        XCTAssertEqual(ready.storyCampaign.mission, nil, "failed preparation must not change memory")
        _ = root
    }

    func testOrphanProtectionIsIgnoredByContinue() throws {
        let (coordinator, _) = try makeCoordinator()
        let created = try coordinator.createNewCampaign(manualSlotIndex: 0) { campaignID in
            var state = self.journeyReadyState(standing: 90)
            state.campaignID = campaignID
            return state
        }
        // Write only the protection: the crash window between the two phases
        // leaves pre_mist_ridge behind without a following mission_current.
        _ = try coordinator.save(
            created.state,
            kind: .preMistRidge,
            ownerManualSlot: slot
        )
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertEqual(
            continued.generation.metadata.generationKind,
            .manual,
            "an orphan protection must never become a Continue candidate"
        )
        XCTAssertTrue(
            continued.diagnostics.contains { $0.contains("孤儿保护档 pre_mist_ridge") },
            "orphan protections are reported, not silently claimed"
        )
    }

    func testMissionWrittenThenContinueRestoresActiveMission() throws {
        let (coordinator, _) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        _ = generation
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertEqual(continued.generation.metadata.generationKind, .missionCurrent)
        XCTAssertEqual(
            continued.generation.state.storyCampaign.mission?.checkpoint,
            .departure
        )
        XCTAssertEqual(
            continued.generation.state.storyCampaign.mission?.status,
            .travelling
        )
        // The protection link is intact, so abandon stays available.
        XCTAssertEqual(
            continued.generation.state.storyCampaign.mission?.canAbandonToProtection,
            true
        )
    }

    // MARK: - Checkpoints

    func testThreeCheckpointsAdvanceInOrderAndResumeFromLatestWritten() throws {
        let (coordinator, _) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        var state = generation.state
        // Skipping, moving backwards, departure and homecoming are rejected.
        XCTAssertEqual(
            JourneyService.advanceCheckpoint(state: state, to: .mistRidgeFork),
            .failure(.invalidTransition)
        )
        XCTAssertEqual(
            JourneyService.advanceCheckpoint(state: state, to: .departure),
            .failure(.invalidTransition)
        )
        XCTAssertEqual(
            JourneyService.advanceCheckpoint(state: state, to: .homecoming),
            .failure(.invalidTransition)
        )
        state = try JourneyService.advanceCheckpoint(state: state, to: .oldWaterway).get()
        XCTAssertEqual(
            JourneyService.advanceCheckpoint(state: state, to: .oldWaterway),
            .failure(.invalidTransition)
        )
        // Each checkpoint is persisted as mission_current.
        _ = try coordinator.save(state, kind: .missionCurrent, ownerManualSlot: slot)
        var resumed = try coordinator.bestContinueGeneration().generation.state
        XCTAssertEqual(resumed.storyCampaign.mission?.checkpoint, .oldWaterway)
        state = try JourneyService.advanceCheckpoint(state: resumed, to: .mistRidgeFork).get()
        _ = try coordinator.save(state, kind: .missionCurrent, ownerManualSlot: slot)
        resumed = try coordinator.bestContinueGeneration().generation.state
        XCTAssertEqual(resumed.storyCampaign.mission?.checkpoint, .mistRidgeFork)
        state = try JourneyService.advanceCheckpoint(state: resumed, to: .greyFenceFarm).get()
        _ = try coordinator.save(state, kind: .missionCurrent, ownerManualSlot: slot)
        resumed = try coordinator.bestContinueGeneration().generation.state
        XCTAssertEqual(resumed.storyCampaign.mission?.checkpoint, .greyFenceFarm)
        try SaveValidation.validateN027(resumed, catalog: catalog)
    }

    // MARK: - Abandon

    func testAbandonRollsBackToProtectionIdempotently() throws {
        let (coordinator, _) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        let state = generation.state
        let rolledBack = try JourneyService.abandon(
            state: state,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        XCTAssertNil(rolledBack.storyCampaign.mission, "rollback restores the pre-journey state")
        XCTAssertEqual(rolledBack.storyCampaign.segment(.q08)?.phase, .eruption)
        XCTAssertEqual(rolledBack.storyCampaign.frontstageLease, nil)
        XCTAssertEqual(rolledBack.economy.shipping.pendingEntries.count, 2)
        // Repeating the abandon on the same source returns the same state.
        let again = try JourneyService.abandon(
            state: state,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        XCTAssertEqual(again, rolledBack, "abandon is idempotent for the same mission")
        // The restored state no longer has a mission, so abandon cannot re-run.
        XCTAssertThrowsError(
            try JourneyService.abandon(
                state: rolledBack,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        )
    }

    func testMissingProtectionDisablesAbandonWithDiagnostic() throws {
        let (coordinator, root) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        // Simulate the protection file being lost after mission_current was
        // written.
        let campaignDir = coordinator.campaignDirectory(generation.state.campaignID)
        let files = try FileManager.default.contentsOfDirectory(atPath: campaignDir.path)
        for file in files where file.hasPrefix("pre_mist_ridge") {
            try FileManager.default.removeItem(
                at: campaignDir.appendingPathComponent(file)
            )
        }
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertEqual(continued.generation.metadata.generationKind, .missionCurrent)
        XCTAssertEqual(
            continued.generation.state.storyCampaign.mission?.canAbandonToProtection,
            false,
            "a mission without its protection must disable rollback"
        )
        XCTAssertFalse(continued.generation.state.storyCampaign.protection.preMistRidgeVerified)
        XCTAssertTrue(
            continued.diagnostics.contains { $0.contains("已禁用放弃回滚") },
            "the disabled rollback must carry an explicit diagnosis"
        )
        XCTAssertThrowsError(
            try JourneyService.abandon(
                state: continued.generation.state,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        )
        _ = root
    }

    // MARK: - Homecoming exactly-once

    func testHomecomingSettlesFrozenShippingAdvancesDayAndCaresForAnimals() throws {
        let (coordinator, _) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        let state = try advanceToGreyFence(state: generation.state, coordinator: coordinator)
        let balanceBefore = state.economy.balance
        let berryCellBefore = state.farmCells[GridPosition(x: 6, y: 5)]!
        let animalCareBefore = state.livestock.animals.map(\.totalCareDays)

        let returned = try JourneyService.completeHomecoming(
            state: state,
            coordinator: coordinator,
            ownerManualSlot: slot
        )
        let home = returned.state
        // Frozen pending entries settle exactly once at snapshot prices.
        XCTAssertEqual(home.economy.shipping.pendingEntries.isEmpty, true)
        XCTAssertEqual(home.economy.balance, balanceBefore + 3 * 10 + 5 * 6)
        XCTAssertEqual(home.economy.settlementHistory.count, 1)
        XCTAssertEqual(home.economy.settlementHistory[0].lines.count, 2)
        // Unique settlement receipt and completed mission.
        let mission = try XCTUnwrap(home.storyCampaign.mission)
        XCTAssertEqual(mission.status, .completed)
        XCTAssertEqual(mission.checkpoint, .homecoming)
        XCTAssertFalse(mission.canAbandonToProtection)
        XCTAssertTrue(
            home.storyCampaign.effectReceipts.contains {
                $0.receiptID == mission.settlementReceiptID
            }
        )
        // Q08 enters aftermath; the journey lease is released.
        XCTAssertEqual(home.storyCampaign.segment(.q08)?.phase, .aftermath)
        XCTAssertNil(home.storyCampaign.frontstageLease)
        XCTAssertEqual(home.storyCampaign.cursor, .empty)
        // Crops advanced one safe day; the near-mature berry matured and stays
        // harvestable.
        let berryCellAfter = home.farmCells[GridPosition(x: 6, y: 5)]!
        XCTAssertEqual(
            berryCellAfter.stageProgressDays,
            berryCellBefore.stageProgressDays + 1
        )
        XCTAssertTrue(berryCellAfter.readyToHarvest)
        // Animals were safely cared for.
        for (index, animal) in home.livestock.animals.enumerated() {
            XCTAssertEqual(animal.totalCareDays, animalCareBefore[index] + 1)
            XCTAssertEqual(animal.lastCaredDay, state.clock.day)
        }
        try SaveValidation.validateN027(home, catalog: catalog)

        // The receipt blocks any re-issue: crash-after-save replay.
        XCTAssertThrowsError(
            try JourneyService.completeHomecoming(
                state: home,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        ) { error in
            XCTAssertEqual(error as? JourneyFailure, .settlementAlreadyReceived)
        }
        // Continue after the crash restores the completed campaign, not a
        // travelling mission, so the receipt keeps blocking re-settlement.
        let continued = try coordinator.bestContinueGeneration()
        XCTAssertNotEqual(continued.generation.metadata.generationKind, .missionCurrent)
        XCTAssertThrowsError(
            try JourneyService.completeHomecoming(
                state: continued.generation.state,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        ) { error in
            XCTAssertEqual(error as? JourneyFailure, .settlementAlreadyReceived)
        }
    }

    func testHomecomingSettlementRejectionLeavesMemoryUntouched() throws {
        let (coordinator, _) = try makeCoordinator()
        let (_, generation) = try prepareJourney(coordinator: coordinator)
        let state = try advanceToGreyFence(state: generation.state, coordinator: coordinator)
        var tampered = state
        tampered.economy.shipping.pendingEntries[0].quantity += 1
        let tamperedBefore = tampered
        XCTAssertThrowsError(
            try JourneyService.completeHomecoming(
                state: tampered,
                coordinator: coordinator,
                ownerManualSlot: slot
            )
        ) { error in
            XCTAssertEqual(error as? JourneyFailure, .settlementRejected)
        }
        XCTAssertEqual(
            tampered,
            tamperedBefore,
            "a rejected settlement must not mutate the in-memory state"
        )
    }

    // MARK: - Journey scenes stay in the anchor catalog

    func testJourneyScenesLiveOnlyInAnchorCatalog() throws {
        let scenes = StoryAnchorCatalog.journeyScenes
        XCTAssertEqual(scenes.count, 3)
        XCTAssertEqual(
            Set(scenes.map(\.id)),
            Set([
                StorySceneID.oldWaterway,
                StorySceneID.mistRidgeFork,
                StorySceneID.greygateFarm,
            ])
        )
        for scene in scenes {
            guard let entry = StoryAnchorCatalog.anchor(id: scene.entryAnchorID),
                  let exit = StoryAnchorCatalog.anchor(id: scene.exitAnchorID) else {
                return XCTFail("journey scene \(scene.id) lacks paired anchors")
            }
            for anchor in [entry, exit] {
                guard case .journeyLocal(let local) = anchor else {
                    return XCTFail("journey anchors must be journey-local: \(anchor.id)")
                }
                XCTAssertEqual(local.sceneID, scene.id)
            }
        }
        // No world-grid anchor references a journey scene; the N-015 two-map
        // topology is untouched.
        for anchor in StoryAnchorCatalog.worldGridAnchors {
            XCTAssertTrue(
                [ContentID.farmHomestead, ContentID.creekMarket].contains(anchor.mapID),
                "world-grid anchor \(anchor.id) leaves the N-015 maps"
            )
        }
    }
}
