import Foundation

enum FormalManualSlotState: Equatable, Sendable {
    case empty
    case occupied(FormalCampaignSummary)
    case unreadable
}

struct FormalCampaignSummary: Equatable, Sendable {
    var campaignID: String
    var ownerManualSlot: String
    var generationKind: SaveGenerationKind
    var saveSequence: Int
    var writtenAtMilliseconds: Int64
    var day: Int
    var minute: Int
    var currentMapID: String
    var balance: Int
    var standing: Int
    var finaleBeat: FinaleBeat
    var missionStatus: StoryMissionStatus?
}

struct FormalManualSlotSummary: Equatable, Sendable {
    var slotIndex: Int
    var ownerManualSlot: String
    var displayLabel: String
    var state: FormalManualSlotState

    var campaign: FormalCampaignSummary? {
        guard case .occupied(let campaign) = state else { return nil }
        return campaign
    }

    var isEmpty: Bool {
        state == .empty
    }
}

/// Opaque proof of exactly what occupied the selected manual slot when the
/// overwrite preview was shown. The service rejects it if that manual
/// generation or any generation owned by its campaign changes before confirm.
struct FormalNewGameConfirmationToken: Equatable, Sendable {
    fileprivate var storageIdentity: String
    fileprivate var slotIndex: Int
    fileprivate var ownerManualSlot: String
    fileprivate var previousCampaignID: String?
    fileprivate var hadPhysicalSaveFiles: Bool
    fileprivate var fingerprint: FormalSlotFingerprint
}

struct FormalNewGameRequest: Equatable, Sendable {
    var slot: FormalManualSlotSummary
    var replacingCampaign: FormalCampaignSummary?
    var requiresOverwriteConfirmation: Bool
    var confirmationToken: FormalNewGameConfirmationToken

    var replacesUnreadableSave: Bool {
        slot.state == .unreadable
    }
}

struct FormalSessionLaunch: Equatable, Sendable {
    var state: GameState
    var manualSlotIndex: Int
    var ownerManualSlot: String
    var campaignID: String
    var generationKind: SaveGenerationKind
    var diagnostics: [String]
}

enum FormalGameSessionError: Equatable, Error {
    case invalidManualSlot
    case staleConfirmationToken
    case ambiguousCampaignOwnership
    case noContinuableCampaign
    case invalidContinueBinding
    case debugFixtureRequired
    case persistenceFailure
}

/// Pure domain/persistence facade for the formal title-screen flow. Its root is
/// always supplied by the caller; it never reaches into DemoSessionStore or a
/// global Application Support path on its own.
struct FormalGameSessionService: Sendable {
    let storageRoot: URL
    let catalog: ContentCatalog

    private let scope: FormalSessionStorageScope

    init(productionRoot: URL, catalog: ContentCatalog = .vs0) {
        storageRoot = productionRoot.standardizedFileURL
        self.catalog = catalog
        scope = .production
    }

    private init(
        storageRoot: URL,
        catalog: ContentCatalog,
        scope: FormalSessionStorageScope
    ) {
        self.storageRoot = storageRoot.standardizedFileURL
        self.catalog = catalog
        self.scope = scope
    }

#if DEBUG
    /// Test and evidence fixtures live below an explicit sandbox supplied by
    /// the caller. Production UI must use `init(productionRoot:)` instead.
    static func debugFixture(
        sandboxRoot: URL,
        catalog: ContentCatalog = .vs0
    ) -> FormalGameSessionService {
        FormalGameSessionService(
            storageRoot: sandboxRoot.appendingPathComponent(
                "n027-formal-session-fixture",
                isDirectory: true
            ),
            catalog: catalog,
            scope: .debugFixture
        )
    }
#endif

    /// Always returns the three formal manual slots in stable UI order. A
    /// corrupt primary/backup is reported as unreadable, never as an empty slot
    /// that the UI could overwrite without confirmation.
    func manualSlots() -> [FormalManualSlotSummary] {
        SaveSlotCatalog.manualSlotNames.indices.map { inspectSlot(at: $0).summary }
    }

