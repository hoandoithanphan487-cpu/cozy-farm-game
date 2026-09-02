import Foundation

enum JourneyFailure: Equatable, Error, Sendable {
    case notEligible
    case missionAlreadyActive
    case notInJourney
    case unknownCheckpoint
    case invalidTransition
    case settlementAlreadyReceived
    case cannotAbandon
    case protectionMissing
    case saveFailed
    case overflow
    case settlementRejected
}

enum JourneyCheckpointOrder {
    static func order(of checkpoint: StoryJourneyCheckpoint) -> Int {
        switch checkpoint {
        case .departure: 0
        case .oldWaterway: 1
        case .mistRidgeFork: 2
        case .greyFenceFarm: 3
        case .homecoming: 4
        }
    }
}

/// Q08 lossless journey runtime. The mission snapshot is deliberately finite;
/// full rollback lives only in the campaign-scoped `pre_mist_ridge`
/// protection generation.
enum JourneyService {
    // MARK: - Snapshot

    static func buildMissionSnapshot(
        state: GameState,
        catalog: ContentCatalog = .vs0
    ) -> Result<StoryMissionSnapshot, JourneyFailure> {
        guard state.storyCampaign.segment(.q08)?.phase == .eruption,
              state.storyCampaign.frontstageLease == nil,
              state.community.activeEvents.isEmpty,
              state.community.standing >= 90,
              state.storyCampaign.mission == nil else {
            return .failure(.notEligible)
        }
        let missionInstanceID = "brookseed.story.journey.mission.\(state.campaignID)"
        let settlementReceiptID = "brookseed.story.receipt.q08.homecoming.\(state.campaignID)"
        guard ContentID.isValid(missionInstanceID),
              ContentID.isValid(settlementReceiptID) else {
            return .failure(.notEligible)
        }
        let covered = state.farmCells
            .filter { $0.value.isGrowingCrop }
            .map { FarmCellIdentity.id(for: $0.key) }
            .filter(ContentID.isValid)
            .sorted()
        let animals = state.livestock.animals.map(\.instanceID).sorted()
        let frozenOrders = state.questLog.entries
            .filter { $0.status == .active || $0.status == .readyToTurnIn }
            .map(\.questID)
            .sorted()
        let shippingEntries = state.economy.shipping.pendingEntries
            .map { entry in
                MissionShippingEntrySnapshot(
                    entryID: entry.entryID,
                    itemID: entry.itemID,
                    quantity: entry.quantity,
                    unitPrice: entry.unitPriceSnapshot
                )
            }
            .sorted { $0.entryID < $1.entryID }
        let snapshot = StoryMissionSnapshot(
            campaignID: state.campaignID,
            missionInstanceID: missionInstanceID,
            startDay: state.clock.day,
            status: .travelling,
            coveredCropCellIDs: covered,
            protectedAnimalIDs: animals,
            frozenOrderIDs: frozenOrders,
            frozenDeadlineIDs: [],
            frozenOfferIDs: [],
            shippingEntries: shippingEntries,
            checkpoint: .departure,
            settlementReceiptID: settlementReceiptID,
            canAbandonToProtection: false
        )
        return .success(snapshot)
    }

    /// Two-phase commit through the campaign save coordinator. The returned
    /// generation must be committed to memory only after this succeeds.
    static func prepareJourney(
        state: GameState,
        coordinator: CampaignSaveCoordinator,
        ownerManualSlot: String
    ) throws -> SaveGeneration {
        let snapshot: StoryMissionSnapshot
        switch buildMissionSnapshot(state: state) {
        case .success(let built): snapshot = built
        case .failure(let error): throw error
        }
        return try coordinator.prepareMission(
            source: state,
            snapshot: snapshot,
            ownerManualSlot: ownerManualSlot
        )
    }

    // MARK: - Checkpoint advance

