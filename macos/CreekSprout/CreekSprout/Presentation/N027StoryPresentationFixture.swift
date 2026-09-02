//
//  N027StoryPresentationFixture.swift
//  CreekSprout
//
//  DEBUG-only accelerated fixtures and launch options for the isolated
//  real-app smoke driver. Everything here is compiled out of Release builds:
//  Release binaries never contain these argument keys or fixture paths.
//  Fixtures only call real domain services or install a legal complete state
//  snapshot; they never replace gameplay reachability.
//

#if DEBUG

import Foundation

/// Launch options used by `scripts/drive-n027-story-app.py`. The evidence root
/// redirects saves, campaign companions and settings into an isolated
/// directory so production Application Support is never touched.
enum N027SmokeLaunchOptions {
    static let evidenceRootKey = "--n027-evidence-root"
    static let uiScaleKey = "--n027-ui-scale"
    static let textSpeedKey = "--n027-text-speed"
    static let fixtureKey = "--n027-smoke-fixture"

    /// Isolated root for the smoke driver; `nil` in normal launches.
    static var evidenceRoot: URL? {
        guard let value = argumentValue(after: evidenceRootKey) else { return nil }
        return URL(fileURLWithPath: value)
    }

    static var uiScale: Int? {
        argumentValue(after: uiScaleKey).flatMap(Int.init)
    }

    static var textSpeed: TextSpeed? {
        guard let raw = argumentValue(after: textSpeedKey) else { return nil }
        return TextSpeed(rawValue: raw)
    }

    static var smokeFixture: N027StorySmokeFixture? {
        argumentValue(after: fixtureKey).flatMap(N027StorySmokeFixture.init(rawValue:))
    }

    private static func argumentValue(after key: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: key),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// Fixture kinds the smoke driver can request. Each one installs a legal
/// complete state through real domain services (or a presentation-only
/// unlocked-gallery snapshot, which is never saved).
enum N027StorySmokeFixture: String {
    case q01WarningOne = "q01_warning_one"
    case journey = "journey"
    case gallery = "gallery"
}

/// DEBUG-only accelerated story fixtures.
enum N027StoryPresentationFixture {
    /// Unwraps a domain Result; a failing fixture is a DEBUG-time bug.
    private static func must<T, E: Error>(_ result: Result<T, E>) -> T {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            fatalError("N027 story fixture failure: \(error)")
        }
    }

    /// Q01 `warning_1` armed through the real domain chain:
    /// new game → tutorial complete → canal quest completed →
    /// `unlockEligibleBenefit` → mature metrics → `requestWarningOne`.
    /// The returned state is SaveValidation-legal (asserted below) and reuses
    /// the live campaign ID so campaignAuto saves pass the coordinator guard.
    static func q01WarningOneArmed(campaignID: String = "brookseed.campaign.fixture_q01_warning") -> GameState {
        var state = GameState.vs0NewGame(
            catalog: .vs0,
            campaignID: campaignID
        )

        // Tutorial fully complete (matches what TutorialService produces).
        state.tutorial.completedStepIDs = ContentID.tutorialStepIDs
        state.tutorial.currentStepID = ContentID.tutorialNextDay
        state.tutorial.harvestCount = 3
        state.tutorial.talkedToWaterApprentice = true
        state.tutorial.didManualSave = true

        // Canal quest completed (Q01 benefit prerequisite).
        var quest = state
        quest = must(QuestService.accept(
            state: quest,
            questID: ContentID.restoreOldCanalQuest,
            catalog: .vs0
        ))
        quest = must(QuestService.markCanalPlaced(state: quest, catalog: .vs0))
        quest = must(QuestService.complete(
            state: quest,
            questID: ContentID.restoreOldCanalQuest,
            catalog: .vs0
        ))
        state = quest

        // Enter benefit; the baseline is captured by the domain service here.
        state = must(StoryDirector.unlockEligibleBenefit(state: state, arcID: .q01))
        let baselineGrowing = state.storyCampaign.segment(.q01)?.benefitBaseline?
            .growingCropCount ?? 0

        // Six-plus new growing cells beyond the baseline (causal expansion).
        let freshPositions: [GridPosition] = [
            GridPosition(x: 1, y: 0), GridPosition(x: 2, y: 0),
            GridPosition(x: 3, y: 0), GridPosition(x: 1, y: 1),
            GridPosition(x: 2, y: 1), GridPosition(x: 3, y: 1),
            GridPosition(x: 1, y: 2), GridPosition(x: 2, y: 2),
        ]
        for position in freshPositions {
            state.farmCells[position] = FarmCell(
                prepared: true,
                wateredToday: true,
                cropID: ContentID.mistRadishCrop,
                cropStage: 1,
                stageProgressDays: 1,
                plantedDay: 12
            )
        }

        // Maturity metrics consistent with the actual state.
        state.clock = GameClock(day: 12, minute: GameClock.dayStartMinute)
        let planted = state.farmCells.values.filter(\.hasCrop).count
        state.storyMetrics.plantedCellsByCropID = [ContentID.mistRadishCrop: planted]
        state.storyMetrics.plantedCellCount = planted
        state.storyMetrics.harvestsByCropID = [ContentID.mistRadishCrop: 2]
        state.storyMetrics.completedCyclesByCropID = [ContentID.mistRadishCrop: 2]
        state.storyMetrics.harvestedCropCount = 2
        state.storyMetrics.manualWaterCellDays = 30
        state.storyMetrics.temporaryCanalBenefitDays = [8, 9, 10, 11]
        let growing = state.farmCells.values.filter(\.isGrowingCrop).count
        state.storyMetrics.maxGrowingCropCount = max(
            baselineGrowing,
            growing
        )
        state.storyMetrics.canonicalize()
        state.storyCampaign.canonicalize()

        // Arm warning_1 through the real director.
        state = must(StoryDirector.requestWarningOne(
            state: state,
            arcID: .q01,
            sleepEpoch: 0
        ))

        // The snapshot must be save-legal; assert in DEBUG so a fixture
        // regression is caught at install time, not at first save.
        do {
            try SaveValidation.validate(state, catalog: .vs0)
        } catch {
            assertionFailure("N027 Q01 fixture failed SaveValidation: \(error)")
        }
        return state
    }

    /// Presentation-only unlocked gallery snapshot. It renders the full
    /// gallery layout but is intentionally never saved (the real graduation
    /// chain persists the legal state through `FinaleService.graduate`).
    static func galleryUnlockedPresentation() -> GameState {
        var state = GameState.vs0NewGame(
            catalog: .vs0,
            campaignID: "brookseed.campaign.fixture_gallery_preview"
        )
        state.storyCampaign.gallery.isUnlocked = true
        state.storyCampaign.gallery.endingID = "brookseed.story.ending.water"
        state.storyCampaign.gallery.keepsakeIDs = [
            "brookseed.gallery.keepsake.hero_plaque",
            "brookseed.gallery.keepsake.group_photo",
        ]
        state.storyCampaign.gallery.discoveredLedgerPageIDs = [
            "brookseed.gallery.ledger.page_01",
            "brookseed.gallery.ledger.page_07",
        ]
        state.storyCampaign.gallery.discoveredAnnotationIDs = [
            "brookseed.gallery.annotation.record_03",
            "brookseed.gallery.annotation.record_11",
        ]
        state.storyCampaign.canonicalize()
        return state
    }
}

#endif
