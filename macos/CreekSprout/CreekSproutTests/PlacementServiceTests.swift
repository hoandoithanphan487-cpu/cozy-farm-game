import XCTest
@testable import CreekSprout

final class PlacementServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testPlaceConsumesItemAndCreatesState() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 5, y: 4)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let origin = GridPosition(x: 5, y: 5)
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: origin,
            facing: .up,
            catalog: catalog
        )
        guard case .success(let next) = result else {
            return XCTFail("expected placement success")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.woodenCrateItem), 0)
        XCTAssertEqual(next.placedObjects.count, 1)
        XCTAssertEqual(next.placedObjects[0].origin, origin)
        XCTAssertEqual(next.placedObjects[0].definitionID, ContentID.woodenCrateObject)
    }

    func testOutOfBoundsDoesNotConsumeItem() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 8, y: 4)
        XCTAssertTrue(grant(&state, itemID: ContentID.compostRackItem))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.compostRackObject,
            origin: GridPosition(x: 9, y: 4),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.outOfBounds))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.compostRackItem), 1)
        XCTAssertTrue(state.placedObjects.isEmpty)
    }

    func testRearCultivationPlotDoesNotExpandFurniturePlacementBounds() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 7, y: 11)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 7, y: 12),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.outOfBounds))
        XCTAssertTrue(state.placedObjects.isEmpty)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testCropConflictDoesNotConsumeItem() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 4, y: 2)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 4, y: 3),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.occupancyConflict))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testExistingObjectConflictDoesNotConsumeItem() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 5, y: 4)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        state = try! PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 5, y: 5),
            facing: .up,
            catalog: catalog
        ).get()
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 5, y: 5),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.occupancyConflict))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
        XCTAssertEqual(state.placedObjects.count, 1)
    }

    func testNonAdjacentOriginFailsWithoutConsuming() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 5, y: 4)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 8, y: 5),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.notAdjacentToPlayer))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testBlockingExitFailsWithoutConsuming() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 7, y: 1)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: catalog.scenario.exitCell,
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.exitUnreachable))
        XCTAssertEqual(state, before)
        XCTAssertTrue(state.placedObjects.isEmpty)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testPreviewIsNotPersisted() {
        var state = GameState.m1NewGame(seedQuantity: 0)
        state.position = GridPosition(x: 5, y: 4)
        XCTAssertTrue(grant(&state, itemID: ContentID.woodenCrateItem))
        let preview = PlacementService.preview(
            state: state,
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 5, y: 5),
            facing: .up,
            catalog: catalog
        )
        XCTAssertTrue(preview.isValid)
        XCTAssertEqual(preview.footprint, [GridPosition(x: 5, y: 5)])
        XCTAssertTrue(state.placedObjects.isEmpty)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testRotatedFootprintUsesFacing() {
        let origin = GridPosition(x: 3, y: 3)
        let up = PlacementService.absoluteFootprint(
            definitionID: ContentID.compostRackObject,
            origin: origin,
            facing: .up,
            catalog: catalog
        )
        let right = PlacementService.absoluteFootprint(
            definitionID: ContentID.compostRackObject,
            origin: origin,
            facing: .right,
            catalog: catalog
        )
        XCTAssertEqual(up, [GridPosition(x: 3, y: 3), GridPosition(x: 4, y: 3)])
        XCTAssertEqual(right, [GridPosition(x: 3, y: 3), GridPosition(x: 3, y: 2)])
    }

    private func grant(_ state: inout GameState, itemID: String) -> Bool {
        switch InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: itemID,
            quantity: 1,
            stackLimit: catalog.stackLimit(for: itemID)
        ) {
        case .failure:
            return false
        case .success(let inventory):
            state.inventory = inventory
            return true
        }
    }
}
