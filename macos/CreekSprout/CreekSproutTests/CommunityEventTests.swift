import XCTest
@testable import CreekSprout

extension Result {
    /// Convenience accessor so failure assertions stay readable.
    var failureValue: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

    var successValue: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}

/// M3-003 domain rules: the five-action state machine, deadline ordering,
/// idempotency, atomic rollback and the fixed-point trust math.
/// Balance numbers come from `ContentCatalog.vs0`; the literals asserted here
/// are the acceptance outputs, not a second copy of the configuration.
final class CommunityEventTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private var balance: CommunityBalanceDefinition { catalog.communityBalance }

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
        _ npcID: String,
        catalog overrideCatalog: ContentCatalog? = nil
    ) -> Result<GossipSubmitOutcome, GossipFailure> {
        ResolveGossipActionUseCase.submit(
            state: &state,
            actionID: actionID,
            npcID: npcID,
            catalog: overrideCatalog ?? catalog
        )
    }

    private func verifiedState(standing: Int? = nil) -> GameState {
        var state = offeredState(standing: standing)
        submit(&state, ContentID.startVerificationAction, ContentID.neighborHearsay)
        submit(&state, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .verified)
        return state
    }

    // MARK: - Trigger and state machine

    func testEventIsOfferedOnDayTwoAndDueOnDayThreeAtDeadlineMinute() throws {
        var day1 = GameState.vs0NewGame(catalog: catalog)
        GossipService.advanceToDayStart(state: &day1, catalog: catalog)
        XCTAssertNil(GossipService.activeEvent(state: day1))

        let state = offeredState()
        let event = try XCTUnwrap(GossipService.activeEvent(state: state))
        XCTAssertEqual(event.status, .offered)
        XCTAssertEqual(event.offeredDay, 2)
        XCTAssertEqual(event.deadlineDay, 3)
        XCTAssertEqual(event.deadlineMinute, GameClock.dayEndMinute)
        XCTAssertFalse(event.isDue(day: 3, minute: GameClock.dayEndMinute - 1))
        XCTAssertTrue(event.isDue(day: 3, minute: GameClock.dayEndMinute))
        XCTAssertTrue(event.actionHistory.isEmpty)
    }

    func testTriggeringTwiceCreatesOneInstance() {
        var state = offeredState()
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        GossipService.triggerScheduledEvents(state: &state, catalog: catalog)
        XCTAssertEqual(state.community.activeEvents.count, 1)
        XCTAssertTrue(state.community.eventHistory.isEmpty)
    }

    func testAllFiveActionsAreStableAndLegalFromTheirRequiredStatus() {
        let names = ContentID.gossipActionIDs.compactMap { catalog.gossipAction(id: $0)?.shortName }
        XCTAssertEqual(names, ContentID.requiredGossipActionNames)

        var relay = offeredState()
        let relayed = submit(&relay, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(relayed.successValue?.event.status, .resolvedRelay)

        var deferred = offeredState()
        let deferredOutcome = submit(&deferred, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        XCTAssertEqual(deferredOutcome.successValue?.event.status, .deferred)

        var verify = offeredState()
        let started = submit(&verify, ContentID.startVerificationAction, ContentID.neighborHearsay)
        XCTAssertEqual(started.successValue?.event.status, .investigating)
        let checked = submit(&verify, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        XCTAssertEqual(checked.successValue?.event.status, .verified)
        XCTAssertEqual(checked.successValue?.event.truthVerified, true)
        let corrected = submit(&verify, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(corrected.successValue?.event.status, .resolvedCorrected)

        let history = corrected.successValue?.event.actionHistory ?? []
        XCTAssertEqual(history.map(\.sequence), [1, 2, 3])
        XCTAssertEqual(
            history.map(\.actionID),
            [
                ContentID.startVerificationAction,
                ContentID.verifyWithCAction,
                ContentID.correctDAction,
            ]
        )
    }

    func testIllegalTransitionsAreRejected() {
        var state = offeredState()
        let tooEarlyCorrect = submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(tooEarlyCorrect.failureValue, .illegalTransition)
        let tooEarlyVerify = submit(&state, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        XCTAssertEqual(tooEarlyVerify.failureValue, .illegalTransition)
        let wrongNeighbour = submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborEvidence)
        XCTAssertEqual(wrongNeighbour.failureValue, .wrongInteractionNpc)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .offered)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.actionHistory.count, 0)

        var deferred = offeredState()
        submit(&deferred, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        // `deferred` may only expire; no further action can revive it.
        for actionID in ContentID.gossipActionIDs where actionID != ContentID.deferJudgmentAction {
            let rejected = submit(&deferred, actionID, ContentID.neighborHearsay)
            XCTAssertNotNil(rejected.failureValue, actionID)
        }
        XCTAssertEqual(GossipService.activeEvent(state: deferred)?.status, .deferred)
        XCTAssertEqual(GossipService.activeEvent(state: deferred)?.actionHistory.count, 1)
    }

    func testTerminalStatusesCannotBeLeft() {
        for status in GossipEventStatus.allCases where status.isTerminal {
            XCTAssertEqual(GossipTransitionTable.allowed[status], [])
        }
    }

    // MARK: - Deadline ordering

    func testExpiryIsProcessedBeforeAnActionSubmittedInTheSameMinute() throws {
        var state = offeredState()
        state.clock = GameClock(day: 3, minute: GameClock.dayEndMinute)
        let rejected = submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(rejected.failureValue, .noActiveEvent)
        XCTAssertTrue(state.community.activeEvents.isEmpty)
        let expired = try XCTUnwrap(state.community.eventHistory.first)
        XCTAssertEqual(expired.status, .expired)
        XCTAssertEqual(expired.resolvedDay, 3)
        XCTAssertTrue(expired.actionHistory.isEmpty)
        XCTAssertEqual(state.community.standing, balance.newGameStanding)
    }

    func testActionOneMinuteBeforeTheDeadlineStillSucceeds() {
        var state = offeredState()
        state.clock = GameClock(day: 3, minute: GameClock.dayEndMinute - 1)
        let outcome = submit(&state, ContentID.deferJudgmentAction, ContentID.neighborHearsay)
        XCTAssertEqual(outcome.successValue?.didApply, true)
        XCTAssertEqual(outcome.successValue?.event.status, .deferred)
    }

    func testAvailableActionsAreEmptyOnceTheDeadlinePassed() {
        var state = offeredState()
        state.clock = GameClock(day: 3, minute: GameClock.dayEndMinute)
        let actions = GossipService.availableActions(
            state: state,
            npcID: ContentID.neighborHearsay,
            catalog: catalog
        )
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: - Idempotency

    func testRepeatedActionIsIdempotent() {
        var state = offeredState()
        let first = submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(first.successValue?.didApply, true)
        let snapshot = state

        let second = submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(second.successValue?.didApply, false)
        XCTAssertEqual(second.successValue?.event.actionHistory.count, 1)
        XCTAssertEqual(state, snapshot)
    }

    func testCorrectDGrantsTheWatershedBonusOnlyOnceAcrossRetries() {
        var state = verifiedState()
        let outcome = submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(outcome.successValue?.watershedPointsAwarded, 2)
        XCTAssertEqual(outcome.successValue?.trustSubpointsAwarded, 0)
        XCTAssertEqual(state.watershed.restorationPoints, 2)
        XCTAssertTrue(state.relationships.trust.isEmpty)

        let retry = submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(retry.successValue?.didApply, false)
        XCTAssertEqual(state.watershed.restorationPoints, 2)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 0)
    }

    func testCorrectDGrantsTrustInsteadOfWatershedWhenTheCanalQuestIsDone() {
        var state = verifiedState()
        state.questLog.setStatus(.completed, for: ContentID.restoreOldCanalQuest)
        let outcome = submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(outcome.successValue?.watershedPointsAwarded, 0)
        XCTAssertEqual(outcome.successValue?.trustSubpointsAwarded, 300)
        XCTAssertEqual(state.watershed.restorationPoints, 0)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 300)
        // The flat bonus bypasses every multiplier and leaves the remainder alone.
        XCTAssertEqual(state.relationships.remainder(ContentID.waterApprentice), 0)

        let retry = submit(&state, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(retry.successValue?.didApply, false)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 300)
    }

    // MARK: - Atomic rollback

    func testFailedRewardRollsBackTheWholeSubmission() throws {
        var broken = catalog
        var action = try XCTUnwrap(broken.gossipAction(id: ContentID.correctDAction))
        // Force both reward branches so the trust write lands before the
        // watershed write that is about to fail.
        action.rewardPolicy = .applyConfigured
        broken.gossipActions[ContentID.correctDAction] = action
        broken.watershedContributions.removeValue(forKey: ContentID.correctDBonusContribution)

        var state = verifiedState()
        let before = state
        let rejected = submit(
            &state,
            ContentID.correctDAction,
            ContentID.neighborConsensus,
            catalog: broken
        )
        XCTAssertEqual(rejected.failureValue, .invalidContent)
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.community.standing, balance.newGameStanding)
        XCTAssertTrue(state.relationships.trust.isEmpty)
        XCTAssertEqual(state.watershed.restorationPoints, 0)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .verified)
        XCTAssertEqual(GossipService.activeEvent(state: state)?.actionHistory.count, 2)
    }

    // MARK: - Ordinary conversation

    func testOrdinaryTalkChangesTrustOnlyAndNeverStandingWatershedOrEvents() {
        let service = CommunityCommandService(catalog: catalog)
        var state = offeredState()
        let before = state
        let feedback = service.talk(state: &state, npcID: ContentID.waterApprentice)
        XCTAssertNotNil(feedback)
        XCTAssertEqual(state.community, before.community)
        XCTAssertEqual(state.watershed, before.watershed)
        XCTAssertEqual(state.questLog, before.questLog)
        XCTAssertEqual(state.economy, before.economy)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 300)

        // A second conversation on the same day grants nothing more.
        let afterFirst = state
        let repeated = service.talk(state: &state, npcID: ContentID.waterApprentice)
        XCTAssertNil(repeated)
        XCTAssertEqual(state, afterFirst)

        // Neighbours are not trust targets in VS-1.
        let neighbourTalk = service.talk(state: &state, npcID: ContentID.neighborHearsay)
        XCTAssertNil(neighbourTalk)
        XCTAssertNil(state.relationships.record(ContentID.neighborHearsay))
    }

    // MARK: - Fixed-point trust

    func testFirstTalkUsesBaseHighAndLowStandingMultipliers() throws {
        let neutral = try XCTUnwrap(
            balance.bands.first { $0.trustMultiplierBP == CommunityBalanceDefinition.neutralBasisPoints }
        )
        let high = try XCTUnwrap(balance.bands.max { $0.trustMultiplierBP < $1.trustMultiplierBP })
        let low = try XCTUnwrap(balance.bands.min { $0.trustMultiplierBP < $1.trustMultiplierBP })

        XCTAssertEqual(awardedSubpoints(atStanding: neutral.lowerBound), 300)
        XCTAssertEqual(awardedSubpoints(atStanding: high.lowerBound), 330)
        XCTAssertEqual(awardedSubpoints(atStanding: low.lowerBound), 255)
    }

    private func awardedSubpoints(atStanding standing: Int) -> Int {
        var state = offeredState(standing: standing)
        let grant = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(grant.successValue?.didApply, true)
        XCTAssertEqual(state.relationships.lastFirstTalkDay(ContentID.waterApprentice), 2)
        return grant.successValue?.awardedSubpoints ?? -1
    }

    func testRelayZeroesTheSameDayGrowthAndHalvesTheNextFirstTalk() {
        var state = offeredState()
        submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)

        let sameDay = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(sameDay.successValue?.wasZeroGrowth, true)
        XCTAssertEqual(sameDay.successValue?.awardedSubpoints, 0)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 0)
        XCTAssertEqual(state.relationships.remainder(ContentID.waterApprentice), 0)

        state.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
        let nextDay = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(nextDay.successValue?.awardedSubpoints, 150)
        XCTAssertEqual(nextDay.successValue?.firstTalkMultiplierBP, 5_000)

        // The 0.50 multiplier is consumed exactly once.
        state.clock = GameClock(day: 4, minute: GameClock.dayStartMinute)
        RelationshipService.pruneExpiredEffects(state: &state)
        let recovered = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(recovered.successValue?.awardedSubpoints, 300)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 450)
        XCTAssertTrue(state.relationships.effects.isEmpty)
    }

    func testRemainderIsSavedAndConsumedOnTheNextGrant() throws {
        // Low standing plus the 0.50 misunderstanding multiplier leaves half a
        // subpoint behind; the next grant must pick it up.
        let low = try XCTUnwrap(balance.bands.min { $0.trustMultiplierBP < $1.trustMultiplierBP })
        var state = offeredState(standing: low.upperBound)
        submit(&state, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertTrue(state.community.standing <= low.upperBound)

        state.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
        let halved = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(halved.successValue?.awardedSubpoints, 127)
        XCTAssertEqual(halved.successValue?.remainder, balance.fixedPointScale / 2)

        state.clock = GameClock(day: 4, minute: GameClock.dayStartMinute)
        RelationshipService.pruneExpiredEffects(state: &state)
        let full = RelationshipService.applyDailyFirstTalk(
            state: &state,
            npcID: ContentID.waterApprentice,
            catalog: catalog
        )
        XCTAssertEqual(full.successValue?.awardedSubpoints, 255)
        XCTAssertEqual(full.successValue?.remainder, balance.fixedPointScale / 2)
        XCTAssertEqual(state.relationships.subpoints(ContentID.waterApprentice), 382)
    }

    func testComputeGainUsesSixtyFourBitMathWithoutOverflow() {
        let result = RelationshipService.computeGain(
            baseSubpoints: balance.maxTrustSubpoints,
            standingBP: CommunityBalanceDefinition.maxBasisPoints,
            firstTalkBP: CommunityBalanceDefinition.maxBasisPoints,
            savedRemainder: balance.fixedPointScale - 1,
            scale: balance.fixedPointScale
        )
        XCTAssertEqual(result.gain, 1_000_000)
        XCTAssertEqual(result.remainder, balance.fixedPointScale - 1)
    }

    // MARK: - Standing and the optional node boundary

    func testNaturalStandingIsFortyTwoAfterRelayAndFiftyEightAfterCorrection() {
        var relay = offeredState()
        XCTAssertEqual(relay.community.standing, 50)
        submit(&relay, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(relay.community.standing, 42)

        var corrected = verifiedState()
        XCTAssertEqual(corrected.community.standing, 50)
        submit(&corrected, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(corrected.community.standing, 58)
    }

    func testSyntheticBoundaryPausesAndResumesTheOptionalNode() {
        var paused = offeredState(standing: 39)
        submit(&paused, ContentID.relayUnverifiedAction, ContentID.neighborHearsay)
        XCTAssertEqual(paused.community.standing, 31)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(of: ContentID.marketNoticeQuest, state: paused, catalog: catalog),
            .paused
        )

        var resumed = verifiedState(standing: 39)
        submit(&resumed, ContentID.correctDAction, ContentID.neighborConsensus)
        XCTAssertEqual(resumed.community.standing, 47)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(of: ContentID.marketNoticeQuest, state: resumed, catalog: catalog),
            .available
        )

        for branch in [paused, resumed] {
            var canal = branch
            XCTAssertEqual(
                QuestService.optionalNodeStatus(
                    of: ContentID.restoreOldCanalQuest,
                    state: canal,
                    catalog: catalog
                ),
                .ungated
            )
            XCTAssertEqual(mainlinePoints(from: &canal), 20)
        }
    }

    func testUngatedRecoveryPathResumesAPausedOptionalNode() {
        var state = offeredState(standing: 39)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(of: ContentID.marketNoticeQuest, state: state, catalog: catalog),
            .paused
        )
        let recovery = QuestService.recoveryPathIDs(for: ContentID.marketNoticeQuest, catalog: catalog)
        XCTAssertTrue(recovery.contains(ContentID.evidenceOneStepQuest))
        XCTAssertNil(catalog.quest(id: ContentID.evidenceOneStepQuest)?.minStanding)

        let first = ResolveGossipActionUseCase.completeEvidenceObjective(state: &state, catalog: catalog)
        XCTAssertEqual(first.successValue, 44)
        XCTAssertEqual(
            QuestService.optionalNodeStatus(of: ContentID.marketNoticeQuest, state: state, catalog: catalog),
            .available
        )
        XCTAssertTrue(state.community.endorsementUnlocked(for: ContentID.neighborEvidence))

        // Repeating the recovery path never stacks standing.
        let again = ResolveGossipActionUseCase.completeEvidenceObjective(state: &state, catalog: catalog)
        XCTAssertEqual(again.successValue, 44)
    }

    func testEndorsementConditionIsSatisfiedOnlyAfterTheEvidenceObjective() throws {
        let condition = try XCTUnwrap(catalog.gossipCondition(id: ContentID.endorsementCondition))
        var state = offeredState()
        let event = try XCTUnwrap(GossipService.activeEvent(state: state))
        XCTAssertFalse(GossipService.evaluate(condition, event: event, state: state))

        let endorsed = ResolveGossipActionUseCase.completeEvidenceObjective(state: &state, catalog: catalog)
        XCTAssertNotNil(endorsed.successValue)
        XCTAssertTrue(GossipService.evaluate(condition, event: event, state: state))

        submit(&state, ContentID.startVerificationAction, ContentID.neighborHearsay)
        let verified = submit(&state, ContentID.verifyWithCAction, ContentID.neighborEvidence)
        XCTAssertEqual(verified.successValue?.event.status, .verified)
    }

    private func mainlinePoints(from state: inout GameState) -> Int {
        let placed = CanalProgressionService.commitCanalPlacementIfNeeded(
            state: state,
            definitionID: ContentID.canalSegmentObject,
            catalog: catalog
        )
        state = placed.successValue ?? state
        let delivered = CanalProgressionService.deliverCanalRepair(state: state, catalog: catalog)
        state = delivered.successValue ?? state
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .completed)
        return state.watershed.appliedContributionIDs
            .compactMap { catalog.contribution(id: $0) }
            .filter(\.countsTowardMainline)
            .reduce(0) { $0 + $1.points }
    }
}
