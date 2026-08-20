import Foundation

enum SettingsStoreError: Equatable, Error {
    case cannotCreateDirectory
    case temporaryVerificationFailed
    case cannotPreserveBackup
    case replacementFailed
    case invalidContents
}

struct SettingsLoadResult: Equatable {
    var state: SettingsState
    var usedDefaults: Bool
    var hadError: Bool
}

struct SettingsStore: Sendable {
    let directory: URL

    static var defaultDirectory: URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("CreekSprout", isDirectory: true)
    }

    init(directory: URL = SettingsStore.defaultDirectory) {
        self.directory = directory
    }

    var primaryURL: URL {
        directory.appendingPathComponent("settings.json")
    }

    var backupURL: URL {
        directory.appendingPathComponent("settings.backup")
    }

    var temporaryURL: URL {
        directory.appendingPathComponent("settings.tmp")
    }

    func load() -> SettingsLoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: primaryURL.path) else {
            return SettingsLoadResult(state: .defaults, usedDefaults: true, hadError: false)
        }

        if let data = try? Data(contentsOf: primaryURL),
           let state = try? decodeValid(data) {
            return SettingsLoadResult(state: state, usedDefaults: false, hadError: false)
        }

        preserveCorruptFile()
        SettingsLog.logSettingsFallback(
            reason: "Settings file rejected; defaults restored.",
            path: primaryURL.lastPathComponent,
            directory: directory
        )
        return SettingsLoadResult(state: .defaults, usedDefaults: true, hadError: true)
    }

    func save(_ state: SettingsState) throws {
        try SettingsValidation.validate(state)

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw SettingsStoreError.cannotCreateDirectory
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let payload = try encoder.encode(state)
        try payload.write(to: temporaryURL, options: .atomic)

        let readBack = try Data(contentsOf: temporaryURL)
        guard let verified = try? decodeValid(readBack), verified == state else {
            try? fileManager.removeItem(at: temporaryURL)
            throw SettingsStoreError.temporaryVerificationFailed
        }

        if fileManager.fileExists(atPath: primaryURL.path),
           let currentData = try? Data(contentsOf: primaryURL),
           let _ = try? decodeValid(currentData) {
            do {
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: primaryURL, to: backupURL)
            } catch {
                throw SettingsStoreError.cannotPreserveBackup
            }
        }

        do {
            if fileManager.fileExists(atPath: primaryURL.path) {
                _ = try fileManager.replaceItemAt(primaryURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: primaryURL)
            }
        } catch {
            throw SettingsStoreError.replacementFailed
        }
    }

    private func decodeValid(_ data: Data) throws -> SettingsState {
        let state = try JSONDecoder().decode(SettingsState.self, from: data)
        try SettingsValidation.validate(state)
        return state
    }

    private func preserveCorruptFile() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: primaryURL.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let diagnostic = directory.appendingPathComponent("settings.corrupt.\(stamp)")
        try? fileManager.copyItem(at: primaryURL, to: diagnostic)
    }
}

enum SettingsValidation {
    static func validate(_ settings: SettingsState) throws {
        guard SettingsState.validUIScales.contains(settings.uiScale) else {
            throw SettingsStoreError.invalidContents
        }
        guard TextSpeed.allCases.contains(settings.textSpeed) else {
            throw SettingsStoreError.invalidContents
        }
        try validateVolumes(settings.volumes)
        try validateBindings(settings.bindings.keyboardMouse, device: .keyboardMouse)
        try validateBindings(settings.bindings.gamepad, device: .gamepad)
    }

    private static func validateVolumes(_ volumes: VolumeSettings) throws {
        for value in [volumes.master, volumes.music, volumes.ambience, volumes.sfx, volumes.ui] {
            guard (0.0...1.0).contains(value) else {
                throw SettingsStoreError.invalidContents
            }
        }
    }

    private static func validateBindings(_ table: [String: [String]], device: InputDeviceKind) throws {
        for actionID in InputBindingDefinitions.allActionIDs {
            guard let bindings = table[actionID], !bindings.isEmpty else {
                throw SettingsStoreError.invalidContents
            }
            for binding in bindings where binding.isEmpty {
                throw SettingsStoreError.invalidContents
            }
        }

        for actionID in InputBindingDefinitions.allActionIDs {
            guard let bindings = table[actionID], let first = bindings.first else { continue }
            let context = InputBindingDefinitions.context(for: actionID)
            for otherID in InputBindingDefinitions.allActionIDs where otherID != actionID {
                guard InputBindingDefinitions.context(for: otherID) == context,
                      let otherBindings = table[otherID],
                      otherBindings.contains(first) else {
                    continue
                }
                throw SettingsStoreError.invalidContents
            }
        }
        _ = device
    }
}
