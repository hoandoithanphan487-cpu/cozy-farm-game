import XCTest
@testable import CreekSprout

/// M3-003 content validation: the shipped catalog is legal, and every rule the
/// design calls out rejects its counter-example.
final class CommunityContentTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private var balance: CommunityBalanceDefinition { catalog.communityBalance }

    // MARK: - Shipped catalog

    func testShippedCatalogPassesFullValidation() {
        XCTAssertNoThrow(try ContentValidator.validate(catalog))
    }

    func testFiveStableActionNamesAndSevenLegalStatuses() {
        let names = ContentID.gossipActionIDs.compactMap { catalog.gossipAction(id: $0)?.shortName }
        XCTAssertEqual(
            names,
            ["relay_unverified", "defer_judgment", "start_verification", "verify_with_c", "correct_d"]
        )
        XCTAssertEqual(
            GossipEventStatus.allCases.map(\.rawValue).sorted(),
            [
                "deferred",
                "expired",
                "investigating",
                "offered",
                "resolved_corrected",
                "resolved_relay",
                "verified",
            ]
        )
    }

    func testEventScheduleAndActionBalanceMatchTheDesign() throws {
        let event = try XCTUnwrap(catalog.gossipEvent(id: ContentID.sluicePlankEvent))
        XCTAssertEqual(event.triggerDay, 2)
        XCTAssertEqual(event.deadlineOffsetDays, 1)
        XCTAssertEqual(event.deadlineMinute, 23 * 60 + 30)
        XCTAssertEqual(event.triggerNpcID, ContentID.neighborHearsay)

        XCTAssertEqual(catalog.gossipAction(id: ContentID.relayUnverifiedAction)?.standingDelta, -8)
        XCTAssertEqual(catalog.gossipAction(id: ContentID.deferJudgmentAction)?.standingDelta, 0)
        XCTAssertEqual(catalog.gossipAction(id: ContentID.startVerificationAction)?.standingDelta, 0)
        XCTAssertEqual(catalog.gossipAction(id: ContentID.verifyWithCAction)?.standingDelta, 0)
        XCTAssertEqual(catalog.gossipAction(id: ContentID.correctDAction)?.standingDelta, 8)

        XCTAssertEqual(balance.newGameStanding, 50)
        XCTAssertEqual(balance.baseFirstTalkSubpoints, 300)
        XCTAssertEqual(balance.trustMultiplierBP(for: 80), 11_000)
        XCTAssertEqual(balance.trustMultiplierBP(for: 50), 10_000)
        XCTAssertEqual(balance.trustMultiplierBP(for: 20), 8_500)

        let relayEffect = try XCTUnwrap(catalog.relationshipEffect(id: ContentID.relayMisunderstandingEffect))
        XCTAssertTrue(relayEffect.zeroGrowthToday)
        XCTAssertEqual(relayEffect.firstTalkMultiplierBP, 5_000)
        XCTAssertEqual(relayEffect.firstTalkStartOffsetDays, 1)
        XCTAssertEqual(relayEffect.durationDays, 1)

        let trustEffect = try XCTUnwrap(catalog.relationshipEffect(id: ContentID.correctDTrustEffect))
        XCTAssertEqual(trustEffect.flatBonusSubpoints, 300)
        XCTAssertFalse(trustEffect.hasFirstTalkModifier)
    }

    func testNeighbourDisplayNamesUseQingyanAndXuning() throws {
        XCTAssertEqual(catalog.npc(id: ContentID.neighborEvidence)?.displayName, "青砚")
        XCTAssertEqual(catalog.npc(id: ContentID.neighborConsensus)?.displayName, "絮宁")
        for retired in ContentID.retiredNeighborDisplayNames {
            XCTAssertFalse(catalog.displayNames.values.contains(retired), retired)
            XCTAssertFalse(catalog.npcs.values.contains { $0.displayName == retired }, retired)
        }
    }

    func testMainlineQuestHasNoStandingGateAndSocialBonusStaysOffTheMainline() throws {
        let canal = try XCTUnwrap(catalog.quest(id: ContentID.restoreOldCanalQuest))
        XCTAssertTrue(canal.isMainline)
        XCTAssertNil(canal.minStanding)
        for quest in catalog.quests.values where quest.isMainline {
            XCTAssertNil(quest.minStanding, quest.id)
        }

        let bonus = try XCTUnwrap(catalog.contribution(id: ContentID.correctDBonusContribution))
        XCTAssertFalse(bonus.countsTowardMainline)
        XCTAssertEqual(bonus.points, 2)
        let mainline = catalog.watershedContributions.values
            .filter(\.countsTowardMainline)
            .reduce(0) { $0 + $1.points }
        XCTAssertEqual(mainline, 20)
    }

    func testGatedOptionalNodeDeclaresUngatedRecoveryPaths() throws {
        let optional = try XCTUnwrap(catalog.quest(id: ContentID.marketNoticeQuest))
        XCTAssertEqual(optional.minStanding, 41)
        XCTAssertFalse(optional.recoveryPathIDs.isEmpty)
        for recoveryID in optional.recoveryPathIDs {
            if let quest = catalog.quest(id: recoveryID) {
                XCTAssertNil(quest.minStanding, recoveryID)
                XCTAssertGreaterThan(quest.standingReward, 0, recoveryID)
            } else if let action = catalog.gossipAction(id: recoveryID) {
                XCTAssertGreaterThan(action.standingDelta, 0, recoveryID)
            } else {
                XCTFail("恢复路径引用缺失：\(recoveryID)")
            }
        }
    }

    // MARK: - Counter-examples

    func testMainlineQuestWithStandingGateIsRejected() throws {
        var broken = catalog
        var quest = try XCTUnwrap(broken.quest(id: ContentID.restoreOldCanalQuest))
        quest.minStanding = 41
        quest.recoveryPathIDs = [ContentID.evidenceOneStepQuest]
        broken.quests[quest.id] = quest
        assertRejected(broken)
    }

    func testGatedOptionalNodeWithoutRecoveryPathIsRejected() throws {
        var broken = catalog
        var quest = try XCTUnwrap(broken.quest(id: ContentID.marketNoticeQuest))
        quest.recoveryPathIDs = []
        broken.quests[quest.id] = quest
        assertRejected(broken)
    }

    func testRecoveryPathThatIsItselfGatedIsRejected() throws {
        var broken = catalog
        var recovery = try XCTUnwrap(broken.quest(id: ContentID.evidenceOneStepQuest))
        recovery.minStanding = 41
        recovery.recoveryPathIDs = [ContentID.correctDAction]
        broken.quests[recovery.id] = recovery
        assertRejected(broken)
    }

    func testMissingRecoveryPathReferenceIsRejected() throws {
        var broken = catalog
        var quest = try XCTUnwrap(broken.quest(id: ContentID.marketNoticeQuest))
        quest.recoveryPathIDs = ["brookseed.quest.not_real"]
        broken.quests[quest.id] = quest
        assertRejected(broken)
    }

    func testRetiredNeighbourDisplayNameIsRejected() throws {
        var broken = catalog
        var npc = try XCTUnwrap(broken.npc(id: ContentID.neighborEvidence))
        npc.displayName = ContentID.retiredNeighborDisplayNames[0]
        broken.npcs[npc.id] = npc
        assertRejected(broken)
    }

    func testWrongTriggerDayOrDeadlineIsRejected() throws {
        var lateTrigger = catalog
        var event = try XCTUnwrap(lateTrigger.gossipEvent(id: ContentID.sluicePlankEvent))
        event.triggerDay = 3
        lateTrigger.gossipEvents[event.id] = event
        assertRejected(lateTrigger)

        var wrongMinute = catalog
        var minuteEvent = try XCTUnwrap(wrongMinute.gossipEvent(id: ContentID.sluicePlankEvent))
        minuteEvent.deadlineMinute = 1_200
        wrongMinute.gossipEvents[minuteEvent.id] = minuteEvent
        assertRejected(wrongMinute)
    }

    func testMissingActionInTheEventIsRejected() throws {
        var broken = catalog
        var event = try XCTUnwrap(broken.gossipEvent(id: ContentID.sluicePlankEvent))
        event.actionIDs = Array(ContentID.gossipActionIDs.dropLast())
        broken.gossipEvents[event.id] = event
        assertRejected(broken)
    }

    func testIllegalActionTransitionIsRejected() throws {
        var broken = catalog
        var action = try XCTUnwrap(broken.gossipAction(id: ContentID.deferJudgmentAction))
        action.nextStatus = .resolvedCorrected
        broken.gossipActions[action.id] = action
        assertRejected(broken)
    }

    func testActionReferencingMissingContentIsRejected() throws {
        var missingCondition = catalog
        var verify = try XCTUnwrap(missingCondition.gossipAction(id: ContentID.verifyWithCAction))
        verify.conditionGroupID = "brookseed.condition_group.not_real"
        missingCondition.gossipActions[verify.id] = verify
        assertRejected(missingCondition)

        var missingNeighbour = catalog
        var correct = try XCTUnwrap(missingNeighbour.gossipAction(id: ContentID.correctDAction))
        correct.fixedNpcID = "brookseed.npc.not_real"
        missingNeighbour.gossipActions[correct.id] = correct
        assertRejected(missingNeighbour)

        var missingEffect = catalog
        var relay = try XCTUnwrap(missingEffect.gossipAction(id: ContentID.relayUnverifiedAction))
        relay.relationshipEffectID = "brookseed.effect.not_real"
        missingEffect.gossipActions[relay.id] = relay
        assertRejected(missingEffect)
    }

    func testSocialActionCannotPayIntoTheMainlineWatershed() throws {
        var broken = catalog
        var correct = try XCTUnwrap(broken.gossipAction(id: ContentID.correctDAction))
        correct.watershedEffectID = ContentID.placeCanalContribution
        broken.gossipActions[correct.id] = correct
        assertRejected(broken)
    }

    func testClaimWithNonNeighbourRelayIsRejected() throws {
        var broken = catalog
        var claim = try XCTUnwrap(broken.gossipClaim(id: ContentID.sluicePlankClaim))
        claim.relayNpcID = ContentID.waterApprentice
        broken.gossipClaims[claim.id] = claim
        assertRejected(broken)
    }

    func testStandingBandGapIsRejected() {
        var broken = catalog
        var bands = broken.communityBalance.bands
        bands.removeLast()
        broken.communityBalance.bands = bands
        assertRejected(broken)
    }

    func testWrongFixedPointScaleIsRejected() {
        var broken = catalog
        broken.communityBalance.fixedPointScale = 10_000
        assertRejected(broken)
    }

    func testCatalogKeyThatDisagreesWithItsIdIsRejected() throws {
        var broken = catalog
        let action = try XCTUnwrap(broken.gossipAction(id: ContentID.correctDAction))
        broken.gossipActions["brookseed.gossip.action.mismatch"] = action
        assertRejected(broken)
    }

    private func assertRejected(
        _ broken: ContentCatalog,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try ContentValidator.validate(broken), "", file: file, line: line) { error in
            XCTAssertTrue(error is ContentValidationError, "\(error)", file: file, line: line)
        }
    }
}
