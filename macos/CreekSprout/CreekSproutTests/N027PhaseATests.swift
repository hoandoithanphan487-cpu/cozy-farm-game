import Foundation
import XCTest
@testable import CreekSprout

final class N027StoryContentTests: XCTestCase {
    private let catalog = StoryContentCatalog.shared

    func testFrozenCatalogCountsSourceIDsAndValidator() throws {
        let manuscriptLines = catalog.allDialogueLines.filter { $0.origin == .manuscript }
        let sourceIDs = try manuscriptLines.map { try XCTUnwrap($0.sourceID) }
        let cueSourceIDs = catalog.blockingCues.map(\.sourceBlockingID)

        XCTAssertEqual(catalog.stories.count, 10)
        XCTAssertEqual(Set(catalog.stories.map(\.id)), Set(StoryArcID.allCases))
        XCTAssertEqual(manuscriptLines.count, 236)
        XCTAssertEqual(Set(sourceIDs).count, 236)
        XCTAssertEqual(catalog.blockingCues.count, 50)
        XCTAssertEqual(Set(cueSourceIDs).count, 50)
        XCTAssertNoThrow(try StoryContentValidator.validate(catalog))
    }

    func testStableBranchesMatchFrozenContract() {
        let expected: [StoryArcID: [String]] = [
            .q01: ["field_first", "reed_first", "inspect_first"],
            .q02: ["harvest", "sandbag", "patrol", "livestock"],
            .q03: ["cut_test", "trace_rumor", "protect_inventory"],
            .q04: ["regroup", "parallel_crop", "publish_missing_page"],
            .q05: ["public", "coop", "delay"],
            .q06: ["talk", "no_side", "pause", "love", "tender", "friend"],
            .q07: ["menu", "inventory", "harvest", "livestock"],
            .q08: ["evidence", "trade_union", "old_waterway"],
            .q09: ["take_ledger", "keep_reading", "close_ledger", "return_titles"],
            .q10: ["why_me", "any_truth", "silence", "break_titles", "water", "leave"],
        ]

        for arcID in StoryArcID.allCases {
            let choices = StoryChoiceID.choices(for: arcID)
            XCTAssertEqual(choices.map(\.rawValue), expected[arcID], arcID.rawValue)
            XCTAssertEqual(Set(choices.map { $0.stableID(in: arcID) }).count, choices.count)
            XCTAssertEqual(catalog.story(id: arcID)?.branchChoices, choices)
        }
    }

    func testRevealCallbacksAndCuesAreHiddenUntilFinaleUnlock() throws {
        for arcID in StoryArcID.allCases where arcID.sequence <= 8 {
            XCTAssertTrue(
                catalog.visibleLines(
                    arcID: arcID,
                    stage: .revealCallback,
                    finaleUnlocked: false
                ).isEmpty,
                arcID.rawValue
            )
            XCTAssertFalse(
                catalog.visibleLines(
                    arcID: arcID,
                    stage: .revealCallback,
                    finaleUnlocked: true
                ).isEmpty,
                arcID.rawValue
            )
            let revealCue = try XCTUnwrap(catalog.blockingCues.first {
                $0.arcID == arcID && $0.sourceBlockingID.hasSuffix("_05")
            })
            XCTAssertNil(catalog.visibleBlockingCue(id: revealCue.id, finaleUnlocked: false))
            XCTAssertEqual(
                catalog.visibleBlockingCue(id: revealCue.id, finaleUnlocked: true),
                revealCue
            )
        }
    }

    func testConspiratorRosterContainsEveryDistinctRequiredActor() {
        let required: Set<String> = [
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
        ]
        let flagged = Set(catalog.actors.filter(\.isConspirator).map(\.id))

        XCTAssertEqual(Set(StoryActorCatalog.conspiratorRoster), required)
        XCTAssertEqual(flagged, required)
        XCTAssertNotEqual(StoryActorID.greygateRepresentative, StoryActorID.greygateFarmer)
    }

    func testInterpolationResolvesAllowedTokensAndRejectsUnknownOrMissingValues() throws {
        XCTAssertEqual(
            try StoryDialogueInterpolator.interpolate(
                "声誉 {{reputation}}，处理为 {{q05_resolution}}。",
                standing: 73,
                q05Resolution: .coop
            ),
            "声誉 73，处理为 联合供货。"
        )
        XCTAssertThrowsError(
            try StoryDialogueInterpolator.interpolate("{{unknown_token}}", standing: 50)
        ) { error in
            XCTAssertEqual(
                error as? StoryDialogueInterpolationError,
                .unknownToken("unknown_token")
            )
        }
        XCTAssertThrowsError(
            try StoryDialogueInterpolator.interpolate("{{q05_resolution}}", standing: 50)
        ) { error in
            XCTAssertEqual(error as? StoryDialogueInterpolationError, .missingQ05Resolution)
        }
    }

    func testValidatorRejectsUnknownTokenWithoutChangingFrozenCounts() throws {
        var stories = catalog.stories
        let lineIndex = try XCTUnwrap(stories[0].stages[0].lines.indices.first)
        stories[0].stages[0].lines[lineIndex].text += " {{unknown_token}}"
        let invalid = StoryContentCatalog(
            stories: stories,
            actors: catalog.actors,
            blockingCues: catalog.blockingCues,
            anchors: catalog.anchors,
            journeyScenes: catalog.journeyScenes
        )

        XCTAssertThrowsError(try StoryContentValidator.validate(invalid)) { error in
            XCTAssertTrue(
                String(describing: error).contains("未知 token"),
                String(describing: error)
            )
        }
    }
}

final class N027StoryStateMachineTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testQ01ThroughQ08SegmentsAreSeparateFromFinaleBeats() {
        let campaign = StoryCampaignState.newGame

