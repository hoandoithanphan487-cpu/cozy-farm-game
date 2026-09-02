import Foundation

enum CampaignSaveError: Equatable, Error {
    case invalidManualSlot
    case invalidCampaign
    case invalidGenerationKind
    case missingCampaign
    case missionAlreadyActive
    case missionNotReady
    case protectionWriteFailed
    case missionWriteFailed
    case finaleNotReady
    case preRevealWriteFailed
}

struct CampaignContinueResult: Equatable, Sendable {
    var generation: SaveGeneration
    var diagnostics: [String]
}

struct CampaignSaveCoordinator: Sendable {
    let rootDirectory: URL
    let catalog: ContentCatalog

    init(rootDirectory: URL, catalog: ContentCatalog = .vs0) {
        self.rootDirectory = rootDirectory
        self.catalog = catalog
    }

    var campaignsDirectory: URL {
        rootDirectory.appendingPathComponent("campaigns", isDirectory: true)
    }

    func campaignDirectory(_ campaignID: String) -> URL {
        campaignsDirectory.appendingPathComponent(campaignID, isDirectory: true)
    }

    func save(
        _ state: GameState,
        kind: SaveGenerationKind,
        ownerManualSlot: String
    ) throws -> SaveGenerationMetadata {
        guard SaveSlotCatalog.manualSlotNames.contains(ownerManualSlot) else {
            throw CampaignSaveError.invalidManualSlot
        }
        guard ContentID.isValid(state.campaignID),
              state.campaignID.hasPrefix("brookseed.campaign.") else {
            throw CampaignSaveError.invalidCampaign
        }
        guard kind != .legacy else {
            throw CampaignSaveError.invalidGenerationKind
        }
        if kind != .manual {
            guard let manual = try? manualStore(ownerManualSlot).loadGeneration(),
                  manual.state.campaignID == state.campaignID else {
                throw CampaignSaveError.missingCampaign
            }
        }
        let metadata = SaveGenerationMetadata(
            campaignID: state.campaignID,
            ownerManualSlot: ownerManualSlot,
            generationKind: kind,
            saveSequence: try nextGlobalSequence(),
            writtenAtMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        let location = storeLocation(
            campaignID: state.campaignID,
            kind: kind,
            ownerManualSlot: ownerManualSlot
        )
        try SaveStore(
            directory: location.directory,
            slotName: location.slotName,
            catalog: catalog,
            generationMetadata: metadata,
            expectation: physicalExpectation(
                campaignID: state.campaignID,
                kind: kind,
                ownerManualSlot: ownerManualSlot
            )
        ).save(state)
        return metadata
    }

    /// Replaces exactly one manual slot and, only after the new generation is
    /// verified, removes companion generations owned by that slot's old
    /// campaign. Other slots, campaigns, and settings are untouched.
    func createNewCampaign(
        manualSlotIndex: Int,
        makeState: (String) -> GameState = { campaignID in
            GameState.vs0NewGame(catalog: .vs0, campaignID: campaignID)
        }
    ) throws -> SaveGeneration {
        guard SaveSlotCatalog.manualSlotNames.indices.contains(manualSlotIndex) else {
            throw CampaignSaveError.invalidManualSlot
        }
        let owner = SaveSlotCatalog.manualSlotNames[manualSlotIndex]
        let oldCampaignID = try? manualStore(owner).loadGeneration().state.campaignID
        let campaignID = CampaignIdentity.make()
        var state = makeState(campaignID)
        state.campaignID = campaignID
        let metadata = try save(state, kind: .manual, ownerManualSlot: owner)
        if let oldCampaignID, oldCampaignID != campaignID {
            let oldDirectory = campaignDirectory(oldCampaignID)
            if FileManager.default.fileExists(atPath: oldDirectory.path) {
                try FileManager.default.removeItem(at: oldDirectory)
            }
        }
        return SaveGeneration(state: state, metadata: metadata)
    }

    /// A v9 manual save is materialized only after its migration round-trip
    /// succeeds. The previous raw bytes remain as SaveStore's backup.
    @discardableResult
    func materializeLegacyManualSlot(_ ownerManualSlot: String) throws -> SaveGeneration? {
        guard SaveSlotCatalog.manualSlotNames.contains(ownerManualSlot) else {
            throw CampaignSaveError.invalidManualSlot
        }
        let store = manualStore(ownerManualSlot)
        guard FileManager.default.fileExists(atPath: store.primaryURL.path) else { return nil }
        let generation = try store.loadGeneration()
        guard generation.metadata.generationKind == .legacy else { return generation }
        let metadata = try save(
            generation.state,
            kind: .manual,
            ownerManualSlot: ownerManualSlot
        )
        return SaveGeneration(state: generation.state, metadata: metadata)
    }

    func bestContinueGeneration() throws -> CampaignContinueResult {
        var diagnostics = materializeLegacyManualSlotsForContinue()
        let manualGenerations = readableManualGenerations()
        guard !manualGenerations.isEmpty else {
            throw CampaignSaveError.missingCampaign
        }

        var grouped: [CampaignOwnerKey: [SaveGeneration]] = [:]
        for manual in manualGenerations {
            let key = CampaignOwnerKey(
                campaignID: manual.state.campaignID,
                ownerManualSlot: manual.metadata.ownerManualSlot
            )
            grouped[key, default: []].append(manual)
            for kind in [SaveGenerationKind.campaignAuto, .missionCurrent] {
                if let generation = try? companionStore(
                    campaignID: manual.state.campaignID,
                    kind: kind,
                    ownerManualSlot: manual.metadata.ownerManualSlot
                ).loadGeneration() {
                    grouped[key, default: []].append(generation)
                }
            }
        }

        guard let newestKey = grouped.keys.sorted(by: { lhs, rhs in
            campaignGroupIsNewer(lhs, than: rhs, grouped: grouped)
        }).first,
              let generations = grouped[newestKey] else {
            throw CampaignSaveError.missingCampaign
        }
        let mission = generations.first { generation in
            generation.metadata.generationKind == .missionCurrent
                && generation.state.storyCampaign.mission.map {
                    $0.status != .completed
                } == true
        }
        let selectedCandidate = mission ?? generations
            .filter { generation in
                generation.metadata.generationKind == .campaignAuto
                    || generation.metadata.generationKind == .manual
                    || generation.metadata.generationKind == .legacy
            }
            .sorted(by: generationIsNewer)
            .first
        guard var selected = selectedCandidate else {
            throw CampaignSaveError.missingCampaign
        }

        if selected.metadata.generationKind == .missionCurrent {
            let protection = try? companionStore(
                campaignID: selected.state.campaignID,
                kind: .preMistRidge,
                ownerManualSlot: selected.metadata.ownerManualSlot
            ).loadGeneration()
            let protectionIsLinked = protection.map {
                $0.metadata.saveSequence < selected.metadata.saveSequence
            } == true
            if !protectionIsLinked {
                selected.state.storyCampaign.mission?.canAbandonToProtection = false
                selected.state.storyCampaign.protection.preMistRidgeVerified = false
                diagnostics.append("活动旅程缺少 pre_mist_ridge（或代际顺序无效）；可继续，但已禁用放弃回滚。")
            }
        }
        diagnostics.append(contentsOf: orphanProtectionDiagnostics(
            manualGenerations: manualGenerations
        ))
        return CampaignContinueResult(
            generation: selected,
            diagnostics: Array(Set(diagnostics)).sorted()
        )
    }

    /// Two-phase Q08 start: verified protection first, then mission_current.
    /// The caller commits the returned state to memory only after this returns.
    func prepareMission(
        source: GameState,
        snapshot: StoryMissionSnapshot,
        ownerManualSlot: String
    ) throws -> SaveGeneration {
        guard source.storyCampaign.mission == nil else {
            throw CampaignSaveError.missionAlreadyActive
        }
        guard source.storyCampaign.segment(.q08)?.phase == .eruption,
              source.storyCampaign.frontstageLease == nil,
              source.community.activeEvents.isEmpty,
              snapshot.status == .travelling,
              snapshot.checkpoint == .departure else {
            throw CampaignSaveError.missionNotReady
        }
        guard snapshot.campaignID == source.campaignID else {
            throw CampaignSaveError.invalidCampaign
        }
        do {
            _ = try save(source, kind: .preMistRidge, ownerManualSlot: ownerManualSlot)
        } catch {
            throw CampaignSaveError.protectionWriteFailed
        }
        var candidate = source
        candidate.storyCampaign.mission = snapshot
        candidate.storyCampaign.mission?.canAbandonToProtection = true
        candidate.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q08.journey.\(snapshot.campaignID)",
            owner: .journey,
            resourceID: snapshot.missionInstanceID,
            acquiredDay: source.clock.day,
            checkpointID: snapshot.checkpoint.rawValue
        )
        candidate.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q08.rawValue,
            sceneID: nil,
            beatID: "journey",
            lineID: nil,
            lineIndex: 0,
            cueID: nil,
            checkpointID: snapshot.checkpoint.rawValue
        )
        candidate.storyCampaign.protection.preMistRidgeVerified = true
        candidate.storyCampaign.canonicalize()
        do {
            let metadata = try save(candidate, kind: .missionCurrent, ownerManualSlot: ownerManualSlot)
            return SaveGeneration(state: candidate, metadata: metadata)
        } catch {
            throw CampaignSaveError.missionWriteFailed
        }
    }

    /// Creates the independent protection generation before any Q09 ledger
    /// text is made visible. It returns a candidate; it does not mutate source.
    func preparePreReveal(
        source: GameState,
        ownerManualSlot: String
    ) throws -> SaveGeneration {
        guard source.storyCampaign.q08Completed,
              source.storyCampaign.segment(.q08)?.phase == .resolved,
              source.storyCampaign.mission?.status == .completed else {
            throw CampaignSaveError.finaleNotReady
        }
        do {
            _ = try save(source, kind: .preReveal, ownerManualSlot: ownerManualSlot)
            var candidate = source
            candidate.storyCampaign.protection.preRevealVerified = true
            candidate.storyCampaign.finaleBeat = .preRevealSavePending
            candidate.storyCampaign.finaleBeatDay = source.clock.day
            candidate.storyCampaign.canonicalize()
            let metadata = try save(
                candidate,
                kind: .campaignAuto,
                ownerManualSlot: ownerManualSlot
            )
            return SaveGeneration(state: candidate, metadata: metadata)
        } catch {
            throw CampaignSaveError.preRevealWriteFailed
        }
    }

    func loadProtection(
        campaignID: String,
        kind: SaveGenerationKind,
        ownerManualSlot requestedOwner: String? = nil
    ) throws -> SaveGeneration {
        guard ContentID.isValid(campaignID),
              campaignID.hasPrefix("brookseed.campaign.") else {
            throw CampaignSaveError.invalidCampaign
        }
        guard kind.isProtection else {
            throw CampaignSaveError.invalidGenerationKind
        }

        let owner: String
        if let requestedOwner {
            guard SaveSlotCatalog.manualSlotNames.contains(requestedOwner) else {
                throw CampaignSaveError.invalidManualSlot
            }
            owner = requestedOwner
        } else {
            let owners = readableManualGenerations()
                .filter { $0.state.campaignID == campaignID }
                .map(\.metadata.ownerManualSlot)
            guard Set(owners).count == 1, let resolved = owners.first else {
                throw CampaignSaveError.missingCampaign
            }
            owner = resolved
        }

        guard let manual = try? manualStore(owner).loadGeneration(),
              manual.state.campaignID == campaignID else {
            throw CampaignSaveError.missingCampaign
        }
        return try companionStore(
            campaignID: campaignID,
            kind: kind,
            ownerManualSlot: owner
        ).loadGeneration()
    }

    private func manualStore(_ ownerManualSlot: String) -> SaveStore {
        SaveStore(
            directory: rootDirectory,
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
        kind: SaveGenerationKind,
        ownerManualSlot: String
    ) -> SaveStore {
        SaveStore(
            directory: campaignDirectory(campaignID),
            slotName: kind.rawValue,
            catalog: catalog,
            expectation: SaveGenerationExpectation(
                campaignID: campaignID,
                ownerManualSlot: ownerManualSlot,
                generationKinds: [kind]
            )
        )
    }

    private func physicalExpectation(
        campaignID: String,
        kind: SaveGenerationKind,
        ownerManualSlot: String
    ) -> SaveGenerationExpectation {
        if kind == .manual || kind == .legacy {
            return SaveGenerationExpectation(
                ownerManualSlot: ownerManualSlot,
                generationKinds: [.manual, .legacy]
            )
        }
        return SaveGenerationExpectation(
            campaignID: campaignID,
            ownerManualSlot: ownerManualSlot,
            generationKinds: [kind]
        )
    }

    private func storeLocation(
        campaignID: String,
        kind: SaveGenerationKind,
        ownerManualSlot: String
    ) -> (directory: URL, slotName: String) {
        if kind == .manual || kind == .legacy {
            return (rootDirectory, ownerManualSlot)
        }
        return (campaignDirectory(campaignID), kind.rawValue)
    }

    private func nextGlobalSequence() throws -> Int {
        let sequences = allReadableGenerations().map(\.metadata.saveSequence)
        let maximum = sequences.max() ?? 0
        guard maximum < Int.max else { throw CampaignSaveError.invalidCampaign }
        return maximum + 1
    }

    private func allReadableGenerations() -> [SaveGeneration] {
        let manuals = readableManualGenerations()
        var result = manuals
        let ownersByCampaign = Dictionary(grouping: manuals, by: \.state.campaignID)
            .mapValues { Set($0.map(\.metadata.ownerManualSlot)) }
        let fileManager = FileManager.default
        guard let campaignDirectories = try? fileManager.contentsOfDirectory(
            at: campaignsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return result
        }
        for directory in campaignDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let campaignID = directory.lastPathComponent
            guard ContentID.isValid(campaignID),
                  campaignID.hasPrefix("brookseed.campaign.") else {
                continue
            }
            for kind in SaveGenerationKind.allCases where kind != .manual && kind != .legacy {
                guard let knownOwners = ownersByCampaign[campaignID] else { continue }
                let generation = knownOwners.sorted().lazy.compactMap { owner in
                    try? companionStore(
                        campaignID: campaignID,
                        kind: kind,
                        ownerManualSlot: owner
                    ).loadGeneration()
                }.first
                if let generation {
                    result.append(generation)
                }
            }
        }
        return result
    }

    private func maximumSequence(_ generations: [SaveGeneration]) -> Int {
        generations.map(\.metadata.saveSequence).max() ?? 0
    }

    private func maximumWrittenAt(_ generations: [SaveGeneration]) -> Int64 {
        generations.map(\.metadata.writtenAtMilliseconds).max() ?? 0
    }

    private func readableManualGenerations() -> [SaveGeneration] {
        SaveSlotCatalog.manualSlotNames.compactMap { owner in
            try? manualStore(owner).loadGeneration()
        }
    }

    private func materializeLegacyManualSlotsForContinue() -> [String] {
        var diagnostics: [String] = []
        for owner in SaveSlotCatalog.manualSlotNames {
            let store = manualStore(owner)
            guard FileManager.default.fileExists(atPath: store.primaryURL.path),
                  (try? store.loadGeneration().metadata.generationKind) == .legacy else {
                continue
            }
            do {
                _ = try materializeLegacyManualSlot(owner)
            } catch {
                diagnostics.append("旧版手动档 \(owner) 无法物化；Continue 将使用稳定槽位顺序。")
            }
        }
        return diagnostics
    }

    private func campaignGroupIsNewer(
        _ lhs: CampaignOwnerKey,
        than rhs: CampaignOwnerKey,
        grouped: [CampaignOwnerKey: [SaveGeneration]]
    ) -> Bool {
        let left = (grouped[lhs] ?? []).filter(participatesInContinueRanking)
        let right = (grouped[rhs] ?? []).filter(participatesInContinueRanking)
        let leftSequence = maximumSequence(left)
        let rightSequence = maximumSequence(right)
        if leftSequence != rightSequence { return leftSequence > rightSequence }
        let leftWrittenAt = maximumWrittenAt(left)
        let rightWrittenAt = maximumWrittenAt(right)
        if leftWrittenAt != rightWrittenAt { return leftWrittenAt > rightWrittenAt }
        let leftSlotRank = SaveSlotCatalog.manualSlotNames.firstIndex(
            of: lhs.ownerManualSlot
        ) ?? Int.max
        let rightSlotRank = SaveSlotCatalog.manualSlotNames.firstIndex(
            of: rhs.ownerManualSlot
        ) ?? Int.max
        if leftSlotRank != rightSlotRank { return leftSlotRank < rightSlotRank }
        if lhs.campaignID != rhs.campaignID { return lhs.campaignID < rhs.campaignID }
        return lhs.ownerManualSlot < rhs.ownerManualSlot
    }

    private func participatesInContinueRanking(_ generation: SaveGeneration) -> Bool {
        switch generation.metadata.generationKind {
        case .manual, .campaignAuto, .legacy:
            return true
        case .missionCurrent:
            return generation.state.storyCampaign.mission.map {
                $0.status != .completed
            } == true
        case .preMistRidge, .preReveal:
            return false
        }
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
            .campaignAuto: 0,
            .manual: 1,
            .legacy: 2,
        ]
        let leftRank = rank[lhs.metadata.generationKind] ?? Int.max
        let rightRank = rank[rhs.metadata.generationKind] ?? Int.max
        if leftRank != rightRank { return leftRank < rightRank }
        return lhs.metadata.ownerManualSlot < rhs.metadata.ownerManualSlot
    }

    private func orphanProtectionDiagnostics(
        manualGenerations: [SaveGeneration]
    ) -> [String] {
        let fileManager = FileManager.default
        guard let directories = try? fileManager.contentsOfDirectory(
            at: campaignsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        let ownersByCampaign = Dictionary(grouping: manualGenerations, by: \.state.campaignID)
            .mapValues { Set($0.map(\.metadata.ownerManualSlot)) }
        var diagnostics: [String] = []
        for directory in directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let campaignID = directory.lastPathComponent
            guard let owners = ownersByCampaign[campaignID], !owners.isEmpty else {
                let hasProtection = [SaveGenerationKind.preMistRidge, .preReveal]
                    .contains { hasGenerationFile(kind: $0, in: directory, fileManager: fileManager) }
                if hasProtection {
                    diagnostics.append("忽略孤儿保护档：\(campaignID)")
                }
                continue
            }
            var matchedPreMist = false
            var matchedPreReveal = false
            for owner in owners.sorted() {
                let preMist = try? companionStore(
                    campaignID: campaignID,
                    kind: .preMistRidge,
                    ownerManualSlot: owner
                ).loadGeneration()
                if let preMist {
                    matchedPreMist = true
                    let mission = try? companionStore(
                        campaignID: campaignID,
                        kind: .missionCurrent,
                        ownerManualSlot: owner
                    ).loadGeneration()
                    let missionFollowsProtection = mission.map {
                        $0.metadata.saveSequence > preMist.metadata.saveSequence
                    } == true
                    if !missionFollowsProtection {
                        diagnostics.append(
                            "孤儿保护档 pre_mist_ridge：\(campaignID)/\(owner) 缺少同绑定且后写的 mission_current。"
                        )
                    }
                }

                let preReveal = try? companionStore(
                    campaignID: campaignID,
                    kind: .preReveal,
                    ownerManualSlot: owner
                ).loadGeneration()
                if let preReveal {
                    matchedPreReveal = true
                    let automatic = try? companionStore(
                        campaignID: campaignID,
                        kind: .campaignAuto,
                        ownerManualSlot: owner
                    ).loadGeneration()
                    let isArmed = automatic?.state.storyCampaign.protection.preRevealVerified == true
                        && (automatic?.state.storyCampaign.finaleBeat.order ?? -1)
                            >= FinaleBeat.preRevealSavePending.order
                        && (automatic?.metadata.saveSequence ?? 0)
                            > preReveal.metadata.saveSequence
                    if !isArmed {
                        diagnostics.append(
                            "孤儿保护档 pre_reveal：\(campaignID)/\(owner) 缺少已武装 campaign_auto。"
                        )
                    }
                }
            }
            if hasGenerationFile(
                kind: .preMistRidge,
                in: directory,
                fileManager: fileManager
            ), !matchedPreMist {
                diagnostics.append(
                    "忽略绑定无效保护档 pre_mist_ridge：\(campaignID)"
                )
            }
            if hasGenerationFile(
                kind: .preReveal,
                in: directory,
                fileManager: fileManager
            ), !matchedPreReveal {
                diagnostics.append(
                    "忽略绑定无效保护档 pre_reveal：\(campaignID)"
                )
            }
        }
        return diagnostics
    }

    private func hasGenerationFile(
        kind: SaveGenerationKind,
        in directory: URL,
        fileManager: FileManager
    ) -> Bool {
        fileManager.fileExists(
            atPath: directory.appendingPathComponent("\(kind.rawValue).json").path
        ) || fileManager.fileExists(
            atPath: directory.appendingPathComponent("\(kind.rawValue).backup").path
        )
    }

    private struct CampaignOwnerKey: Hashable {
        var campaignID: String
        var ownerManualSlot: String
    }
}
