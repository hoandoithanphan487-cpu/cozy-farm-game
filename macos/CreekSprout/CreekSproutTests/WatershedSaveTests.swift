import Foundation
import XCTest
@testable import CreekSprout

final class WatershedSaveTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-m3-002-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testTwelveAndTwentyRoundTripWithoutRepeatAwards() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var twelve = GameState.vs0NewGame(catalog: catalog)
        twelve = try WatershedService.apply(
            state: twelve,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get().state
        twelve = try QuestService.markCanalPlaced(state: twelve, catalog: catalog).get()
        twelve.harvestedGatherNodeIDs = [ContentID.farmWoodGather]
        twelve.position = GridPosition(x: 7, y: 3)

        try store.save(twelve)
        let payload = decodedJSON(at: store.primaryURL)
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        let loadedTwelve = try store.load()
        XCTAssertEqual(loadedTwelve.watershed.restorationPoints, 12)
        XCTAssertEqual(loadedTwelve.watershed.appliedContributionIDs, [ContentID.placeCanalContribution])
        XCTAssertEqual(loadedTwelve.harvestedGatherNodeIDs, [ContentID.farmWoodGather])
        XCTAssertEqual(
            QuestService.status(of: ContentID.restoreOldCanalQuest, in: loadedTwelve),
            .readyToTurnIn
        )
        XCTAssertFalse(loadedTwelve.watershed.isRestored)
        let repeatTwelve = try WatershedService.apply(
            state: loadedTwelve,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get()
        XCTAssertFalse(repeatTwelve.didApply)
        XCTAssertEqual(repeatTwelve.state.watershed.restorationPoints, 12)

        let twenty = try CanalProgressionService.deliverCanalRepair(
            state: loadedTwelve,
            catalog: catalog
        ).get()
        try store.save(twenty)
        let loadedTwenty = try store.load()
        XCTAssertEqual(loadedTwenty, twenty)
        XCTAssertEqual(loadedTwenty.watershed.restorationPoints, 20)
        XCTAssertTrue(loadedTwenty.watershed.isRestored)
        XCTAssertTrue(loadedTwenty.watershed.unlockedNodes.contains(ContentID.rainBarrelUnlock))
        XCTAssertTrue(loadedTwenty.watershed.unlockedNodes.contains(ContentID.restoredBrookGather))
        XCTAssertEqual(loadedTwenty.watershed.ambienceLayerID, ContentID.flowingWaterAmbience)
        let repeatTwenty = try WatershedService.apply(
            state: loadedTwenty,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ).get()
        XCTAssertFalse(repeatTwenty.didApply)
        XCTAssertEqual(repeatTwenty.state.watershed.restorationPoints, 20)
        XCTAssertEqual(repeatTwenty.state.watershed.unlockedNodes, loadedTwenty.watershed.unlockedNodes)
    }

    func testV4SaveMigratesToEmptyWatershedAndQuestLog() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 5, y: 4)
        try store.save(state)
        var payload = decodedJSON(at: store.primaryURL)
        payload["schema_version"] = 4
        payload.removeValue(forKey: "watershed")
        payload.removeValue(forKey: "quest_log")
        payload.removeValue(forKey: "harvested_gather_node_ids")
        let v4 = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try v4.write(to: store.primaryURL, options: .atomic)

        let migrated = try SaveMigrator.migrate(v4)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(migrated.watershed.restorationPoints, 0)
        XCTAssertTrue(migrated.watershed.appliedContributionIDs.isEmpty)
        XCTAssertTrue(migrated.questLog.entries.isEmpty)
        XCTAssertTrue(migrated.harvestedGatherNodeIDs.isEmpty)

        let loaded = try store.load()
        XCTAssertEqual(loaded.watershed, .empty)
        XCTAssertEqual(loaded.currentMapID, ContentID.farmHomestead)
        XCTAssertEqual(loaded.economy.balance, 720)
        XCTAssertTrue(loaded.harvestedGatherNodeIDs.isEmpty)
    }

    func testZeroTwelveTwentySavesRemainLegalAfterReload() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        let zero = GameState.vs0NewGame(catalog: catalog)
        try store.save(zero)
        XCTAssertEqual(try store.load().watershed.restorationPoints, 0)

        var twelve = zero
        twelve = try WatershedService.apply(
            state: twelve,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ).get().state
        try store.save(twelve)
        XCTAssertEqual(try store.load().watershed.restorationPoints, 12)

        var twenty = twelve
        twenty = try WatershedService.apply(
            state: twenty,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ).get().state
        try store.save(twenty)
        let loaded = try store.load()
        XCTAssertEqual(loaded.watershed.restorationPoints, 20)
        XCTAssertEqual(loaded.watershed.unlockedNodes.sorted(), ContentID.watershedThresholdUnlockIDs.sorted())
    }

    private func decodedJSON(at url: URL) -> [String: Any] {
        let data = try! Data(contentsOf: url)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
