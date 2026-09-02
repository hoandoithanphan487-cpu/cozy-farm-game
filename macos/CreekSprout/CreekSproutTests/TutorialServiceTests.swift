import Foundation
import XCTest
@testable import CreekSprout

final class TutorialServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let farm = FarmActionService()
    private var tutorial: TutorialService { TutorialService(catalog: catalog) }
    private var commands: M2CommandService { M2CommandService(catalog: catalog) }
    private let teachingPlots = [
        GridPosition(x: 4, y: 3),
        GridPosition(x: 5, y: 3),
        GridPosition(x: 6, y: 3),
    ]
    private let wildPlot = GridPosition(x: 2, y: 3)

    func testNewGameHudShowsHarvestGoal() {
        let state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertEqual(state.economy.balance, 720)
        XCTAssertEqual(state.inventoryCapacity, 16)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishSeed), 8)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialHarvest)
        XCTAssertTrue(tutorial.goalLine(for: state).contains("当前目标：收获 3 株成熟雾萝卜"))
        XCTAssertEqual(catalog.scenario.startingNpcSpawns.first?.npcID, ContentID.waterApprentice)
        XCTAssertEqual(catalog.scenario.startingNpcSpawns.first?.position, GridPosition(x: 8, y: 6))
    }

    func testHarvestDepositTillPlantWaterTalkSaveSleepAdvanceInOrder() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        let clock = ClockSystem()

        for plot in teachingPlots {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
            _ = tutorial.recordHarvest(state: &state)
        }
        XCTAssertEqual(state.tutorial.harvestCount, 3)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialDeposit)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishItem), 3)

        let deposit = commands.depositShipping(
            state: &state,
            itemID: ContentID.mistRadishItem,
            quantity: 3
        )
        XCTAssertTrue(deposit.isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.economy.shipping.pendingQuantity, 3)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialTill)

        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .hoe, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialPlant)

        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .seed, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialWater)

        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .water, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialTalk)

        let completedTalk = tutorial.recordTalk(state: &state)
        XCTAssertEqual(completedTalk, [ContentID.tutorialTalk])
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialSave)
        XCTAssertTrue(tutorial.recordTalk(state: &state).isEmpty)

        let completedSave = tutorial.recordManualSave(state: &state)
        XCTAssertEqual(completedSave, [ContentID.tutorialSave])
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialSleep)

        let summary = try SleepUseCase().sleep(state: &state, clock: clock, catalog: catalog, store: nil)
        XCTAssertEqual(summary.settlement.total, 174)
        XCTAssertEqual(state.economy.balance, 894)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialNextDay)
        XCTAssertTrue(tutorial.goalLine(for: state).contains("明天继续照料新种下的雾萝卜"))
        XCTAssertTrue(tutorial.goalLine(for: state).contains("开始核实"))
        XCTAssertTrue(tutorial.goalLine(for: state).contains("向青砚核实"))
        XCTAssertTrue(tutorial.goalLine(for: state).contains("不要按 V"))
        XCTAssertFalse(tutorial.goalLine(for: state).contains("水脉"))
    }

    func testInvalidSeedDoesNotAdvanceTutorialOrChangeFarm() {
        var state = GameState.vs0NewGame(catalog: catalog)
        for plot in teachingPlots {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
            _ = tutorial.recordHarvest(state: &state)
        }
        _ = commands.depositShipping(state: &state, itemID: ContentID.mistRadishItem, quantity: 3)
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialTill)

        let before = state
        let result = farm.apply(to: &state, target: wildPlot, tool: .seed, catalog: catalog)
        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.reason.contains("只能在空的已翻土地块播种"))
        _ = tutorial.advance(state: &state)
        XCTAssertEqual(state.farmCells[wildPlot], before.farmCells[wildPlot])
        XCTAssertEqual(state.inventory, before.inventory)
        XCTAssertEqual(state.tutorial, before.tutorial)
    }

    func testDialoguePausesClockAndResumeAfterEnd() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let clock = ClockSystem()
        let spawn = catalog.scenario.startingNpcSpawns[0]
        let session = DialogueService.startTeaching(
            spawn: spawn,
            catalog: catalog,
            alreadyCompleted: false,
            clock: clock
        )
        XCTAssertEqual(session?.lines.count, 3)
        XCTAssertTrue(clock.containsPauseReason(.dialogue))
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 10), 0)
        XCTAssertEqual(state.clock.minute, GameClock.dayStartMinute)
        DialogueService.end(clock: clock)
        XCTAssertFalse(clock.containsPauseReason(.dialogue))
        XCTAssertGreaterThan(clock.advance(state: &state, deltaSeconds: 3), 0)
    }

    func testTalkRequiresFacingOrStandingOnApprentice() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let spawn = catalog.scenario.startingNpcSpawns[0]
        state.position = GridPosition(x: 5, y: 4)
        state.facing = .down
        XCTAssertFalse(tutorial.canTalk(to: spawn, from: state))

        state.position = GridPosition(x: 8, y: 5)
        state.facing = .up
        XCTAssertEqual(state.targetCell(in: WorldCatalog.farmHomestead), spawn.position)
        XCTAssertTrue(tutorial.canTalk(to: spawn, from: state))

        state.position = spawn.position
        state.facing = .down
        XCTAssertTrue(tutorial.canTalk(to: spawn, from: state))
    }
}