    /// Read-only phase of New Game. Discarding the returned request is the
    /// cancellation path and performs no filesystem mutation.
    func prepareNewGame(inManualSlot index: Int) throws -> FormalNewGameRequest {
        guard SaveSlotCatalog.manualSlotNames.indices.contains(index) else {
            throw FormalGameSessionError.invalidManualSlot
        }
        let inspection = inspectSlot(at: index)
        let fingerprint: FormalSlotFingerprint
        do {
            fingerprint = try makeFingerprint(
                ownerManualSlot: inspection.summary.ownerManualSlot,
                campaignID: inspection.ownedCampaignID
            )
        } catch {
            throw FormalGameSessionError.persistenceFailure
        }
        return FormalNewGameRequest(
            slot: inspection.summary,
            replacingCampaign: inspection.summary.campaign,
            requiresOverwriteConfirmation: inspection.hasPhysicalSaveFiles,
            confirmationToken: FormalNewGameConfirmationToken(
                storageIdentity: storageIdentity,
                slotIndex: index,
                ownerManualSlot: inspection.summary.ownerManualSlot,
                previousCampaignID: inspection.ownedCampaignID,
                hadPhysicalSaveFiles: inspection.hasPhysicalSaveFiles,
                fingerprint: fingerprint
            )
        )
    }

    /// Commit phase of New Game. A non-empty slot can only reach this method
    /// with the opaque token returned alongside its visible overwrite preview.
    func confirmNewGame(
        using token: FormalNewGameConfirmationToken
    ) throws -> FormalSessionLaunch {
        try confirmNewGame(
            using: token,
            makeState: { campaignID in
                GameState.vs0NewGame(catalog: catalog, campaignID: campaignID)
            }
        )
    }

#if DEBUG
    /// Failure-injection hook for atomicity tests. It is unavailable to a
    /// production-scoped service even in a Debug app build.
    func confirmNewGame(
        using token: FormalNewGameConfirmationToken,
        debugStateFactory: (String) -> GameState
    ) throws -> FormalSessionLaunch {
        guard scope == .debugFixture else {
            throw FormalGameSessionError.debugFixtureRequired
        }
        return try confirmNewGame(using: token, makeState: debugStateFactory)
    }
#endif

    /// Delegates ranking to CampaignSaveCoordinator, then verifies the returned
    /// physical owner and generation kind before exposing it to presentation.
    func continueGame() throws -> FormalSessionLaunch {
        let result: CampaignContinueResult
        do {
            result = try coordinator.bestContinueGeneration()
        } catch CampaignSaveError.missingCampaign {
            throw FormalGameSessionError.noContinuableCampaign
        } catch {
            throw FormalGameSessionError.persistenceFailure
        }

        let generation = result.generation
        let metadata = generation.metadata
        let allowedKinds: Set<SaveGenerationKind> = [
            .manual, .campaignAuto, .missionCurrent, .legacy,
        ]
        guard allowedKinds.contains(metadata.generationKind),
              metadata.campaignID == generation.state.campaignID,
              let slotIndex = SaveSlotCatalog.manualSlotNames.firstIndex(
                of: metadata.ownerManualSlot
              ),
              let manual = try? manualStore(
                ownerManualSlot: metadata.ownerManualSlot
              ).loadGeneration(),
              manual.state.campaignID == generation.state.campaignID else {
            throw FormalGameSessionError.invalidContinueBinding
        }
        if metadata.generationKind == .missionCurrent {
            guard generation.state.storyCampaign.mission.map({
                $0.status != .completed
            }) == true else {
                throw FormalGameSessionError.invalidContinueBinding
            }
        }
        return launch(
            generation: generation,
            slotIndex: slotIndex,
            diagnostics: result.diagnostics
        )
    }

    private var coordinator: CampaignSaveCoordinator {
        CampaignSaveCoordinator(rootDirectory: storageRoot, catalog: catalog)
    }

    private var storageIdentity: String {
        storageRoot.standardizedFileURL.path
    }

