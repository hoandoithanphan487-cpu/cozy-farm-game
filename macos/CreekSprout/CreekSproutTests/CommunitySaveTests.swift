import Foundation
import XCTest
@testable import CreekSprout

/// M3-003 persistence: schema v6 round trips, the v5 migration, save
/// validation negatives, and the three mutually exclusive runtime fixtures
/// replayed through save / quit / restart.
final class CommunitySaveTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0
    private var balance: CommunityBalanceDefinition { catalog.communityBalance }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-m3-003-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    // MARK: - Fixtures

    private func offeredState(standing: Int? = nil) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        state.community.standing = standing ?? balance.newGameStanding
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        return state
    }

    @discardableResult
    private func submit(
        _ state: inout GameState,
        _ actionID: String,
        _ npcID: String
    ) -> Result<GossipSubmitOutcome, GossipFailure> {
        ResolveGossipActionUseCase.submit(
            state: &state,
            actionID: actionID,
            npcID: npcID,
            catalog: catalog
        )
    }

    /// Save with one store, then load with a freshly constructed one to model a
    /// quit and restart.
    private func roundTrip(_ state: GameState, slot: String) throws -> GameState {
        let writer = SaveStore(directory: directory, slotName: slot, catalog: catalog)
        try writer.save(state)
        let reader = SaveStore(directory: directory, slotName: slot, catalog: catalog)
        return try reader.load()
    }

    // MARK: - Schema

    func testCurrentSchemaIsSevenAndCarriesCommunityRelationshipsAndSettings() throws {
        var state = offeredState()
        submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(state)

        let payload = try decodedJSON(at: store.primaryURL)
        XCTAssertEqual(SaveSchema.currentVersion, 10)
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        let community = try XCTUnwrap(payload["community"] as? [String: Any])
        XCTAssertEqual((community["standing"] as? NSNumber)?.intValue, 42)
        XCTAssertNotNil(community["active_events"])
        XCTAssertNotNil(community["event_history"])
        let relationships = try XCTUnwrap(payload["relationships"] as? [String: Any])
        XCTAssertNotNil(relationships["trust"])
        XCTAssertNotNil(relationships["effects"])
        let settings = try XCTUnwrap(payload["settings"] as? [String: Any])
        XCTAssertEqual((settings["ui_scale"] as? NSNumber)?.intValue, 100)

        let history = try XCTUnwrap(community["event_history"] as? [[String: Any]])
        let event = try XCTUnwrap(history.first)
        XCTAssertEqual(event["status"] as? String, "resolved_relay")
        XCTAssertEqual((event["truth_verified"] as? NSNumber)?.boolValue, false)
        XCTAssertNotNil(event["action_history"])
        XCTAssertNotNil(event["granted_effect_ids"])
    }

    func testV5SaveMigratesToLegalCommunityAndRelationshipDefaults() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = offeredState()
        submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        try store.save(state)

        var payload = try decodedJSON(at: store.primaryURL)
        payload["schema_version"] = 5
        payload.removeValue(forKey: "community")
        payload.removeValue(forKey: "relationships")
        let v5 = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])

        let migrated = try SaveMigrator.migrate(v5)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(migrated.community.standing, balance.newGameStanding)
        XCTAssertTrue(migrated.community.neighborStates.isEmpty)
        XCTAssertTrue(migrated.community.activeEvents.isEmpty)
        XCTAssertTrue(migrated.community.eventHistory.isEmpty)
        XCTAssertTrue(migrated.relationships.trust.isEmpty)
        XCTAssertTrue(migrated.relationships.effects.isEmpty)

        try v5.write(to: store.primaryURL, options: .atomic)
        try? FileManager.default.removeItem(at: store.backupURL)
        let loaded = try store.load()
        XCTAssertEqual(loaded.community, .empty)
        XCTAssertEqual(loaded.relationships, .empty)
        XCTAssertEqual(loaded.watershed.restorationPoints, 0)
    }

    func testEmptyActionHistorySurvivesTheRoundTrip() throws {
        let state = offeredState()
        let loaded = try roundTrip(state, slot: "empty_history")
        XCTAssertEqual(loaded, state)
        XCTAssertEqual(loaded.community.activeEvents.count, 1)
        XCTAssertTrue(loaded.community.activeEvents[0].actionHistory.isEmpty)
        XCTAssertNoThrow(try SaveValidation.validate(loaded, catalog: catalog))
    }

    // MARK: - Three mutually exclusive fixtures

    func testFixtureOneRelayLosesStandingZeroesGrowthAndHalvesNextFirstTalk() throws {
        var state = offeredState()
        XCTAssertEqual(state.community.standing, 50)
        submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(state.community.standing, 42)

        var reloaded = try roundTrip(state, slot: "fixture_relay")
        XCTAssertEqual(reloaded, state)
        XCTAssertEqual(reloaded.community.standing, 42)
        XCTAssertEqual(reloaded.community.eventHistory.first?.status, .resolvedRelay)
        XCTAssertEqual(
            reloaded.community.neighbor(ContentID.neighborConsensus)?.stance,
            .relayingUnverified
        )

        let sameDay = RelationshipService.applyDailyFirstTalk(
            state: &reloaded,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(sameDay.successValue?.awardedSubpoints, 0)
        XCTAssertEqual(reloaded.relationships.subpoints(ContentID.waterApprentice), 0)

        reloaded.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
        let saved = try roundTrip(reloaded, slot: "fixture_relay_day3")
        var nextDayState = saved
        let nextDay = RelationshipService.applyDailyFirstTalk(
            state: &nextDayState,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(nextDay.successValue?.awardedSubpoints, 150)
        XCTAssertEqual(nextDayState.relationships.subpoints(ContentID.waterApprentice), 150)
    }

    func testFixtureTwoDeferSurvivesRestartAndExpiresWithoutPenalty() throws {
        var state = offeredState()
        submit(&state, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .deferred)
        XCTAssertEqual(state.community.standing, 50)

        var reloaded = try roundTrip(state, slot: "fixture_defer")
        XCTAssertEqual(reloaded, state)
        XCTAssertEqual(GossipService.activeEvent(state: reloaded)?.status, .deferred)
        XCTAssertEqual(reloaded.community.standing, 50)
        XCTAssertEqual(GossipService.activeEvent(state: reloaded)?.actionHistory.map(\.sequence), [1])

        reloaded.clock = GameClock(day: 3, minute: GameClock.dayEndMinute)
        let expiry = GossipService.expireDueEvents(state: &reloaded)
        XCTAssertTrue(expiry.didExpire)
        XCTAssertEqual(reloaded.community.standing, 50)
        XCTAssertTrue(reloaded.community.activeEvents.isEmpty)
        XCTAssertEqual(reloaded.community.eventHistory.first?.status, .expired)
        XCTAssertEqual(reloaded.community.eventHistory.first?.actionHistory.count, 1)

        let afterExpiry = try roundTrip(reloaded, slot: "fixture_defer_expired")
        XCTAssertEqual(afterExpiry, reloaded)
        XCTAssertEqual(afterExpiry.community.standing, 50)
    }

    func testFixtureThreeVerifyCorrectReachesFiftyEightWithThreeActionRecords() throws {
        var state = offeredState()
        submit(&state, ContentID.startVerificationAction, ContentID.neighborHearsay)
        state = try roundTrip(state, slot: "fixture_correct_1")
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .investigating)

        submit(&state, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        state = try roundTrip(state, slot: "fixture_correct_2")
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .verified)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.truthVerified, true)

        submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        let final = try roundTrip(state, slot: "fixture_correct_3")
        XCTAssertEqual(final, state)
        XCTAssertEqual(final.community.standing, 58)

        let event = try XCTUnwrap(final.community.eventHistory.first)
        XCTAssertEqual(event.status, .resolvedCorrected)
        XCTAssertTrue(event.truthVerified)
        XCTAssertEqual(event.actionHistory.map(\.sequence), [1, 2, 3])
        XCTAssertEqual(
            event.actionHistory.map(\.actionID),
            [
                ContentID.startVerificationAction,
                ContentID.verifyWithCAction,
                ContentID.correctDAction,
            ]
        )
        XCTAssertEqual(event.grantedEffectIDs, [ContentID.correctDWatershedEffect])
        XCTAssertEqual(
            final.community.neighbor(ContentID.neighborConsensus)?.stance,
            .relayingVerified
        )
        XCTAssertEqual(final.watershed.restorationPoints, 2)

        // Replaying the terminal action after a reload never pays twice.
        var replay = final
        let retry = submit(&replay, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(retry.successValue?.didApply, false)
        XCTAssertEqual(replay.watershed.restorationPoints, 2)
        XCTAssertEqual(replay.community.standing, 58)
    }

    func testSyntheticBoundaryFixturesRoundTripAndKeepTheCanalReachable() throws {
        var paused = offeredState(standing: 39)
        submit(&paused, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        let pausedLoaded = try roundTrip(paused, slot: "fixture_boundary_paused")
        XCTAssertEqual(pausedLoaded.community.standing, 31)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(
                of: ContentID.marketNoticeQuest,
                state: pausedLoaded,
                catalog: catalog
            ),
            .paused
        )

        var resumed = offeredState(standing: 39)
        submit(&resumed, ContentID.startVerificationAction, ContentID.neighborHearsay)
        submit(&resumed, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        submit(&resumed, ContentID.correctDAction, ContentID.neighborConsensus)
        let resumedLoaded = try roundTrip(resumed, slot: "fixture_boundary_resumed")
        XCTAssertEqual(resumedLoaded.community.standing, 47)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(
                of: ContentID.marketNoticeQuest,
                state: resumedLoaded,
                catalog: catalog
            ),
            .available
        )

        for (index, branch) in [pausedLoaded, resumedLoaded].enumerated() {
            var canal = branch
            let placed = CanalProgressionService.commitCanalPlacementIfNeeded(
                state: canal,
                definitionID: ContentID.canalSegmentObject,
                catalog: catalog
            )
            canal = try XCTUnwrap(placed.successValue)
            let delivered = CanalProgressionService.deliverCanalRepair(state: canal, catalog: catalog)
            canal = try XCTUnwrap(delivered.successValue)
            XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: canal), .completed)
            let mainline = canal.watershed.appliedContributionIDs
                .compactMap { catalog.contribution(id: $0) }
                .filter(\.countsTowardMainline)
                .reduce(0) { $0 + $1.points }
            XCTAssertEqual(mainline, 20)
            let reloaded = try roundTrip(canal, slot: "fixture_boundary_canal_\(index)")
            XCTAssertEqual(reloaded.watershed.restorationPoints, canal.watershed.restorationPoints)
            XCTAssertTrue(reloaded.watershed.isRestored)
        }
    }

    // MARK: - Save validation negatives

    func testValidationRejectsOutOfRangeStandingTrustAndRemainder() throws {
        let base = offeredState()

        var lowStanding = base
        lowStanding.community.standing = balance.minStanding - 1
        assertRejected(lowStanding, "standing below minimum")

        var highStanding = base
        highStanding.community.standing = balance.maxStanding + 1
        assertRejected(highStanding, "standing above maximum")

        var trustTooHigh = base
        trustTooHigh.relationships.upsert(
            TrustRecord(
                npcID: ContentID.waterApprentice,
                subpoints: balance.maxTrustSubpoints + 1
            )
        )
        assertRejected(trustTooHigh, "trust above maximum")

        var negativeTrust = base
        negativeTrust.relationships.upsert(
            TrustRecord(npcID: ContentID.waterApprentice, subpoints: -1)
        )
        assertRejected(negativeTrust, "negative trust")

        var badRemainder = base
        badRemainder.relationships.upsert(
            TrustRecord(
                npcID: ContentID.waterApprentice,
                subpoints: 0,
                remainder: balance.fixedPointScale
            )
        )
        assertRejected(badRemainder, "remainder at scale")

        var futureTalk = base
        futureTalk.relationships.upsert(
            TrustRecord(
                npcID: ContentID.waterApprentice,
                subpoints: 300,
                remainder: 0,
                lastFirstTalkDay: base.clock.day + 1
            )
        )
        assertRejected(futureTalk, "first talk in the future")
    }

    func testValidationRejectsDuplicateEventsAndBrokenActionHistory() throws {
        var state = offeredState()
        submit(&state, ContentID.startVerificationAction, ContentID.neighborHearsay)
        let event = try XCTUnwrap(GossipService.activeEvent(state: state))

        var retired = event
        retired.status = .expired
        retired.resolvedDay = event.offeredDay
        var duplicate = state
        duplicate.community.eventHistory = [retired]
        assertRejected(duplicate, "duplicate instance id")

        var brokenSequence = state
        brokenSequence.community.activeEvents[0].actionHistory[0].sequence = 2
        assertRejected(brokenSequence, "non-contiguous sequence")

        var repeatedAction = state
        repeatedAction.community.activeEvents[0].actionHistory.append(
            GossipActionRecord(
                sequence: 2,
                actionID: ContentID.startVerificationAction,
                npcID: ContentID.neighborHearsay,
                day: 2,
                minute: GameClock.dayStartMinute
            )
        )
        assertRejected(repeatedAction, "duplicate action id")

        var badDeadline = state
        badDeadline.community.activeEvents[0].deadlineDay = event.offeredDay - 1
        assertRejected(badDeadline, "deadline before offer")

        var badDeadlineMinute = state
        badDeadlineMinute.community.activeEvents[0].deadlineMinute = 1_440
        assertRejected(badDeadlineMinute, "deadline minute out of range")

        var terminalInActive = state
        terminalInActive.community.activeEvents[0].status = .expired
        terminalInActive.community.activeEvents[0].resolvedDay = 2
        assertRejected(terminalInActive, "terminal event left active")

        var unresolvedHistory = state
        unresolvedHistory.community.activeEvents = []
        unresolvedHistory.community.eventHistory = [event]
        assertRejected(unresolvedHistory, "non-terminal event in history")

        var verifiedWithoutTruth = state
        verifiedWithoutTruth.community.activeEvents[0].status = .verified
        verifiedWithoutTruth.community.activeEvents[0].truthVerified = false
        assertRejected(verifiedWithoutTruth, "verified without truth flag")

        var unknownEffect = state
        unknownEffect.community.activeEvents[0].grantedEffectIDs = ["brookseed.effect.not_real"]
        assertRejected(unknownEffect, "unknown granted effect")

        var unknownDefinition = state
        unknownDefinition.community.activeEvents[0].definitionID = "brookseed.gossip.event.missing"
        assertRejected(unknownDefinition, "unknown event definition")

        var unknownNeighbor = state
        unknownNeighbor.community.upsertNeighbor(NeighborState(npcID: "brookseed.npc.missing"))
        assertRejected(unknownNeighbor, "unknown neighbour")

        var unknownEffectState = state
        unknownEffectState.relationships.upsert(
            RelationshipEffectState(
                effectID: "brookseed.effect.missing",
                npcID: ContentID.waterApprentice,
                startDay: 2,
                endDay: 3,
                zeroGrowthDay: 2,
                firstTalkMultiplierBP: 5_000,
                firstTalkStartDay: 3,
                firstTalkConsumed: false
            ),
            policy: .replace
        )
        assertRejected(unknownEffectState, "unknown relationship effect")
    }

    func testValidationAcceptsAnEmptyActionHistoryAndRejectsAnImpossibleOne() throws {
        var offeredWithoutActions = offeredState()
        XCTAssertNoThrow(try SaveValidation.validate(offeredWithoutActions, catalog: catalog))

        // An untouched event may only end by expiry.
        offeredWithoutActions.community.activeEvents[0].status = .resolvedRelay
        offeredWithoutActions.community.activeEvents[0].resolvedDay = 2
        assertRejected(offeredWithoutActions, "resolved without any action")

        var expiredWithoutActions = offeredState()
        var event = expiredWithoutActions.community.activeEvents[0]
        event.status = .expired
        event.resolvedDay = 3
        expiredWithoutActions.community.retireEvent(event)
        XCTAssertNoThrow(try SaveValidation.validate(expiredWithoutActions, catalog: catalog))
    }

    func testIllegalStatusEnumInJsonIsRejectedWithoutOverwriting() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = offeredState()
        submit(&state, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        try store.save(state)
        try? FileManager.default.removeItem(at: store.backupURL)

        var payload = try decodedJSON(at: store.primaryURL)
        var community = try XCTUnwrap(payload["community"] as? [String: Any])
        var events = try XCTUnwrap(community["active_events"] as? [[String: Any]])
        events[0]["status"] = "not_a_status"
        community["active_events"] = events
        payload["community"] = community
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    func testRejectedWriteKeepsTheLastValidSave() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var valid = offeredState()
        submit(&valid, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        try store.save(valid)
        let bytes = try Data(contentsOf: store.primaryURL)

        var illegal = valid
        illegal.community.standing = balance.maxStanding + 5
        XCTAssertThrowsError(try store.save(illegal)) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), bytes)
        XCTAssertEqual(try store.load(), valid)
    }

    // MARK: - Helpers

    private func assertRejected(
        _ state: GameState,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try SaveValidation.validate(state, catalog: catalog), label, file: file, line: line) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents, label, file: file, line: line)
        }
    }

    private func decodedJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SaveStoreError.invalidContents
        }
        return json
    }
}
