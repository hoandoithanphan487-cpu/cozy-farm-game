import Foundation

enum FinaleFailure: Equatable, Error, Sendable {
    case notEligible
    case preRevealWriteFailed
    case invalidTransition
    case stageUnavailable
    case noLease
    case alreadyGraduated
    case waterActionMissing
    case leaveAnchorUnavailable
    case saveFailed
}

/// Q09/Q10 finale runtime: ledger discovery, all-evil confrontation, the two
/// final actions and graduation. Uses the independent finale beats, never the
/// Q01–Q08 benefit/warning/eruption stages.
enum FinaleService {
    // MARK: - Q09 trigger

    /// Writes the campaign-scoped `pre_reveal` protection generation BEFORE
    /// any ledger text (Q09_DIS_001) becomes visible. Returns the armed
    /// candidate; memory must only be committed after the write succeeded.
    static func beginDiscovery(
        state: GameState,
        coordinator: CampaignSaveCoordinator,
        ownerManualSlot: String
    ) throws -> SaveGeneration {
        guard state.storyCampaign.finaleBeat == .locked else {
            throw FinaleFailure.invalidTransition
        }
        do {
            return try coordinator.preparePreReveal(
                source: state,
                ownerManualSlot: ownerManualSlot
            )
        } catch {
            throw FinaleFailure.preRevealWriteFailed
        }
    }