        XCTAssertEqual(
            campaign.segments.map(\.arcID),
            [.q01, .q02, .q03, .q04, .q05, .q06, .q07, .q08]
        )
        XCTAssertTrue(campaign.segments.allSatisfy { $0.phase == .locked })
        XCTAssertNil(campaign.segment(.q09))
        XCTAssertNil(campaign.segment(.q10))
        XCTAssertEqual(campaign.finaleBeat, .locked)
        XCTAssertEqual(
            FinaleBeat.allCases.map(\.rawValue),
            [
                "locked", "pre_reveal_save_pending", "discovery",
                "confrontation", "final_action_pending", "graduated",
            ]
        )
    }

    func testFrontstageArbiterKeepsExistingLeaseAndOtherwiseUsesFrozenPriority() throws {
        let candidates = [
            FrontstageCandidate(owner: .hint, resourceID: "brookseed.story.hint", checkpointID: nil),
            FrontstageCandidate(owner: .story, resourceID: StoryArcID.q01.rawValue, checkpointID: nil),
            FrontstageCandidate(owner: .communityEvent, resourceID: "brookseed.community.event", checkpointID: nil),
            FrontstageCandidate(owner: .journey, resourceID: StoryArcID.q08.rawValue, checkpointID: "departure"),
            FrontstageCandidate(owner: .forcedTutorial, resourceID: "brookseed.tutorial.forced", checkpointID: nil),
        ]

        XCTAssertEqual(
            FrontstageEventArbiter.select(existing: nil, candidates: candidates)?.owner,
            .forcedTutorial
        )
        let existing = FrontstageLease(
            leaseID: "brookseed.story.lease.restore",
            owner: .story,
            resourceID: StoryArcID.q03.rawValue,
            acquiredDay: 4,
            checkpointID: "warning_2"
        )
        let selected = try XCTUnwrap(
            FrontstageEventArbiter.select(existing: existing, candidates: candidates)
        )
        XCTAssertEqual(selected.owner, .story)
        XCTAssertEqual(selected.resourceID, StoryArcID.q03.rawValue)
        XCTAssertEqual(selected.checkpointID, "warning_2")
    }

    func testWarningTwoAndEruptionRequireSeparateRelatedActionsAndReleaseControl() throws {
        var state = warningState(arcID: .q03, phase: .warningOne, evidenceSerial: 0, sleepEpoch: 1)

        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q03, sleepEpoch: 1),
            .failure(.relatedActionRequired)
        )
        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q03.first_action",
            arcID: .q03
        )
        let warningTwo = try StoryDirector.requestWarningTwo(
            state: state,
            arcID: .q03,
            sleepEpoch: 1
        ).get()
        XCTAssertEqual(warningTwo.storyCampaign.frontstageLease?.owner, .story)

        let released = try StoryDirector.closeDialogue(
            state: warningTwo,
            arcID: .q03,
            completedPhase: .warningTwo
        ).get()
        XCTAssertNil(released.storyCampaign.frontstageLease)
        XCTAssertEqual(
            StoryDirector.requestEruption(state: released, arcID: .q03, sleepEpoch: 1),
            .failure(.relatedActionRequired)
        )

        var afterReentry = released
        StoryMetricsRecorder.recordRelatedAction(
            metrics: &afterReentry.storyMetrics,
            sourceID: "brookseed.story.metric.q03.anchor_reentry",
            arcID: .q03,
            anchorReentry: true
        )
        let eruption = try StoryDirector.requestEruption(
            state: afterReentry,
            arcID: .q03,
            sleepEpoch: 1
        ).get()
        XCTAssertEqual(eruption.storyCampaign.segment(.q03)?.phase, .eruption)
        XCTAssertEqual(eruption.storyCampaign.frontstageLease?.owner, .story)
    }

    func testQ06EruptionAndAftermathChoicesPersistInSeparateFinalSlots() throws {
        var state = warningState(arcID: .q06, phase: .warningTwo, evidenceSerial: 1, sleepEpoch: 1)
        var q06 = try XCTUnwrap(state.storyCampaign.segment(.q06))
        q06.enter(.eruption, day: 4)
        state.storyCampaign.updateSegment(q06)

        let eruptionChoice = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q06,
            choice: .talk
        ).get()
        XCTAssertEqual(
            StoryCommandService.selectChoice(
                state: eruptionChoice,
                arcID: .q06,
                choice: .pause
            ),
            .failure(.choiceAlreadyFinal)
        )

        state = eruptionChoice
        state.clock = GameClock(day: 5, minute: GameClock.dayStartMinute)
        q06 = try XCTUnwrap(state.storyCampaign.segment(.q06))
        q06.enter(.aftermath, day: 5)
        state.storyCampaign.updateSegment(q06)
        state.storyCampaign.q06Outcome = .friend
        let aftermathChoice = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q06,
            choice: .friend
        ).get()
        XCTAssertEqual(
            StoryCommandService.selectChoice(
                state: aftermathChoice,
                arcID: .q06,
                choice: .tender
            ),
            .failure(.unavailableArc)
        )

        let records = aftermathChoice.storyCampaign.choices.filter { $0.arcID == .q06 }
        XCTAssertEqual(records.map(\.slotID), [.aftermath, .eruption])
        XCTAssertEqual(
            aftermathChoice.storyCampaign.segment(.q06)?.selectedChoiceIDsBySlot,
            [
                StoryChoiceSlotID.eruption.rawValue: StoryChoiceID.talk.stableID(in: .q06),
                StoryChoiceSlotID.aftermath.rawValue: StoryChoiceID.friend.stableID(in: .q06),
            ]
        )
        let persisted = try JSONDecoder().decode(
            StoryCampaignState.self,
            from: JSONEncoder().encode(aftermathChoice.storyCampaign)
        )
        XCTAssertEqual(persisted.choices, aftermathChoice.storyCampaign.choices)
        XCTAssertEqual(
            persisted.segment(.q06)?.selectedChoiceIDsBySlot,
            aftermathChoice.storyCampaign.segment(.q06)?.selectedChoiceIDsBySlot
        )
    }

    func testQ06OutcomeComesFromEruptionChoiceAndBenefitCareWithoutAftermathRewrite() throws {
        let careActionIDs = [
            "brookseed.story.q06.care.shared_log",
            "brookseed.story.q06.care.tea_and_roster",
        ]

        var paused = q06BenefitState()
        for actionID in careActionIDs {
            paused = try StoryCommandService.recordAction(
                state: paused,
                arcID: .q06,
                actionID: actionID
            ).get()
        }
        XCTAssertTrue(paused.storyCampaign.romanceTender)
        paused = q06StateEntering(.eruption, from: paused, day: 4)
        paused = try StoryCommandService.selectChoice(
            state: paused,
            arcID: .q06,
            choice: .pause
        ).get()
        XCTAssertEqual(paused.storyCampaign.q06Outcome, .tender)
        paused = q06StateEntering(.aftermath, from: paused, day: 5)
        if case .success = StoryCommandService.selectChoice(
            state: paused,
            arcID: .q06,
            choice: .love
        ) {
            XCTFail("aftermath must not rewrite pause -> tender")
        }
        let tender = try StoryCommandService.selectChoice(
            state: paused,
            arcID: .q06,
            choice: .tender
        ).get()
        XCTAssertEqual(tender.storyCampaign.q06Outcome, .tender)

        var loved = q06BenefitState()
        for actionID in careActionIDs {
            loved = try StoryCommandService.recordAction(
                state: loved,
                arcID: .q06,
                actionID: actionID
            ).get()
        }
        loved = q06StateEntering(.eruption, from: loved, day: 4)
        loved = try StoryCommandService.selectChoice(
            state: loved,
            arcID: .q06,
            choice: .talk
        ).get()
        XCTAssertEqual(loved.storyCampaign.q06Outcome, .love)
        loved = q06StateEntering(.aftermath, from: loved, day: 5)
        if case .success = StoryCommandService.selectChoice(
            state: loved,
            arcID: .q06,
            choice: .friend
        ) {
            XCTFail("aftermath must not rewrite cared non-pause -> love")
        }
        loved = try StoryCommandService.selectChoice(
            state: loved,
            arcID: .q06,
            choice: .love
        ).get()
        XCTAssertEqual(loved.storyCampaign.q06Outcome, .love)

        var friends = q06BenefitState()
        friends = try StoryCommandService.recordAction(
            state: friends,
            arcID: .q06,
            actionID: careActionIDs[0]
        ).get()
        XCTAssertFalse(friends.storyCampaign.romanceTender)
        friends = q06StateEntering(.eruption, from: friends, day: 4)
        friends = try StoryCommandService.selectChoice(
            state: friends,
            arcID: .q06,
            choice: .noSide
        ).get()
        XCTAssertEqual(friends.storyCampaign.q06Outcome, .friend)
        friends = q06StateEntering(.aftermath, from: friends, day: 5)
        if case .success = StoryCommandService.selectChoice(
            state: friends,
            arcID: .q06,
            choice: .love
        ) {
            XCTFail("aftermath must not rewrite incomplete-care non-pause -> friend")
        }
        friends = try StoryCommandService.selectChoice(
            state: friends,
            arcID: .q06,
            choice: .friend
        ).get()
        XCTAssertEqual(friends.storyCampaign.q06Outcome, .friend)
    }

    func testQ10ConfrontationAndFinalActionUseIndependentFinalSlots() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 40, minute: GameClock.dayStartMinute)
        state.storyCampaign.finaleBeat = .confrontation

        let confrontationChoice = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .whyMe
        ).get()
        XCTAssertEqual(
            StoryCommandService.selectChoice(
                state: confrontationChoice,
                arcID: .q10,
                choice: .silence
            ),
            .failure(.choiceAlreadyFinal)
        )

        state = confrontationChoice
        state.storyCampaign.finaleBeat = .finalActionPending
        let finalActionChoice = try StoryCommandService.selectChoice(
            state: state,
            arcID: .q10,
            choice: .water
        ).get()
        XCTAssertEqual(
            StoryCommandService.selectChoice(
                state: finalActionChoice,
                arcID: .q10,
                choice: .leave
            ),
            .failure(.choiceAlreadyFinal)
        )
        let records = finalActionChoice.storyCampaign.choices.filter { $0.arcID == .q10 }
        XCTAssertEqual(records.map(\.slotID), [.confrontationIntent, .finalAction])
        XCTAssertEqual(records.map(\.choiceID), [
            StoryChoiceID.whyMe.stableID(in: .q10),
            StoryChoiceID.water.stableID(in: .q10),
        ])
    }

    func testQ02WarningIntervalRequiresACompletedSleepBoundary() {
        var state = warningState(arcID: .q02, phase: .warningOne, evidenceSerial: 0, sleepEpoch: 4)
        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q02.related_action",
            arcID: .q02
        )

        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q02, sleepEpoch: 4),
            .failure(.sleepBoundaryRequired)
        )
        XCTAssertNoThrow(
            try StoryDirector.requestWarningTwo(state: state, arcID: .q02, sleepEpoch: 5).get()
        )
    }

    func testQ02AndQ07WarningTwoAndEruptionRequireLaterCalendarDaysEvenIfEpochAdvances() throws {
        for arcID in [StoryArcID.q02, .q07] {
            var warningOneDay = warningState(
                arcID: arcID,
                phase: .warningOne,
                evidenceSerial: 0,
                sleepEpoch: 4
            )
            warningOneDay.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
            StoryMetricsRecorder.recordRelatedAction(
                metrics: &warningOneDay.storyMetrics,
                sourceID: "brookseed.story.metric.\(arcID.shortCode).warning_two_action",
                arcID: arcID
            )

            XCTAssertEqual(
                StoryDirector.requestWarningTwo(
                    state: warningOneDay,
                    arcID: arcID,
                    sleepEpoch: 5
                ),
                .failure(.sleepBoundaryRequired),
                arcID.rawValue
            )

            var nextDay = warningOneDay
            nextDay.clock = GameClock(day: 4, minute: GameClock.dayStartMinute)
            let warningTwo = try StoryDirector.requestWarningTwo(
                state: nextDay,
                arcID: arcID,
                sleepEpoch: 5
            ).get()
            var sameEruptionDay = try StoryDirector.closeDialogue(
                state: warningTwo,
                arcID: arcID,
                completedPhase: .warningTwo
            ).get()
            StoryMetricsRecorder.recordRelatedAction(
                metrics: &sameEruptionDay.storyMetrics,
                sourceID: "brookseed.story.metric.\(arcID.shortCode).eruption_action",
                arcID: arcID
            )

            XCTAssertEqual(
                StoryDirector.requestEruption(
                    state: sameEruptionDay,
                    arcID: arcID,
                    sleepEpoch: 6
                ),
                .failure(.sleepBoundaryRequired),
                arcID.rawValue
            )

            sameEruptionDay.clock = GameClock(day: 5, minute: GameClock.dayStartMinute)
            let eruption = try StoryDirector.requestEruption(
                state: sameEruptionDay,
                arcID: arcID,
                sleepEpoch: 6
            ).get()
            XCTAssertEqual(eruption.storyCampaign.segment(arcID)?.phase, .eruption)
        }
    }

    func testQ08WarningTwoRequiresCommittedEvidenceCheck() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 4, minute: GameClock.dayStartMinute)
        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q08.pre_warning_evidence_check",
            arcID: .q08,
            evidenceCheck: true
        )
        var segment = StorySegmentState.locked(.q08)
        segment.enter(.benefit, day: 2)
        segment.enter(.warningOne, day: 3)
        segment.warningOneEvidenceSerial = state.storyMetrics.relatedActionSerials[
            StoryArcID.q08.rawValue,
            default: 0
        ]
        segment.warningOneEvidenceCheckSerial = state.storyMetrics.evidenceCheckSerials[
            StoryArcID.q08.rawValue,
            default: 0
        ]
        segment.warningOneSleepEpoch = 2
        state.storyCampaign.updateSegment(segment)

        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q08.post_warning_ordinary_related_action",
            arcID: .q08
        )
        XCTAssertEqual(state.storyMetrics.evidenceCheckSerials[StoryArcID.q08.rawValue], 1)
        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q08, sleepEpoch: 2),
            .failure(.evidenceRequired)
        )

        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q08.burned_paper_check",
            arcID: .q08,
            evidenceCheck: true
        )
        let next = try StoryDirector.requestWarningTwo(
            state: state,
            arcID: .q08,
            sleepEpoch: 2
        ).get()
        XCTAssertEqual(next.storyCampaign.segment(.q08)?.phase, .warningTwo)
    }

    func testActiveCommunityEventBlocksAStoryWarning() {
        var state = warningState(arcID: .q03, phase: .warningOne, evidenceSerial: 0, sleepEpoch: 1)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        XCTAssertFalse(state.community.activeEvents.isEmpty)
        StoryMetricsRecorder.recordRelatedAction(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.q03.community_blocked_action",
            arcID: .q03
        )

        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q03, sleepEpoch: 1),
            .failure(.communityEventActive)
        )
    }

    func testResponsibleAftermathAwardsEachQ01ThroughQ07ExactlyOnce() throws {
        for arcID in [StoryArcID.q01, .q02, .q03, .q04, .q05, .q06, .q07] {
            var state = aftermathState(arcID: arcID, standing: 31)
            let resolved = try StoryDirector.resolveResponsibleAftermath(
                state: state,
                arcID: arcID
            ).get()
            XCTAssertEqual(resolved.community.standing, 37, arcID.rawValue)
            XCTAssertEqual(resolved.storyCampaign.segment(arcID)?.phase, .resolved)
            XCTAssertNotNil(resolved.storyCampaign.segment(arcID)?.standingAwardReceiptID)

            state = resolved
            XCTAssertEqual(
                StoryDirector.resolveResponsibleAftermath(state: state, arcID: arcID),
                .failure(.illegalTransition),
                arcID.rawValue
            )
            XCTAssertEqual(state.community.standing, 37)
        }
    }

    func testThreeDistinctRepairCommissionsAwardSixEachAndDuplicateIsRejected() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 5, minute: GameClock.dayStartMinute)
        state.community.standing = 73
        var q07 = StorySegmentState.locked(.q07)
        q07.aftermathQuality = .responsible
        q07.enter(.resolved, day: 5)
        state.storyCampaign.updateSegment(q07)

        state = try StoryDirector.completeRepairCommission(
            state: state,
            commissionID: "brookseed.story.repair.first"
        ).get()
        XCTAssertEqual(state.community.standing, 79)
        XCTAssertEqual(
            StoryDirector.completeRepairCommission(
                state: state,
                commissionID: "brookseed.story.repair.first"
            ),
            .failure(.duplicateReceipt)
        )

        state = try StoryDirector.completeRepairCommission(
            state: state,
            commissionID: "brookseed.story.repair.second"
        ).get()
        XCTAssertEqual(state.community.standing, 85)
        state = try StoryDirector.completeRepairCommission(
            state: state,
            commissionID: "brookseed.story.repair.third"
        ).get()
        XCTAssertEqual(state.community.standing, 91)
        XCTAssertEqual(state.storyCampaign.repairCommissionIDs.count, 3)
        XCTAssertEqual(
            StoryDirector.completeRepairCommission(
                state: state,
                commissionID: "brookseed.story.repair.fourth"
            ),
            .failure(.illegalTransition)
        )
    }

    private func warningState(
        arcID: StoryArcID,
        phase: StoryPhase,
        evidenceSerial: Int,
        sleepEpoch: Int
    ) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 4, minute: GameClock.dayStartMinute)
        var segment = StorySegmentState.locked(arcID)
        segment.enter(.benefit, day: 2)
        if phase.order >= StoryPhase.warningOne.order {
            segment.enter(.warningOne, day: 3)
            segment.warningOneEvidenceSerial = evidenceSerial
            segment.warningOneEvidenceCheckSerial = 0
            segment.warningOneSleepEpoch = sleepEpoch
        }
        if phase.order >= StoryPhase.warningTwo.order {
            segment.enter(.warningTwo, day: 4)
            segment.warningTwoEvidenceSerial = evidenceSerial
            segment.warningTwoSleepEpoch = sleepEpoch
        }
        state.storyCampaign.updateSegment(segment)
        state.storyCampaign.frontstageLease = nil
        return state
    }

    private func aftermathState(arcID: StoryArcID, standing: Int) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 5, minute: GameClock.dayStartMinute)
        state.community.standing = standing
        var segment = StorySegmentState.locked(arcID)
        segment.enter(.benefit, day: 1)
        segment.enter(.warningOne, day: 1)
        segment.enter(.warningTwo, day: 2)
        segment.enter(.eruption, day: 2)
        segment.enter(.aftermath, day: 3)
        let eruptionChoice: StoryChoiceID = arcID == .q06
            ? .talk
            : StoryChoiceID.choices(for: arcID)[0]
        let eruptionSlot = eruptionChoice.slot(in: arcID)
        let eruptionStableID = eruptionChoice.stableID(in: arcID)
        segment.selectedChoiceIDsBySlot[eruptionSlot.rawValue] = eruptionStableID
        state.storyCampaign.choices.append(
            StoryChoiceRecord(
                arcID: arcID,
                slotID: eruptionSlot,
                choiceID: eruptionStableID,
                day: 2
            )
        )
        if arcID == .q06 {
            let aftermathChoice = StoryChoiceID.friend
            let aftermathSlot = aftermathChoice.slot(in: arcID)
            let aftermathStableID = aftermathChoice.stableID(in: arcID)
            segment.selectedChoiceIDsBySlot[aftermathSlot.rawValue] = aftermathStableID
            state.storyCampaign.choices.append(
                StoryChoiceRecord(
                    arcID: arcID,
                    slotID: aftermathSlot,
                    choiceID: aftermathStableID,
                    day: 3
                )
            )
            state.storyCampaign.q06Outcome = .friend
        }
        state.storyCampaign.updateSegment(segment)
        state.storyCampaign.canonicalize()
        return state
    }

    private func q06BenefitState() -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 1, minute: GameClock.dayStartMinute)
        var segment = StorySegmentState.locked(.q06)
        segment.benefitOfferID = "brookseed.story.offer.q06.relationship_care"
        segment.benefitBaselineDay = 1
        segment.benefitBaseline = .zero
        segment.enter(.benefit, day: 1)
        state.storyCampaign.updateSegment(segment)
        return state
    }

    private func q06StateEntering(
        _ phase: StoryPhase,
        from source: GameState,
        day: Int
    ) -> GameState {
        var state = source
        state.clock = GameClock(day: day, minute: GameClock.dayStartMinute)
        guard var segment = state.storyCampaign.segment(.q06) else {
            XCTFail("missing Q06 segment")
            return state
        }
        if phase == .eruption {
            segment.enter(.warningOne, day: 2)
            segment.enter(.warningTwo, day: 3)
        }
        segment.enter(phase, day: day)
        state.storyCampaign.updateSegment(segment)
        return state
    }
}

