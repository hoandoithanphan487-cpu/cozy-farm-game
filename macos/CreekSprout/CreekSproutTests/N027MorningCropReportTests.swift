import Foundation
import XCTest
@testable import CreekSprout

final class N027MorningCropReportTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testSnapshotUsesRealCellsAndExactPressureRules() {
        let mustA = GridPosition(x: 0, y: 5)
        let mustB = GridPosition(x: 4, y: 1)
        let suggestedHealthy = GridPosition(x: 1, y: 4)
        let suggestedThirsty = GridPosition(x: 5, y: 0)
        let manuallyWatered = GridPosition(x: 2, y: 2)
        let canalCovered = GridPosition(x: 3, y: 0)
        let communityCovered = GridPosition(x: 6, y: 1)
        let mature = GridPosition(x: 7, y: 0)
        let phantom = GridPosition(x: 9, y: 5)

        var state = baseState(day: 1)
        state.farmCells = [
            communityCovered: growingCell(dryStreak: 2),
            mustB: growingCell(dryStreak: 2),
            mature: matureCell(),
            suggestedThirsty: growingCell(dryStreak: 1),
            manuallyWatered: growingCell(dryStreak: 0, wateredToday: true),
            canalCovered: growingCell(dryStreak: 2),
            suggestedHealthy: growingCell(dryStreak: 0),
            mustA: growingCell(dryStreak: 2),
        ]
        let canal = CropCoverageSummary(
            day: 1,
            records: [
                CropCoverageRecord(position: phantom, source: .temporaryCanal),
                CropCoverageRecord(position: canalCovered, source: .temporaryCanal),
            ]
        )
        let community = CropCoverageSummary(
            day: 1,
            records: [CropCoverageRecord(position: communityCovered, source: .communityCare)]
        )
        let wrongDay = CropCoverageSummary(
            day: 2,
            records: [CropCoverageRecord(position: mustB, source: .formalCanal)]
        )

        let before = state
        let snapshot = MorningCropReportService.snapshot(
            state: state,
            catalog: catalog,
            plannedCoverage: [wrongDay, community, canal]
        )

