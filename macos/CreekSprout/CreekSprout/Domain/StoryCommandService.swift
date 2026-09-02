import Foundation

enum StoryCommandFailure: Equatable, Error, Sendable {
    case invalidChoice
    case choiceAlreadyFinal
    case invalidActionID
    case unavailableArc
    case duplicateAction
    case frontstageBusy
    case invalidCue
    case invalidLine
    case invalidReservation
    case insufficientQuantity
}

/// Pure Story transactions. Presentation may save/validate the returned
/// candidate before replacing its in-memory GameState.
enum StoryCommandService {
    static func selectChoice(
        state: GameState,
        arcID: StoryArcID,
        choice: StoryChoiceID
    ) -> Result<GameState, StoryCommandFailure> {
        guard StoryChoiceID.choices(for: arcID).contains(choice) else {
            return .failure(.invalidChoice)
        }
        guard choiceIsAvailable(state: state, arcID: arcID, choice: choice) else {
            return .failure(.unavailableArc)
        }
        let stableID = choice.stableID(in: arcID)
        let slotID = choice.slot(in: arcID)
        if let existing = state.storyCampaign.choices.first(where: {
            $0.arcID == arcID && $0.slotID == slotID
        }) {
            return existing.choiceID == stableID ? .success(state) : .failure(.choiceAlreadyFinal)
        }

        if arcID == .q06, slotID == .aftermath {
            guard let outcome = state.storyCampaign.q06Outcome,
                  choice.rawValue == outcome.rawValue else {
                return .failure(.invalidChoice)
            }
            if state.storyCampaign.choices.contains(where: {
                $0.arcID == .q06
                    && $0.slotID == .eruption
                    && $0.choiceID == StoryChoiceID.pause.stableID(in: .q06)
            }) {
                guard let eruptionDay = state.storyCampaign.segment(.q06)?.enteredDay(for: .eruption),
                      state.clock.day > eruptionDay else {
                    return .failure(.unavailableArc)
                }
            }
        }

        var next = state
        if arcID.sequence <= StoryArcID.q08.sequence {
            guard var segment = next.storyCampaign.segment(arcID), segment.phase != .locked else {
                return .failure(.unavailableArc)
            }
            segment.selectedChoiceIDsBySlot[slotID.rawValue] = stableID
            next.storyCampaign.updateSegment(segment)
        } else {
            guard next.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order else {
                return .failure(.unavailableArc)
            }
        }
        next.storyCampaign.choices.append(
            StoryChoiceRecord(
                arcID: arcID,
                slotID: slotID,
                choiceID: stableID,
                day: state.clock.day
            )
        )
        if arcID == .q06, slotID == .eruption {
            switch choice {
            case .pause:
                next.storyCampaign.q06Outcome = .tender
            case .talk, .noSide:
                next.storyCampaign.q06Outcome = next.storyCampaign.romanceTender ? .love : .friend
            default:
                return .failure(.invalidChoice)
            }
        }
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    private static func choiceIsAvailable(
        state: GameState,
        arcID: StoryArcID,
        choice: StoryChoiceID
    ) -> Bool {
        switch arcID {
        case .q01, .q02, .q03, .q04, .q05, .q07, .q08:
            return state.storyCampaign.segment(arcID)?.phase == .eruption
        case .q06:
            let phase = state.storyCampaign.segment(.q06)?.phase
            return choice.slot(in: arcID) == .eruption
                ? phase == .eruption
                : phase == .aftermath && state.storyCampaign.q06Outcome?.rawValue == choice.rawValue
        case .q09:
            return state.storyCampaign.finaleBeat == .discovery
        case .q10:
            return choice.slot(in: arcID) == .finalAction
                ? state.storyCampaign.finaleBeat == .finalActionPending
                : state.storyCampaign.finaleBeat == .confrontation
        }
    }

    static func recordAction(
        state: GameState,
        arcID: StoryArcID,
        actionID: String,
        anchorReentry: Bool = false,
        evidenceCheck: Bool = false,
        helpedNPCID: String? = nil,
        isCollaboration: Bool = false
    ) -> Result<GameState, StoryCommandFailure> {
        guard ContentID.isValid(actionID) else { return .failure(.invalidActionID) }
        let receiptID = "brookseed.story.receipt.action.\(arcID.shortCode).\(actionID)"
        if state.storyCampaign.actionReceipts.contains(where: { $0.receiptID == receiptID }) {
            return .success(state)
        }

        var next = state
        if arcID.sequence <= StoryArcID.q08.sequence {
            guard var segment = next.storyCampaign.segment(arcID), segment.phase != .locked else {
                return .failure(.unavailableArc)
            }
            let q06CareIDs = Set([
                "brookseed.story.q06.care.shared_log",
                "brookseed.story.q06.care.tea_and_roster",
            ])
            if arcID == .q06, q06CareIDs.contains(actionID), segment.phase != .benefit {
                return .failure(.unavailableArc)
            }
            let (nextSerial, overflow) = segment.lastRelatedActionSerial.addingReportingOverflow(1)
            guard !overflow, nextSerial <= 10_000_000 else {
                return .failure(.invalidActionID)
            }
            segment.completedActionIDs.append(actionID)
            segment.lastRelatedActionSerial = nextSerial
            next.storyCampaign.updateSegment(segment)
            if arcID == .q06 {
                let completed = Set(segment.completedActionIDs)
                next.storyCampaign.romanceTender = q06CareIDs.isSubset(of: completed)
            }
        } else {
            guard next.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order else {
                return .failure(.unavailableArc)
            }
        }

        StoryMetricsRecorder.recordRelatedAction(
            metrics: &next.storyMetrics,
            sourceID: "brookseed.story.metric.action.\(arcID.shortCode).event_\(next.storyMetrics.recordedSourceIDs.count + 1)",
            arcID: arcID,
            anchorReentry: anchorReentry,
            evidenceCheck: evidenceCheck
        )
        if let helpedNPCID {
            StoryMetricsRecorder.recordUniqueHelp(
                metrics: &next.storyMetrics,
                sourceID: "brookseed.story.metric.help.\(arcID.shortCode).event_\(next.storyMetrics.recordedSourceIDs.count + 1)",
                actionID: actionID,
                npcID: helpedNPCID,
                isCollaboration: isCollaboration
            )
        }
        next.storyCampaign.actionReceipts.append(
            StoryReceiptRecord(receiptID: receiptID, sourceID: actionID, day: state.clock.day)
        )
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Holds a real inventory stack for Q07's active benefit offer. The held
    /// quantity remains visible in inventory, but SaveValidation prevents it
    /// from being spent while the reservation is active.
    static func reserveCelebrationInventory(
        state: GameState,
        itemID: String,
        quantity: Int,
        requestID: String,
        catalog: ContentCatalog = .vs0
    ) -> Result<GameState, StoryCommandFailure> {
        guard quantity > 0,
              ContentID.isValid(itemID), catalog.knowsItemID(itemID),
              ContentID.isValid(requestID) else {
            return .failure(.invalidReservation)
        }
        guard var segment = state.storyCampaign.segment(.q07),
              segment.phase == .benefit,
              let offerID = segment.benefitOfferID else {
            return .failure(.unavailableArc)
        }
        let receiptID = "brookseed.story.receipt.q07.inventory_reservation.\(requestID)"
        if state.storyCampaign.actionReceipts.contains(where: { $0.receiptID == receiptID }) {
            return .success(state)
        }
        let alreadyReserved = segment.reservedInventoryByItemID[itemID, default: 0]
        let (requestedTotal, overflow) = alreadyReserved.addingReportingOverflow(quantity)
        guard !overflow,
              requestedTotal <= InventoryService.count(state.inventory, itemID: itemID) else {
            return .failure(.insufficientQuantity)
        }
        var next = state
        segment.reservedInventoryByItemID[itemID] = requestedTotal
        segment.inventoryReservationReceipts.append(
            StoryInventoryReservationRecord(
                receiptID: receiptID,
                requestID: requestID,
                offerID: offerID,
                itemID: itemID,
                quantity: quantity,
                day: state.clock.day
            )
        )
        next.storyCampaign.updateSegment(segment)
        next.storyCampaign.actionReceipts.append(
            StoryReceiptRecord(receiptID: receiptID, sourceID: requestID, day: state.clock.day)
        )
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    static func beginBlockingSession(
        state: GameState,
        arcID: StoryArcID,
        phase: StoryPhase,
        cueID: String,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, StoryCommandFailure> {
        guard let cue = catalog.visibleBlockingCue(
            id: cueID,
            finaleUnlocked: state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order
        ), cue.arcID == arcID,
              state.storyCampaign.segment(arcID)?.phase == phase,
              state.community.activeEvents.isEmpty,
              state.storyCampaign.mission?.status != .travelling,
              state.storyCampaign.finaleBeat.order < FinaleBeat.discovery.order else {
            return .failure(.invalidCue)
        }
        if let lease = state.storyCampaign.frontstageLease {
            guard lease.owner == .story, lease.resourceID == arcID.rawValue else {
                return .failure(.frontstageBusy)
            }
        } else if !FrontstageEventArbiter.canOpenStoryBeat(state: state) {
            return .failure(.frontstageBusy)
        }
        var next = state
        next.storyCampaign.frontstageLease = FrontstageLease(
            leaseID: "brookseed.story.lease.\(arcID.shortCode).\(phase.rawValue).day_\(state.clock.day)",
            owner: .story,
            resourceID: arcID.rawValue,
            acquiredDay: state.clock.day,
            checkpointID: nil
        )
        next.storyCampaign.cursor = StoryRuntimeCursor(
            eventID: arcID.rawValue,
            sceneID: cue.sceneID,
            beatID: phase.rawValue,
            lineID: nil,
            lineIndex: 0,
            cueID: cueID,
            checkpointID: nil
        )
        return .success(next)
    }

    static func persistLine(
        state: GameState,
        lineID: String,
        lineIndex: Int,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, StoryCommandFailure> {
        guard lineIndex >= 0,
              let lease = state.storyCampaign.frontstageLease,
              lease.owner == .story || lease.owner == .finale,
              lease.resourceID == state.storyCampaign.cursor.eventID,
              let line = catalog.visibleLine(
                id: lineID,
                finaleUnlocked: state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order
              ),
              let arcID = StoryArcID(rawValue: lease.resourceID),
              let beatID = state.storyCampaign.cursor.beatID,
              let stageKind = StoryStageID(rawValue: beatID),
              let stage = catalog.stage(arcID: arcID, kind: stageKind),
              let expectedIndex = stage.lines.firstIndex(where: { $0.id == line.id }),
              expectedIndex == lineIndex,
              line.blockingCueID == nil
                || line.blockingCueID == state.storyCampaign.cursor.cueID else {
            return .failure(.invalidLine)
        }
        var next = state
        next.storyCampaign.cursor.lineID = lineID
        next.storyCampaign.cursor.lineIndex = lineIndex
        return .success(next)
    }
}