final class N027StoryMetricsTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testFarmMutationAndMetricShareOneCandidateWhileFailureHasNoCandidate() throws {
        let service = FarmActionService()
        let target = GridPosition(x: 2, y: 3)
        let original = GameState.m1NewGame()

        let prepared = service.candidate(
            state: original,
            target: target,
            tool: .hoe,
            catalog: .m1Placeholder
        )
        let candidate = try XCTUnwrap(prepared.state)
        XCTAssertTrue(prepared.outcome.isSuccess)
        XCTAssertFalse(original.cell(at: target).prepared)
        XCTAssertEqual(original.storyMetrics.tilledCellCount, 0)
        XCTAssertTrue(candidate.cell(at: target).prepared)
        XCTAssertEqual(candidate.storyMetrics.tilledCellCount, 1)
        XCTAssertEqual(candidate.storyMetrics.recordedSourceIDs.count, 1)

        let retry = service.candidate(
            state: candidate,
            target: target,
            tool: .hoe,
            catalog: .m1Placeholder
        )
        XCTAssertFalse(retry.outcome.isSuccess)
        XCTAssertNil(retry.state)
        XCTAssertEqual(candidate.storyMetrics.tilledCellCount, 1)

        var exhausted = original
        exhausted.stamina = 1
        let failed = service.candidate(
            state: exhausted,
            target: target,
            tool: .hoe,
            catalog: .m1Placeholder
        )
        XCTAssertFalse(failed.outcome.isSuccess)
        XCTAssertNil(failed.state)
        XCTAssertEqual(exhausted.storyMetrics, .empty)
    }

    func testTalkMetricLivesInCandidateAndRepeatingSameNPCDayIsIdempotent() throws {
        let service = CommunityCommandService(catalog: catalog)
        let original = GameState.vs0NewGame(catalog: catalog)

        let first = try XCTUnwrap(
            service.talkCandidate(state: original, npcID: ContentID.waterApprentice)
        )
        XCTAssertTrue(original.storyMetrics.npcTalkDays.isEmpty)
        XCTAssertEqual(first.state.storyMetrics.npcTalkDays[ContentID.waterApprentice], [1])

        let repeated = try XCTUnwrap(
            service.talkCandidate(state: first.state, npcID: ContentID.waterApprentice)
        )
        XCTAssertEqual(repeated.state.storyMetrics.npcTalkDays[ContentID.waterApprentice], [1])
        XCTAssertEqual(
            repeated.state.storyMetrics.recordedSourceIDs,
            first.state.storyMetrics.recordedSourceIDs
        )
        XCTAssertNil(service.talkCandidate(state: first.state, npcID: "brookseed.npc.unknown"))
    }

    func testCatShopReceiptAndMetricsCommitTogetherAndFailuresDoNotCount() throws {
        var original = GameState.vs0NewGame(catalog: catalog)
        let offer = try XCTUnwrap(CatShopCatalog.offers(day: 1, content: catalog).first {
            if case .crop = $0.kind { return true }
            return false
        })
        guard case .crop(let itemID) = offer.kind else { return XCTFail("expected crop offer") }
        original.inventory = try InventoryService.tryAdd(
            original.inventory,
            capacity: original.inventoryCapacity,
            itemID: itemID,
            quantity: 2,
            stackLimit: catalog.stackLimit(for: itemID)
        ).get()
        let requestID = "n027.metrics.crop.day1.receipt1"

        let supplied = try CatShopSupplyService.supplyCrop(
            state: original,
            offerID: offer.id,
            itemID: itemID,
            quantity: 2,
            requestID: requestID,
            catalog: catalog
        ).get()
        XCTAssertTrue(original.catShop.receipts.isEmpty)
        XCTAssertTrue(original.storyMetrics.catShopReceiptIDs.isEmpty)
        XCTAssertEqual(supplied.state.catShop.receipts.map(\.receiptID), [requestID])
        XCTAssertEqual(supplied.state.storyMetrics.catShopReceiptIDs, [requestID])
        XCTAssertEqual(supplied.state.storyMetrics.catShopCropReceiptIDs, [requestID])

        XCTAssertEqual(
            CatShopSupplyService.supplyCrop(
                state: supplied.state,
                offerID: offer.id,
                itemID: itemID,
                quantity: 1,
                requestID: requestID,
                catalog: catalog
            ),
            .failure(.duplicateRequest)
        )
        XCTAssertEqual(supplied.state.storyMetrics.catShopReceiptIDs, [requestID])

        var empty = original
        empty.inventory = []
        XCTAssertEqual(
            CatShopSupplyService.supplyCrop(
                state: empty,
                offerID: offer.id,
                itemID: itemID,
                quantity: 1,
                requestID: "n027.metrics.crop.day1.failed",
                catalog: catalog
            ),
            .failure(.insufficientQuantity)
        )
        XCTAssertTrue(empty.storyMetrics.catShopReceiptIDs.isEmpty)
    }

    func testLivestockCareMetricCommitsWithCandidateAndSameDayRetryDoesNotCount() throws {
        let original = GameState.vs0NewGame(catalog: catalog)
        let cared = try LivestockService.care(
            state: original,
            animalID: ContentID.starterCow
        ).get()

        XCTAssertNil(original.livestock.animal(id: ContentID.starterCow)?.lastCaredDay)
        XCTAssertTrue(original.storyMetrics.livestockCareDays.isEmpty)
        XCTAssertEqual(cared.livestock.animal(id: ContentID.starterCow)?.lastCaredDay, 1)
        XCTAssertEqual(cared.storyMetrics.livestockCareDays[ContentID.starterCow], [1])
        XCTAssertEqual(
            LivestockService.care(state: cared, animalID: ContentID.starterCow),
            .failure(.alreadyCaredToday)
        )
        XCTAssertEqual(cared.storyMetrics.livestockCareDays[ContentID.starterCow], [1])

        var exhausted = original
        exhausted.stamina = 1
        XCTAssertEqual(
            LivestockService.care(state: exhausted, animalID: ContentID.starterCow),
            .failure(.insufficientStamina)
        )
        XCTAssertTrue(exhausted.storyMetrics.livestockCareDays.isEmpty)
    }

    func testAnimalSupplyKeepsGrowthHistoryAfterAnimalLeavesRoster() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state = try LivestockService.care(state: state, animalID: ContentID.starterCow).get()
        let offer = try XCTUnwrap(CatShopCatalog.offers(day: 1, content: catalog).first {
            $0.kind == .animal(definitionID: ContentID.livestockCow)
        })
        let requestID = "n027.metrics.animal.day1.receipt1"

        let supplied = try CatShopSupplyService.supplyAnimal(
            state: state,
            offerID: offer.id,
            animalID: ContentID.starterCow,
            requestID: requestID,
            catalog: catalog
        ).get()

        XCTAssertNil(supplied.state.livestock.animal(id: ContentID.starterCow))
        let history = try XCTUnwrap(supplied.state.storyMetrics.animalSupplyHistory.first)
        XCTAssertEqual(history.animalID, ContentID.starterCow)
        XCTAssertEqual(history.definitionID, ContentID.livestockCow)
        XCTAssertEqual(history.receiptID, requestID)
        XCTAssertEqual(supplied.state.storyMetrics.catShopAnimalReceiptIDs, [requestID])
    }

    func testQ03PremiumMaturityRequiresThreeConsecutiveSettledDays() throws {
        var state = try q03MaturityState()
        state.storyMetrics.dailyMetricDays = [1, 2, 3, 4]

        state.storyMetrics.premiumBenefitDays = [1, 3, 4]
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q03, state: state)
                .missingConditionIDs.contains("q03.consecutive_premium_days_3")
        )

        state.storyMetrics.premiumBenefitDays = [2, 3]
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q03, state: state)
                .missingConditionIDs.contains("q03.consecutive_premium_days_3")
        )

        state.storyMetrics.premiumBenefitDays = [2, 3, 4]
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q03, state: state),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )
    }

    func testQ03ThirdPremiumDayMustBeSettledBeforeMaturity() throws {
        var state = try q03MaturityState()
        state.storyMetrics.premiumBenefitDays = [2, 3, 4]
        state.storyMetrics.dailyMetricDays = [1, 2, 3]

        XCTAssertTrue(
            StoryMaturityService.evaluate(.q03, state: state)
                .missingConditionIDs.contains("q03.consecutive_premium_days_3")
        )

        state.storyMetrics.dailyMetricDays.append(4)
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q03, state: state),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )
    }

    func testQ07PremiumDeltaRequiresThreeReceiptsFromItsBenefitOffer() throws {
        var state = q07MaturityState(growingCellCount: 8)
        let offerID = try XCTUnwrap(state.storyCampaign.segment(.q07)?.benefitOfferID)
        let unrelatedOfferID = "brookseed.story.offer.q05.unrelated"
        let currentReceiptIDs = (1...3).map { "brookseed.story.receipt.q07.premium.\($0)" }
        let unrelatedReceiptIDs = (1...3).map { "brookseed.story.receipt.q05.premium.\($0)" }
        state.storyMetrics.catShopPremiumReceiptIDs = unrelatedReceiptIDs + currentReceiptIDs
        state.storyMetrics.catShopPrepaymentReceiptIDs = []
        for receiptID in unrelatedReceiptIDs + currentReceiptIDs {
            state.storyMetrics.catShopReceiptOfferSourceIDs[receiptID] = unrelatedOfferID
        }
        state.catShop.receipts = unrelatedReceiptIDs.enumerated().map { index, receiptID in
            CatShopReceipt(
                receiptID: receiptID,
                day: (index * 2) + 2,
                offerID: unrelatedOfferID,
                kind: .crop,
                subjectID: ContentID.bellBerryItem,
                definitionID: ContentID.bellBerryItem,
                displayName: "N027 unrelated premium fixture",
                quantity: 1,
                unitPrice: 1,
                total: 1
            )
        } + currentReceiptIDs.enumerated().map { index, receiptID in
            CatShopReceipt(
                receiptID: receiptID,
                day: index + 8,
                offerID: offerID,
                kind: .crop,
                subjectID: ContentID.bellBerryItem,
                definitionID: ContentID.bellBerryItem,
                displayName: "N027 Q07 premium fixture",
                quantity: 1,
                unitPrice: 1,
                total: 1
            )
        }

        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: state)
                .missingConditionIDs.contains("q07.causal_premium_or_prepay_3")
        )

        for receiptID in currentReceiptIDs.prefix(2) {
            state.storyMetrics.catShopReceiptOfferSourceIDs[receiptID] = offerID
        }
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: state)
                .missingConditionIDs.contains("q07.causal_premium_or_prepay_3")
        )

        state.storyMetrics.catShopReceiptOfferSourceIDs[currentReceiptIDs[2]] = offerID
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q07, state: state),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )
    }

    func testQ07ThirdReceiptMustBeSettledAndAllCausalReceiptsMustFollowBenefitBaseline() throws {
        var unsettled = q07MaturityState(growingCellCount: 8)
        unsettled.storyMetrics.dailyMetricDays.removeAll { $0 == 10 }
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: unsettled)
                .missingConditionIDs.contains("q07.causal_premium_or_prepay_3")
        )

        unsettled.storyMetrics.dailyMetricDays = Array(1...12)
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q07, state: unsettled),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )

        var outsideBenefitWindow = q07MaturityState(growingCellCount: 8)
        let benefitDay = try XCTUnwrap(
            outsideBenefitWindow.storyCampaign.segment(.q07)?.benefitBaselineDay
        )
        for (offset, receiptID) in outsideBenefitWindow.storyMetrics
            .catShopPremiumReceiptIDs.enumerated() {
            let receiptIndex = try XCTUnwrap(
                outsideBenefitWindow.catShop.receipts.firstIndex {
                    $0.receiptID == receiptID
                }
            )
            outsideBenefitWindow.catShop.receipts[receiptIndex].day = benefitDay - 1 + offset
        }
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: outsideBenefitWindow)
                .missingConditionIDs.contains("q07.causal_premium_or_prepay_3")
        )

        for (offset, receiptID) in outsideBenefitWindow.storyMetrics
            .catShopPremiumReceiptIDs.enumerated() {
            let receiptIndex = try XCTUnwrap(
                outsideBenefitWindow.catShop.receipts.firstIndex {
                    $0.receiptID == receiptID
                }
            )
            outsideBenefitWindow.catShop.receipts[receiptIndex].day = benefitDay + 1 + offset
        }
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q07, state: outsideBenefitWindow),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )
    }

    func testQ07InventoryInvestmentRequiresExplicitTwelveUnitReservation() throws {
        var state = q07MaturityState(growingCellCount: 0)
        state.inventory = try InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: ContentID.bellBerryItem,
            quantity: 12,
            stackLimit: catalog.stackLimit(for: ContentID.bellBerryItem)
        ).get()
        let inventoryBeforeReservation = state.inventory

        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: state)
                .missingConditionIDs.contains("q07.causal_celebration_investment")
        )

        state = try StoryCommandService.reserveCelebrationInventory(
            state: state,
            itemID: ContentID.bellBerryItem,
            quantity: 11,
            requestID: "brookseed.story.q07.reservation.first"
        ).get()
        XCTAssertEqual(state.inventory, inventoryBeforeReservation)
        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: state)
                .missingConditionIDs.contains("q07.causal_celebration_investment")
        )

        state = try StoryCommandService.reserveCelebrationInventory(
            state: state,
            itemID: ContentID.bellBerryItem,
            quantity: 1,
            requestID: "brookseed.story.q07.reservation.second"
        ).get()
        XCTAssertEqual(
            state.storyCampaign.segment(.q07)?.reservedInventoryByItemID[ContentID.bellBerryItem],
            12
        )
        XCTAssertEqual(state.inventory, inventoryBeforeReservation)
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q07, state: state),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )

        let idempotent = try StoryCommandService.reserveCelebrationInventory(
            state: state,
            itemID: ContentID.bellBerryItem,
            quantity: 1,
            requestID: "brookseed.story.q07.reservation.second"
        ).get()
        XCTAssertEqual(idempotent, state)
        XCTAssertEqual(
            StoryCommandService.reserveCelebrationInventory(
                state: state,
                itemID: ContentID.bellBerryItem,
                quantity: 1,
                requestID: "brookseed.story.q07.reservation.overflow"
            ),
            .failure(.insufficientQuantity)
        )
    }

    func testQ07QuietMaturityRequiresFiveConsecutiveSettledDays() {
        var state = q07MaturityState(growingCellCount: 8)
        state.clock = GameClock(day: 13, minute: GameClock.dayStartMinute)
        state.storyMetrics.dailyMetricDays = Array(1...12)
        state.storyMetrics.quietDays = [7, 8, 9, 11, 12]

        XCTAssertTrue(
            StoryMaturityService.evaluate(.q07, state: state)
                .missingConditionIDs.contains("q07.quiet_days_5")
        )

        state.storyMetrics.quietDays = [8, 9, 10, 11, 12]
        XCTAssertEqual(
            StoryMaturityService.evaluate(.q07, state: state),
            StoryMaturityResult(isMature: true, missingConditionIDs: [])
        )
    }

    private func q03MaturityState() throws -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 5, minute: GameClock.dayStartMinute)
        state.storyCampaign.updateSegment(resolvedSegment(.q02, startDay: 1))
        state.storyMetrics.completedCyclesByCropID[ContentID.bellBerryCrop] = 2
        state.storyMetrics.deliveryRecipientIDsByCropID[ContentID.bellBerryCrop] = [
            "brookseed.npc.q03.recipient.a",
            "brookseed.npc.q03.recipient.b",
            "brookseed.npc.q03.recipient.c",
        ]
        state.inventory = try InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: ContentID.bellBerryItem,
            quantity: 6,
            stackLimit: catalog.stackLimit(for: ContentID.bellBerryItem)
        ).get()
        return state
    }

    private func q07MaturityState(growingCellCount: Int) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 13, minute: GameClock.dayStartMinute)
        for (index, arcID) in [
            StoryArcID.q01, .q02, .q03, .q04, .q05, .q06,
        ].enumerated() {
            state.storyCampaign.updateSegment(
                resolvedSegment(arcID, startDay: index + 1)
            )
        }
        var q07 = StorySegmentState.locked(.q07)
        q07.benefitOfferID = "brookseed.story.offer.q07.celebration"
        q07.benefitBaselineDay = 7
        q07.benefitBaseline = StoryMaturityService.baseline(for: state)
        q07.enter(.benefit, day: 7)
        state.storyCampaign.updateSegment(q07)

        state.storyMetrics.catShopCropReceiptIDs = (1...5).map {
            "brookseed.story.receipt.q07.crop.\($0)"
        }
        state.storyMetrics.catShopAnimalReceiptIDs = [
            "brookseed.story.receipt.q07.animal.1",
        ]
        state.storyMetrics.animalsGrownToAdultIDs = ["brookseed.animal.q07.adult"]
        let causalReceiptIDs = (1...3).map {
            "brookseed.story.receipt.q07.causal_premium.\($0)"
        }
        state.storyMetrics.catShopReceiptIDs = causalReceiptIDs
        state.storyMetrics.catShopPremiumReceiptIDs = causalReceiptIDs
        for receiptID in causalReceiptIDs {
            state.storyMetrics.catShopReceiptOfferSourceIDs[receiptID] = q07.benefitOfferID
        }
        state.catShop.receipts = causalReceiptIDs.enumerated().map { index, receiptID in
            CatShopReceipt(
                receiptID: receiptID,
                day: index + 8,
                offerID: q07.benefitOfferID ?? "",
                kind: .crop,
                subjectID: ContentID.bellBerryItem,
                definitionID: ContentID.bellBerryItem,
                displayName: "N027 Q07 premium fixture",
                quantity: 1,
                unitPrice: 1,
                total: 1
            )
        }
        state.storyMetrics.premiumBenefitDays = [8, 9, 10]
        state.storyMetrics.dailyMetricDays = Array(1...12)
        state.storyMetrics.quietDays = [8, 9, 10, 11, 12]

        for index in 0..<growingCellCount {
            state.farmCells[GridPosition(x: index, y: 0)] = FarmCell(
                prepared: true,
                wateredToday: true,
                cropID: ContentID.mistRadishCrop,
                cropStage: 0,
                stageProgressDays: 0,
                plantedDay: 1
            )
        }
        return state
    }

    private func resolvedSegment(
        _ arcID: StoryArcID,
        startDay: Int
    ) -> StorySegmentState {
        var segment = StorySegmentState.locked(arcID)
        segment.benefitOfferID = "brookseed.story.offer.\(arcID.shortCode).metrics_fixture"
        segment.benefitBaselineDay = startDay
        segment.benefitBaseline = .zero
        segment.enter(.benefit, day: startDay)
        segment.enter(.warningOne, day: startDay)
        segment.enter(.warningTwo, day: startDay)
        segment.enter(.eruption, day: startDay)
        segment.enter(.aftermath, day: startDay)
        segment.aftermathQuality = .responsible
        segment.enter(.resolved, day: startDay)
        return segment
    }
}