    private func confirmNewGame(
        using token: FormalNewGameConfirmationToken,
        makeState: (String) -> GameState
    ) throws -> FormalSessionLaunch {
        guard token.storageIdentity == storageIdentity,
              SaveSlotCatalog.manualSlotNames.indices.contains(token.slotIndex),
              SaveSlotCatalog.manualSlotNames[token.slotIndex] == token.ownerManualSlot else {
            throw FormalGameSessionError.staleConfirmationToken
        }

        let current = inspectSlot(at: token.slotIndex)
        guard current.hasPhysicalSaveFiles == token.hadPhysicalSaveFiles,
              current.ownedCampaignID == token.previousCampaignID else {
            throw FormalGameSessionError.staleConfirmationToken
        }
        let currentFingerprint: FormalSlotFingerprint
        do {
            currentFingerprint = try makeFingerprint(
                ownerManualSlot: token.ownerManualSlot,
                campaignID: token.previousCampaignID
            )
        } catch {
            throw FormalGameSessionError.persistenceFailure
        }
        guard currentFingerprint == token.fingerprint else {
            throw FormalGameSessionError.staleConfirmationToken
        }

        if let previousCampaignID = token.previousCampaignID {
            let duplicateOwners = SaveSlotCatalog.manualSlotNames.enumerated()
                .filter { $0.offset != token.slotIndex }
                .compactMap { _, owner -> String? in
                    guard let generation = try? manualStore(
                        ownerManualSlot: owner
                    ).loadGeneration(),
                          generation.state.campaignID == previousCampaignID else {
                        return nil
                    }
                    return owner
                }
            guard duplicateOwners.isEmpty else {
                throw FormalGameSessionError.ambiguousCampaignOwnership
            }
        }

        let generation: SaveGeneration
        do {
            generation = try coordinator.createNewCampaign(
                manualSlotIndex: token.slotIndex,
                makeState: makeState
            )
        } catch CampaignSaveError.invalidManualSlot {
            throw FormalGameSessionError.invalidManualSlot
        } catch {
            throw FormalGameSessionError.persistenceFailure
        }
        return launch(
            generation: generation,
            slotIndex: token.slotIndex,
            diagnostics: []
        )
    }

    private func inspectSlot(at index: Int) -> FormalSlotInspection {
        let owner = SaveSlotCatalog.manualSlotNames[index]
        let hasPhysicalFiles = manualGenerationURLs(ownerManualSlot: owner)
            .contains { FileManager.default.fileExists(atPath: $0.path) }
        let base = FormalManualSlotSummary(
            slotIndex: index,
            ownerManualSlot: owner,
            displayLabel: SaveSlotCatalog.displayLabel(for: owner),
            state: .empty
        )
        guard hasPhysicalFiles else {
            return FormalSlotInspection(
                summary: base,
                ownedCampaignID: nil,
                hasPhysicalSaveFiles: false
            )
        }
        guard let manual = try? manualStore(
            ownerManualSlot: owner
        ).loadGeneration() else {
            var unreadable = base
            unreadable.state = .unreadable
            return FormalSlotInspection(
                summary: unreadable,
                ownedCampaignID: nil,
                hasPhysicalSaveFiles: true
            )
        }

        let selected = summaryGeneration(manual: manual)
        var occupied = base
        occupied.state = .occupied(summary(for: selected))
        return FormalSlotInspection(
            summary: occupied,
            ownedCampaignID: manual.state.campaignID,
            hasPhysicalSaveFiles: true
        )
    }

    private func summaryGeneration(manual: SaveGeneration) -> SaveGeneration {
        let campaignID = manual.state.campaignID
        let owner = manual.metadata.ownerManualSlot
        let mission = try? companionStore(
            campaignID: campaignID,
            ownerManualSlot: owner,
            kind: .missionCurrent
        ).loadGeneration()
        if let mission,
           mission.state.storyCampaign.mission.map({ $0.status != .completed }) == true {
            return mission
        }
        let automatic = try? companionStore(
            campaignID: campaignID,
            ownerManualSlot: owner,
            kind: .campaignAuto
        ).loadGeneration()
        return [manual, automatic].compactMap { $0 }.sorted(by: generationIsNewer).first
            ?? manual
    }

    private func summary(for generation: SaveGeneration) -> FormalCampaignSummary {
        FormalCampaignSummary(
            campaignID: generation.state.campaignID,
            ownerManualSlot: generation.metadata.ownerManualSlot,
            generationKind: generation.metadata.generationKind,
            saveSequence: generation.metadata.saveSequence,
            writtenAtMilliseconds: generation.metadata.writtenAtMilliseconds,
            day: generation.state.clock.day,
            minute: generation.state.clock.minute,
            currentMapID: generation.state.currentMapID,
            balance: generation.state.economy.balance,
            standing: generation.state.community.standing,
            finaleBeat: generation.state.storyCampaign.finaleBeat,
            missionStatus: generation.state.storyCampaign.mission?.status
        )
    }

    private func launch(
        generation: SaveGeneration,
        slotIndex: Int,
        diagnostics: [String]
    ) -> FormalSessionLaunch {
        FormalSessionLaunch(
            state: generation.state,
            manualSlotIndex: slotIndex,
            ownerManualSlot: generation.metadata.ownerManualSlot,
            campaignID: generation.state.campaignID,
            generationKind: generation.metadata.generationKind,
            diagnostics: diagnostics
        )
    }