    /// Advances the journey to the next scene checkpoint. Every checkpoint is
    /// persisted atomically by the presentation layer as `mission_current`.
    static func advanceCheckpoint(
        state: GameState,
        to checkpoint: StoryJourneyCheckpoint
    ) -> Result<GameState, JourneyFailure> {
        guard var mission = state.storyCampaign.mission else {
            return .failure(.notInJourney)
        }
        guard mission.status == .travelling else {
            return .failure(.invalidTransition)
        }
        guard checkpoint != .departure,
              checkpoint != .homecoming else {
            return .failure(.invalidTransition)
        }
        let currentOrder = JourneyCheckpointOrder.order(of: mission.checkpoint)
        let nextOrder = JourneyCheckpointOrder.order(of: checkpoint)
        guard nextOrder == currentOrder + 1 else {
            return .failure(.invalidTransition)
        }
        var next = state
        mission.checkpoint = checkpoint
        next.storyCampaign.mission = mission
        if let lease = next.storyCampaign.frontstageLease,
           lease.owner == .journey {
            next.storyCampaign.frontstageLease = FrontstageLease(
                leaseID: lease.leaseID,
                owner: .journey,
                resourceID: lease.resourceID,
                acquiredDay: lease.acquiredDay,
                checkpointID: checkpoint.rawValue
            )
        }
        next.storyCampaign.cursor.checkpointID = checkpoint.rawValue
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    // MARK: - Exactly-once homecoming

    /// Returns the player home. In a single candidate it settles the frozen
    /// shipping entries at snapshot prices, advances crops one safe day,
    /// records safe animal care, writes the unique settlement receipt and
    /// enters Q08 aftermath. The candidate is saved as campaign current BEFORE
    /// memory is committed; a crash before the save settles nothing, and a
    /// crash after the save is blocked by the receipt.
    static func completeHomecoming(
        state: GameState,
        coordinator: CampaignSaveCoordinator,
        ownerManualSlot: String,
        catalog: ContentCatalog = .vs0
    ) throws -> SaveGeneration {
        guard var mission = state.storyCampaign.mission else {
            throw JourneyFailure.notInJourney
        }
        guard !state.storyCampaign.effectReceipts.contains(where: {
            $0.receiptID == mission.settlementReceiptID
        }) else {
            throw JourneyFailure.settlementAlreadyReceived
        }
        guard mission.checkpoint == .greyFenceFarm,
              mission.status == .travelling else {
            throw JourneyFailure.invalidTransition
        }
        var candidate = state
        // Frozen shipping settles exactly once at snapshot unit prices.
        var pending = candidate.economy.shipping.pendingEntries
        var settlementLines: [SettlementLine] = []
        var total = 0
        for snapshotEntry in mission.shippingEntries {
            guard let index = pending.firstIndex(where: {
                $0.entryID == snapshotEntry.entryID
            }) else {
                continue
            }
            let entry = pending[index]
            guard entry.quantity == snapshotEntry.quantity,
                  entry.unitPriceSnapshot == snapshotEntry.unitPrice else {
                throw JourneyFailure.settlementRejected
            }
            let (amount, overflow) = entry.quantity.multipliedReportingOverflow(
                by: entry.unitPriceSnapshot
            )
            guard !overflow, amount >= 0 else {
                throw JourneyFailure.settlementRejected
            }
            pending.remove(at: index)
            total += amount
            settlementLines.append(
                SettlementLine(
                    itemID: entry.itemID,
                    quantity: entry.quantity,
                    quality: entry.quality,
                    amount: amount,
                    displayText: "远行结算 \(entry.quantity) × \(entry.unitPriceSnapshot)"
                )
            )
        }
        let (newBalance, balanceOverflow) = candidate.economy.balance.addingReportingOverflow(total)
        guard !balanceOverflow, newBalance >= 0 else {
            throw JourneyFailure.overflow
        }
        candidate.economy.balance = newBalance
        candidate.economy.shipping.pendingEntries = pending
        if !settlementLines.isEmpty {
            candidate.economy.settlementHistory.append(
                SettlementRecord(
                    settlementID: "\(candidate.scenarioID).journey_homecoming.\(mission.campaignID)",
                    scenarioID: candidate.scenarioID,
                    gameDay: state.clock.day,
                    lines: settlementLines,
                    total: total
                )
            )
            candidate.economy.settlementHistory.sort { $0.settlementID < $1.settlementID }
        }
        // Mission clock: one safe day for crops (no water stress), mature
        // crops stay harvestable.
        advanceSafeCropDay(state: &candidate, catalog: catalog)
        // Animals were safely cared for during the journey.
        for index in candidate.livestock.animals.indices {
            candidate.livestock.animals[index].ageDays += 1
            candidate.livestock.animals[index].totalCareDays += 1
            candidate.livestock.animals[index].lastCaredDay = state.clock.day
        }
        candidate.livestock.sortAnimals()
        // Unique settlement / keepsake receipt.
        candidate.storyCampaign.effectReceipts.append(
            StoryReceiptRecord(
                receiptID: mission.settlementReceiptID,
                sourceID: mission.missionInstanceID,
                day: state.clock.day
            )
        )
        mission.status = .completed
        mission.checkpoint = .homecoming
        mission.canAbandonToProtection = false
        candidate.storyCampaign.mission = mission
        candidate.storyCampaign.frontstageLease = nil
        candidate.storyCampaign.cursor = .empty
        candidate.storyCampaign.dialogueSession = nil
        var segment = candidate.storyCampaign.segment(.q08)
        segment?.enter(.aftermath, day: state.clock.day)
        if let segment {
            candidate.storyCampaign.updateSegment(segment)
        }
        candidate.storyCampaign.canonicalize()
        // Exactly-once ordering: replace mission_current with the completed
        // journey first, then write campaign current. Continue never
        // re-selects a completed mission, so a crash between the two writes
        // resumes from the pre-journey campaign save (no double settlement);
        // the unique settlement receipt in both generations blocks any re-issue
        // after both writes land.
        _ = try coordinator.save(
            candidate,
            kind: .missionCurrent,
            ownerManualSlot: ownerManualSlot
        )
        let saved = try coordinator.save(
            candidate,
            kind: .campaignAuto,
            ownerManualSlot: ownerManualSlot
        )
        return SaveGeneration(state: candidate, metadata: saved)
    }

    // MARK: - Abandon / rollback

    /// Abandons the journey and restores the `pre_mist_ridge` protection
    /// generation. Only possible while the linked protection exists; a
    /// missing protection disables this path with an explicit diagnosis.
    static func abandon(
        state: GameState,
        coordinator: CampaignSaveCoordinator,
        ownerManualSlot: String
    ) throws -> GameState {
        guard let mission = state.storyCampaign.mission else {
            throw JourneyFailure.notInJourney
        }
        guard mission.status != .completed else {
            throw JourneyFailure.invalidTransition
        }
        guard mission.canAbandonToProtection,
              state.storyCampaign.protection.preMistRidgeVerified else {
            throw JourneyFailure.cannotAbandon
        }
        let protection: SaveGeneration
        do {
            protection = try coordinator.loadProtection(
                campaignID: state.campaignID,
                kind: .preMistRidge,
                ownerManualSlot: ownerManualSlot
            )
        } catch {
            throw JourneyFailure.protectionMissing
        }
        return protection.state
    }

    // MARK: - Mission clock

    /// One safe growth day: growing crops advance without water stress and
    /// mature crops remain harvestable.
    static func advanceSafeCropDay(
        state: inout GameState,
        catalog: ContentCatalog
    ) {
        for key in state.farmCells.keys {
            guard var cell = state.farmCells[key], cell.hasCrop, !cell.readyToHarvest,
                  let crop = catalog.crop(id: cell.cropID) else { continue }
            let totalDays = crop.stageDays.reduce(0, +)
            cell.stageProgressDays += 1
            if cell.stageProgressDays >= totalDays {
                cell.stageProgressDays = min(cell.stageProgressDays, totalDays)
                cell.readyToHarvest = true
            }
            state.farmCells[key] = cell
        }
    }
}
