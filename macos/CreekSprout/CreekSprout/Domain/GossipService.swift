//
//  GossipService.swift
//  CreekSprout
//
//  Sole writer of `CommunityState`. It creates scripted event instances, expires
//  due events, decides which actions are offered at a given NPC and evaluates
//  the verification condition groups. Reward application lives in
//  `ResolveGossipActionUseCase` so cross-service work stays transactional.
//

enum GossipFailure: Equatable, Error, Sendable {
    case unknownEvent
    case unknownAction
    case noActiveEvent
    case illegalTransition
    case wrongInteractionNpc
    case conditionsNotMet
    case deadlinePassed
    case invalidContent
}

struct GossipExpiryResult: Equatable, Sendable {
    var expiredInstanceIDs: [String]

    var didExpire: Bool { !expiredInstanceIDs.isEmpty }
}

enum GossipService {
    // MARK: - Lifecycle

    /// Creates every scripted event whose trigger day has arrived. Re-running it
    /// for the same day is a no-op because the instance ID is derived from the
    /// definition and the offered day.
    @discardableResult
    static func triggerScheduledEvents(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> [String] {
        let day = state.clock.day
        var created: [String] = []
        for definition in catalog.gossipEvents.values.sorted(by: { $0.id < $1.id }) {
            guard day >= definition.triggerDay else {
                continue
            }
            let instanceID = ContentID.gossipInstanceID(
                definitionID: definition.id,
                offeredDay: definition.triggerDay
            )
            guard state.community.event(instanceID: instanceID) == nil else {
                continue
            }
            guard definition.prerequisiteIDs.allSatisfy({ isPrerequisiteMet($0, state: state) }) else {
                continue
            }
            guard let neighbor = catalog.npc(id: definition.triggerNpcID),
                  neighbor.role == .neighbor,
                  catalog.gossipClaim(id: definition.claimID) != nil else {
                continue
            }
            let event = GossipEventState(
                instanceID: instanceID,
                definitionID: definition.id,
                claimID: definition.claimID,
                status: .offered,
                offeredDay: definition.triggerDay,
                deadlineDay: definition.triggerDay + definition.deadlineOffsetDays,
                deadlineMinute: definition.deadlineMinute,
                actionHistory: [],
                truthVerified: false,
                resolvedDay: nil,
                grantedEffectIDs: []
            )
            state.community.replaceActiveEvent(event)
            created.append(instanceID)
        }
        return created
    }

    /// Deadline processing runs before any player action in the same minute, so
    /// a submission at exactly the deadline minute always sees `expired`.
    @discardableResult
    static func expireDueEvents(state: inout GameState) -> GossipExpiryResult {
        let day = state.clock.day
        let minute = state.clock.minute
        var expired: [String] = []
        for event in state.community.activeEvents.sorted(by: { $0.instanceID < $1.instanceID }) {
            guard !event.status.isTerminal else {
                state.community.retireEvent(event)
                continue
            }
            guard event.isDue(day: day, minute: minute) else {
                continue
            }
            guard GossipTransitionTable.isLegal(from: event.status, to: .expired) else {
                continue
            }
            var retired = event
            retired.status = .expired
            retired.resolvedDay = day
            state.community.retireEvent(retired)
            expired.append(retired.instanceID)
        }
        return GossipExpiryResult(expiredInstanceIDs: expired)
    }

    /// Day-start bookkeeping: create scripted events, expire anything overdue,
    /// and drop relationship effects whose window closed.
    static func advanceToDayStart(state: inout GameState, catalog: ContentCatalog) {
        _ = expireDueEvents(state: &state)
        triggerScheduledEvents(state: &state, catalog: catalog)
        RelationshipService.pruneExpiredEffects(state: &state)
    }

    // MARK: - Queries

    static func activeEvent(state: GameState) -> GossipEventState? {
        state.community.activeEvents.sorted { $0.instanceID < $1.instanceID }.first
    }

    static func latestEvent(state: GameState) -> GossipEventState? {
        activeEvent(state: state)
            ?? state.community.eventHistory.sorted { $0.instanceID < $1.instanceID }.last
    }

    /// Actions the player may submit while standing next to `npcID`.
    static func availableActions(
        state: GameState,
        npcID: String,
        catalog: ContentCatalog
    ) -> [GossipActionDefinition] {
        guard let event = activeEvent(state: state),
              let definition = catalog.gossipEvent(id: event.definitionID) else {
            return []
        }
        guard !event.isDue(day: state.clock.day, minute: state.clock.minute) else {
            return []
        }
        return definition.actionIDs
            .compactMap { catalog.gossipAction(id: $0) }
            .filter { action in
                isOffered(action, event: event, definition: definition, npcID: npcID, state: state, catalog: catalog)
            }
    }

    static func isOffered(
        _ action: GossipActionDefinition,
        event: GossipEventState,
        definition: GossipEventDefinition,
        npcID: String,
        state: GameState,
        catalog: ContentCatalog
    ) -> Bool {
        guard event.status == action.requiredStatus else {
            return false
        }
        guard GossipTransitionTable.isLegal(from: event.status, to: action.nextStatus) else {
            return false
        }
        guard expectedNpcID(for: action, definition: definition) == npcID else {
            return false
        }
        return conditionsSatisfied(action, event: event, state: state, catalog: catalog)
    }

    static func expectedNpcID(
        for action: GossipActionDefinition,
        definition: GossipEventDefinition
    ) -> String? {
        switch action.interactionSelector {
        case .triggerNpc:
            return definition.triggerNpcID
        case .fixedNpc:
            return action.fixedNpcID
        }
    }

    static func conditionsSatisfied(
        _ action: GossipActionDefinition,
        event: GossipEventState,
        state: GameState,
        catalog: ContentCatalog
    ) -> Bool {
        guard let groupID = action.conditionGroupID else {
            return true
        }
        guard let group = catalog.conditionGroup(id: groupID) else {
            return false
        }
        let results = group.conditionIDs.map { conditionID -> Bool in
            guard let condition = catalog.gossipCondition(id: conditionID) else {
                return false
            }
            return evaluate(condition, event: event, state: state)
        }
        guard !results.isEmpty else {
            return false
        }
        switch group.mode {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains(true)
        }
    }

    static func evaluate(
        _ condition: GossipConditionDefinition,
        event: GossipEventState,
        state: GameState
    ) -> Bool {
        switch condition.kind {
        case .observedEvidence:
            guard let required = condition.requiredStatus else {
                return false
            }
            return event.status == required
        case .endorsementFlag:
            return state.community.endorsementUnlocked(for: condition.npcID)
        }
    }

    // MARK: - Standing

    static func applyStandingDelta(
        state: inout GameState,
        delta: Int,
        catalog: ContentCatalog
    ) -> Int {
        let balance = catalog.communityBalance
        state.community.standing = balance.clampStanding(state.community.standing + delta)
        return state.community.standing
    }

    static func setEndorsement(
        state: inout GameState,
        npcID: String,
        unlocked: Bool
    ) {
        var neighbor = state.community.neighbor(npcID) ?? NeighborState(npcID: npcID)
        neighbor.endorsementUnlocked = unlocked
        state.community.upsertNeighbor(neighbor)
    }

    static func setStance(
        state: inout GameState,
        npcID: String,
        stance: NeighborStance
    ) {
        var neighbor = state.community.neighbor(npcID) ?? NeighborState(npcID: npcID)
        neighbor.stance = stance
        state.community.upsertNeighbor(neighbor)
    }

    /// Sorting-only normalisation. It must stay idempotent because the save
    /// store compares the decoded state with the state it just wrote.
    static func reconcile(_ state: GameState) -> GameState {
        var next = state
        next.community.neighborStates.sort { $0.npcID < $1.npcID }
        next.community.activeEvents.sort { $0.instanceID < $1.instanceID }
        next.community.eventHistory.sort { $0.instanceID < $1.instanceID }
        for index in next.community.activeEvents.indices {
            next.community.activeEvents[index].grantedEffectIDs.sort()
        }
        for index in next.community.eventHistory.indices {
            next.community.eventHistory[index].grantedEffectIDs.sort()
        }
        return next
    }

    private static func isPrerequisiteMet(_ prerequisiteID: String, state: GameState) -> Bool {
        state.questLog.status(of: prerequisiteID) == .completed
            || state.watershed.hasApplied(prerequisiteID)
            || state.watershed.unlockedNodes.contains(prerequisiteID)
    }
}
