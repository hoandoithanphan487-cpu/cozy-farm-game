import Foundation
import XCTest
@testable import CreekSprout

/// M4-001: multi-slot saves, UX fixes, performance helpers, and schema v8 recipe memory.
final class M4SaveAndUxTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-M4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testManualSlotsAreIsolated() throws {
        var first = GameState.vs0NewGame(catalog: catalog)
        first.clock = GameClock(day: 3, minute: 600)
        first.economy.balance = 111
        var second = GameState.vs0NewGame(catalog: catalog)
        second.clock = GameClock(day: 5, minute: 720)
        second.economy.balance = 222
        var third = GameState.vs0NewGame(catalog: catalog)
        third.clock = GameClock(day: 7, minute: 800)
        third.economy.balance = 333

        let store1 = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[0], catalog: catalog)
        let store2 = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[1], catalog: catalog)
        let store3 = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[2], catalog: catalog)
        try store1.save(first)
        try store2.save(second)
        try store3.save(third)

        XCTAssertEqual(try store1.load().economy.balance, 111)
        XCTAssertEqual(try store2.load().economy.balance, 222)
        XCTAssertEqual(try store3.load().economy.balance, 333)
    }

    func testAutoSlotSeparateFromManual() throws {
        var manual = GameState.vs0NewGame(catalog: catalog)
        manual.economy.balance = 500
        var auto = GameState.vs0NewGame(catalog: catalog)
        auto.clock = GameClock(day: 4, minute: 1000)
        auto.economy.balance = 900

        let manualStore = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[0], catalog: catalog)
        let autoStore = SaveStore(directory: directory, slotName: SaveSlotCatalog.autoSlotName, catalog: catalog)
        try manualStore.save(manual)
        try autoStore.save(auto)

        XCTAssertEqual(try manualStore.load().economy.balance, 500)
        XCTAssertEqual(try autoStore.load().clock.day, 4)
        XCTAssertEqual(try autoStore.load().economy.balance, 900)
    }

    func testSleepWritesAutoSlotOnly() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.economy.shipping.pendingEntries = [
            ShippingEntry(
                entryID: "e1",
                itemID: ContentID.mistRadishItem,
                quantity: 3,
                quality: .normal,
                depositedDay: 1,
                unitPriceSnapshot: 58
            ),
        ]
        let autoStore = SaveStore(directory: directory, slotName: SaveSlotCatalog.autoSlotName, catalog: catalog)
        let manualStore = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[0], catalog: catalog)
        _ = try SleepUseCase().sleep(state: &state, clock: ClockSystem(), catalog: catalog, store: autoStore)

        XCTAssertNoThrow(try autoStore.load())
        XCTAssertThrowsError(try manualStore.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .missingSave)
        }
    }

    func testSaveFailureDoesNotCorruptValidGeneration() throws {
        let store = SaveStore(directory: directory, slotName: SaveSlotCatalog.manualSlotNames[0], catalog: catalog)
        var valid = GameState.vs0NewGame(catalog: catalog)
        valid.economy.balance = 777
        try store.save(valid)

        let readOnlyDirectory = directory.appendingPathComponent("readonly-slot", isDirectory: true)
        try FileManager.default.createDirectory(at: readOnlyDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: readOnlyDirectory.path)
        let failingStore = SaveStore(
            directory: readOnlyDirectory,
            slotName: SaveSlotCatalog.manualSlotNames[1],
            catalog: catalog
        )
        var candidate = GameState.vs0NewGame(catalog: catalog)
        candidate.economy.balance = 999
        XCTAssertThrowsError(try failingStore.save(candidate))

        let reloaded = try store.load()
        XCTAssertEqual(reloaded.economy.balance, 777)
    }

    func testRecipePersistsInSchemaV8Save() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        state.selectedRecipeID = ContentID.canalSegmentRecipe
        try store.save(state)
        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as? [String: Any]
        XCTAssertEqual((payload?["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        XCTAssertEqual(payload?["selected_recipe_id"] as? String, ContentID.canalSegmentRecipe)
        let loaded = try store.load()
        XCTAssertEqual(loaded.selectedRecipeID, ContentID.canalSegmentRecipe)
    }

    func testV7SaveMigratesSelectedRecipeDefault() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        var payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as? [String: Any]
        payload?["schema_version"] = 7
        payload?.removeValue(forKey: "selected_recipe_id")
        let v7 = try JSONSerialization.data(withJSONObject: payload!, options: [.prettyPrinted])
        let migrated = try SaveMigrator.migrate(v7)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertNil(migrated.selectedRecipeID)
    }

    func testSteppingOnExitDoesNotTravel() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.currentMapID = ContentID.farmHomestead
        state.position = GridPosition(x: 5, y: 0)
        state.facing = .down
        let beforeMap = state.currentMapID
        _ = MapTravelService.tryMove(state: &state, direction: .up, catalog: catalog)
        XCTAssertEqual(state.currentMapID, beforeMap)
    }

    func testFacingExitAndInteractTravels() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.currentMapID = ContentID.farmHomestead
        state.position = GridPosition(x: 5, y: 0)
        state.facing = .up
        let result = MapTravelService.interactWithExit(state: &state, catalog: catalog)
        XCTAssertTrue(result?.didTravel == true)
        XCTAssertEqual(state.currentMapID, ContentID.creekMarket)
    }

    func testWatershedDisplayWhenOverThresholdWithCorrection() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.watershed.restorationPoints = 22
        state.watershed.appliedContributionIDs = [ContentID.correctDBonusContribution]
        let line = HudCopy.watershedLine(state: state, catalog: catalog)
        XCTAssertTrue(line.contains("20 已达成"))
        XCTAssertTrue(line.contains("含纠正 +2 → 22"))
    }

    func testDay3GoalDoesNotRepeatVerificationTutorial() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.tutorial.currentStepID = ContentID.tutorialNextDay
        state.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
        state.watershed.restorationPoints = 2
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.startVerificationAction,
            npcID: ContentID.neighborHearsay
        )
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.verifyWithCAction,
            npcID: ContentID.neighborEvidence
        )
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.correctDAction,
            npcID: ContentID.neighborConsensus
        )
        let goal = TutorialService(catalog: catalog).goalLine(for: state)
        XCTAssertFalse(goal.contains("开始核实"))
        XCTAssertFalse(goal.contains("向青砚核实"))
        XCTAssertTrue(goal.contains("让旧水渠再次流动") || goal.contains("水渠"))
    }

    func testVerificationHintSuppressedAfterCorrectionOnDay3() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 3, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.startVerificationAction,
            npcID: ContentID.neighborHearsay
        )
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.verifyWithCAction,
            npcID: ContentID.neighborEvidence
        )
        _ = CommunityCommandService(catalog: catalog).submit(
            state: &state,
            actionID: ContentID.correctDAction,
            npcID: ContentID.neighborConsensus
        )
        let hint = CommunityCommandService(catalog: catalog).verificationPathLine(state: state)
        XCTAssertTrue(hint.isEmpty)
    }

    func testFarmSceneRestoresRecipeAfterLoad() {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        scene.cycleRecipe()
        let savedRecipe = scene.hudText
            .components(separatedBy: "\n")
            .first(where: { $0.hasPrefix("配方 ") })?
            .replacingOccurrences(of: "配方 ", with: "") ?? ""
        XCTAssertFalse(savedRecipe.isEmpty)
        scene.saveGame(toSlot: 0)
        scene.cycleRecipe()
        scene.cycleRecipe()
        scene.loadGame(fromSlot: 0)
        XCTAssertTrue(scene.hudText.contains("配方 \(savedRecipe)"))
    }

    func testCompactHudContainsFoldHint() {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        let compact = scene.hudText(compact: true)
        XCTAssertTrue(compact.contains("HUD 已折叠"))
        XCTAssertTrue(compact.contains("【状态】"))
        XCTAssertFalse(compact.contains("【按键】"))
    }

    func testFrameTimeSamplerPercentiles() {
        var sampler = FrameTimeSampler(warmupSeconds: 0)
        for _ in 0..<50 {
            Thread.sleep(forTimeInterval: 0.001)
            sampler.recordFrameDuration(seconds: 0.001)
        }
        XCTAssertGreaterThanOrEqual(sampler.postWarmupSampleCount, 40)
        XCTAssertNotNil(sampler.p95Ms)
        XCTAssertNotNil(sampler.p99Ms)
    }

    func testMapLoadTimerRecordsSuccessfulTransition() {
        var timer = MapLoadTimer()
        timer.beginLoad()
        Thread.sleep(forTimeInterval: 0.005)
        timer.finishLoad()
        XCTAssertEqual(timer.samplesMs.count, 1)
        XCTAssertGreaterThan(timer.samplesMs[0], 4)
    }

    func testMapTravelDoesNotRecordCancelledLoad() {
        var timer = MapLoadTimer()
        timer.beginLoad()
        timer.cancelLoad()
        timer.finishLoad()
        XCTAssertTrue(timer.samplesMs.isEmpty)
    }
}