    private func manualStore(ownerManualSlot: String) -> SaveStore {
        SaveStore(
            directory: storageRoot,
            slotName: ownerManualSlot,
            catalog: catalog,
            expectation: SaveGenerationExpectation(
                ownerManualSlot: ownerManualSlot,
                generationKinds: [.manual, .legacy]
            )
        )
    }

    private func companionStore(
        campaignID: String,
        ownerManualSlot: String,
        kind: SaveGenerationKind
    ) -> SaveStore {
        SaveStore(
            directory: coordinator.campaignDirectory(campaignID),
            slotName: kind.rawValue,
            catalog: catalog,
            expectation: SaveGenerationExpectation(
                campaignID: campaignID,
                ownerManualSlot: ownerManualSlot,
                generationKinds: [kind]
            )
        )
    }

    private func manualGenerationURLs(ownerManualSlot: String) -> [URL] {
        let store = manualStore(ownerManualSlot: ownerManualSlot)
        return [store.primaryURL, store.backupURL, store.temporaryURL]
    }

    private func makeFingerprint(
        ownerManualSlot: String,
        campaignID: String?
    ) throws -> FormalSlotFingerprint {
        var entries: [FormalSlotFingerprint.Entry] = []
        for url in manualGenerationURLs(ownerManualSlot: ownerManualSlot) {
            entries.append(try fingerprintEntry(for: url))
        }
        if let campaignID {
            let directory = coordinator.campaignDirectory(campaignID)
            entries.append(try fingerprintEntry(for: directory))
            if FileManager.default.fileExists(atPath: directory.path) {
                guard let enumerator = FileManager.default.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
                    ],
                    options: []
                ) else {
                    throw FormalGameSessionError.persistenceFailure
                }
                for case let url as URL in enumerator {
                    entries.append(try fingerprintEntry(for: url))
                }
            }
        }
        entries.sort { $0.relativePath < $1.relativePath }
        return FormalSlotFingerprint(entries: entries)
    }

    private func fingerprintEntry(
        for url: URL
    ) throws -> FormalSlotFingerprint.Entry {
        let fileManager = FileManager.default
        let relativePath = relativeStoragePath(for: url)
        guard fileManager.fileExists(atPath: url.path) else {
            return FormalSlotFingerprint.Entry(
                relativePath: relativePath,
                contents: .missing
            )
        }
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        if values.isSymbolicLink == true {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: url.path)
            return FormalSlotFingerprint.Entry(
                relativePath: relativePath,
                contents: .symbolicLink(destination)
            )
        }
        if values.isDirectory == true {
            return FormalSlotFingerprint.Entry(
                relativePath: relativePath,
                contents: .directory
            )
        }
        guard values.isRegularFile == true else {
            throw FormalGameSessionError.persistenceFailure
        }
        return FormalSlotFingerprint.Entry(
            relativePath: relativePath,
            contents: .file(try Data(contentsOf: url))
        )
    }

    private func relativeStoragePath(for url: URL) -> String {
        let rootPath = storageRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return path }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func generationIsNewer(
        _ lhs: SaveGeneration,
        _ rhs: SaveGeneration
    ) -> Bool {
        if lhs.metadata.saveSequence != rhs.metadata.saveSequence {
            return lhs.metadata.saveSequence > rhs.metadata.saveSequence
        }
        if lhs.metadata.writtenAtMilliseconds != rhs.metadata.writtenAtMilliseconds {
            return lhs.metadata.writtenAtMilliseconds > rhs.metadata.writtenAtMilliseconds
        }
        let rank: [SaveGenerationKind: Int] = [
            .missionCurrent: 0,
            .campaignAuto: 1,
            .manual: 2,
            .legacy: 3,
        ]
        return rank[lhs.metadata.generationKind, default: Int.max]
            < rank[rhs.metadata.generationKind, default: Int.max]
    }
}

private enum FormalSessionStorageScope: Equatable, Sendable {
    case production
#if DEBUG
    case debugFixture
#endif
}

private struct FormalSlotInspection {
    var summary: FormalManualSlotSummary
    var ownedCampaignID: String?
    var hasPhysicalSaveFiles: Bool
}

private struct FormalSlotFingerprint: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        var relativePath: String
        var contents: Contents
    }

    enum Contents: Equatable, Sendable {
        case missing
        case directory
        case file(Data)
        case symbolicLink(String)
    }

    var entries: [Entry]
}