        XCTAssertEqual(snapshot.day, 1)
        XCTAssertEqual(snapshot.weather, .clear)
        XCTAssertEqual(snapshot.requiredCells.map(\.position), [mustA, mustB])
        XCTAssertEqual(
            snapshot.recommendedCells.map(\.position),
            [suggestedHealthy, suggestedThirsty]
        )
        XCTAssertEqual(snapshot.matureCells.map(\.position), [mature])
        XCTAssertEqual(
            snapshot.coveredCells.map(\.position),
            [manuallyWatered, canalCovered, communityCovered]
        )
        XCTAssertEqual(
            snapshot.coveredCells.map(\.coverageSources),
            [[.manual], [.temporaryCanal], [.communityCare]]
        )
        XCTAssertEqual(snapshot.estimatedMinimumStamina, 4)
        XCTAssertEqual(snapshot.estimatedFullCareStamina, 8)
        XCTAssertFalse(snapshot.allDangerousCropsSafe)
        XCTAssertEqual(snapshot.safetyMessage, "还有 2 格作物今晚必须照料，否则会枯萎。")
        XCTAssertFalse(
            (snapshot.requiredCells + snapshot.recommendedCells + snapshot.coveredCells)
                .map(\.position)
                .contains(phantom)
        )
        XCTAssertEqual(state, before, "A derived report must not mutate the farm")
    }

    func testRainAndCoverageNeverManufactureACrisis() {
        let wilted = GridPosition(x: 4, y: 2)
        let thirsty = GridPosition(x: 1, y: 1)
        let mature = GridPosition(x: 2, y: 1)
        let phantom = GridPosition(x: 8, y: 5)
        var state = baseState(day: 2)
        state.farmCells = [
            wilted: growingCell(dryStreak: 2),
            thirsty: growingCell(dryStreak: 1),
            mature: matureCell(),
        ]

        let snapshot = MorningCropReportService.snapshot(
            state: state,
            catalog: catalog,
            plannedCoverage: [
                CropCoverageSummary(
                    day: 2,
                    records: [CropCoverageRecord(position: phantom, source: .communityCare)]
                ),
            ]
        )

        XCTAssertEqual(snapshot.weather, .rain)
        XCTAssertTrue(snapshot.requiredCells.isEmpty)
        XCTAssertTrue(snapshot.recommendedCells.isEmpty)
        XCTAssertEqual(snapshot.coveredCells.map(\.position), [thirsty, wilted])
        XCTAssertTrue(snapshot.coveredCells.allSatisfy { $0.coverageSources == [.rain] })
        XCTAssertEqual(snapshot.matureCells.map(\.position), [mature])
        XCTAssertEqual(snapshot.estimatedMinimumStamina, 0)
        XCTAssertEqual(snapshot.estimatedFullCareStamina, 0)
        XCTAssertTrue(snapshot.allDangerousCropsSafe)
        XCTAssertEqual(snapshot.safetyMessage, MorningCropReportService.safeMessage)
        XCTAssertTrue(snapshot.accessibilitySummary.contains("田里的作物都稳住了。"))
        XCTAssertFalse(snapshot.coveredCells.map(\.position).contains(phantom))
    }

    func testSnapshotAndCoverageSourceOrderAreStableAcrossInsertionOrder() {
        let a = GridPosition(x: 4, y: 3)
        let b = GridPosition(x: 0, y: 4)
        let c = GridPosition(x: 4, y: 1)
        var first = baseState(day: 1)
        first.farmCells = [
            a: growingCell(dryStreak: 2),
            b: growingCell(dryStreak: 1),
            c: growingCell(dryStreak: 2),
        ]
        var second = baseState(day: 1)
        second.farmCells = [
            c: growingCell(dryStreak: 2),
            b: growingCell(dryStreak: 1),
            a: growingCell(dryStreak: 2),
        ]
        let forwardCoverage = [
            CropCoverageSummary(
                day: 1,
                records: [
                    CropCoverageRecord(position: c, source: .communityCare),
                    CropCoverageRecord(position: c, source: .formalCanal),
                    CropCoverageRecord(position: c, source: .formalCanal),
                ]
            ),
        ]
        let reverseCoverage = [
            CropCoverageSummary(
                day: 1,
                records: [
                    CropCoverageRecord(position: c, source: .formalCanal),
                    CropCoverageRecord(position: c, source: .communityCare),
                ]
            ),
        ]

        let firstSnapshot = MorningCropReportService.snapshot(
            state: first,
            catalog: catalog,
            plannedCoverage: forwardCoverage
        )
        let secondSnapshot = MorningCropReportService.snapshot(
            state: second,
            catalog: catalog,
            plannedCoverage: reverseCoverage
        )

        XCTAssertEqual(firstSnapshot, secondSnapshot)
        XCTAssertEqual(firstSnapshot.requiredCells.map(\.position), [a])
        XCTAssertEqual(firstSnapshot.recommendedCells.map(\.position), [b])
        XCTAssertEqual(firstSnapshot.coveredCells.map(\.position), [c])
        XCTAssertEqual(firstSnapshot.coveredCells.first?.coverageSources, [.formalCanal, .communityCare])
    }

    func testDailyPresentationStateShowsOnceThenClosesAndReopens() throws {
        var session = MorningCropReportSessionState()

        XCTAssertEqual(session.enterFarm(day: 3), .openedAutomatically(day: 3))
        XCTAssertTrue(session.isPresented)
        XCTAssertEqual(session.enterFarm(day: 3), .unchanged)
        XCTAssertEqual(session.close(day: 3), .closed(day: 3))
        XCTAssertFalse(session.isPresented)
        XCTAssertEqual(session.enterFarm(day: 3), .unchanged)
        XCTAssertEqual(session.reopen(day: 3), .openedManually(day: 3))
        XCTAssertTrue(session.isPresented)
        XCTAssertEqual(session.close(day: 3), .closed(day: 3))
        XCTAssertEqual(session.enterFarm(day: 4), .openedAutomatically(day: 4))

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(MorningCropReportSessionState.self, from: data)
        XCTAssertEqual(restored, session)
    }

    func testCancelConsumesTokenWithoutChangingGameStateOrClock() throws {
        let riskPosition = GridPosition(x: 2, y: 3)
        var state = baseState(day: 1)
        state.farmCells = [riskPosition: growingCell(dryStreak: 2)]
        let clock = ClockSystem()
        let stateBefore = state
        let clockBefore = clock.snapshot()
        var confirmation = CropSleepRiskConfirmationCoordinator()

        let request = try XCTUnwrap(confirmation.issue(state: state, catalog: catalog))
        XCTAssertEqual(request.count, 1)
        XCTAssertEqual(request.positions, [riskPosition])
        XCTAssertEqual(request.positionText, "(2, 3)")
        XCTAssertTrue(request.consequence.contains("本次日结枯萎"))
        XCTAssertEqual(confirmation.cancel(token: request.token), .cancelled)

        XCTAssertEqual(state, stateBefore)
        XCTAssertEqual(clock.snapshot(), clockBefore)
        XCTAssertNil(confirmation.activeRequest)
        XCTAssertEqual(
            confirmation.confirm(token: request.token, state: state, catalog: catalog),
            .notPending
        )
    }

    func testChangedFarmMakesConfirmationTokenStale() throws {
        let riskPosition = GridPosition(x: 3, y: 3)
        var state = baseState(day: 1)
        state.farmCells = [riskPosition: growingCell(dryStreak: 2)]
        var confirmation = CropSleepRiskConfirmationCoordinator()
        let request = try XCTUnwrap(confirmation.issue(state: state, catalog: catalog))

        let result = FarmActionService().apply(
            to: &state,
            target: riskPosition,
            tool: .water,
            catalog: catalog
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(
            confirmation.confirm(token: request.token, state: state, catalog: catalog),
            .stale
        )
        XCTAssertNil(confirmation.activeRequest)
    }

    func testNewRequestInvalidatesOlderTokenButKeepsCurrentRequest() throws {
        let riskPosition = GridPosition(x: 2, y: 2)
        var state = baseState(day: 1)
        state.farmCells = [riskPosition: growingCell(dryStreak: 2)]
        var confirmation = CropSleepRiskConfirmationCoordinator()
        let oldRequest = try XCTUnwrap(confirmation.issue(state: state, catalog: catalog))
        let currentRequest = try XCTUnwrap(confirmation.issue(state: state, catalog: catalog))

        XCTAssertNotEqual(oldRequest.token, currentRequest.token)
        XCTAssertEqual(
            confirmation.confirm(token: oldRequest.token, state: state, catalog: catalog),
            .stale
        )
        XCTAssertEqual(confirmation.activeRequest, currentRequest)
        XCTAssertEqual(
            confirmation.confirm(token: currentRequest.token, state: state, catalog: catalog),
            .authorized(currentRequest)
        )
        XCTAssertNil(confirmation.activeRequest)
    }

    func testNoRealRiskProducesNoRequest() {
        let suggested = GridPosition(x: 1, y: 2)
        var state = baseState(day: 1)
        state.farmCells = [suggested: growingCell(dryStreak: 1)]
        var confirmation = CropSleepRiskConfirmationCoordinator()

        XCTAssertNil(confirmation.issue(state: state, catalog: catalog))
        XCTAssertNil(confirmation.activeRequest)
    }

    func testStableUIActionsSupportReboundKeyboardAndControllerRouting() throws {
        var state = baseState(day: 1)
        state.farmCells = [GridPosition(x: 1, y: 1): growingCell(dryStreak: 2)]
        var confirmation = CropSleepRiskConfirmationCoordinator()
        let request = try XCTUnwrap(confirmation.issue(state: state, catalog: catalog))

        XCTAssertEqual(
            MorningCropReportActionRouter.route(
                actionID: InputBindingDefinitions.actionInteract,
                context: .reportHidden
            ),
            .reopenReport
        )
        XCTAssertEqual(
            MorningCropReportActionRouter.route(
                actionID: InputBindingDefinitions.actionUIAccept,
                context: .reportPresented
            ),
            .closeReport
        )
        XCTAssertEqual(
            MorningCropReportActionRouter.route(
                actionID: InputBindingDefinitions.actionUIAccept,
                context: .sleepRiskPresented(token: request.token)
            ),
            .confirmSleep(request.token)
        )
        XCTAssertEqual(
            MorningCropReportActionRouter.route(
                actionID: InputBindingDefinitions.actionUICancel,
                context: .sleepRiskPresented(token: request.token)
            ),
            .cancelSleep(request.token)
        )
        XCTAssertNil(
            MorningCropReportActionRouter.route(
                actionID: InputBindingDefinitions.actionMoveLeft,
                context: .sleepRiskPresented(token: request.token)
            )
        )

        var settings = SettingsState.defaults
        settings.lastUsedDevice = .gamepad
        let hints = MorningCropReportControlHints.resolve(settings: settings)
        XCTAssertEqual(hints.confirm, "手柄 A")
        XCTAssertEqual(hints.cancel, "手柄 B")
        XCTAssertEqual(hints.reopen, "手柄 A")
    }

    private func baseState(day: Int) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: day, minute: GameClock.dayStartMinute)
        state.farmCells = [:]
        return state
    }

    private func growingCell(
        dryStreak: Int,
        wateredToday: Bool = false
    ) -> FarmCell {
        FarmCell(
            prepared: true,
            wateredToday: wateredToday,
            cropID: ContentID.mistRadishCrop,
            cropStage: 0,
            stageProgressDays: 0,
            plantedDay: 1,
            readyToHarvest: false,
            dryStreak: wateredToday ? 0 : dryStreak,
            cropCondition: wateredToday ? .healthy : condition(forDryStreak: dryStreak)
        )
    }

    private func matureCell() -> FarmCell {
        let crop = catalog.crops[ContentID.mistRadishCrop]!
        return FarmCell(
            prepared: true,
            wateredToday: false,
            cropID: crop.id,
            cropStage: crop.matureStageIndex,
            stageProgressDays: crop.stageDays.reduce(0, +),
            plantedDay: 1,
            readyToHarvest: true,
            dryStreak: 0,
            cropCondition: .healthy
        )
    }

    private func condition(forDryStreak dryStreak: Int) -> CropCondition {
        switch dryStreak {
        case 0: return .healthy
        case 1: return .thirsty
        case 2: return .wilted
        default: return .withered
        }
    }
}
