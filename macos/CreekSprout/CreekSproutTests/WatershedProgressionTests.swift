import XCTest
@testable import CreekSprout

final class WatershedProgressionTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let commands = M2CommandService(catalog: .vs0)

    func testZeroTwelveTwentyPathIsObservableAndIdempotent() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let restoredBrookCell = ProgressionCatalog.gatherNodeList.first {
            $0.id == ContentID.restoredBrookGather
        }!.position
        XCTAssertEqual(state.watershed.restorationPoints, 0)
        XCTAssertEqual(state.watershed.ambienceLabel, "干涸层")
        XCTAssertFalse(catalog.isRecipeUnlocked(ContentID.rainBarrelRecipe, watershed: state.watershed))
        XCTAssertNil(
            catalog.gatherNode(at: restoredBrookCell, mapID: ContentID.creekMarket, state: state)
        )

        XCTAssertTrue(placeCanal(&state))
        XCTAssertEqual(state.watershed.restorationPoints, 12)
        XCTAssertEqual(state.watershed.appliedContributionIDs, [ContentID.placeCanalContribution])
        XCTAssertFalse(state.watershed.isRestored)
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .readyToTurnIn)

        let afterTwelve = state
        XCTAssertTrue(placeCanal(&state))
        XCTAssertEqual(state.watershed.restorationPoints, 12)
        XCTAssertEqual(state.watershed.appliedContributionIDs, afterTwelve.watershed.appliedContributionIDs)

        state = try! CanalProgressionService.deliverCanalRepair(state: state, catalog: catalog).get()
        XCTAssertEqual(state.watershed.restorationPoints, 20)
        XCTAssertTrue(state.watershed.isRestored)
        XCTAssertEqual(state.watershed.ambienceLayerID, ContentID.flowingWaterAmbience)
        XCTAssertTrue(catalog.isRecipeUnlocked(ContentID.rainBarrelRecipe, watershed: state.watershed))
        XCTAssertNotNil(
            catalog.gatherNode(at: restoredBrookCell, mapID: ContentID.creekMarket, state: state)
        )
        XCTAssertEqual(
            WorldVariant.landmarkLabel(
                MapLandmarkDefinition(
                    id: "brookseed.landmark.market_blocked_mouth",
                    label: "阻塞水口",
                    position: GridPosition(x: 9, y: 0)
                ),
                restored: true
            ),
            "复流水口"
        )

        let afterTwenty = state
        state = try! CanalProgressionService.deliverCanalRepair(state: state, catalog: catalog).get()
        XCTAssertEqual(state.watershed.restorationPoints, 20)
        XCTAssertEqual(state.watershed.unlockedNodes, afterTwenty.watershed.unlockedNodes)
        XCTAssertEqual(state.watershed.completedProjects, [ContentID.canalSegmentProject])
    }

    func testContributionSourceOrderAndRepeatAreEnforced() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let wrongSource = WatershedService.apply(
            state: state,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        )
        XCTAssertEqual(wrongSource, .failure(.sourceMismatch))
        XCTAssertEqual(state.watershed.restorationPoints, 0)

        let earlyDeliver = WatershedService.apply(
            state: state,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        )
        XCTAssertEqual(earlyDeliver, .failure(.missingPrerequisite))
        XCTAssertEqual(state.watershed.restorationPoints, 0)

        state = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get().state
        XCTAssertEqual(state.watershed.restorationPoints, 12)

        let repeatPlace = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get()
        XCTAssertFalse(repeatPlace.didApply)
        XCTAssertEqual(repeatPlace.state.watershed.restorationPoints, 12)

        state = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ).get().state
        XCTAssertEqual(state.watershed.restorationPoints, 20)

        let repeatDeliver = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ).get()
        XCTAssertFalse(repeatDeliver.didApply)
        XCTAssertEqual(repeatDeliver.state.watershed.restorationPoints, 20)
        XCTAssertEqual(repeatDeliver.state.watershed.unlockedNodes, state.watershed.unlockedNodes)
    }

    func testFailedCraftAndPlaceDoNotAdvanceQuestOrWatershed() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(grant(&state, itemID: ContentID.creekWood, quantity: 5))
        XCTAssertTrue(grant(&state, itemID: ContentID.mossStone, quantity: 4))
        let beforeCraft = state
        XCTAssertEqual(
            CraftingService.craft(state: state, recipeID: ContentID.canalSegmentRecipe, catalog: catalog),
            .failure(.insufficientMaterials)
        )
        XCTAssertEqual(state, beforeCraft)
        XCTAssertEqual(state.watershed.restorationPoints, 0)
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .notStarted)

        var placeState = GameState.vs0NewGame(catalog: catalog)
        placeState.position = GridPosition(x: 7, y: 3)
        let beforePlace = placeState
        let feedback = commands.place(
            state: &placeState,
            definitionID: ContentID.canalSegmentObject,
            origin: GridPosition(x: 7, y: 4),
            facing: .up
        )
        XCTAssertFalse(feedback.isSuccess)
        XCTAssertEqual(placeState, beforePlace)
        XCTAssertTrue(placeState.placedObjects.isEmpty)
        XCTAssertEqual(placeState.watershed.restorationPoints, 0)

        var conflict = GameState.vs0NewGame(catalog: catalog)
        conflict.position = GridPosition(x: 4, y: 2)
        XCTAssertTrue(grant(&conflict, itemID: ContentID.canalSegmentItem, quantity: 1))
        let beforeConflict = conflict
        let blocked = commands.place(
            state: &conflict,
            definitionID: ContentID.canalSegmentObject,
            origin: GridPosition(x: 4, y: 3),
            facing: .up
        )
        XCTAssertFalse(blocked.isSuccess)
        XCTAssertEqual(conflict.inventory, beforeConflict.inventory)
        XCTAssertEqual(conflict.watershed, beforeConflict.watershed)
        XCTAssertTrue(conflict.placedObjects.isEmpty)
    }

    func testRainBarrelStaysLockedUntilTwentyAndDoesNotConsume() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(grant(&state, itemID: ContentID.creekWood, quantity: 12))
        XCTAssertTrue(grant(&state, itemID: ContentID.mossStone, quantity: 6))
        let before = state
        XCTAssertEqual(
            CraftingService.craft(state: state, recipeID: ContentID.rainBarrelRecipe, catalog: catalog),
            .failure(.recipeLocked)
        )
        XCTAssertEqual(state, before)

        state = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get().state
        state = try! WatershedService.apply(
            state: state,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ).get().state
        let crafted = CraftingService.craft(
            state: state,
            recipeID: ContentID.rainBarrelRecipe,
            catalog: catalog
        )
        guard case .success(let next) = crafted else {
            return XCTFail("rain barrel should craft after 20")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.rainBarrelItem), 1)
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.creekWood), 0)
    }

    func testMainlinePathDoesNotReadStandingFields() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertTrue(placeCanal(&state))
        state = try! CanalProgressionService.deliverCanalRepair(state: state, catalog: catalog).get()
        XCTAssertEqual(state.watershed.restorationPoints, 20)
        XCTAssertEqual(QuestService.status(of: ContentID.restoreOldCanalQuest, in: state), .completed)
        XCTAssertNil(catalog.quest(id: ContentID.restoreOldCanalQuest)?.minStanding)
    }

    @discardableResult
    private func placeCanal(_ state: inout GameState) -> Bool {
        if InventoryService.count(state.inventory, itemID: ContentID.canalSegmentItem) == 0 {
            _ = grant(&state, itemID: ContentID.canalSegmentItem, quantity: 1)
        }
        state.position = GridPosition(x: 7, y: 3)
        let origin = GridPosition(x: 7, y: 4)
        if state.placedObjects.contains(where: { $0.origin == origin }) {
            let feedback = commands.place(
                state: &state,
                definitionID: ContentID.canalSegmentObject,
                origin: GridPosition(x: 6, y: 3),
                facing: .up
            )
            return feedback.isSuccess || state.watershed.restorationPoints >= 12
        }
        let feedback = commands.place(
            state: &state,
            definitionID: ContentID.canalSegmentObject,
            origin: origin,
            facing: .up
        )
        return feedback.isSuccess
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
}