    /// Enters the Q09 discovery stage and takes the finale frontstage lease.
    /// Called only after `beginDiscovery` succeeded.
    static func enterDiscovery(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.protection.preRevealVerified,
              state.storyCampaign.finaleBeat == .preRevealSavePending else {
            return .failure(.invalidTransition)
        }
        guard let cueID = firstCueID(of: .q09, stage: .discovery, catalog: catalog) else {
            return .failure(.stageUnavailable)
        }
        var next = state
        next.storyCampaign.finaleBeat = .discovery
        next.storyCampaign.finaleBeatDay = state.clock.day
        next.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q09.discovery.day_\(state.clock.day)",
            owner: .finale,
            resourceID: StoryArcID.q09.rawValue,
            acquiredDay: state.clock.day,
            checkpointID: "discovery"
        )
        next.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q09.rawValue,
            sceneID: nil,
            beatID: StoryStageID.discovery.rawValue,
            lineID: nil,
            lineIndex: 0,
            cueID: cueID,
            checkpointID: nil
        )
        next.storyCampaign.dialogueSession = nil
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Records discovered ledger evidence while the ledger is on screen.
    static func discoverLedgerPage(
        state: GameState,
        pageID: String
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order,
              state.storyCampaign.finaleBeat != .graduated,
              ContentID.isValid(pageID) else {
            return .failure(.invalidTransition)
        }
        var next = state
        if !next.storyCampaign.gallery.discoveredLedgerPageIDs.contains(pageID) {
            next.storyCampaign.gallery.discoveredLedgerPageIDs.append(pageID)
            next.storyCampaign.gallery.discoveredLedgerPageIDs.sort()
        }
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    // MARK: - Stage progression

    /// Opens the finale dialogue session for the cursor's stage.
    static func openStageSession(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.frontstageLease?.owner == .finale else {
            return .failure(.noLease)
        }
        switch StoryDialogueService.openSession(state: state, catalog: catalog) {
        case .success(let candidate):
            return .success(candidate)
        case .failure:
            return .failure(.stageUnavailable)
        }
    }

    /// Q09 intent recorded → continuous entry into Q10 confrontation.
    static func advanceAfterLedgerIntent(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat == .discovery,
              state.storyCampaign.choices.contains(where: { $0.arcID == .q09 }),
              state.storyCampaign.frontstageLease?.owner == .finale else {
            return .failure(.invalidTransition)
        }
        guard let cueID = firstCueID(of: .q10, stage: .confrontationOpen, catalog: catalog) else {
            return .failure(.stageUnavailable)
        }
        var next = state
        next.storyCampaign.finaleBeat = .confrontation
        next.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q10.confrontation.day_\(state.clock.day)",
            owner: .finale,
            resourceID: StoryArcID.q10.rawValue,
            acquiredDay: state.clock.day,
            checkpointID: "confrontation"
        )
        next.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q10.rawValue,
            sceneID: nil,
            beatID: StoryStageID.confrontationOpen.rawValue,
            lineID: nil,
            lineIndex: 0,
            cueID: cueID,
            checkpointID: nil
        )
        next.storyCampaign.dialogueSession = nil
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Q10 confrontation intent recorded → final action pending.
    static func advanceAfterConfrontationIntent(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat == .confrontation,
              state.storyCampaign.choices.contains(where: {
                  $0.arcID == .q10 && $0.slotID == .confrontationIntent
              }),
              state.storyCampaign.frontstageLease?.owner == .finale else {
            return .failure(.invalidTransition)
        }
        guard let cueID = firstCueID(of: .q10, stage: .lastFarmAction, catalog: catalog) else {
            return .failure(.stageUnavailable)
        }
        var next = state
        next.storyCampaign.finaleBeat = .finalActionPending
        next.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.q10.last_farm_action.day_\(state.clock.day)",
            owner: .finale,
            resourceID: StoryArcID.q10.rawValue,
            acquiredDay: state.clock.day,
            checkpointID: "last_farm_action"
        )
        next.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: StoryArcID.q10.rawValue,
            sceneID: nil,
            beatID: StoryStageID.lastFarmAction.rawValue,
            lineID: nil,
            lineIndex: 0,
            cueID: cueID,
            checkpointID: nil
        )
        next.storyCampaign.dialogueSession = nil
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    // MARK: - Final actions

    /// `water`: a real, successful last watering transaction on the farm.
    /// At least one farm cell must carry today's watered mark.
    static func graduateAfterWater(
        state: GameState,
        endingID: String = "brookseed.story.ending.water",
        keepsakeIDs: [String] = []
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat == .finalActionPending else {
            return .failure(.invalidTransition)
        }
        guard state.currentMapID == ContentID.farmHomestead,
              state.farmCells.values.contains(where: \.wateredToday) else {
            return .failure(.waterActionMissing)
        }
        return graduate(state: state, endingID: endingID, keepsakeIDs: keepsakeIDs)
    }

    /// `leave`: from the existing market wharf interaction position.
    static func graduateAfterLeave(
        state: GameState,
        endingID: String = "brookseed.story.ending.leave",
        keepsakeIDs: [String] = []
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat == .finalActionPending else {
            return .failure(.invalidTransition)
        }
        guard state.currentMapID == ContentID.creekMarket,
              let anchor = StoryAnchorCatalog.anchor(id: StoryAnchorCatalog.endingDepartureAnchorID),
              case let .worldGrid(world) = anchor,
              world.landmarkID == "brookseed.landmark.market_wharf",
              state.position == world.cell || state.targetCell == world.cell else {
            return .failure(.leaveAnchorUnavailable)
        }
        return graduate(state: state, endingID: endingID, keepsakeIDs: keepsakeIDs)
    }

    /// Graduation preserves the farm, currency, animals, relationships and
    /// standing; it only stops community evaluation and unlocks the gallery.
    static func graduate(
        state: GameState,
        endingID: String,
        keepsakeIDs: [String]
    ) -> Result<GameState, FinaleFailure> {
        guard state.storyCampaign.finaleBeat == .finalActionPending,
              state.storyCampaign.choices.contains(where: {
                  $0.arcID == .q10 && $0.slotID == .finalAction
              }),
              ContentID.isValid(endingID) else {
            return .failure(.invalidTransition)
        }
        var next = state
        let defaultKeepsakes = [
            "brookseed.gallery.keepsake.hero_plaque",
            "brookseed.gallery.keepsake.group_photo",
        ]
        next.storyCampaign.gallery.isUnlocked = true
        next.storyCampaign.gallery.endingID = endingID
        next.storyCampaign.gallery.keepsakeIDs = Array(
            Set(keepsakeIDs + defaultKeepsakes + next.storyCampaign.gallery.discoveredLedgerPageIDs)
        ).sorted()
        next.storyCampaign.communityEvaluationDisabled = true
        next.storyCampaign.finaleBeat = .graduated
        next.storyCampaign.m3OffersPaused = false
        next.storyCampaign.frontstageLease = nil
        next.storyCampaign.cursor = .empty
        next.storyCampaign.dialogueSession = nil
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Loads the pre-reveal protection generation for gallery recall.
    static func recallPreReveal(
        state: GameState,
        coordinator: CampaignSaveCoordinator,
        ownerManualSlot: String
    ) throws -> GameState {
        guard state.storyCampaign.gallery.isUnlocked,
              state.storyCampaign.protection.preRevealVerified else {
            throw FinaleFailure.invalidTransition
        }
        return try coordinator.loadProtection(
            campaignID: state.campaignID,
            kind: .preReveal,
            ownerManualSlot: ownerManualSlot
        ).state
    }

    private static func firstCueID(
        of arcID: StoryArcID,
        stage kind: StoryStageID,
        catalog: StoryContentCatalog
    ) -> String? {
        catalog.stage(arcID: arcID, kind: kind)?
            .lines
            .compactMap(\.blockingCueID)
            .first
    }
}
