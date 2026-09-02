import Foundation
import XCTest
@testable import CreekSprout

final class N027StoryDialogueTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let storyCatalog = StoryContentCatalog.shared

    // MARK: - Fixtures

    private func warningFixture(
        arcID: StoryArcID,
        phase: StoryPhase,
        day: Int = 4
    ) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: day, minute: GameClock.dayStartMinute)
        var segment = StorySegmentState.locked(arcID)
        segment.enter(.benefit, day: 2)
        segment.benefitOfferID = "brookseed.story.offer.\(arcID.shortCode).dialogue_fixture"
        segment.benefitBaselineDay = 2
        segment.benefitBaseline = .zero
        segment.warningOneEvidenceSerial = 0
        segment.warningOneEvidenceCheckSerial = 0
        segment.warningOneSleepEpoch = 1
        if phase.order >= StoryPhase.warningOne.order {
            segment.enter(.warningOne, day: 3)
            if arcID == .q01 {
                state.storyCampaign.m3OffersPaused = true
            }
        }
        if phase.order >= StoryPhase.warningTwo.order {
            segment.enter(.warningTwo, day: 4)
            segment.warningTwoEvidenceSerial = 1
            segment.warningTwoSleepEpoch = 1
        }
        state.storyCampaign.updateSegment(segment)
        return state
    }

    private func beginSession(
        _ fixture: GameState,
        arcID: StoryArcID,
        phase: StoryPhase,
        cueID: String
    ) throws -> GameState {
        let armed = try StoryCommandService.beginBlockingSession(
            state: fixture,
            arcID: arcID,
            phase: phase,
            cueID: cueID,
            catalog: storyCatalog
        ).get()
        return try StoryDialogueService.openSession(state: armed, catalog: storyCatalog).get()
    }

    private func q01EruptionFixture(day: Int = 5) -> GameState {
        var state = warningFixture(arcID: .q01, phase: .warningTwo, day: day)
        guard var segment = state.storyCampaign.segment(.q01) else { return state }
        segment.enter(.eruption, day: day)
        state.storyCampaign.updateSegment(segment)
        return state
    }

    // MARK: - Open / view / advance

    func testOpenSessionResolvesMultiSpeakerLinesAndBoundary() throws {
        let session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        let state = try XCTUnwrap(session.storyCampaign.dialogueSession)
        XCTAssertEqual(state.sessionID, "brookseed.story.session.q01.warning_1.day_4")
        XCTAssertEqual(state.arcID, .q01)
        XCTAssertEqual(state.stageKind, .warningOne)
        XCTAssertEqual(state.cueID, "brookseed.story.q01.cue.blk_02")
        XCTAssertEqual(state.lineIndex, 0)
        XCTAssertTrue(state.presentedLineIDs.count >= 3)
        XCTAssertNil(state.choiceBoundaryLineIndex)
        XCTAssertTrue(state.pendingChoiceIDs.isEmpty)
        XCTAssertNil(state.selectedChoiceID)
        XCTAssertFalse(state.isClosed)

        let view = try StoryDialogueService.view(
            state: session,
            settings: .defaults,
            catalog: storyCatalog
        )
        XCTAssertEqual(view.arcID, .q01)
        XCTAssertFalse(view.pageLines.isEmpty)
        XCTAssertLessThanOrEqual(view.pageLines.count, 3)
        let speakers = view.pageLines.map(\.speakerID)
        XCTAssertEqual(Set(speakers).count, 1, "One page must be a single speaker turn")
        XCTAssertEqual(view.pageLines.first?.speakerID, StoryActorID.neighborEvidence)
        XCTAssertTrue(view.pendingIntents.isEmpty)
        XCTAssertEqual(view.pacingMultiplier, 1.0)
        XCTAssertTrue(view.accessibilitySummary.contains("剧情 q01 warning_1"))
    }

    func testAdvancePersistsLineCheckpointAndIsResumableAcrossSaveRoundTrip() throws {
        let session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        let firstID = try XCTUnwrap(
            session.storyCampaign.dialogueSession?.presentedLineIDs[0]
        )
        let advanced = try StoryDialogueService.advance(
            state: session,
            catalog: storyCatalog
        ).get().state
        XCTAssertEqual(advanced.storyCampaign.dialogueSession?.lineIndex, 1)
        XCTAssertEqual(advanced.storyCampaign.cursor.lineID, firstID)
        XCTAssertEqual(advanced.storyCampaign.cursor.lineIndex, 0)
        XCTAssertEqual(
            StoryDialogueSnapshot(session: try XCTUnwrap(advanced.storyCampaign.dialogueSession), cursor: advanced.storyCampaign.cursor),
            StoryDialogueService.snapshot(state: advanced)
        )

        // Save / load round trip through the DTO layer.
        let dto = SaveGameDTO(state: advanced)
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(SaveGameDTO.self, from: data)
        let restored = try decoded.makeState()
        XCTAssertEqual(restored.storyCampaign, advanced.storyCampaign)
        XCTAssertEqual(restored.storyCampaign.dialogueSession?.lineIndex, 1)

        // Resuming continues from the checkpoint, not from the start.
        let resumed = try StoryDialogueService.advance(
            state: restored,
            catalog: storyCatalog
        ).get().state
        XCTAssertEqual(resumed.storyCampaign.dialogueSession?.lineIndex, 2)
    }

    func testSpeakerRotationGroupsConsecutiveSameSpeakerLinesIntoPages() throws {
        let session = try beginSession(
            warningFixture(arcID: .q02, phase: .warningOne),
            arcID: .q02,
            phase: .warningOne,
            cueID: "brookseed.story.q02.cue.blk_02"
        )
        let view = try StoryDialogueService.view(
            state: session,
            settings: .defaults,
            catalog: storyCatalog
        )
        XCTAssertFalse(view.pageLines.isEmpty)
        XCTAssertLessThanOrEqual(view.pageLines.count, 3)
        let allSpeakers = Set(view.pageLines.map(\.speakerID))
        XCTAssertEqual(allSpeakers.count, 1)
        XCTAssertGreaterThanOrEqual(view.pageCount, 1)
    }

    func testTextSpeedFourTiersReachDialoguePacing() throws {
        let session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        var settings = SettingsState.defaults
        for speed in TextSpeed.allCases {
            settings.textSpeed = speed
            let view = try StoryDialogueService.view(
                state: session,
                settings: settings,
                catalog: storyCatalog
            )
            XCTAssertEqual(view.pacingMultiplier, speed.pacingMultiplier)
            XCTAssertEqual(view.textSpeedDisplayName, speed.displayName)
        }
    }

    // MARK: - Intents

    func testSelectIntentInsertsInlineResponseAndContinuesRemainingLines() throws {
        var session = q01EruptionFixture()
        session = try beginSession(
            session,
            arcID: .q01,
            phase: .eruption,
            cueID: "brookseed.story.q01.cue.blk_03"
        )
        // exp_001, exp_002 play before the boundary.
        session = try StoryDialogueService.advance(state: session, catalog: storyCatalog).get().state
        session = try StoryDialogueService.advance(state: session, catalog: storyCatalog).get().state
        let before = try XCTUnwrap(session.storyCampaign.dialogueSession)
        XCTAssertTrue(before.intentsPending)
        XCTAssertTrue(before.isAtBoundary)
        XCTAssertEqual(before.pendingChoiceIDs, [.fieldFirst, .reedFirst, .inspectFirst])
        switch StoryDialogueService.advance(state: session, catalog: storyCatalog) {
        case .failure(let error):
            XCTAssertEqual(error, .intentRequired)
        case .success:
            XCTFail("advance at the intent boundary must be rejected")
        }

        session = try StoryDialogueService.selectIntent(
            state: session,
            choice: .reedFirst,
            catalog: storyCatalog
        ).get()
        let after = try XCTUnwrap(session.storyCampaign.dialogueSession)
        XCTAssertEqual(after.selectedChoiceID, "brookseed.story.q01.choice.reed_first")
        XCTAssertTrue(after.pendingChoiceIDs.isEmpty)
        XCTAssertTrue(
            after.presentedLineIDs.contains("brookseed.story.q01.choice_response.reed_first.response_01")
        )
        XCTAssertEqual(
            session.storyCampaign.segment(.q01)?.selectedChoiceIDsBySlot[StoryChoiceSlotID.primary.rawValue],
            "brookseed.story.q01.choice.reed_first"
        )

        // The response line is now current at the same checkpoint.
        let current = try XCTUnwrap(
            after.presentedLineIDs[safe: after.lineIndex]
        )
        XCTAssertEqual(current, "brookseed.story.q01.choice_response.reed_first.response_01")
        // Second intent selection is rejected (single choice point).
        XCTAssertEqual(
            StoryDialogueService.selectIntent(state: session, choice: .fieldFirst, catalog: storyCatalog),
            .failure(.intentAlreadySelected)
        )
    }

    func testCancelReleasesLeaseAndControlWithoutPhaseChange() throws {
        var session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        session = try StoryDialogueService.advance(state: session, catalog: storyCatalog).get().state
        let phase = session.storyCampaign.segment(.q01)?.phase
        let cancelled = try StoryDialogueService.cancelSession(state: session).get()
        XCTAssertNil(cancelled.storyCampaign.dialogueSession)
        XCTAssertNil(cancelled.storyCampaign.frontstageLease)
        XCTAssertEqual(cancelled.storyCampaign.cursor, .empty)
        XCTAssertEqual(cancelled.storyCampaign.segment(.q01)?.phase, phase)

        // Re-entering the anchor re-opens the beat from the start of the stage.
        let reopened = try StoryCommandService.beginBlockingSession(
            state: cancelled,
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02",
            catalog: storyCatalog
        ).get()
        let session2 = try StoryDialogueService.openSession(state: reopened, catalog: storyCatalog).get()
        XCTAssertEqual(session2.storyCampaign.dialogueSession?.lineIndex, 0)
        XCTAssertNotNil(session2.storyCampaign.frontstageLease)
    }

    func testWarningTwoSessionClosesAndEruptionRequiresSeparateAction() throws {
        var session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningTwo),
            arcID: .q01,
            phase: .warningTwo,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        let stage = try XCTUnwrap(storyCatalog.stage(arcID: .q01, kind: .warningTwo))
        var guardCount = 0
        for _ in stage.lines {
            guardCount += 1
            let result = StoryDialogueService.advance(state: session, catalog: storyCatalog)
            guard case .success = result else { break }
            session = try result.get().state
        }
        XCTAssertGreaterThan(guardCount, 0)
        // After the last line the session is complete; close releases control.
        let closed = try StoryDirector.closeDialogue(
            state: session,
            arcID: .q01,
            completedPhase: .warningTwo
        ).get()
        XCTAssertNil(closed.storyCampaign.frontstageLease)
        XCTAssertNil(closed.storyCampaign.dialogueSession)
        XCTAssertEqual(closed.storyCampaign.segment(.q01)?.phase, .warningTwo)
        // Eruption cannot chain in the same session: it needs a related action.
        XCTAssertEqual(
            StoryDirector.requestEruption(state: closed, arcID: .q01, sleepEpoch: 1),
            .failure(.relatedActionRequired)
        )
    }

    func testSessionValidationRejectsCorruptLineCheckpoints() throws {
        let session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        // Corrupt: lineIndex past the presented sequence.
        var corrupt = session
        corrupt.storyCampaign.dialogueSession?.lineIndex = 999
        XCTAssertThrowsError(try SaveValidation.validateN027(corrupt, catalog: catalog))

        // Corrupt: presented line not bound to the session cue.
        var mismatched = session
        mismatched.storyCampaign.dialogueSession?.presentedLineIDs = [
            "brookseed.story.q01.line.exp_001",
        ]
        XCTAssertThrowsError(try SaveValidation.validateN027(mismatched, catalog: catalog))

        // Legal session passes validation.
        XCTAssertNoThrow(try SaveValidation.validateN027(session, catalog: catalog))
    }

    // MARK: - Input routing

    func testInputRouterUsesRebindableActionsForDialogueContext() throws {
        // Default keyboard bindings.
        let defaults = DeviceBindings.defaults
        let interact = try XCTUnwrap(
            defaults.keyboardMouse[InputBindingDefinitions.actionInteract]?.first
        )
        XCTAssertEqual(interact, "Key:Space")

        // While lines play, interact/talk advance and ui_cancel cancels.
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionInteract,
                intentsPending: false,
                atBoundary: false,
                hasSelectedIntent: false,
                focusedIntentIndex: 0,
                intentCount: 0
            ),
            .advance
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionTalk,
                intentsPending: false,
                atBoundary: false,
                hasSelectedIntent: false,
                focusedIntentIndex: 0,
                intentCount: 0
            ),
            .advance
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUICancel,
                intentsPending: false,
                atBoundary: false,
                hasSelectedIntent: false,
                focusedIntentIndex: 0,
                intentCount: 0
            ),
            .cancel
        )

        // At the intent boundary: ui_up/ui_down focus, ui_accept selects.
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUIUp,
                intentsPending: true,
                atBoundary: true,
                hasSelectedIntent: false,
                focusedIntentIndex: 1,
                intentCount: 3
            ),
            .focusIntent(delta: -1)
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUIDown,
                intentsPending: true,
                atBoundary: true,
                hasSelectedIntent: false,
                focusedIntentIndex: 0,
                intentCount: 3
            ),
            .focusIntent(delta: 1)
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUIAccept,
                intentsPending: true,
                atBoundary: true,
                hasSelectedIntent: false,
                focusedIntentIndex: 2,
                intentCount: 3
            ),
            .selectIntent(index: 2)
        )
        // Rebinding interact to a new key still routes through the action ID.
        var rebound = defaults
        rebound.keyboardMouse[InputBindingDefinitions.actionInteract] = ["Key:X"]
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionInteract,
                intentsPending: false,
                atBoundary: false,
                hasSelectedIntent: false,
                focusedIntentIndex: nil,
                intentCount: 0
            ),
            .advance
        )
    }

    func testGamepadActionsRouteIntoDialogue() throws {
        let gamepad = DeviceBindings.defaults.gamepad
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionInteract,
                intentsPending: false,
                atBoundary: false,
                hasSelectedIntent: false,
                focusedIntentIndex: nil,
                intentCount: 0
            ),
            .advance
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUICancel,
                intentsPending: true,
                atBoundary: true,
                hasSelectedIntent: false,
                focusedIntentIndex: 0,
                intentCount: 2
            ),
            .cancel
        )
        XCTAssertEqual(
            StoryDialogueInputRouter.route(
                actionID: InputBindingDefinitions.actionUIAccept,
                intentsPending: true,
                atBoundary: true,
                hasSelectedIntent: false,
                focusedIntentIndex: 1,
                intentCount: 2
            ),
            .selectIntent(index: 1)
        )
        XCTAssertFalse(gamepad.isEmpty)
    }

    // MARK: - Interpolation

    func testDialogueViewInterpolatesWhitelistTokensAndRejectsUnknown() throws {
        var session = try beginSession(
            warningFixture(arcID: .q01, phase: .warningOne),
            arcID: .q01,
            phase: .warningOne,
            cueID: "brookseed.story.q01.cue.blk_02"
        )
        session.community.standing = 73
        // Build a catalog copy with an unknown token in the current line.
        var stories = storyCatalog.stories
        if let storyIndex = stories.firstIndex(where: { $0.id == .q01 }),
           let stageIndex = stories[storyIndex].stages.firstIndex(where: {
               $0.kind == .warningOne
           }),
           let lineIndex = stories[storyIndex].stages[stageIndex].lines.firstIndex(where: {
               $0.id == "brookseed.story.q01.line.w1_001"
           }) {
            stories[storyIndex].stages[stageIndex].lines[lineIndex].text =
                "声誉 {{reputation}} 未知 {{unknown_token}}"
        }
        let badCatalog = StoryContentCatalog(
            stories: stories,
            actors: storyCatalog.actors,
            blockingCues: storyCatalog.blockingCues,
            anchors: storyCatalog.anchors,
            journeyScenes: storyCatalog.journeyScenes
        )
        XCTAssertThrowsError(try StoryDialogueService.view(
            state: session,
            settings: .defaults,
            catalog: badCatalog
        )) { error in
            XCTAssertTrue(
                String(describing: error).contains("interpolation"),
                String(describing: error)
            )
        }
    }

    func testQ05ResolutionTokenUsesSavedBranch() throws {
        let text = try StoryDialogueInterpolator.interpolate(
            "{{reputation}} 与 {{q05_resolution}}",
            standing: 66,
            q05Resolution: .coop
        )
        XCTAssertEqual(text, "66 与 联合供货")
        XCTAssertEqual(
            try StoryDialogueInterpolator.interpolate(
                "{{q05_resolution}}",
                standing: 50,
                q05Resolution: .publicOrder
            ),
            "公开限量单"
        )
        XCTAssertEqual(
            try StoryDialogueInterpolator.interpolate(
                "{{q05_resolution}}",
                standing: 50,
                q05Resolution: .delay
            ),
            "暂缓签约"
        )
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
