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
    let generationMetadata: SaveGenerationMetadata?
    let expectation: SaveGenerationExpectation?

    init(
        directory: URL,
        slotName: String = "slot_0",
        catalog: ContentCatalog = .vs0,
        generationMetadata: SaveGenerationMetadata? = nil,
        expectation: SaveGenerationExpectation? = nil
    ) {
        self.directory = directory
        self.slotName = slotName
        self.catalog = catalog
        self.generationMetadata = generationMetadata
        self.expectation = expectation
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
        let metadata = generationMetadata ?? .neutral(
            campaignID: state.campaignID,
            sourceSlotName: slotName
        )
        try validate(metadata: metadata, for: state)

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw SaveStoreError.cannotCreateDirectory
        }

        let payload = try SaveCodec.encode(state, generationMetadata: metadata)
        try payload.write(to: temporaryURL, options: .atomic)

        let readBack = try Data(contentsOf: temporaryURL)
        guard let verified = try? decodeValid(readBack),
              verified.state == state,
              verified.metadata == metadata else {
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
        try loadGeneration().state
    }

    func loadGeneration() throws -> SaveGeneration {
        let fileManager = FileManager.default
        let hasPrimary = fileManager.fileExists(atPath: primaryURL.path)
        let hasBackup = fileManager.fileExists(atPath: backupURL.path)
        guard hasPrimary || hasBackup else {
            throw SaveStoreError.missingSave
        }

        if hasPrimary,
           let data = try? Data(contentsOf: primaryURL),
           let generation = try? decodeValid(data) {
            return generation
        }

        if hasBackup,
           let backupData = try? Data(contentsOf: backupURL),
           let generation = try? decodeValid(backupData) {
            return generation
        }

        throw SaveStoreError.noValidSaveGeneration
    }

    private func decodeValid(_ data: Data) throws -> SaveGeneration {
        let generation = try SaveCodec.decodeGeneration(
            data,
            catalog: catalog,
            context: SaveMigrationContext(sourceSlotName: slotName)
        )
        try SaveValidation.validate(generation.state, catalog: catalog)
        try validate(metadata: generation.metadata, for: generation.state)
        return generation
    }

    private func validate(
        metadata: SaveGenerationMetadata,
        for state: GameState
    ) throws {
        guard metadata.isStructurallyValid,
              metadata.campaignID == state.campaignID,
              expectation?.accepts(metadata) != false else {
            throw SaveStoreError.invalidContents
        }
    }
}
