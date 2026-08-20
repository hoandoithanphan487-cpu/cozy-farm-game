import Foundation
import XCTest
@testable import CreekSprout

final class SettingsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSproutSettingsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testRebindConflictIsBlockedWithReason() {
        var settings = SettingsState.defaults
        let result = InputBindingsService.rebind(
            settings: &settings,
            device: .keyboardMouse,
            actionID: InputBindingDefinitions.actionMoveUp,
            binding: "Key:S"
        )
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, .bindingConflict(conflictActionID: InputBindingDefinitions.actionMoveDown))
        XCTAssertTrue(result.message?.contains("移动-下") == true)
    }

    func testRequiredActionCannotLoseLastBinding() {
        var settings = SettingsState.defaults
        let binding = settings.bindings.keyboardMouse[InputBindingDefinitions.actionMoveUp]!.first!
        let result = InputBindingsService.removeBinding(
            settings: &settings,
            device: .keyboardMouse,
            actionID: InputBindingDefinitions.actionMoveUp,
            binding: binding
        )
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, .requiredBinding)
    }

    func testRestoreDefaultsResetsBindingsAndAccessibility() {
        var settings = SettingsState.defaults
        settings.uiScale = 150
        settings.textSpeed = .fast
        _ = InputBindingsService.rebind(
            settings: &settings,
            device: .keyboardMouse,
            actionID: InputBindingDefinitions.actionMoveUp,
            binding: "Key:Q"
        )
        InputBindingsService.restoreDefaults(settings: &settings)
        XCTAssertEqual(settings, .defaults)
    }

    func testSettingsFilePersistsAcrossReload() throws {
        let store = SettingsStore(directory: directory)
        var settings = SettingsState.defaults
        settings.uiScale = 125
        settings.textSpeed = .fast
        settings.vibrationEnabled = false
        try store.save(settings)

        let loaded = store.load()
        XCTAssertFalse(loaded.usedDefaults)
        XCTAssertEqual(loaded.state.uiScale, 125)
        XCTAssertEqual(loaded.state.textSpeed, .fast)
        XCTAssertFalse(loaded.state.vibrationEnabled)
    }

    func testCorruptSettingsFileFallsBackToDefaults() throws {
        let store = SettingsStore(directory: directory)
        try Data("{not-json".utf8).write(to: store.primaryURL)

        let loaded = store.load()
        XCTAssertTrue(loaded.usedDefaults)
        XCTAssertTrue(loaded.hadError)
        XCTAssertEqual(loaded.state, .defaults)

        let logURL = directory.appendingPathComponent("settings-errors.log")
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))
        let log = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(log.contains("Settings file rejected"))
    }

    func testV6SaveMigratesSettingsDefaults() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.vs0NewGame())

        var payload = try decodedJSON(at: store.primaryURL)
        payload.removeValue(forKey: "settings")
        payload["schema_version"] = 6
        let v6 = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try v6.write(to: store.primaryURL)

        let migrated = try SaveMigrator.migrate(v6)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(migrated.settings, .defaults)
    }

    func testSaveRoundTripCarriesSettingsSnapshot() throws {
        let store = SaveStore(directory: directory)
        var state = GameState.vs0NewGame()
        state.settings.uiScale = 150
        state.settings.textSpeed = .instant
        state.settings.volumes.master = 0.5
        try store.save(state)

        let loaded = try store.load()
        XCTAssertEqual(loaded.settings.uiScale, 150)
        XCTAssertEqual(loaded.settings.textSpeed, .instant)
        XCTAssertEqual(loaded.settings.volumes.master, 0.5)
    }

    func testInvalidSettingsInSaveIsRejected() throws {
        let store = SaveStore(directory: directory)
        try store.save(GameState.vs0NewGame())
        var payload = try decodedJSON(at: store.primaryURL)
        var settings = try XCTUnwrap(payload["settings"] as? [String: Any])
        settings["ui_scale"] = 999
        payload["settings"] = settings
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL)
        try? FileManager.default.removeItem(at: store.backupURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
    }

    func testTextSpeedAndUIScaleRuntimeFactors() {
        var settings = SettingsState.defaults
        settings.uiScale = 125
        settings.textSpeed = .fast
        XCTAssertEqual(settings.uiScaleFactor, 1.25, accuracy: 0.001)
        XCTAssertLessThan(settings.textSpeed.pacingMultiplier, 1.0)
    }

    func testMainHarvestPathStillReaches174WithCustomSettings() throws {
        let catalog = ContentCatalog.vs0
        let farm = FarmActionService()
        var state = GameState.vs0NewGame(catalog: catalog)
        state.settings.uiScale = 150
        state.settings.textSpeed = .fast
        state.settings.reduceFlashing = true

        for plot in catalog.scenario.startingFarmCells.map(\.position) {
            XCTAssertTrue(farm.apply(to: &state, target: plot, tool: .harvest, catalog: catalog).isSuccess)
        }
        state = try ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()

        let result = SettleShippingUseCase.settle(state: state, catalog: catalog)
        XCTAssertEqual(result.record.total, 174)

        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(result.state)
        let loaded = try store.load()
        XCTAssertEqual(loaded.settings.uiScale, 150)
        XCTAssertEqual(loaded.economy.balance, result.state.economy.balance)
    }

    private func decodedJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
