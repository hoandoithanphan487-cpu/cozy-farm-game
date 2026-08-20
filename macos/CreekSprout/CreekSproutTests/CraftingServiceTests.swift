import XCTest
@testable import CreekSprout

final class CraftingServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testWoodenCrateCraftConsumesInputsAndAddsOutput() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertEqual(
            grant(state: &state, itemID: ContentID.creekWood, quantity: 12),
            true
        )
        let result = CraftingService.craft(
            state: state,
            recipeID: ContentID.woodenCrateRecipe,
            catalog: catalog
        )
        guard case .success(let next) = result else {
            return XCTFail("expected craft success")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.creekWood), 0)
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testInsufficientMaterialsLeaveInventoryUnchanged() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(grant(state: &state, itemID: ContentID.creekWood, quantity: 11))
        let before = state
        let result = CraftingService.craft(
            state: state,
            recipeID: ContentID.woodenCrateRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.insufficientMaterials))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekWood), 11)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 0)
    }

    func testUnknownRecipeDoesNotConsumeItems() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(grant(state: &state, itemID: ContentID.creekWood, quantity: 12))
        let before = state
        let result = CraftingService.craft(
            state: state,
            recipeID: "brookseed.recipe.not_real",
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.unknownRecipe))
        XCTAssertEqual(state, before)
    }

    func testOutputCapacityFailureRollsBackConsumedMaterials() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.inventory = []
        state.inventoryCapacity = 1
        XCTAssertTrue(grant(state: &state, itemID: ContentID.creekWood, quantity: 13))
        XCTAssertEqual(state.inventory.count, 1)
        let before = state
        let result = CraftingService.craft(
            state: state,
            recipeID: ContentID.woodenCrateRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.outputCapacityExceeded))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekWood), 13)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodenCrateItem), 0)
    }

    private func grant(state: inout GameState, itemID: String, quantity: Int) -> Bool {
        switch InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: itemID,
            quantity: quantity,
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
