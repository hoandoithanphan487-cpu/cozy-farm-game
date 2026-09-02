import XCTest
@testable import CreekSprout

final class ProcessingServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private var commands: M2CommandService { M2CommandService(catalog: catalog) }

    func testProcessingRecipesAreDataDrivenAndExcludeMistRadish() throws {
        try ContentValidator.validate(catalog)
        let recipes = catalog.availableProcessingRecipeIDs(for: GameState.vs0NewGame(catalog: catalog))
        XCTAssertGreaterThanOrEqual(recipes.count, 3)
        XCTAssertFalse(catalog.availableRecipeIDs(for: GameState.vs0NewGame(catalog: catalog)).contains {
            catalog.recipe(id: $0)?.isProcessingRecipe == true
        })
        for recipeID in recipes {
            let recipe = try XCTUnwrap(catalog.recipe(id: recipeID))
            XCTAssertTrue(recipe.isProcessingRecipe)
            XCTAssertEqual(recipe.staminaCost, 2)
            XCTAssertFalse(recipe.inputs.contains { $0.itemID == ContentID.mistRadishItem })
            XCTAssertFalse(recipe.inputs.contains { $0.itemID == ContentID.mistRadishSeed })
            XCTAssertEqual(recipe.inputs.count, 1)
            XCTAssertEqual(recipe.outputs.count, 1)
            XCTAssertNotNil(catalog.item(id: recipe.inputs[0].itemID))
            XCTAssertNotNil(catalog.item(id: recipe.outputs[0].itemID))
        }
        XCTAssertEqual(catalog.displayName(forItemID: ContentID.woodhoneyHearthItem), "木蜜灶台")
        XCTAssertEqual(catalog.displayName(forItemID: ContentID.honeySearedCreekGreensItem), "蜜烤溪叶菜")
        XCTAssertFalse(catalog.displayNames.values.contains(where: { $0.contains("猫猫烧烤") }))
        XCTAssertNil(catalog.npc(id: "brookseed.npc.cat_barbecue"))
    }

    func testFinishedGoodPricesStayInsideMarkupBandAndAreShippable() {
        let prices = EconomyCatalog(content: catalog)
        let pairs: [(String, String, Int)] = [
            (ContentID.creekGreensItem, ContentID.honeySearedCreekGreensItem, 124),
            (ContentID.amberBeanItem, ContentID.honeySearedAmberBeanItem, 65),
            (ContentID.bellBerryItem, ContentID.honeyPreservedBellBerryItem, 59),
            (ContentID.honeyMelonItem, ContentID.honeySearedHoneyMelonItem, 277),
        ]
        for (inputID, outputID, expected) in pairs {
            let inputPrice = catalog.item(id: inputID)?.baseSellPrice ?? 0
            let outputPrice = catalog.item(id: outputID)?.baseSellPrice ?? 0
            XCTAssertEqual(outputPrice, expected)
            let minPrice = (inputPrice * ContentID.processingMarkupMinBp + 99) / 100
            let maxPrice = (inputPrice * ContentID.processingMarkupMaxBp) / 100
            XCTAssertTrue((minPrice...maxPrice).contains(outputPrice), "\(outputID) \(outputPrice) not in \(minPrice)...\(maxPrice)")
            XCTAssertTrue(prices.isShippable(itemID: outputID))
            XCTAssertEqual(catalog.item(id: ContentID.mistRadishItem)?.baseSellPrice, 58)
        }
    }

    func testSuccessfulProcessConsumesInputAddsOutputAndStamina() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 2))
        let stamina = state.stamina
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        guard case .success(let next) = result else {
            return XCTFail("expected process success")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.creekGreensItem), 1)
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.honeySearedCreekGreensItem), 1)
        XCTAssertEqual(next.stamina, stamina - 2)
        let second = ProcessingService.process(
            state: next,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        guard case .success(let twice) = second else {
            return XCTFail("expected second process success")
        }
        XCTAssertEqual(InventoryService.count(twice.inventory, itemID: ContentID.creekGreensItem), 0)
        XCTAssertEqual(InventoryService.count(twice.inventory, itemID: ContentID.honeySearedCreekGreensItem), 2)
        XCTAssertEqual(twice.stamina, stamina - 4)
    }

    func testInsufficientMaterialsLeavesStateUnchanged() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        let before = state
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedAmberBeanRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.insufficientMaterials))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekGreensItem), 1)
        XCTAssertEqual(state.stamina, before.stamina)
    }

    func testMissingStationLeavesStateUnchanged() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.facing = .down
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        let before = state
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.stationMissing))
        XCTAssertEqual(state, before)
    }

    func testNotFacingStationLeavesStateUnchanged() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        state.facing = .left
        let before = state
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.notAdjacent))
        XCTAssertEqual(state, before)
    }

    func testOutputCapacityFailureDoesNotConsumeInputOrStamina() {
        var state = stationedState()
        state.inventory = []
        state.inventoryCapacity = 1
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 2))
        XCTAssertEqual(state.inventory.count, 1)
        let before = state
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.outputCapacityExceeded))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekGreensItem), 2)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.honeySearedCreekGreensItem), 0)
    }

    func testInsufficientStaminaDoesNotConsumeMaterials() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        state.stamina = 1
        let before = state
        let result = ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.insufficientStamina))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekGreensItem), 1)
    }

    func testHearthPlacementFailureDoesNotConsumeItem() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 4, y: 2)
        state.facing = .up
        XCTAssertTrue(grant(&state, itemID: ContentID.woodhoneyHearthItem, quantity: 1))
        let before = state
        let result = PlacementService.place(
            state: state,
            definitionID: ContentID.woodhoneyHearthObject,
            origin: GridPosition(x: 4, y: 3),
            facing: .up,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.occupancyConflict))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.woodhoneyHearthItem), 1)
        XCTAssertTrue(state.placedObjects.isEmpty)
    }

    func testProcessedGoodsShipAndSettleOnce() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        state = try! ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        ).get()
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekGreensItem), 0)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.honeySearedCreekGreensItem), 1)
        state = try! ShippingService.deposit(
            state: state,
            itemID: ContentID.honeySearedCreekGreensItem,
            quantity: 1,
            catalog: catalog
        ).get()
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.honeySearedCreekGreensItem), 0)
        XCTAssertEqual(state.economy.shipping.pendingQuantity, 1)

        let first = SettleShippingUseCase.settle(state: state, catalog: catalog)
        XCTAssertFalse(first.wasAlreadySettled)
        XCTAssertEqual(first.record.total, 124)
        XCTAssertTrue(first.record.lines.map(\.displayText).contains("蜜烤溪叶菜×1 = 124"))
        XCTAssertEqual(first.state.economy.balance, catalog.scenario.startingCurrency + 124)
        XCTAssertTrue(first.state.economy.shipping.pendingEntries.isEmpty)

        let second = SettleShippingUseCase.settle(state: first.state, catalog: catalog)
        XCTAssertTrue(second.wasAlreadySettled)
        XCTAssertEqual(second.state.economy.balance, first.state.economy.balance)
        XCTAssertEqual(
            second.state.economy.ledger.filter { $0.reasonID == ContentID.shippingSettleReason }.count,
            1
        )
    }

    func testSaveLoadRoundTripKeepsStationGoodsPendingAndBalance() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-n004-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(directory: directory, catalog: catalog)

        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        state = try ProcessingService.process(
            state: state,
            recipeID: ContentID.honeySearedCreekGreensRecipe,
            catalog: catalog
        ).get()
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.honeySearedCreekGreensItem,
            quantity: 1,
            catalog: catalog
        ).get()
        let balance = state.economy.balance
        try store.save(state)
        let loaded = try store.load()
        XCTAssertEqual(loaded.placedObjects.map(\.definitionID), [ContentID.woodhoneyHearthObject])
        XCTAssertEqual(InventoryService.count(loaded.inventory, itemID: ContentID.honeySearedCreekGreensItem), 0)
        XCTAssertEqual(loaded.economy.shipping.pendingQuantity, 1)
        XCTAssertEqual(loaded.economy.balance, balance)
        XCTAssertEqual(loaded.stamina, state.stamina)
        XCTAssertEqual((try decodedJSON(at: store.primaryURL)["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
    }

    func testCraftCommandRejectsProcessingRecipesWithoutChangingState() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        let before = state
        let feedback = commands.craft(state: &state, recipeID: ContentID.honeySearedCreekGreensRecipe)
        XCTAssertFalse(feedback.isSuccess)
        XCTAssertTrue(feedback.message.contains("加工"))
        XCTAssertEqual(state, before)
    }

    func testProcessCommandFeedbackUsesChineseMarks() {
        var state = stationedState()
        XCTAssertTrue(grant(&state, itemID: ContentID.creekGreensItem, quantity: 1))
        let success = commands.process(state: &state, recipeID: ContentID.honeySearedCreekGreensRecipe)
        XCTAssertTrue(success.isSuccess)
        XCTAssertTrue(success.message.contains("✅"))
        XCTAssertTrue(success.message.contains("蜜烤溪叶菜"))
        let failure = commands.process(state: &state, recipeID: ContentID.honeySearedAmberBeanRecipe)
        XCTAssertFalse(failure.isSuccess)
        XCTAssertTrue(failure.message.contains("❌"))
        XCTAssertTrue(failure.message.contains("原料不足"))
    }

    func testBaselineCropPricesAreUnchanged() {
        XCTAssertEqual(catalog.item(id: ContentID.mistRadishItem)?.baseSellPrice, 58)
        XCTAssertEqual(catalog.item(id: ContentID.creekGreensItem)?.baseSellPrice, 92)
        XCTAssertEqual(catalog.item(id: ContentID.amberBeanItem)?.baseSellPrice, 48)
        XCTAssertEqual(catalog.item(id: ContentID.bellBerryItem)?.baseSellPrice, 44)
        XCTAssertEqual(catalog.item(id: ContentID.honeyMelonItem)?.baseSellPrice, 205)
        XCTAssertEqual(catalog.scenario.startingCurrency, 720)
        XCTAssertEqual(catalog.scenario.startingItems.first?.quantity, 8)
    }

    private func stationedState() -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 5, y: 1)
        state.facing = .up
        XCTAssertTrue(grant(&state, itemID: ContentID.woodhoneyHearthItem, quantity: 1))
        state = try! PlacementService.place(
            state: state,
            definitionID: ContentID.woodhoneyHearthObject,
            origin: GridPosition(x: 5, y: 2),
            facing: .up,
            catalog: catalog
        ).get()
        return state
    }

    private func grant(_ state: inout GameState, itemID: String, quantity: Int) -> Bool {
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

    private func decodedJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
