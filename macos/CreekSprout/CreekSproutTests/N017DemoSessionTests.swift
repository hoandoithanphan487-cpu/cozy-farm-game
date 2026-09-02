import Foundation
import SpriteKit
import XCTest
@testable import CreekSprout

final class N017DemoSessionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-N017-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testWelcomeCopyIsCompleteAndLocalSinglePlayer() {
        XCTAssertEqual(DemoCopy.title, "溪谷新芽")
        XCTAssertTrue(DemoCopy.subtitle.contains("农场") || DemoCopy.subtitle.contains("新芽农场"))
        XCTAssertTrue(DemoCopy.subtitle.contains("水渠"))
        XCTAssertTrue(DemoCopy.subtitle.contains("邻居") || DemoCopy.subtitle.contains("社区"))
        XCTAssertTrue(DemoCopy.localSinglePlayer.contains("本地单人"))
        XCTAssertEqual(DemoCopy.welcomeItems, ["开始演示", "继续游戏", "设置", "操作说明"])
        XCTAssertEqual(DemoCopy.pauseItems, ["继续", "设置", "操作说明", "重新开始演示", "返回标题"])
        XCTAssertTrue(DemoCopy.confirmRestartBody.contains("不会被改写") || DemoCopy.confirmRestartBody.contains("不会"))
        XCTAssertFalse(DemoCopy.controlsBody.contains("[G]"))
        XCTAssertFalse(DemoCopy.controlsBody.contains("阻"))
        XCTAssertTrue(DemoCopy.controlsBody.contains("成功："))
        XCTAssertTrue(DemoCopy.controlsBody.contains("失败："))
    }

    func testWelcomeAndPauseLayoutsFitTargetResolutions() {
        for size in [CGSize(width: 960, height: 640), CGSize(width: 1_280, height: 800)] {
            let welcome = DemoChromeLayout.welcome(in: size)
            XCTAssertEqual(welcome.buttons.count, 4)
            XCTAssertTrue(welcome.fitsWithoutOverlapOrClipping(in: size), "welcome overlap at \(size)")
            let pause = DemoPauseLayout.pause(in: size)
            XCTAssertEqual(pause.buttons.count, 5)
            XCTAssertTrue(pause.fitsWithoutOverlapOrClipping(in: size), "pause overlap at \(size)")
        }
    }

    func testShellStartsDemoAndEscapeOpensPauseWithRestartConfirm() {
        var shell = DemoShellState()
        XCTAssertEqual(shell.route, .welcome)
        XCTAssertTrue(shell.isClockPaused)
        shell.apply(shell.activateWelcomeSelection())
        XCTAssertEqual(shell.route, .playing)
        XCTAssertEqual(shell.sessionKind, .demo)
        XCTAssertEqual(shell.handleEscape(), .none)
        XCTAssertEqual(shell.overlay, .pause)
        XCTAssertTrue(shell.isClockPaused)
        shell.selectedPauseIndex = 3
        shell.apply(shell.activatePauseSelection())
        XCTAssertEqual(shell.overlay, .restartConfirm)
        XCTAssertEqual(shell.handleEscape(), .cancelRestart)
        XCTAssertEqual(shell.overlay, .pause)
        shell.selectedPauseIndex = 3
        shell.apply(.requestRestartDemo)
        shell.apply(.confirmRestartDemo)
        XCTAssertEqual(shell.sessionKind, .demo)
        XCTAssertEqual(shell.overlay, .none)
        shell.apply(.returnToTitle)
        XCTAssertEqual(shell.route, .welcome)
        XCTAssertEqual(shell.sessionKind, .none)
    }

    func testContinueIsDisabledUntilASaveExists() {
        var shell = DemoShellState(continueAvailable: false)
        shell.selectedWelcomeIndex = 1
        XCTAssertEqual(shell.activateWelcomeSelection(), .none)
        shell.continueAvailable = true
        XCTAssertEqual(shell.activateWelcomeSelection(), .continueGame)
        shell.apply(.continueGame)
        XCTAssertEqual(shell.sessionKind, .continuePlay)
    }

    func testDemoFixtureUsesTeachingCropsAndHearthWithoutDebugIDs() {
        let state = DemoSessionFixture.makeInitialState()
        XCTAssertEqual(DemoSessionFixture.matureTeachingCropCount(state), 3)
        XCTAssertTrue(state.placedObjects.contains { $0.definitionID == ContentID.woodhoneyHearthObject })
        XCTAssertEqual(
            state.placedObjects.first { $0.definitionID == ContentID.woodhoneyHearthObject }?.origin,
            DemoSessionFixture.hearthOrigin
        )
        XCTAssertEqual(state.currentMapID, ContentID.farmHomestead)
        XCTAssertEqual(SaveSchema.currentVersion, 10)
        XCTAssertFalse(state.placedObjects.contains { $0.instanceID.contains("debug") })
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishSeed), 8)

        let crates = state.placedObjects.filter { $0.definitionID == ContentID.woodenCrateObject }
        XCTAssertEqual(crates.count, 1)
        XCTAssertEqual(crates.first?.origin, GridPosition(x: 7, y: 4))
        XCTAssertTrue(crates.first?.instanceID.contains("#7,4#") == true)
        XCTAssertTrue(state.placedObjects.allSatisfy(\.origin.isInsideFarm))
    }

    func testDemoCrateRoundTripsAtItsAuthoritativeCell() throws {
        let store = SaveStore(directory: directory, slotName: "r19-crate", catalog: .vs0)
        let initial = DemoSessionFixture.makeInitialState()
        try store.save(initial)
        let loaded = try store.load()
        let crates = loaded.placedObjects.filter { $0.definitionID == ContentID.woodenCrateObject }
        XCTAssertEqual(crates.count, 1)
        XCTAssertEqual(crates.first?.origin, GridPosition(x: 7, y: 4))
        XCTAssertEqual(loaded.placedObjects.count, initial.placedObjects.count)
    }

    func testDemoSavesDoNotTouchProductionSlots() throws {
        let production = directory.appendingPathComponent("production", isDirectory: true)
        let demo = DemoSessionStore.demoDirectory(root: production)
        try FileManager.default.createDirectory(at: production, withIntermediateDirectories: true)

        var productionState = GameState.vs0NewGame()
        productionState.economy.balance = 1_234
        let productionStore = SaveStore(
            directory: production,
            slotName: SaveSlotCatalog.manualSlotNames[0],
            catalog: .vs0
        )
        try productionStore.save(productionState)
        let autoStore = SaveStore(directory: production, slotName: SaveSlotCatalog.autoSlotName, catalog: .vs0)
        var autoState = GameState.vs0NewGame()
        autoState.economy.balance = 2_222
        try autoStore.save(autoState)
        let before = DemoSessionStore.fingerprint(of: production)

        try DemoSessionStore.resetDemoDirectory(demo)
        let scene = FarmScene(size: CGSize(width: 960, height: 640), saveDirectory: demo)
        scene.replaceSessionState(DemoSessionFixture.makeInitialState())
        var mutated = scene.gameState
        mutated.economy.balance = 50
        scene.replaceSessionState(mutated)
        scene.saveGame()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertTrue(FileManager.default.fileExists(atPath: demo.appendingPathComponent("slot_manual_1.json").path))
        XCTAssertEqual(DemoSessionStore.fingerprint(of: production), before)
        XCTAssertEqual(try productionStore.load().economy.balance, 1_234)
        XCTAssertEqual(try autoStore.load().economy.balance, 2_222)
        XCTAssertTrue(DemoSessionStore.hasContinuableSave(in: production))
        XCTAssertFalse(DemoSessionStore.hasContinuableSave(in: directory.appendingPathComponent("empty")))
    }

    func testRestartingDemoLeavesProductionSavesReadable() throws {
        let production = directory.appendingPathComponent("production", isDirectory: true)
        let demo = DemoSessionStore.demoDirectory(root: production)
        try FileManager.default.createDirectory(at: production, withIntermediateDirectories: true)
        var keep = GameState.vs0NewGame()
        keep.stamina = 77
        try SaveStore(directory: production, slotName: SaveSlotCatalog.manualSlotNames[1], catalog: .vs0).save(keep)
        try DemoSessionStore.resetDemoDirectory(demo)
        let demoScene = FarmScene(size: CGSize(width: 960, height: 640), saveDirectory: demo)
        demoScene.replaceSessionState(DemoSessionFixture.makeInitialState())
        demoScene.saveGame()
        try DemoSessionStore.resetDemoDirectory(demo)
        let restarted = FarmScene(size: CGSize(width: 960, height: 640), saveDirectory: demo)
        restarted.replaceSessionState(DemoSessionFixture.makeInitialState())
        XCTAssertEqual(DemoSessionFixture.matureTeachingCropCount(restarted.gameState), 3)
        let loaded = try SaveStore(
            directory: production,
            slotName: SaveSlotCatalog.manualSlotNames[1],
            catalog: .vs0
        ).load()
        XCTAssertEqual(loaded.stamina, 77)
        let continued = DemoSessionStore.loadBestSave(in: production)
        XCTAssertEqual(continued?.state.stamina, 77)
        XCTAssertEqual(continued?.slotIndex, 1)
    }

    func testMenuPauseStopsClockAndResumeContinuesExistingRule() {
        let scene = FarmScene(
            size: CGSize(width: 960, height: 640),
            saveDirectory: directory
        )
        scene.prepareForPerformanceMeasurement(warmupSeconds: 0)
        scene.setMenuPaused(true)
        XCTAssertTrue(scene.isMenuPaused)
        let pausedClock = scene.gameState.clock
        scene.update(1.0)
        scene.update(1.8)
        XCTAssertEqual(scene.gameState.clock, pausedClock)
        scene.setMenuPaused(false)
        XCTAssertFalse(scene.isMenuPaused)
        scene.update(2.6)
        scene.update(3.4)
        XCTAssertGreaterThan(scene.gameState.clock.minute, pausedClock.minute)
    }

    func testDefaultCompactHudOmitsDebugGlyphsAndCoordinates() {
        let scene = FarmScene(size: CGSize(width: 960, height: 640), saveDirectory: directory)
        scene.replaceSessionState(DemoSessionFixture.makeInitialState())
        let compact = scene.hudText(compact: true)
        let hud = scene.hudPresentationState
        XCTAssertFalse(compact.contains("brookseed."))
        XCTAssertFalse(hud.questLine.contains("brookseed."))
        XCTAssertFalse(compact.contains("[G]"))
        XCTAssertEqual(hud.calendar.mapName, "农场与农舍")
        XCTAssertFalse(hud.questLine.isEmpty)
        XCTAssertEqual(hud.toolbelt.count, 4)
        let toast = HudCopy.feedbackLine(message: "已收获。", isSuccess: true)
        XCTAssertTrue(toast.contains("成功："))
        XCTAssertTrue(HudCopy.feedbackLine(message: "无法浇水。", isSuccess: false).contains("失败："))
    }

    func testFixtureRoundTripKeepsSchemaAndDoesNotEnterProductionDirectory() throws {
        let production = directory.appendingPathComponent("production", isDirectory: true)
        let demo = DemoSessionStore.demoDirectory(root: production)
        try FileManager.default.createDirectory(at: production, withIntermediateDirectories: true)
        try DemoSessionStore.resetDemoDirectory(demo)
        let original = DemoSessionFixture.makeInitialState()
        let store = SaveStore(directory: demo, slotName: SaveSlotCatalog.manualSlotNames[0], catalog: .vs0)
        try store.save(original)
        let loaded = try store.load()
        XCTAssertEqual(loaded.placedObjects, original.placedObjects)
        XCTAssertEqual(DemoSessionFixture.matureTeachingCropCount(loaded), 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: production.appendingPathComponent("slot_manual_1.json").path))
        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as? [String: Any]
        XCTAssertEqual(payload?["schema_version"] as? Int, SaveSchema.currentVersion)
    }
}