final class TutorialSaveTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0
    private let farm = FarmActionService()
    private var tutorial: TutorialService { TutorialService(catalog: catalog) }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-tutorial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testTutorialFlagsRoundTripAndDoNotRegress() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        for plot in catalog.scenario.startingFarmCells.map(\.position) {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
            _ = tutorial.recordHarvest(state: &state)
        }
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        _ = tutorial.advance(state: &state)

        let wildPlot = GridPosition(x: 2, y: 3)
        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .hoe, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .seed, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        XCTAssertTrue(farm.apply(to: &state, target: wildPlot, tool: .water, catalog: catalog).isSuccess)
        _ = tutorial.advance(state: &state)
        _ = tutorial.recordTalk(state: &state)
        _ = tutorial.recordManualSave(state: &state)

        XCTAssertEqual(state.economy.shipping.pendingQuantity, 3)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialSleep)
        XCTAssertTrue(state.tutorial.talkedToWaterApprentice)
        XCTAssertTrue(state.tutorial.didManualSave)

        try store.save(state)
        let payload = decodedJSON(at: store.primaryURL)
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)

        let loaded = try store.load()
        XCTAssertEqual(loaded.tutorial, state.tutorial)
        XCTAssertEqual(loaded.economy.shipping.pendingQuantity, 3)
        XCTAssertEqual(loaded.economy.balance, 720)
        XCTAssertEqual(loaded.tutorial.currentStepID, ContentID.tutorialSleep)
        XCTAssertEqual(
            loaded.farmCells.keys.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x },
            state.farmCells.keys.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        )
    }

    func testV2SaveMigratesToHarvestStepWithoutDestroyingEconomy() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var v2State = GameState.vs0NewGame(catalog: catalog)
        v2State.tutorial = .newGame
        try store.save(v2State)
        var payload = decodedJSON(at: store.primaryURL)
        payload["schema_version"] = 2
        payload.removeValue(forKey: "tutorial")
        let v2 = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try v2.write(to: store.primaryURL, options: .atomic)

        let migrated = try SaveMigrator.migrate(v2)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(migrated.currentMapID, ContentID.farmHomestead)
        let loaded = try store.load()
        XCTAssertEqual(loaded.tutorial.currentStepID, ContentID.tutorialHarvest)
        XCTAssertTrue(loaded.tutorial.completedStepIDs.isEmpty)
        XCTAssertEqual(loaded.tutorial.harvestCount, 0)
        XCTAssertFalse(loaded.tutorial.talkedToWaterApprentice)
        XCTAssertEqual(loaded.economy.balance, 720)
        XCTAssertEqual(loaded.inventoryCapacity, 16)
    }

    func testIllegalCompletedSetIsRejected() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        try? FileManager.default.removeItem(at: store.backupURL)
        var payload = decodedJSON(at: store.primaryURL)
        payload["tutorial"] = [
            "current_step_id": ContentID.tutorialTalk,
            "completed_step_ids": [ContentID.tutorialHarvest],
            "harvest_count": 3,
            "talked_to_water_apprentice": false,
            "did_manual_save": false,
        ]
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), illegal)
    }

    func testUnknownTutorialStepIsRejected() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        try? FileManager.default.removeItem(at: store.backupURL)
        var payload = decodedJSON(at: store.primaryURL)
        payload["tutorial"] = [
            "current_step_id": "brookseed.tutorial.not_real",
            "completed_step_ids": [],
            "harvest_count": 0,
            "talked_to_water_apprentice": false,
            "did_manual_save": false,
        ]
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
    }

    private func decodedJSON(at url: URL) -> [String: Any] {
        let data = try! Data(contentsOf: url)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
