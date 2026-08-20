import XCTest
@testable import CreekSprout

final class SettlementTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let farm = FarmActionService()
    private let dayCycle = DayCycleService()

    func testThreeNormalRadishesSettleOnceWithCatalogTotal() {
        let state = harvestedAndShippedTeachingRadishes()
        let unitPrice = EconomyCatalog(content: catalog).unitPrice(
            itemID: ContentID.mistRadishItem,
            quality: .normal
        )!
        let expectedTotal = unitPrice * 3
        let expectedLine = EconomyCatalog(content: catalog).settlementLine(
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            amount: expectedTotal
        )
        let startingBalance = catalog.scenario.startingCurrency

        let result = SettleShippingUseCase.settle(state: state, catalog: catalog)
        XCTAssertFalse(result.wasAlreadySettled)
        XCTAssertEqual(result.record.settlementID, "\(ContentID.vs0Scenario).day1")
        XCTAssertEqual(result.record.total, expectedTotal)
        XCTAssertEqual(result.record.lines.map(\.displayText), [expectedLine])
        XCTAssertEqual(result.state.economy.balance, startingBalance + expectedTotal)
        XCTAssertTrue(result.state.economy.shipping.pendingEntries.isEmpty)
        XCTAssertEqual(result.state.economy.ledger.last?.reasonID, ContentID.shippingSettleReason)
        XCTAssertEqual(result.state.economy.ledger.last?.amount, expectedTotal)
        XCTAssertEqual(expectedLine, "雾萝卜×3 = 174")
        XCTAssertEqual(result.state.economy.balance, 894)
    }

    func testSameDaySettlementIsIdempotent() {
        let state = harvestedAndShippedTeachingRadishes()
        let first = SettleShippingUseCase.settle(state: state, catalog: catalog)
        let second = SettleShippingUseCase.settle(state: first.state, catalog: catalog)
        XCTAssertTrue(second.wasAlreadySettled)
        XCTAssertEqual(second.state.economy.balance, first.state.economy.balance)
        XCTAssertEqual(second.state.economy.settlementHistory.count, 1)
        XCTAssertEqual(second.state.economy.ledger.filter { $0.reasonID == ContentID.shippingSettleReason }.count, 1)
        XCTAssertEqual(second.record.settlementID, first.record.settlementID)
    }

    func testSleepThenReloadDoesNotPayAgain() throws {
        var state = harvestedAndShippedTeachingRadishes()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-settle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(directory: directory, catalog: catalog)
        let clock = ClockSystem()
        let first = try SleepUseCase().sleep(state: &state, clock: clock, catalog: catalog, store: store)
        let balanceAfterSleep = state.economy.balance
        XCTAssertGreaterThan(first.settlement.total, 0)
        XCTAssertEqual(first.settlement.gameDay, 1)

        var loaded = try store.load()
        XCTAssertEqual(loaded.economy.balance, balanceAfterSleep)
        let again = try SleepUseCase().sleep(state: &loaded, clock: ClockSystem(), catalog: catalog, store: store)
        XCTAssertEqual(loaded.economy.balance, balanceAfterSleep)
        XCTAssertEqual(again.settlement.gameDay, 2)
        XCTAssertEqual(again.settlement.total, 0)
    }

    func testAutosaveFailureFullyRollsBackStateAndClock() throws {
        var state = harvestedAndShippedTeachingRadishes()
        let plot = GridPosition(x: 2, y: 3)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .water, catalog: catalog).isSuccess)
        let clock = ClockSystem()
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 0.5), 0)
        let before = state

        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-sleep-fail-\(UUID().uuidString)")
        try Data("not-a-directory".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let failingStore = SaveStore(directory: blocker, catalog: catalog)

        XCTAssertThrowsError(
            try SleepUseCase().sleep(state: &state, clock: clock, catalog: catalog, store: failingStore)
        )
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.clock.day, 1)
        XCTAssertEqual(state.economy.shipping.pendingEntries.count, 1)
        XCTAssertTrue(state.cell(at: plot).wateredToday)
        XCTAssertEqual(state.cell(at: plot).cropStage, 0)
        XCTAssertFalse(clock.isPaused)
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 0.5), 1)
    }

    func testAutosaveFailureThenRetryAdvancesOnlyOneDay() throws {
        var state = harvestedAndShippedTeachingRadishes()
        let plot = GridPosition(x: 2, y: 3)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .water, catalog: catalog).isSuccess)
        let pending = state.economy.shipping.pendingEntries
        let clock = ClockSystem()

        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-sleep-retry-\(UUID().uuidString)")
        try Data("not-a-directory".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        XCTAssertThrowsError(
            try SleepUseCase().sleep(
                state: &state,
                clock: clock,
                catalog: catalog,
                store: SaveStore(directory: blocker, catalog: catalog)
            )
        )
        XCTAssertEqual(state.clock.day, 1)
        XCTAssertEqual(state.economy.shipping.pendingEntries, pending)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-sleep-ok-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let summary = try SleepUseCase().sleep(
            state: &state,
            clock: clock,
            catalog: catalog,
            store: SaveStore(directory: directory, catalog: catalog)
        )
        XCTAssertEqual(state.clock.day, 2)
        XCTAssertEqual(summary.previousDay, 1)
        XCTAssertTrue(state.economy.shipping.pendingEntries.isEmpty)
        XCTAssertTrue(state.cell(at: plot).wateredToday)
        XCTAssertEqual(state.cell(at: plot).cropStage, 1)
        XCTAssertEqual(
            state.economy.ledger.filter { $0.reasonID == ContentID.shippingSettleReason }.count,
            1
        )
    }

    func testNegativeCurrencyTransactionIsRejected() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.economy.balance = 0
        let before = state
        let result = EconomyService.apply(
            state.economy,
            transaction: CurrencyTransaction(
                reasonID: ContentID.debugGrantReason,
                amount: -1,
                sourceRef: "brookseed.debug.negative",
                dayIndex: 1
            )
        )
        XCTAssertEqual(result, .failure(.negativeBalanceRejected))
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.economy.balance, 0)
        XCTAssertTrue(state.economy.ledger.isEmpty)
    }

    func testHarvestShipSleepPathUsesTeachingPlots() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertEqual(state.economy.balance, catalog.scenario.startingCurrency)
        for plot in catalog.scenario.startingFarmCells.map(\.position) {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
        }
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishItem), 3)
        state = try! ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        let summary = dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        let unitPrice = EconomyCatalog(content: catalog).unitPrice(
            itemID: ContentID.mistRadishItem,
            quality: .normal
        )!
        XCTAssertEqual(summary.settlement.total, unitPrice * 3)
        XCTAssertEqual(state.economy.balance, catalog.scenario.startingCurrency + unitPrice * 3)
        XCTAssertEqual(state.clock.day, 2)
        XCTAssertTrue(summary.headline.contains(summary.settlement.lines[0].displayText))
        XCTAssertTrue(summary.headline.contains("今天是雨天"))
        XCTAssertEqual(catalog.scenario.weather(on: 2), .rain)
        XCTAssertEqual(catalog.scenario.weather(on: 1), .clear)
    }

    private func harvestedAndShippedTeachingRadishes() -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        for plot in catalog.scenario.startingFarmCells.map(\.position) {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
        }
        return try! ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
    }
}