final class N027StorySaveMigrationTests: XCTestCase {
    private enum InjectedSleepStageError: Error, Equatable {
        case stage(String)
    }

    private var directory: URL!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-N027-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testSleepPipelineOrderAndIntermediateFailureRollBackWithoutSaving() throws {
        let expectedStages = [
            "shipping_settled",
            "overnight_coverage_applied",
            "crops_advanced",
            "livestock_settled",
            "story_metrics_recorded",
            "clock_advanced",
            "community_advanced",
            "story_advanced",
            "validated",
            "saved",
        ]
        let successDirectory = directory.appendingPathComponent("sleep-success", isDirectory: true)
        let successStore = SaveStore(directory: successDirectory, catalog: catalog)
        var successState = GameState.vs0NewGame(catalog: catalog)
        let successClock = ClockSystem()
        var observedSuccessStages: [String] = []

        _ = try SleepUseCase().sleep(
            state: &successState,
            clock: successClock,
            catalog: catalog,
            store: successStore,
            stageObserver: { stage, _ in
                observedSuccessStages.append(stage.rawValue)
            }
        )

        XCTAssertEqual(observedSuccessStages, expectedStages)
        XCTAssertEqual(try successStore.load(), successState)

        for failingStage in [SleepPipelineStage.livestockSettled, .storyAdvanced] {
            let failureDirectory = directory.appendingPathComponent(
                "sleep-failure-\(failingStage.rawValue)",
                isDirectory: true
            )
            let failureStore = SaveStore(directory: failureDirectory, catalog: catalog)
            var state = GameState.vs0NewGame(catalog: catalog)
            state.economy.shipping.pendingEntries = [
                ShippingEntry(
                    entryID: "brookseed.shipping.n027.\(failingStage.rawValue)",
                    itemID: ContentID.mistRadishItem,
                    quantity: 1,
                    quality: .normal,
                    depositedDay: 1,
                    unitPriceSnapshot: 58
                ),
            ]
            let clock = ClockSystem()
            XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 0.5), 0)
            let stateBeforeSleep = state
            let clockBeforeSleep = clock.snapshot()
            var observedFailureStages: [String] = []

