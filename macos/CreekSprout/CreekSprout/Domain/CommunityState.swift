//
//  CommunityState.swift
//  CreekSprout
//
//  Persisted community standing, neighbour runtime data and gossip event
//  instances. Terminal events move from `activeEvents` to `eventHistory` and are
//  never discarded, so reward idempotency and save replay stay deterministic.
//

import Foundation

enum NeighborStance: String, Equatable, Codable, Sendable, CaseIterable {
    case neutral
    case relayingUnverified = "relaying_unverified"
    case relayingVerified = "relaying_verified"

    var displayName: String {
        switch self {
        case .neutral: return "中立"
        case .relayingUnverified: return "转述未核实版本"
        case .relayingVerified: return "转述已核实版本"
        }
    }
}

struct GossipActionRecord: Equatable, Codable, Sendable {
    /// Monotonic, 1-based and contiguous within one event instance.
    var sequence: Int
    var actionID: String
    var npcID: String
    var day: Int
    var minute: Int

    enum CodingKeys: String, CodingKey {
        case sequence
        case actionID = "action_id"
        case npcID = "npc_id"
        case day
        case minute
    }
}

struct GossipEventState: Equatable, Codable, Sendable {
    var instanceID: String
    var definitionID: String
    var claimID: String
    var status: GossipEventStatus
    var offeredDay: Int
    var deadlineDay: Int
    var deadlineMinute: Int
    var actionHistory: [GossipActionRecord]
    var truthVerified: Bool
    var resolvedDay: Int?
    var grantedEffectIDs: [String]

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case definitionID = "definition_id"
        case claimID = "claim_id"
        case status
        case offeredDay = "offered_day"
        case deadlineDay = "deadline_day"
        case deadlineMinute = "deadline_minute"
        case actionHistory = "action_history"
        case truthVerified = "truth_verified"
        case resolvedDay = "resolved_day"
        case grantedEffectIDs = "granted_effect_ids"
    }

    var nextSequence: Int {
        actionHistory.count + 1
    }

    var lastAction: GossipActionRecord? {
        actionHistory.last
    }

    func hasGranted(_ effectID: String) -> Bool {
        grantedEffectIDs.contains(effectID)
    }

    /// `true` once the clock reaches the deadline minute on the deadline day.
    func isDue(day: Int, minute: Int) -> Bool {
        if day > deadlineDay {
            return true
        }
        return day == deadlineDay && minute >= deadlineMinute
    }

    var deadlineCaption: String {
        let hour = deadlineMinute / 60
        let minute = deadlineMinute % 60
        return String(format: "第 %d 天 %02d:%02d", deadlineDay, hour, minute)
    }
}

struct NeighborState: Equatable, Codable, Sendable {
    var npcID: String
    var stance: NeighborStance
    var gossipCooldownUntilDay: Int
    var endorsementUnlocked: Bool

    enum CodingKeys: String, CodingKey {
        case npcID = "npc_id"
        case stance
        case gossipCooldownUntilDay = "gossip_cooldown_until_day"
        case endorsementUnlocked = "endorsement_unlocked"
    }

    init(
        npcID: String,
        stance: NeighborStance = .neutral,
        gossipCooldownUntilDay: Int = 0,
        endorsementUnlocked: Bool = false
    ) {
        self.npcID = npcID
        self.stance = stance
        self.gossipCooldownUntilDay = gossipCooldownUntilDay
        self.endorsementUnlocked = endorsementUnlocked
    }
}

struct CommunityState: Equatable, Codable, Sendable {
    var standing: Int
    var neighborStates: [NeighborState]
    var activeEvents: [GossipEventState]
    var eventHistory: [GossipEventState]

    enum CodingKeys: String, CodingKey {
        case standing
        case neighborStates = "neighbor_states"
        case activeEvents = "active_events"
        case eventHistory = "event_history"
    }

    static let empty = CommunityState(
        standing: CommunityCatalog.balance.newGameStanding,
        neighborStates: [],
        activeEvents: [],
        eventHistory: []
    )

    static func newGame(balance: CommunityBalanceDefinition = CommunityCatalog.balance) -> CommunityState {
        CommunityState(
            standing: balance.newGameStanding,
            neighborStates: [],
            activeEvents: [],
            eventHistory: []
        )
    }

    func neighbor(_ npcID: String) -> NeighborState? {
        neighborStates.first { $0.npcID == npcID }
    }

    func endorsementUnlocked(for npcID: String) -> Bool {
        neighbor(npcID)?.endorsementUnlocked ?? false
    }

    func activeEvent(definitionID: String) -> GossipEventState? {
        activeEvents.first { $0.definitionID == definitionID }
    }

    func event(instanceID: String) -> GossipEventState? {
        activeEvents.first { $0.instanceID == instanceID }
            ?? eventHistory.first { $0.instanceID == instanceID }
    }

    var allEvents: [GossipEventState] {
        activeEvents + eventHistory
    }

    mutating func upsertNeighbor(_ state: NeighborState) {
        if let index = neighborStates.firstIndex(where: { $0.npcID == state.npcID }) {
            neighborStates[index] = state
        } else {
            neighborStates.append(state)
        }
        neighborStates.sort { $0.npcID < $1.npcID }
    }

    mutating func replaceActiveEvent(_ event: GossipEventState) {
        if let index = activeEvents.firstIndex(where: { $0.instanceID == event.instanceID }) {
            activeEvents[index] = event
        } else {
            activeEvents.append(event)
        }
        activeEvents.sort { $0.instanceID < $1.instanceID }
    }

    mutating func retireEvent(_ event: GossipEventState) {
        activeEvents.removeAll { $0.instanceID == event.instanceID }
        if let index = eventHistory.firstIndex(where: { $0.instanceID == event.instanceID }) {
            eventHistory[index] = event
        } else {
            eventHistory.append(event)
        }
        eventHistory.sort { $0.instanceID < $1.instanceID }
    }
}
