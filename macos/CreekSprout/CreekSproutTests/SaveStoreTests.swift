import Foundation
import XCTest
@testable import CreekSprout

final class SaveStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSproutTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testFarmStaminaInventoryAndClockRoundTrip() throws {
        let store = SaveStore(directory: directory)
        var original = GameState.m1NewGame(seedQuantity: 5)
        original.position = GridPosition(x: 7, y: 3)
        original.facing = .right
        original.clock = GameClock(day: 4, minute: 900)
        original.stamina = 86
        original.inventoryCapacity = 16
        original.farmCells[GridPosition(x: 2, y: 1)] = FarmCell(
            prepared: true,
            wateredToday: true,
            cropID: ContentID.mistRadishCrop,
            cropStage: 1,
            stageProgressDays: 1,
            plantedDay: 3
        )
        original.farmCells[GridPosition(x: 8, y: 4)] = FarmCell(prepared: true)

        try store.save(original)
        let loaded = try store.load()

        XCTAssertEqual(loaded, original)
        XCTAssertEqual(loaded.position, GridPosition(x: 7, y: 3))
        XCTAssertEqual(loaded.clock, GameClock(day: 4, minute: 900))
        XCTAssertEqual(loaded.stamina, 86)
        XCTAssertEqual(loaded.inventoryCapacity, 16)
        XCTAssertEqual(InventoryService.count(loaded.inventory, itemID: ContentID.mistRadishSeed), 5)
        XCTAssertTrue(loaded.cell(at: GridPosition(x: 2, y: 1)).wateredToday)
        XCTAssertTrue(loaded.cell(at: GridPosition(x: 8, y: 4)).prepared)
    }

    func testCorruptPrimaryIsNotOverwritten() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.spikeDefault)

        let corrupt = Data("{not-json".utf8)
        try corrupt.write(to: store.primaryURL, options: .atomic)
        try? FileManager.default.removeItem(at: store.backupURL)
        let before = try Data(contentsOf: store.primaryURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }

        let after = try Data(contentsOf: store.primaryURL)
        XCTAssertEqual(before, after)
        XCTAssertEqual(after, corrupt)
    }

    func testValidBackupIsLoadedWhenPrimaryIsCorrupt() throws {
        let store = SaveStore(directory: directory)
        var first = GameState.m1NewGame(seedQuantity: 3)
        first.position = GridPosition(x: 1, y: 1)
        first.clock = GameClock(day: 1, minute: GameClock.dayStartMinute)
        var second = GameState.m1NewGame(seedQuantity: 9)
        second.position = GridPosition(x: 8, y: 4)
        second.clock = GameClock(day: 2, minute: 720)
        second.stamina = 88

        try store.save(first)
        try store.save(second)

        let corrupt = Data("%corrupt-primary%".utf8)
        try corrupt.write(to: store.primaryURL, options: .atomic)

        let loaded = try store.load()
        XCTAssertEqual(loaded, first)

        let primaryAfterLoad = try Data(contentsOf: store.primaryURL)
        XCTAssertEqual(primaryAfterLoad, corrupt)
    }

    func testMissingSaveFailsSafely() {
        let store = SaveStore(directory: directory)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .missingSave)
        }
    }

    func testUnknownStableIDIsRejected() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.m1NewGame())
        var payload = decodedJSON(at: store.primaryURL)
        payload["inventory"] = [
            ["itemID": "brookseed.item.unknown_widget", "quantity": 1],
        ]
        let unknown = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try unknown.write(to: store.primaryURL, options: .atomic)
        let before = try Data(contentsOf: store.primaryURL)
        try? FileManager.default.removeItem(at: store.backupURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), before)
    }

    func testDuplicateCoordinatesAndIllegalQuantitiesAreRejected() throws {
        let store = SaveStore(directory: directory)

        var duplicatePayload = decodedJSONFromState(GameState.m1NewGame())
        duplicatePayload["farmCells"] = [
            farmCellJSON(x: 2, y: 3),
            farmCellJSON(x: 2, y: 3),
        ]
        try JSONSerialization.data(withJSONObject: duplicatePayload, options: [.prettyPrinted])
            .write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }

        var zeroPayload = decodedJSONFromState(GameState.m1NewGame())
        zeroPayload["inventory"] = [
            ["itemID": ContentID.mistRadishSeed, "quantity": 0],
        ]
        try JSONSerialization.data(withJSONObject: zeroPayload, options: [.prettyPrinted])
            .write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }

        var overflowPayload = decodedJSONFromState(GameState.m1NewGame())
        overflowPayload["inventory"] = [
            ["itemID": ContentID.mistRadishSeed, "quantity": 100],
        ]
        try JSONSerialization.data(withJSONObject: overflowPayload, options: [.prettyPrinted])
            .write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
    }

    func testPrimaryAndBackupBothInvalidKeepFilesAndFailSafely() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.m1NewGame())
        try store.save(GameState.m1NewGame(seedQuantity: 4))

        let corruptPrimary = Data("%corrupt-primary%".utf8)
        let corruptBackup = Data("%corrupt-backup%".utf8)
        try corruptPrimary.write(to: store.primaryURL, options: .atomic)
        try corruptBackup.write(to: store.backupURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), corruptPrimary)
        XCTAssertEqual(try Data(contentsOf: store.backupURL), corruptBackup)
    }

    func testFullStackThenSecondStackOfSameItemRoundTrips() throws {
        let store = SaveStore(directory: directory)
        var state = GameState.m1NewGame(seedQuantity: 0)
        let first = InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: ContentID.mistRadishSeed,
            quantity: 99
        )
        guard case .success(let fullStack) = first else {
            return XCTFail("expected a full stack")
        }
        let second = InventoryService.tryAdd(
            fullStack,
            capacity: state.inventoryCapacity,
            itemID: ContentID.mistRadishSeed,
            quantity: 1
        )
        guard case .success(let twoStacks) = second else {
            return XCTFail("expected a second stack of the same item")
        }
        state.inventory = twoStacks

        try store.save(state)
        let loaded = try store.load()

        XCTAssertEqual(loaded.inventory, twoStacks)
        XCTAssertEqual(InventoryService.count(loaded.inventory, itemID: ContentID.mistRadishSeed), 100)
        XCTAssertEqual(loaded.inventory.map(\.itemID), [ContentID.mistRadishSeed, ContentID.mistRadishSeed])
    }

    func testFarmCellsOutsideTenBySixAreRejected() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.m1NewGame())
        try? FileManager.default.removeItem(at: store.backupURL)

        let invalidCoordinates = [
            GridPosition(x: -1, y: 0),
            GridPosition(x: 10, y: 0),
            GridPosition(x: 0, y: 6),
        ]
        for coordinate in invalidCoordinates {
            XCTAssertFalse(coordinate.isInsideFarm)
            var payload = decodedJSON(at: store.primaryURL)
            payload["farmCells"] = [farmCellJSON(x: coordinate.x, y: coordinate.y)]
            let before = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try before.write(to: store.primaryURL, options: .atomic)
            XCTAssertThrowsError(try store.load()) { error in
                XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
            }
            XCTAssertEqual(try Data(contentsOf: store.primaryURL), before)
        }
    }

    func testCurrentSchemaVersionRoundTrips() throws {
        let store = SaveStore(directory: directory)
        let original = GameState.m1NewGame(seedQuantity: 4)
        try store.save(original)

        let payload = decodedJSON(at: store.primaryURL)
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        XCTAssertEqual(try store.load(), original)
    }

    func testUnversionedSpikeSaveMigratesFromV0() throws {
        let store = SaveStore(directory: directory)
        let spike = """
        {
          "position": { "x": 4, "y": 2 },
          "clock": { "day": 1, "minute": 480 },
          "inventory": { "itemID": "mist_radish_seed", "quantity": 1 }
        }
        """
        try Data(spike.utf8).write(to: store.primaryURL, options: .atomic)

        let loaded = try store.load()
        XCTAssertEqual(loaded.position, GridPosition(x: 4, y: 2))
        XCTAssertEqual(loaded.clock, GameClock(day: 1, minute: 480))
        XCTAssertEqual(loaded.facing, .down)
        XCTAssertEqual(loaded.stamina, 100)
        XCTAssertEqual(loaded.inventoryCapacity, 16)
        XCTAssertEqual(
            loaded.inventory,
            [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 1)]
        )
        XCTAssertTrue(loaded.farmCells.isEmpty)
        XCTAssertEqual(try SaveMigrator.migrate(try Data(contentsOf: store.primaryURL)).schemaVersion, SaveSchema.currentVersion)
    }

    func testUnknownFutureSchemaIsRejectedWithoutOverwriting() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.m1NewGame())
        var payload = decodedJSON(at: store.primaryURL)
        payload["schema_version"] = SaveSchema.currentVersion + 1
        let future = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try future.write(to: store.primaryURL, options: .atomic)
        try? FileManager.default.removeItem(at: store.backupURL)

        XCTAssertThrowsError(try SaveMigrator.migrate(future)) { error in
            XCTAssertEqual(error as? SaveStoreError, .unsupportedSchema)
        }
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), future)
    }

    private func decodedJSON(at url: URL) -> [String: Any] {
        let data = try! Data(contentsOf: url)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func decodedJSONFromState(_ state: GameState) -> [String: Any] {
        let data = try! SaveCodec.encode(state)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func farmCellJSON(x: Int, y: Int) -> [String: Any] {
        [
            "x": x,
            "y": y,
            "prepared": true,
            "wateredToday": false,
            "fertility": 0,
            "cropID": "",
            "cropStage": 0,
            "stageProgressDays": 0,
            "plantedDay": 0,
            "readyToHarvest": false,
        ]
    }
}