            XCTAssertThrowsError(
                try SleepUseCase().sleep(
                    state: &state,
                    clock: clock,
                    catalog: catalog,
                    store: failureStore,
                    stageObserver: { stage, _ in
                        observedFailureStages.append(stage.rawValue)
                        if stage.rawValue == failingStage.rawValue {
                            throw InjectedSleepStageError.stage(stage.rawValue)
                        }
                    }
                )
            ) { error in
                XCTAssertEqual(
                    error as? InjectedSleepStageError,
                    .stage(failingStage.rawValue)
                )
            }
            XCTAssertEqual(observedFailureStages.last, failingStage.rawValue)
            XCTAssertEqual(state, stateBeforeSleep)
            XCTAssertEqual(clock.snapshot(), clockBeforeSleep)
            XCTAssertFalse(FileManager.default.fileExists(atPath: failureStore.primaryURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: failureStore.backupURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: failureStore.temporaryURL.path))
            XCTAssertThrowsError(try failureStore.load()) { error in
                XCTAssertEqual(error as? SaveStoreError, .missingSave)
            }
        }
    }

    func testV9ToV10MigrationIsNeutralAndPreservesExistingDomains() throws {
        var legacyState = GameState.vs0NewGame(
            catalog: catalog,
            campaignID: "brookseed.campaign.c_legacy_source"
        )
        let plot = GridPosition(x: 2, y: 3)
        legacyState.farmCells[plot] = FarmCell(
            prepared: true,
            wateredToday: false,
            cropID: ContentID.mistRadishCrop,
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 1,
            dryStreak: 2,
            cropCondition: .wilted
        )
        legacyState.storyMetrics.manualWaterCellDays = 999
        var q01 = try XCTUnwrap(legacyState.storyCampaign.segment(.q01))
        q01.enter(.benefit, day: 1)
        legacyState.storyCampaign.updateSegment(q01)

        let data = try v9Data(from: legacyState)
        let context = SaveMigrationContext(sourceSlotName: SaveSlotCatalog.manualSlotNames[1])
        let migrated = try SaveMigrator.migrate(data, context: context)

        XCTAssertEqual(migrated.schemaVersion, 10)
        XCTAssertTrue(migrated.campaignID.hasPrefix("brookseed.campaign.legacy_"))
        XCTAssertEqual(migrated.generationMetadata.campaignID, migrated.campaignID)
        XCTAssertEqual(migrated.generationMetadata.ownerManualSlot, context.sourceSlotName)
        XCTAssertEqual(migrated.generationMetadata.generationKind, .legacy)
        XCTAssertEqual(migrated.storyCampaign, .newGame)
        XCTAssertEqual(migrated.storyMetrics, .empty)
        XCTAssertEqual(migrated.inventory, legacyState.inventory)
        XCTAssertEqual(migrated.economy, legacyState.economy)
        XCTAssertEqual(migrated.community, legacyState.community)
        XCTAssertEqual(migrated.relationships, legacyState.relationships)
        XCTAssertEqual(migrated.livestock, legacyState.livestock)
        XCTAssertEqual(migrated.catShop, legacyState.catShop)
        XCTAssertTrue(migrated.farmCells.allSatisfy {
            $0.dryStreak == 0 && $0.cropCondition == .healthy
        })
    }

    func testLegacyCampaignIdentityAndSecondEncodingAreDeterministic() throws {
        let data = try v9Data(from: GameState.vs0NewGame(catalog: catalog))
        let context = SaveMigrationContext(sourceSlotName: SaveSlotCatalog.manualSlotNames[0])
        let first = try SaveMigrator.migrate(data, context: context)
        let second = try SaveMigrator.migrate(data, context: context)
        let otherSlot = try SaveMigrator.migrate(
            data,
            context: SaveMigrationContext(sourceSlotName: SaveSlotCatalog.manualSlotNames[1])
        )

        XCTAssertEqual(first.campaignID, second.campaignID)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first.campaignID, otherSlot.campaignID)

        let state = try first.makeState()
        let encodedOnce = try SaveCodec.encode(
            state,
            generationMetadata: first.generationMetadata
        )
        let reread = try SaveCodec.decodeGeneration(encodedOnce, catalog: catalog, context: context)
        let encodedTwice = try SaveCodec.encode(
            reread.state,
            generationMetadata: reread.metadata
        )
        XCTAssertEqual(encodedOnce, encodedTwice)
        XCTAssertEqual(reread.state, state)
    }

    func testSaveStorePhysicalExpectationRejectsCampaignOwnerAndKindMismatches() throws {
        let expectedCampaignID = "brookseed.campaign.c_n027_expected"
        let otherCampaignID = "brookseed.campaign.c_n027_other"
        let expectedOwner = SaveSlotCatalog.manualSlotNames[0]
        let otherOwner = SaveSlotCatalog.manualSlotNames[1]
        let expectedState = GameState.vs0NewGame(
            catalog: catalog,
            campaignID: expectedCampaignID
        )
        let otherState = GameState.vs0NewGame(
            catalog: catalog,
            campaignID: otherCampaignID
        )
        let expectedMetadata = SaveGenerationMetadata(
            campaignID: expectedCampaignID,
            ownerManualSlot: expectedOwner,
            generationKind: .campaignAuto,
            saveSequence: 7,
            writtenAtMilliseconds: 7_000
        )
        let mismatches: [(String, GameState, SaveGenerationMetadata)] = [
            (
                "campaign",
                otherState,
                SaveGenerationMetadata(
                    campaignID: otherCampaignID,
                    ownerManualSlot: expectedOwner,
                    generationKind: .campaignAuto,
                    saveSequence: 8,
                    writtenAtMilliseconds: 8_000
                )
            ),
            (
                "owner",
                expectedState,
                SaveGenerationMetadata(
                    campaignID: expectedCampaignID,
                    ownerManualSlot: otherOwner,
                    generationKind: .campaignAuto,
                    saveSequence: 8,
                    writtenAtMilliseconds: 8_000
                )
            ),
            (
                "kind",
                expectedState,
                SaveGenerationMetadata(
                    campaignID: expectedCampaignID,
                    ownerManualSlot: expectedOwner,
                    generationKind: .missionCurrent,
                    saveSequence: 8,
                    writtenAtMilliseconds: 8_000
                )
            ),
        ]
        let validBackupData = try SaveCodec.encode(
            expectedState,
            generationMetadata: expectedMetadata
        )

        for (label, mismatchedState, mismatchedMetadata) in mismatches {
            let caseDirectory = directory.appendingPathComponent(
                "physical-mismatch-\(label)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: caseDirectory,
                withIntermediateDirectories: true
            )
            let store = SaveStore(
                directory: caseDirectory,
                slotName: SaveGenerationKind.campaignAuto.rawValue,
                catalog: catalog,
                expectation: SaveGenerationExpectation(
                    campaignID: expectedCampaignID,
                    ownerManualSlot: expectedOwner,
                    generationKinds: [.campaignAuto]
                )
            )
            let mismatchedData = try SaveCodec.encode(
                mismatchedState,
                generationMetadata: mismatchedMetadata
            )
            try mismatchedData.write(to: store.primaryURL, options: .atomic)
            try validBackupData.write(to: store.backupURL, options: .atomic)

            let recovered = try store.loadGeneration()
            XCTAssertEqual(recovered.state.campaignID, expectedCampaignID, label)
            XCTAssertEqual(recovered.metadata, expectedMetadata, label)

            try mismatchedData.write(to: store.backupURL, options: .atomic)
            XCTAssertThrowsError(try store.loadGeneration(), label) { error in
                XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration, label)
            }
        }
    }

    func testCoordinatorRecoversMatchingCompanionBackupButIgnoresMismatchedBackup() throws {
        let coordinator = CampaignSaveCoordinator(rootDirectory: directory, catalog: catalog)
        let owner = SaveSlotCatalog.manualSlotNames[0]
        let otherOwner = SaveSlotCatalog.manualSlotNames[1]
        let manual = try coordinator.createNewCampaign(manualSlotIndex: 0)
        let validMetadata = try coordinator.save(
            manual.state,
            kind: .campaignAuto,
            ownerManualSlot: owner
        )
        let companionDirectory = coordinator.campaignDirectory(manual.state.campaignID)
        let companionStore = SaveStore(
            directory: companionDirectory,
            slotName: SaveGenerationKind.campaignAuto.rawValue,
            catalog: catalog,
            expectation: SaveGenerationExpectation(
                campaignID: manual.state.campaignID,
                ownerManualSlot: owner,
                generationKinds: [.campaignAuto]
            )
        )
        let validData = try Data(contentsOf: companionStore.primaryURL)
        let wrongOwnerData = try SaveCodec.encode(
            manual.state,
            generationMetadata: SaveGenerationMetadata(
                campaignID: manual.state.campaignID,
                ownerManualSlot: otherOwner,
                generationKind: .campaignAuto,
                saveSequence: validMetadata.saveSequence + 1,
                writtenAtMilliseconds: validMetadata.writtenAtMilliseconds + 1
            )
        )
        try wrongOwnerData.write(to: companionStore.primaryURL, options: .atomic)
        try validData.write(to: companionStore.backupURL, options: .atomic)

        var best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.metadata, validMetadata)
        XCTAssertEqual(best.generation.metadata.generationKind, .campaignAuto)

        let wrongKindData = try SaveCodec.encode(
            manual.state,
            generationMetadata: SaveGenerationMetadata(
                campaignID: manual.state.campaignID,
                ownerManualSlot: owner,
                generationKind: .missionCurrent,
                saveSequence: validMetadata.saveSequence + 2,
                writtenAtMilliseconds: validMetadata.writtenAtMilliseconds + 2
            )
        )
        try wrongKindData.write(to: companionStore.backupURL, options: .atomic)

        best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.metadata.generationKind, .manual)
        XCTAssertEqual(best.generation.metadata.ownerManualSlot, owner)
        XCTAssertEqual(best.generation.state.campaignID, manual.state.campaignID)
    }

    func testBestContinueDeterministicallyMaterializesLegacySequenceTiesInSlotOrder() throws {
        let coordinator = CampaignSaveCoordinator(rootDirectory: directory, catalog: catalog)
        let owners = Array(SaveSlotCatalog.manualSlotNames.prefix(2))
        var legacyState = GameState.vs0NewGame(catalog: catalog)
        legacyState.economy.balance = 4_321
        let rawLegacyData = try v9Data(from: legacyState)

        for owner in owners.reversed() {
            try rawLegacyData.write(
                to: directory.appendingPathComponent("\(owner).json"),
                options: .atomic
            )
        }

        let first = try coordinator.bestContinueGeneration()
        XCTAssertEqual(first.generation.metadata.ownerManualSlot, owners[1])
        XCTAssertEqual(first.generation.metadata.generationKind, .manual)
        XCTAssertEqual(first.generation.metadata.saveSequence, 2)
        XCTAssertEqual(first.generation.state.economy.balance, 4_321)

        for (index, owner) in owners.enumerated() {
            let store = SaveStore(
                directory: directory,
                slotName: owner,
                catalog: catalog,
                expectation: SaveGenerationExpectation(
                    ownerManualSlot: owner,
                    generationKinds: [.manual, .legacy]
                )
            )
            let materialized = try store.loadGeneration()
            XCTAssertEqual(materialized.metadata.generationKind, .manual)
            XCTAssertEqual(materialized.metadata.ownerManualSlot, owner)
            XCTAssertEqual(materialized.metadata.saveSequence, index + 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.backupURL.path))
            let migratedBackup = try SaveCodec.decodeGeneration(
                Data(contentsOf: store.backupURL),
                catalog: catalog,
                context: SaveMigrationContext(sourceSlotName: owner)
            )
            XCTAssertEqual(migratedBackup.metadata.generationKind, .legacy)
            XCTAssertEqual(migratedBackup.metadata.saveSequence, 0)
        }

        let second = try coordinator.bestContinueGeneration()
        XCTAssertEqual(second.generation, first.generation)
    }

    func testCampaignGenerationsStayIsolatedAndContinueUsesGlobalSaveSequence() throws {
        let coordinator = CampaignSaveCoordinator(rootDirectory: directory, catalog: catalog)
        let first = try coordinator.createNewCampaign(manualSlotIndex: 0)
        let second = try coordinator.createNewCampaign(manualSlotIndex: 1)
        XCTAssertNotEqual(first.state.campaignID, second.state.campaignID)

        var best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.state.campaignID, second.state.campaignID)
        XCTAssertEqual(best.generation.metadata.generationKind, .manual)

        _ = try coordinator.save(
            first.state,
            kind: .campaignAuto,
            ownerManualSlot: SaveSlotCatalog.manualSlotNames[0]
        )
        best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.state.campaignID, first.state.campaignID)
        XCTAssertEqual(best.generation.metadata.generationKind, .campaignAuto)

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("\(SaveSlotCatalog.manualSlotNames[1]).json").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: coordinator.campaignDirectory(first.state.campaignID)
                .appendingPathComponent("campaign_auto.json").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: coordinator.campaignDirectory(second.state.campaignID)
                .appendingPathComponent("campaign_auto.json").path
        ))
    }

    func testActiveMissionContinueWinsAndMissingProtectionOnlyDisablesRollback() throws {
        let coordinator = CampaignSaveCoordinator(rootDirectory: directory, catalog: catalog)
        let manual = try coordinator.createNewCampaign(manualSlotIndex: 0)
        let source = legalStoryFixture(
            campaignID: manual.state.campaignID,
            q08Phase: .eruption
        )
        let snapshot = missionSnapshot(campaignID: manual.state.campaignID)
        let prepared = try coordinator.prepareMission(
            source: source,
            snapshot: snapshot,
            ownerManualSlot: SaveSlotCatalog.manualSlotNames[0]
        )

        var best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.metadata.generationKind, .missionCurrent)
        XCTAssertEqual(best.generation.state.storyCampaign.mission, prepared.state.storyCampaign.mission)
        let protection = try coordinator.loadProtection(
            campaignID: manual.state.campaignID,
            kind: .preMistRidge
        )
        XCTAssertNil(protection.state.storyCampaign.mission)

        let protectionURL = coordinator.campaignDirectory(manual.state.campaignID)
            .appendingPathComponent("pre_mist_ridge.json")
        try FileManager.default.removeItem(at: protectionURL)
        best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.metadata.generationKind, .missionCurrent)
        XCTAssertEqual(best.generation.state.storyCampaign.mission?.canAbandonToProtection, false)
        XCTAssertTrue(best.diagnostics.contains { $0.contains("缺少 pre_mist_ridge") })
    }

    func testPreRevealProtectionNeverBecomesAutomaticContinueCandidate() throws {
        let coordinator = CampaignSaveCoordinator(rootDirectory: directory, catalog: catalog)
        let manual = try coordinator.createNewCampaign(manualSlotIndex: 0)
        XCTAssertThrowsError(
            try coordinator.preparePreReveal(
                source: manual.state,
                ownerManualSlot: SaveSlotCatalog.manualSlotNames[0]
            )
        ) { error in
            XCTAssertEqual(error as? CampaignSaveError, .finaleNotReady)
        }

        var source = legalStoryFixture(
            campaignID: manual.state.campaignID,
            q08Phase: .resolved
        )
        source.storyCampaign.mission = missionSnapshot(
            campaignID: manual.state.campaignID,
            status: .completed,
            checkpoint: .homecoming
        )
        source.storyCampaign.protection.preMistRidgeVerified = true
        let prepared = try coordinator.preparePreReveal(
            source: source,
            ownerManualSlot: SaveSlotCatalog.manualSlotNames[0]
        )

        XCTAssertEqual(prepared.metadata.generationKind, .campaignAuto)
        XCTAssertEqual(prepared.state.storyCampaign.finaleBeat, .preRevealSavePending)
        XCTAssertTrue(prepared.state.storyCampaign.protection.preRevealVerified)

        let best = try coordinator.bestContinueGeneration()
        XCTAssertEqual(best.generation.metadata.generationKind, .campaignAuto)
        XCTAssertNotEqual(best.generation.metadata.generationKind, .preReveal)

        let protection = try coordinator.loadProtection(
            campaignID: manual.state.campaignID,
            kind: .preReveal
        )
        XCTAssertEqual(protection.metadata.generationKind, .preReveal)
        XCTAssertEqual(protection.state.storyCampaign.finaleBeat, .locked)
        XCTAssertFalse(protection.state.storyCampaign.protection.preRevealVerified)
    }

    func testSaveValidationRejectsContradictoryGraduation() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.storyCampaign.finaleBeat = .graduated

        XCTAssertThrowsError(try SaveValidation.validateN027(state)) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents)
        }
    }

    func testSaveValidationRejectsQ08LockedCompletedMissionAndCompletedMissionThatCanAbandon() {
        var locked = GameState.vs0NewGame(catalog: catalog)
        XCTAssertNoThrow(try SaveValidation.validateN027(locked))
        locked.storyCampaign.mission = missionSnapshot(
            campaignID: locked.campaignID,
            status: .completed,
            checkpoint: .homecoming
        )
        XCTAssertThrowsError(try SaveValidation.validateN027(locked)) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents)
        }

        var completed = legalStoryFixture(
            campaignID: "brookseed.campaign.n027_validation_completed",
            q08Phase: .resolved
        )
        completed.storyCampaign.mission = missionSnapshot(
            campaignID: completed.campaignID,
            status: .completed,
            checkpoint: .homecoming
        )
        XCTAssertNoThrow(try SaveValidation.validateN027(completed))

        completed.storyCampaign.mission?.canAbandonToProtection = true
        XCTAssertThrowsError(try SaveValidation.validateN027(completed)) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents)
        }
    }

    func testSaveValidationRejectsPausedM3OffersWithActiveEventAfterQ01WarningOne() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        XCTAssertFalse(state.community.activeEvents.isEmpty)

        var q01 = StorySegmentState.locked(.q01)
        q01.benefitOfferID = "brookseed.story.offer.q01.validation_fixture"
        q01.benefitBaselineDay = 1
        q01.benefitBaseline = .zero
        q01.enter(.benefit, day: 1)
        q01.enter(.warningOne, day: 2)
        q01.warningOneEvidenceSerial = 0
        q01.warningOneEvidenceCheckSerial = 0
        q01.warningOneSleepEpoch = 1
        state.storyCampaign.updateSegment(q01)
        state.storyCampaign.m3OffersPaused = true
        state.storyCampaign.canonicalize()

        var withoutActiveEvent = state
        withoutActiveEvent.community.activeEvents = []
        XCTAssertNoThrow(try SaveValidation.validateN027(withoutActiveEvent))
        XCTAssertThrowsError(try SaveValidation.validateN027(state)) { error in
            XCTAssertEqual(error as? SaveStoreError, .invalidContents)
        }
    }

    private func legalStoryFixture(
        campaignID: String,
        q08Phase: StoryPhase
    ) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog, campaignID: campaignID)
        state.clock = GameClock(day: 50, minute: GameClock.dayStartMinute)
        let arcIDs: [StoryArcID] = [.q01, .q02, .q03, .q04, .q05, .q06, .q07, .q08]

        for arcID in arcIDs {
            let terminalPhase: StoryPhase = arcID == .q08 ? q08Phase : .resolved
            let benefitDay = ((arcID.sequence - 1) * 6) + 1
            let requiresFullWarningDays = arcID == .q02 || arcID == .q07
            let eruptionDay = benefitDay + (requiresFullWarningDays ? 3 : 2)
            let aftermathDay = eruptionDay + 1
            let resolvedDay = aftermathDay + 2
            var segment = StorySegmentState.locked(arcID)
            segment.benefitOfferID = "brookseed.story.offer.\(arcID.shortCode).n027_fixture"
            segment.benefitBaselineDay = benefitDay
            segment.benefitBaseline = .zero
            segment.enter(.benefit, day: benefitDay)

            if terminalPhase.order >= StoryPhase.warningOne.order {
                segment.enter(.warningOne, day: benefitDay + 1)
                segment.warningOneEvidenceSerial = 0
                segment.warningOneEvidenceCheckSerial = 0
                segment.warningOneSleepEpoch = benefitDay + 1
            }
            if terminalPhase.order >= StoryPhase.warningTwo.order {
                segment.enter(.warningTwo, day: benefitDay + 2)
                segment.warningTwoEvidenceSerial = 1
                segment.warningTwoSleepEpoch = benefitDay + 2
            }
            if terminalPhase.order >= StoryPhase.eruption.order {
                segment.enter(.eruption, day: eruptionDay)
                state.storyMetrics.relatedActionSerials[arcID.rawValue] = 2
                if arcID == .q08 {
                    state.storyMetrics.evidenceCheckSerials[arcID.rawValue] = 1
                }
            }
            if terminalPhase.order >= StoryPhase.aftermath.order {
                segment.enter(.aftermath, day: aftermathDay)
                let eruptionChoice: StoryChoiceID = arcID == .q06
                    ? .talk
                    : StoryChoiceID.choices(for: arcID)[0]
                let eruptionSlot = eruptionChoice.slot(in: arcID)
                let eruptionStableID = eruptionChoice.stableID(in: arcID)
                segment.selectedChoiceIDsBySlot[eruptionSlot.rawValue] = eruptionStableID
                state.storyCampaign.choices.append(
                    StoryChoiceRecord(
                        arcID: arcID,
                        slotID: eruptionSlot,
                        choiceID: eruptionStableID,
                        day: eruptionDay
                    )
                )
                if arcID == .q06 {
                    let aftermathChoice = StoryChoiceID.friend
                    let aftermathSlot = aftermathChoice.slot(in: arcID)
                    let aftermathStableID = aftermathChoice.stableID(in: arcID)
                    segment.selectedChoiceIDsBySlot[aftermathSlot.rawValue] = aftermathStableID
                    state.storyCampaign.choices.append(
                        StoryChoiceRecord(
                            arcID: arcID,
                            slotID: aftermathSlot,
                            choiceID: aftermathStableID,
                            day: aftermathDay
                        )
                    )
                    state.storyCampaign.q06Outcome = .friend
                }
            }
            if terminalPhase == .resolved {
                segment.aftermathQuality = .responsible
                segment.enter(.resolved, day: resolvedDay)
                if arcID.sequence <= StoryArcID.q07.sequence {
                    let receiptID = "brookseed.story.receipt.\(arcID.shortCode).standing"
                    segment.standingAwardReceiptID = receiptID
                    segment.effectReceiptIDs = [receiptID]
                    state.storyCampaign.effectReceipts.append(
                        StoryReceiptRecord(
                            receiptID: receiptID,
                            sourceID: arcID.rawValue,
                            day: resolvedDay
                        )
                    )
                    state.community.standing = min(
                        100,
                        state.community.standing + StoryDirector.standingAward
                    )
                }
            }
            state.storyCampaign.updateSegment(segment)
        }

        state.storyCampaign.q08Completed = q08Phase == .resolved
        state.storyCampaign.m3OffersPaused = true
        state.storyCampaign.frontstageLease = nil
        state.storyCampaign.canonicalize()
        state.storyMetrics.canonicalize()
        return state
    }

    private func v9Data(from state: GameState) throws -> Data {
        let encoded = try SaveCodec.encode(state)
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        payload["schema_version"] = 9
        payload.removeValue(forKey: "campaign_id")
        payload.removeValue(forKey: "generation_metadata")
        payload.removeValue(forKey: "story_campaign")
        payload.removeValue(forKey: "story_metrics")
        if var records = payload["farmCells"] as? [[String: Any]] {
            for index in records.indices {
                records[index].removeValue(forKey: "dryStreak")
                records[index].removeValue(forKey: "cropCondition")
            }
            payload["farmCells"] = records
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    private func missionSnapshot(
        campaignID: String,
        status: StoryMissionStatus = .travelling,
        checkpoint: StoryJourneyCheckpoint = .departure
    ) -> StoryMissionSnapshot {
        StoryMissionSnapshot(
            campaignID: campaignID,
            missionInstanceID: "brookseed.story.mission.n027_test",
            startDay: 1,
            status: status,
            coveredCropCellIDs: [],
            protectedAnimalIDs: [],
            frozenOrderIDs: [],
            frozenDeadlineIDs: [],
            frozenOfferIDs: [],
            shippingEntries: [],
            checkpoint: checkpoint,
            settlementReceiptID: "brookseed.story.receipt.q08_test",
            canAbandonToProtection: status != .completed
        )
    }
}
