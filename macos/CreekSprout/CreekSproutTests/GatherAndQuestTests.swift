import XCTest
@testable import CreekSprout

final class GatherAndQuestTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testGuaranteedNodesCoverCanalRecipeAndMapFloors() throws {
        try ContentValidator.validate(catalog)

        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.farmHomestead, itemID: ContentID.creekWood), 8)
        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.farmHomestead, itemID: ContentID.mossStone), 4)
        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.farmHomestead, itemID: ContentID.reedFiber), 6)
        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.creekMarket, itemID: ContentID.creekWood), 6)
        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.creekMarket, itemID: ContentID.mossStone), 8)
        XCTAssertGreaterThanOrEqual(sum(mapID: ContentID.creekMarket, itemID: ContentID.reedFiber), 6)

        var guaranteed: [String: Int] = [:]
        for id in catalog.scenario.guaranteedGatherNodeIDs {
            let node = try XCTUnwrap(catalog.gatherNode(id: id))
            XCTAssertNil(node.requiredUnlockID)
            XCTAssertTrue(node.oneTime)
            for yield in node.yields {
                guaranteed[yield.itemID, default: 0] += yield.quantity
            }
        }
        XCTAssertGreaterThanOrEqual(guaranteed[ContentID.creekWood] ?? 0, 6)
        XCTAssertGreaterThanOrEqual(guaranteed[ContentID.mossStone] ?? 0, 4)
        XCTAssertFalse(catalog.scenario.guaranteedGatherNodeIDs.contains(ContentID.restoredBrookGather))
    }

    func testHarvestIsDeterministicOneTimeAndIdempotent() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 1, y: 5)
        state.facing = .up
        let first = GatherService.harvest(state: state, nodeID: ContentID.farmWoodGather, catalog: catalog)
        guard case .success(let harvested) = first else {
            return XCTFail("expected first harvest")
        }
        XCTAssertEqual(InventoryService.count(harvested.inventory, itemID: ContentID.creekWood), 8)
        XCTAssertEqual(harvested.stamina, 98)
        XCTAssertEqual(harvested.harvestedGatherNodeIDs, [ContentID.farmWoodGather])

        let before = harvested
        let second = GatherService.harvest(state: harvested, nodeID: ContentID.farmWoodGather, catalog: catalog)
        XCTAssertEqual(second, .failure(.alreadyHarvested))
        XCTAssertEqual(harvested, before)
        XCTAssertEqual(InventoryService.count(harvested.inventory, itemID: ContentID.creekWood), 8)
    }

    func testCapacityFailureDoesNotMarkNodeOrSpendStamina() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.inventoryCapacity = 1
        state.position = GridPosition(x: 1, y: 5)
        let before = state
        let result = GatherService.harvest(state: state, nodeID: ContentID.farmWoodGather, catalog: catalog)
        XCTAssertEqual(result, .failure(.capacityExceeded))
        XCTAssertEqual(state, before)
        XCTAssertTrue(state.harvestedGatherNodeIDs.isEmpty)
        XCTAssertEqual(state.stamina, 100)
    }

    func testMainlineQuestHasNoStandingGateAndDeliverDoesNotConsume() throws {
        let quest = try XCTUnwrap(catalog.quest(id: ContentID.restoreOldCanalQuest))
        XCTAssertTrue(quest.isMainline)
        XCTAssertNil(quest.minStanding)
        XCTAssertTrue(quest.objectives.contains { $0.kind == .deliver && !$0.consumesItems })

        var illegal = catalog
        var mutated = try XCTUnwrap(illegal.quests[ContentID.restoreOldCanalQuest])
        mutated.minStanding = 41
        illegal.quests[ContentID.restoreOldCanalQuest] = mutated
        XCTAssertThrowsError(try ContentValidator.validate(illegal)) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("min_standing"), reason)
        }

        var state = GameState.vs0NewGame(catalog: catalog)
        state = try QuestService.accept(
            state: state,
            questID: ContentID.restoreOldCanalQuest,
            catalog: catalog
        ).get()
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .active)

        XCTAssertTrue(grant(&state, itemID: ContentID.canalSegmentItem))
        let inventoryBeforePlace = state.inventory
        state.position = GridPosition(x: 7, y: 3)
        let commands = M2CommandService(catalog: catalog)
        let placed = commands.place(
            state: &state,
            definitionID: ContentID.canalSegmentObject,
            origin: GridPosition(x: 7, y: 4),
            facing: .up
        )
        XCTAssertTrue(placed.isSuccess)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.canalSegmentItem), 0)
        XCTAssertNotEqual(state.inventory, inventoryBeforePlace)
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .readyToTurnIn)

        let inventoryBeforeDeliver = state.inventory
        state = try CanalProgressionService.deliverCanalRepair(state: state, catalog: catalog).get()
        XCTAssertEqual(state.inventory, inventoryBeforeDeliver)
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .completed)
        XCTAssertEqual(state.watershed.restorationPoints, 20)
    }

    func testFarmWoodAndMossAloneCraftCanalSegment() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 1, y: 5)
        state = try! GatherService.harvest(state: state, nodeID: ContentID.farmWoodGather, catalog: catalog).get()
        state.position = GridPosition(x: 12, y: 5)
        state = try! GatherService.harvest(state: state, nodeID: ContentID.farmMossGather, catalog: catalog).get()
        XCTAssertGreaterThanOrEqual(InventoryService.count(state.inventory, itemID: ContentID.creekWood), 6)
        XCTAssertGreaterThanOrEqual(InventoryService.count(state.inventory, itemID: ContentID.mossStone), 4)
        let crafted = CraftingService.craft(
            state: state,
            recipeID: ContentID.canalSegmentRecipe,
            catalog: catalog
        )
        guard case .success(let next) = crafted else {
            return XCTFail("guaranteed farm nodes should craft a canal segment")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.canalSegmentItem), 1)
    }

    private func sum(mapID: String, itemID: String) -> Int {
        catalog.gatherNodes.values
            .filter { $0.mapID == mapID && $0.requiredUnlockID == nil }
            .flatMap(\.yields)
            .filter { $0.itemID == itemID }
            .reduce(0) { $0 + $1.quantity }
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
