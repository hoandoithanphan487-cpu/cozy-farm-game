import XCTest
@testable import CreekSprout

final class FarmLoopTests: XCTestCase {
    private let catalog = ContentCatalog.m1Placeholder
    private let farm = FarmActionService()
    private let dayCycle = DayCycleService()
    private let plot = GridPosition(x: 2, y: 3)

    func testHoeSeedWaterTwoDayEndsAndHarvest() {
        var state = GameState.m1NewGame()
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .water, catalog: catalog).isSuccess)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertFalse(state.cell(at: plot).readyToHarvest)
        XCTAssertFalse(state.cell(at: plot).wateredToday)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .water, catalog: catalog).isSuccess)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertTrue(state.cell(at: plot).readyToHarvest)
        XCTAssertEqual(state.cell(at: plot).cropStage, 2)
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishItem), 1)
        XCTAssertFalse(state.cell(at: plot).hasCrop)
        XCTAssertEqual(state.stamina, 100 - 10)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishSeed), 7)
    }

    func testUnwateredCropDoesNotGrow() {
        var state = GameState.m1NewGame()
        farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        let cell = state.cell(at: plot)
        XCTAssertEqual(cell.cropStage, 0)
        XCTAssertFalse(cell.readyToHarvest)
        XCTAssertEqual(cell.stageProgressDays, 0)
        XCTAssertFalse(cell.wateredToday)
        XCTAssertTrue(cell.hasCrop)
    }

    func testHoeFailsAtomicallyWhenStaminaIsOne() {
        var state = GameState.m1NewGame()
        state.stamina = 1
        let before = state
        let result = farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(state, before)
        XCTAssertTrue(state.farmCells.isEmpty)
        XCTAssertEqual(state.stamina, 1)
    }

    func testHarvestFailsWhenInventoryIsFullAndCropRemains() {
        var state = GameState.m1NewGame()
        farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .water, catalog: catalog)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .water, catalog: catalog)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertTrue(state.cell(at: plot).readyToHarvest)

        state.inventoryCapacity = 1
        let beforeHarvest = state
        let result = farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(state, beforeHarvest)
        XCTAssertEqual(state.stamina, beforeHarvest.stamina)
        XCTAssertEqual(state.inventory, beforeHarvest.inventory)
        XCTAssertTrue(state.cell(at: plot).readyToHarvest)
        XCTAssertEqual(state.cell(at: plot).cropID, ContentID.mistRadishCrop)
    }

    func testHarvestUsesCatalogStackLimitInsteadOfHardcodedNinetyNine() {
        var catalog = ContentCatalog.m1Placeholder
        var harvestItem = catalog.items[ContentID.mistRadishItem]!
        harvestItem.stackLimit = 5
        catalog.items[ContentID.mistRadishItem] = harvestItem
        XCTAssertEqual(ContentCatalog.m1Placeholder.item(id: ContentID.mistRadishItem)?.stackLimit, 99)
        XCTAssertEqual(catalog.stackLimit(for: ContentID.mistRadishItem), 5)

        var state = GameState.m1NewGame()
        farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .water, catalog: catalog)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .water, catalog: catalog)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertTrue(state.cell(at: plot).readyToHarvest)

        state.inventoryCapacity = 1
        state.inventory = [InventoryQuantity(itemID: ContentID.mistRadishItem, quantity: 5)]
        let beforeHarvest = state
        let result = farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(state, beforeHarvest)
    }

    func testSeedingFailsWhenSeedsAreMissingAndLeavesStateUnchanged() {
        var state = GameState.m1NewGame()
        farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        state.inventory = []
        let before = state
        let result = farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.stamina, before.stamina)
        XCTAssertEqual(state.inventory, [])
        XCTAssertTrue(state.cell(at: plot).prepared)
        XCTAssertFalse(state.cell(at: plot).hasCrop)
    }

    func testSelectedSeedPlantsMatchingDataDrivenCrop() {
        let catalog = ContentCatalog.vs0
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = [:]
        XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog).isSuccess)
        let result = farm.apply(
            to: &state,
            target: plot,
            tool: .seed,
            catalog: catalog,
            seedItemID: ContentID.streamLeafSeed
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(state.cell(at: plot).cropID, ContentID.streamLeafCrop)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.streamLeafSeed), 1)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishSeed), 8)
    }

    func testRearPlotSupportsFullFarmLoopWithoutExpandingAdjacentCells() {
        let catalog = ContentCatalog.vs0
        let rear = GridPosition(x: 7, y: 12)
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = [:]

        XCTAssertTrue(farm.apply(to: &state, target: rear, tool: .hoe, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: rear, tool: .seed, catalog: catalog).isSuccess)
        XCTAssertTrue(farm.apply(to: &state, target: rear, tool: .water, catalog: catalog).isSuccess)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertTrue(farm.apply(to: &state, target: rear, tool: .water, catalog: catalog).isSuccess)
        dayCycle.advanceCrops(state: &state, catalog: catalog)
        XCTAssertTrue(state.cell(at: rear).readyToHarvest)
        XCTAssertTrue(farm.apply(to: &state, target: rear, tool: .harvest, catalog: catalog).isSuccess)

        let before = state
        XCTAssertFalse(farm.apply(
            to: &state,
            target: GridPosition(x: 6, y: 12),
            tool: .hoe,
            catalog: catalog
        ).isSuccess)
        XCTAssertEqual(state, before)
    }

    func testPauseReasonsCompose() {
        var state = GameState.m1NewGame()
        let clock = ClockSystem()
        clock.addPauseReason(.menu)
        clock.addPauseReason(.dialogue)
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 3), 0)
        clock.removePauseReason(.menu)
        XCTAssertTrue(clock.isPaused)
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 3), 0)
        clock.removePauseReason(.dialogue)
        XCTAssertFalse(clock.isPaused)
        XCTAssertGreaterThan(clock.advance(state: &state, deltaSeconds: 3), 0)
        XCTAssertEqual(state.clock.minute, GameClock.dayStartMinute + 3)
    }

    func testDayCycleClearsWaterAndAdvancesClock() {
        var state = GameState.m1NewGame()
        let clock = ClockSystem()
        farm.apply(to: &state, target: plot, tool: .hoe, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .seed, catalog: catalog)
        farm.apply(to: &state, target: plot, tool: .water, catalog: catalog)
        state.clock.minute = GameClock.dayEndMinute
        dayCycle.settle(state: &state, clock: clock, catalog: catalog)
        XCTAssertEqual(state.clock.day, 2)
        XCTAssertEqual(state.clock.minute, GameClock.dayStartMinute)
        XCTAssertTrue(state.cell(at: plot).wateredToday)
        XCTAssertEqual(state.cell(at: plot).cropStage, 1)
        XCTAssertFalse(clock.isPaused)
    }
}
