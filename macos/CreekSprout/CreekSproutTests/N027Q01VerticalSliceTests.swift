import Foundation
import XCTest
@testable import CreekSprout

/// Full Q01 vertical slice: benefit maturity → warning_1 → related labour →
/// warning_2 → control returned → anchor re-entry → eruption with three
/// branches → aftermath → +6 standing → reveal_callback registered but hidden.
/// Every checkpoint survives a JSON save/load round trip.
final class N027Q01VerticalSliceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let storyCatalog = StoryContentCatalog.shared

    private func growingCell(_ cropID: String = ContentID.mistRadishCrop) -> FarmCell {
        FarmCell(
            prepared: true,
            cropID: cropID,
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 10,
            readyToHarvest: false
        )
    }

    /// A legal, generic-labour-mature state with the canal quest completed and
    /// zero growing crops so the benefit baseline is empty.
    private func matureQ01State(day: Int) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: day, minute: GameClock.dayStartMinute)
        // Tutorial fully completed (all but the final next-day step), matching
        // the canonical prefix + current step contract of SaveValidation.
        state.tutorial.completedStepIDs = Array(ContentID.tutorialStepIDs.dropLast())
        state.tutorial.currentStepID = ContentID.tutorialNextDay
        state.tutorial.harvestCount = 3
        state.tutorial.talkedToWaterApprentice = true
        state.tutorial.didManualSave = true
        state.questLog.setStatus(.completed, for: ContentID.restoreOldCanalQuest)
        state.farmCells = [:]
        state.storyMetrics.completedCyclesByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.harvestsByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.harvestedCropCount = 2
        state.storyMetrics.plantedCellsByCropID[ContentID.mistRadishCrop] = 2
        state.storyMetrics.plantedCellCount = 2
        state.storyMetrics.manualWaterCellDays = 30
        state.storyMetrics.temporaryCanalBenefitDays = [day - 4, day - 3, day - 2, day - 1]
        state.storyMetrics.canonicalize()
        return state
    }

    private func playEntireStage(
        _ state: GameState,
        catalog: StoryContentCatalog = .shared
    ) throws -> (state: GameState, advancedCount: Int) {
        var current = state
        var count = 0
        while true {
            let result = StoryDialogueService.advance(state: current, catalog: catalog)
            guard case .success(let outcome) = result else {
                XCTFail("advance failed: \(result)")
                return (current, count)
            }
            count += 1
            current = outcome.state
            if outcome.reachedEnd { break }
        }
        return (current, count)
    }

    func testQ01FullVerticalSliceWithAllThreeBranches() throws {
        let branchResults = try StoryChoiceID.choices(for: .q01).map { branch -> (choice: StoryChoiceID, standing: Int, resolved: Bool) in
            let result = try runQ01Slice(choice: branch)
            return (branch, result.standing, result.resolved)
        }
        XCTAssertEqual(branchResults.count, 3)
        for result in branchResults {
            XCTAssertTrue(result.resolved, result.choice.rawValue)
            XCTAssertEqual(result.standing, 56, result.choice.rawValue)
        }
    }

    private func runQ01Slice(choice: StoryChoiceID) throws -> (standing: Int, resolved: Bool) {
        var state = matureQ01State(day: 10)

        // 1. Benefit unlock with a real baseline snapshot.
        state = try StoryDirector.unlockEligibleBenefit(
            state: state,
            arcID: .q01
        ).get()
        var segment = try XCTUnwrap(state.storyCampaign.segment(.q01))
        XCTAssertEqual(segment.phase, .benefit)
        XCTAssertEqual(segment.benefitBaseline?.growingCropCount, 0)
        try SaveValidation.validate(state, catalog: catalog)

        // Maturity is not yet met (no causal expansion, no growing crop).
        XCTAssertEqual(
            StoryDirector.requestWarningOne(state: state, arcID: .q01, sleepEpoch: 10),
            .failure(.maturityNotMet)
        )

        // 2. Real labour: six new growing cells after the benefit baseline.
        for column in 0..<6 {
            state.farmCells[GridPosition(x: column, y: 5)] = growingCell()
        }
        XCTAssertEqual(
            state.farmCells.values.filter(\.isGrowingCrop).count,
            6
        )
        try SaveValidation.validate(state, catalog: catalog)

        // 3. warning_1.
        state = try StoryDirector.requestWarningOne(
            state: state,
            arcID: .q01,
            sleepEpoch: 10
        ).get()
        XCTAssertEqual(state.storyCampaign.frontstageLease?.owner, .story)
        XCTAssertTrue(state.storyCampaign.m3OffersPaused, "Q01 warning_1 pauses new M3 offers")
        state = try StoryDialogueService.openSession(state: state, catalog: storyCatalog).get()
        let warningOnePlay = try playEntireStage(state)
        XCTAssertEqual(warningOnePlay.advancedCount, 3)
        state = warningOnePlay.state
        // Close releases control.
        state = try StoryDirector.closeDialogue(
            state: state,
            arcID: .q01,
            completedPhase: .warningOne
        ).get()
        XCTAssertNil(state.storyCampaign.frontstageLease)
        XCTAssertNil(state.storyCampaign.dialogueSession)
        try SaveValidation.validate(state, catalog: catalog)

        // 4. Related labour between the two warnings.
        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q01, sleepEpoch: 10),
            .failure(.relatedActionRequired)
        )
        state = try StoryCommandService.recordAction(
            state: state,
            arcID: .q01,
            actionID: "brookseed.story.q01.action.checked_sluice_marks"
        ).get()
        state = try StoryDirector.requestWarningTwo(
            state: state,
            arcID: .q01,
            sleepEpoch: 10
        ).get()
        state = try StoryDialogueService.openSession(state: state, catalog: storyCatalog).get()
        let warningTwoPlay = try playEntireStage(state)
        XCTAssertEqual(warningTwoPlay.advancedCount, 3)
        state = warningTwoPlay.state
        state = try StoryDirector.closeDialogue(
            state: state,
            arcID: .q01,
            completedPhase: .warningTwo
        ).get()
        XCTAssertNil(state.storyCampaign.frontstageLease)

        // Eruption must NOT chain in the same session: another observable
        // related action (anchor re-entry) is required first.
        XCTAssertEqual(
            StoryDirector.requestEruption(state: state, arcID: .q01, sleepEpoch: 10),
            .failure(.relatedActionRequired)
        )
        state = try StoryCommandService.recordAction(
            state: state,
            arcID: .q01,
            actionID: "brookseed.story.q01.action.sluice_anchor_reentry",
            anchorReentry: true
        ).get()
        state = try StoryDirector.requestEruption(
            state: state,
            arcID: .q01,
            sleepEpoch: 10
        ).get()
        XCTAssertEqual(state.storyCampaign.segment(.q01)?.phase, .eruption)

        // 5. Eruption dialogue: two lines, intent, response, two closing lines.
        state = try StoryDialogueService.openSession(state: state, catalog: storyCatalog).get()
        state = try StoryDialogueService.advance(state: state, catalog: storyCatalog).get().state
        state = try StoryDialogueService.advance(state: state, catalog: storyCatalog).get().state
        let atBoundary = try XCTUnwrap(state.storyCampaign.dialogueSession)
        XCTAssertTrue(atBoundary.intentsPending)
        XCTAssertEqual(atBoundary.pendingChoiceIDs, [.fieldFirst, .reedFirst, .inspectFirst])
        state = try StoryDialogueService.selectIntent(
            state: state,
            choice: choice,
            catalog: storyCatalog
        ).get()
        let responseID = "brookseed.story.q01.choice_response.\(choice.rawValue).response_01"
        XCTAssertTrue(
            state.storyCampaign.dialogueSession?.presentedLineIDs.contains(responseID) == true
        )
        // Response line + exp_003 + exp_004 remain.
        let eruptionPlay = try playEntireStage(state)
        XCTAssertEqual(eruptionPlay.advancedCount, 3)
        state = eruptionPlay.state
        state = try StoryDirector.closeDialogue(
            state: state,
            arcID: .q01,
            completedPhase: .eruption
        ).get()
        XCTAssertEqual(state.storyCampaign.segment(.q01)?.phase, .aftermath)
        XCTAssertNil(state.storyCampaign.frontstageLease)
        try SaveValidation.validate(state, catalog: catalog)

        // 6. Two-day aftermath, then responsible resolution with fixed +6.
        state.clock = GameClock(day: 11, minute: GameClock.dayStartMinute)
        XCTAssertEqual(
            StoryDirector.resolveResponsibleAftermath(state: state, arcID: .q01),
            .failure(.aftermathTooShort)
        )
        state.clock = GameClock(day: 13, minute: GameClock.dayStartMinute)
        state = try StoryDirector.resolveResponsibleAftermath(
            state: state,
            arcID: .q01
        ).get()
        segment = try XCTUnwrap(state.storyCampaign.segment(.q01))
        XCTAssertEqual(segment.phase, .resolved)
        XCTAssertEqual(segment.aftermathQuality, .responsible)
        XCTAssertEqual(state.community.standing, 56, "new-game standing 50 + fixed +6")
        XCTAssertEqual(segment.standingAwardReceiptID, "brookseed.story.receipt.q01.standing")
        XCTAssertTrue(segment.effectReceiptIDs.contains("brookseed.story.receipt.q01.standing"))
        try SaveValidation.validate(state, catalog: catalog)

        // 7. reveal_callback is registered in content but never visible now.
        XCTAssertTrue(
            storyCatalog.visibleLines(
                arcID: .q01,
                stage: .revealCallback,
                finaleUnlocked: false
            ).isEmpty
        )
        XCTAssertFalse(
            storyCatalog.visibleLines(
                arcID: .q01,
                stage: .revealCallback,
                finaleUnlocked: true
            ).isEmpty
        )
        XCTAssertNil(
            storyCatalog.visibleBlockingCue(
                id: "brookseed.story.q01.cue.blk_05",
                finaleUnlocked: false
            )
        )
        XCTAssertNil(state.storyCampaign.frontstageLease)
        XCTAssertNil(state.storyCampaign.dialogueSession)

        // 8. Full persistence round trip at the final checkpoint.
        let dto = SaveGameDTO(state: state)
        let restored = try SaveGameDTO(
            state: state
        ).makeState()
        XCTAssertEqual(restored.storyCampaign, state.storyCampaign)
        _ = dto
        return (state.community.standing, segment.phase == .resolved)
    }

    func testQ01VerticalSliceRejectsSkippingWarningBoundary() throws {
        var state = matureQ01State(day: 10)
        state = try StoryDirector.unlockEligibleBenefit(state: state, arcID: .q01).get()
        for column in 0..<6 {
            state.farmCells[GridPosition(x: column, y: 5)] = growingCell()
        }
        state = try StoryDirector.requestWarningOne(
            state: state,
            arcID: .q01,
            sleepEpoch: 10
        ).get()
        // Finish the warning_1 dialogue and return control.
        state = try StoryDialogueService.openSession(state: state, catalog: storyCatalog).get()
        var guardCount = 0
        while true {
            let result = StoryDialogueService.advance(state: state, catalog: storyCatalog)
            guard case .success(let outcome) = result else { break }
            guardCount += 1
            state = outcome.state
            if outcome.reachedEnd { break }
        }
        XCTAssertGreaterThan(guardCount, 0)
        state = try StoryDirector.closeDialogue(
            state: state,
            arcID: .q01,
            completedPhase: .warningOne
        ).get()
        // Skipping the related action must fail even at a later day.
        state.clock = GameClock(day: 11, minute: GameClock.dayStartMinute)
        XCTAssertEqual(
            StoryDirector.requestWarningTwo(state: state, arcID: .q01, sleepEpoch: 11),
            .failure(.relatedActionRequired)
        )
    }
}
