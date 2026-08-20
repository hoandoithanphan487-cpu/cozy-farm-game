import XCTest
@testable import CreekSprout

final class WeatherServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let farm = FarmActionService()
    private let dayCycle = DayCycleService()
    private let outdoorPlot = GridPosition(x: 2, y: 3)

    func testVs0ScenarioScriptsRainOnDayTwoOnly() {
        XCTAssertEqual(catalog.scenario.weather(on: 1), .clear)
        XCTAssertEqual(catalog.scenario.weather(on: 2), .rain)
        XCTAssertEqual(catalog.scenario.weather(on: 3), .clear)
        XCTAssertEqual(WeatherKind.rain.displayName, "雨")
        XCTAssertEqual(WeatherKind.clear.displayName, "晴")
    }

    func testSleepingIntoDayTwoWatersOutdoorCrops() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .water, catalog: catalog).isSuccess)
        let summary = dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        XCTAssertEqual(state.clock.day, 2)
        XCTAssertTrue(state.cell(at: outdoorPlot).wateredToday)
        XCTAssertEqual(state.cell(at: outdoorPlot).cropStage, 1)
        XCTAssertTrue(summary.headline.contains("今天是雨天"))
        XCTAssertTrue(summary.headline.contains("露天地块已被雨水浇过"))
        let event = GossipService.activeEvent(state: state)
        XCTAssertEqual(event?.status, .offered)
        XCTAssertEqual(state.community.standing, 50)
    }

    func testDayThreeIsClearAndDoesNotReapplyRain() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .water, catalog: catalog).isSuccess)
        _ = dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        XCTAssertTrue(state.cell(at: outdoorPlot).wateredToday)
        let dayThree = dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        XCTAssertEqual(state.clock.day, 3)
        XCTAssertEqual(catalog.scenario.weather(on: 3), .clear)
        XCTAssertFalse(state.cell(at: outdoorPlot).wateredToday)
        XCTAssertFalse(dayThree.headline.contains("雨天"))
    }

    func testUnpreparedEmptyCellsAreNotWateredByRain() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = [outdoorPlot: FarmCell()]
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        let watered = WeatherService.applyDayStart(state: &state, catalog: catalog)
        XCTAssertEqual(watered, 0)
        XCTAssertFalse(state.cell(at: outdoorPlot).wateredToday)
    }

    func testRainApplyIsIdempotentWithinTheSameMorning() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: outdoorPlot, tool: .seed, catalog: catalog).isSuccess)
        state.farmCells = [outdoorPlot: state.cell(at: outdoorPlot)]
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        XCTAssertEqual(WeatherService.applyDayStart(state: &state, catalog: catalog), 1)
        XCTAssertTrue(state.cell(at: outdoorPlot).wateredToday)
        XCTAssertEqual(WeatherService.applyDayStart(state: &state, catalog: catalog), 1)
        XCTAssertTrue(state.cell(at: outdoorPlot).wateredToday)
    }
}
