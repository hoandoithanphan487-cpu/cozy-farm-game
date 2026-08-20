import Foundation

enum SaveStoreError: Equatable, Error {
    case missingSave
    case noValidSaveGeneration
    case cannotCreateDirectory
    case temporaryVerificationFailed
    case cannotPreserveBackup
    case replacementFailed
    case invalidContents
    case unsupportedSchema
}

struct SaveStore: Sendable {
    let directory: URL
    let slotName: String
    let catalog: ContentCatalog

    init(
        directory: URL,
        slotName: String = "slot_0",
        catalog: ContentCatalog = .vs0
    ) {
        self.directory = directory
        self.slotName = slotName
        self.catalog = catalog
    }

    var primaryURL: URL {
        directory.appendingPathComponent("\(slotName).json")
    }

    var backupURL: URL {
        directory.appendingPathComponent("\(slotName).backup")
    }

    var temporaryURL: URL {
        directory.appendingPathComponent("\(slotName).tmp")
    }

    func save(_ state: GameState) throws {
        try SaveValidation.validate(state, catalog: catalog)

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw SaveStoreError.cannotCreateDirectory
        }

        let payload = try SaveCodec.encode(state)
        try payload.write(to: temporaryURL, options: .atomic)

        let readBack = try Data(contentsOf: temporaryURL)
        guard let verified = try? decodeValid(readBack), verified == state else {
            try? fileManager.removeItem(at: temporaryURL)
            throw SaveStoreError.temporaryVerificationFailed
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
                throw SaveStoreError.cannotPreserveBackup
            }
        }

        do {
            if fileManager.fileExists(atPath: primaryURL.path) {
                _ = try fileManager.replaceItemAt(primaryURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: primaryURL)
            }
        } catch {
            throw SaveStoreError.replacementFailed
        }
    }

    func load() throws -> GameState {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: primaryURL.path) else {
            throw SaveStoreError.missingSave
        }

        if let data = try? Data(contentsOf: primaryURL), let state = try? decodeValid(data) {
            return state
        }

        if fileManager.fileExists(atPath: backupURL.path),
           let backupData = try? Data(contentsOf: backupURL),
           let state = try? decodeValid(backupData) {
            return state
        }

        throw SaveStoreError.noValidSaveGeneration
    }

    private func decodeValid(_ data: Data) throws -> GameState {
        let state = try SaveCodec.decode(data)
        try SaveValidation.validate(state, catalog: catalog)
        return state
    }
}
