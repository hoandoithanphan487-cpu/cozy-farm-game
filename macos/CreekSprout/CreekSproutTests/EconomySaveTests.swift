import Foundation
import XCTest
@testable import CreekSprout

final class EconomySaveTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-m2-save-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testPendingShippingRoundTripsAcrossSaveAndLoad() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 3)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        let pending = state.economy.shipping.pendingEntries

        try store.save(state)
        let loaded = try store.load()

        XCTAssertEqual(loaded.economy.shipping.pendingEntries, pending)
        XCTAssertEqual(loaded.economy.shipping.pendingEntries[0].quantity, 3)
        XCTAssertEqual(
            loaded.economy.shipping.pendingEntries[0].unitPriceSnapshot,
            EconomyCatalog(content: catalog).unitPrice(itemID: ContentID.mistRadishItem, quality: .normal)
        )
    }

    func testV2EconomyAndPlacementRoundTrip() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        state = try PlacementService.place(
            state: {
                var next = state
                next.position = GridPosition(x: 2, y: 4)
                XCTAssertTrue(grant(&next, itemID: ContentID.woodenCrateItem))
                return next
            }(),
            definitionID: ContentID.woodenCrateObject,
            origin: GridPosition(x: 2, y: 5),
            facing: .up,
            catalog: catalog
        ).get()
        let settled = SettleShippingUseCase.settle(state: state, catalog: catalog)
        state = settled.state

        try store.save(state)
        let payload = decodedJSON(at: store.primaryURL)
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        XCTAssertEqual(payload["scenario_id"] as? String, ContentID.vs0Scenario)

        let loaded = try store.load()
        XCTAssertEqual(loaded, state)
        XCTAssertEqual(loaded.economy.balance, state.economy.balance)
        XCTAssertEqual(loaded.economy.settlementHistory.count, 1)
        XCTAssertEqual(loaded.placedObjects.count, 1)
        XCTAssertTrue(loaded.economy.shipping.pendingEntries.isEmpty)
    }

    func testV1SaveMigratesStartingCurrencyAndGrantLedger() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        let v1 = """
        {
          "schema_version": 1,
          "position": { "x": 5, "y": 4 },
          "facing": "down",
          "clock": { "day": 1, "minute": 390 },
          "stamina": 86,
          "inventoryCapacity": 16,
          "inventory": [
            { "itemID": "brookseed.item.mist_radish_seed", "quantity": 8 }
          ],
          "farmCells": []
        }
        """
        try Data(v1.utf8).write(to: store.primaryURL, options: .atomic)

        let loaded = try store.load()
        XCTAssertEqual(try SaveMigrator.migrate(Data(v1.utf8)).schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(loaded.scenarioID, ContentID.vs0Scenario)
        XCTAssertEqual(loaded.economy.balance, catalog.scenario.startingCurrency)
        XCTAssertTrue(loaded.economy.shipping.pendingEntries.isEmpty)
        XCTAssertTrue(loaded.economy.settlementHistory.isEmpty)
        XCTAssertTrue(loaded.placedObjects.isEmpty)
        XCTAssertEqual(loaded.economy.ledger.count, 1)
        XCTAssertEqual(loaded.economy.ledger[0].reasonID, ContentID.migrationGrantReason)
        XCTAssertEqual(loaded.economy.ledger[0].amount, catalog.scenario.startingCurrency)
        XCTAssertEqual(loaded.stamina, 86)
    }

    func testReloadingSettledSaveDoesNotPayAgain() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 3)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        state = SettleShippingUseCase.settle(state: state, catalog: catalog).state
        let balance = state.economy.balance
        try store.save(state)

        let firstLoad = try store.load()
        XCTAssertEqual(firstLoad.economy.balance, balance)
        let secondLoad = try store.load()
        XCTAssertEqual(secondLoad.economy.balance, balance)
        let retry = SettleShippingUseCase.settle(state: secondLoad, catalog: catalog)
        XCTAssertTrue(retry.wasAlreadySettled)
        XCTAssertEqual(retry.state.economy.balance, balance)
    }

    func testNegativeBalanceSaveIsRejectedWithoutPartialLoad() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        try? FileManager.default.removeItem(at: store.backupURL)
        var payload = decodedJSON(at: store.primaryURL)
        var economy = payload["economy"] as! [String: Any]
        economy["balance"] = -1
        payload["economy"] = economy
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    func testDuplicateSettlementIDsAreRejected() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        state = SettleShippingUseCase.settle(state: state, catalog: catalog).state
        try store.save(state)
        try? FileManager.default.removeItem(at: store.backupURL)

        var payload = decodedJSON(at: store.primaryURL)
        var economy = payload["economy"] as! [String: Any]
        let history = economy["settlement_history"] as! [[String: Any]]
        economy["settlement_history"] = history + history
        payload["economy"] = economy
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    func testOutOfBoundsPlacedObjectIsRejected() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        try? FileManager.default.removeItem(at: store.backupURL)
        var payload = decodedJSON(at: store.primaryURL)
        payload["placed_objects"] = [
            [
                "instance_id": "illegal-placement",
                "definition_id": ContentID.woodenCrateObject,
                "origin": ["x": 10, "y": 0],
                "facing": "up",
            ],
        ]
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    func testPendingQuantityAboveCapIsRejectedAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack { payload in
            mutateFirstPending(in: &payload) { $0["quantity"] = SaveValidation.maxShippingQuantity + 1 }
        }
    }

    func testUnitPriceSnapshotAboveCapIsRejectedAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack { payload in
            mutateFirstPending(in: &payload) { $0["unit_price_snapshot"] = SaveValidation.maxUnitPriceSnapshot + 1 }
        }
    }

    func testPendingLineProductOverflowIsRejectedAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack { payload in
            mutateFirstPending(in: &payload) { entry in
                entry["quantity"] = SaveValidation.maxShippingQuantity
                entry["unit_price_snapshot"] = 20_000
            }
        }
    }

    func testUnsortedPendingEntriesAreRejectedAndFallsBack() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        state.clock.day = 2
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        XCTAssertEqual(state.economy.shipping.pendingEntries.count, 2)
        try assertCorruptionRejectedAndFallsBack(valid: state) { payload in
            var economy = payload["economy"] as! [String: Any]
            var shipping = economy["shipping"] as! [String: Any]
            let pending = shipping["pending_entries"] as! [[String: Any]]
            shipping["pending_entries"] = Array(pending.reversed())
            economy["shipping"] = shipping
            payload["economy"] = economy
        }
    }

    func testEntryIDMustMatchMergeKeyAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack { payload in
            mutateFirstPending(in: &payload) { $0["entry_id"] = "tampered-entry" }
        }
    }

    func testUnsortedSettlementHistoryIsRejectedAndFallsBack() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        let dayCycle = DayCycleService()
        dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        dayCycle.settle(state: &state, clock: ClockSystem(), catalog: catalog)
        XCTAssertEqual(state.economy.settlementHistory.count, 2)
        try assertCorruptionRejectedAndFallsBack(valid: state) { payload in
            var economy = payload["economy"] as! [String: Any]
            let history = economy["settlement_history"] as! [[String: Any]]
            economy["settlement_history"] = Array(history.reversed())
            payload["economy"] = economy
        }
    }

    func testSettlementLineQuantityAboveCapIsRejectedAndFallsBack() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        state = SettleShippingUseCase.settle(state: state, catalog: catalog).state
        try assertCorruptionRejectedAndFallsBack(valid: state) { payload in
            mutateFirstSettlementLine(in: &payload) { line in
                line["quantity"] = SaveValidation.maxShippingQuantity + 1
            }
        }
    }

    func testSettlementLineAmountAboveCapIsRejectedAndFallsBack() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        state = SettleShippingUseCase.settle(state: state, catalog: catalog).state
        try assertCorruptionRejectedAndFallsBack(valid: state) { payload in
            mutateFirstSettlementLine(in: &payload) { line in
                line["amount"] = SaveValidation.maxLineAmount + 1
            }
        }
    }

    func testPlacementOverlappingPlayerIsRejectedAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack(valid: GameState.vs0NewGame(catalog: catalog)) { payload in
            payload["placed_objects"] = [
                placedObjectJSON(origin: GridPosition(x: 5, y: 4)),
            ]
        }
    }

    func testPlacementOccupyingExitIsRejectedAndFallsBack() throws {
        try assertCorruptionRejectedAndFallsBack(valid: GameState.vs0NewGame(catalog: catalog)) { payload in
            payload["placed_objects"] = [
                placedObjectJSON(origin: catalog.scenario.exitCell),
            ]
        }
    }

    func testPlacementBlockingExitIsRejectedAndFallsBack() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 0, y: 0)
        try assertCorruptionRejectedAndFallsBack(valid: state) { payload in
            payload["placed_objects"] = [
                placedObjectJSON(instanceID: "block-a", origin: GridPosition(x: 1, y: 0)),
                placedObjectJSON(instanceID: "block-b", origin: GridPosition(x: 0, y: 1)),
            ]
        }
    }

    private func decodedJSON(at url: URL) -> [String: Any] {
        let data = try! Data(contentsOf: url)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func assertCorruptionRejectedAndFallsBack(
        valid: GameState? = nil,
        mutate: (inout [String: Any]) -> Void
    ) throws {
        var source = valid ?? GameState.vs0NewGame(catalog: catalog)
        if valid == nil {
            addRadishes(&source, quantity: 1)
            source = try ShippingService.deposit(
                state: source,
                itemID: ContentID.mistRadishItem,
                quantity: 1,
                catalog: catalog
            ).get()
        }
        let store = SaveStore(directory: directory, catalog: catalog)
        var backupState = source
        backupState.stamina = 86
        try store.save(backupState)
        try store.save(source)
        var payload = decodedJSON(at: store.primaryURL)
        mutate(&payload)
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])

        try? FileManager.default.removeItem(at: store.backupURL)
        try illegal.write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)

        try store.save(backupState)
        try store.save(source)
        try illegal.write(to: store.primaryURL, options: .atomic)
        let loaded = try store.load()
        XCTAssertEqual(loaded, backupState)
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    private func mutateFirstPending(in payload: inout [String: Any], _ body: (inout [String: Any]) -> Void) {
        var economy = payload["economy"] as! [String: Any]
        var shipping = economy["shipping"] as! [String: Any]
        var pending = shipping["pending_entries"] as! [[String: Any]]
        body(&pending[0])
        shipping["pending_entries"] = pending
        economy["shipping"] = shipping
        payload["economy"] = economy
    }

    private func mutateFirstSettlementLine(in payload: inout [String: Any], _ body: (inout [String: Any]) -> Void) {
        var economy = payload["economy"] as! [String: Any]
        var history = economy["settlement_history"] as! [[String: Any]]
        var lines = history[0]["lines"] as! [[String: Any]]
        body(&lines[0])
        history[0]["lines"] = lines
        economy["settlement_history"] = history
        payload["economy"] = economy
    }

    private func placedObjectJSON(instanceID: String = "illegal-placement", origin: GridPosition) -> [String: Any] {
        [
            "instance_id": instanceID,
            "definition_id": ContentID.woodenCrateObject,
            "origin": ["x": origin.x, "y": origin.y],
            "facing": "up",
        ]
    }

    private func addRadishes(_ state: inout GameState, quantity: Int) {
        let added = InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: ContentID.mistRadishItem,
            quantity: quantity,
            stackLimit: catalog.stackLimit(for: ContentID.mistRadishItem)
        )
        guard case .success(let inventory) = added else {
            return XCTFail("could not add radishes")
        }
        state.inventory = inventory
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
