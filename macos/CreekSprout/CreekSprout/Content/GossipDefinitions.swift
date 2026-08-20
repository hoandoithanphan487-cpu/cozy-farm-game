//
//  GossipDefinitions.swift
//  CreekSprout
//
//  M3-003 data contracts for the community message event: statuses, the legal
//  transition table, action/claim/condition/effect definitions and the standing
//  balance table. Every balance number the domain reads lives in a definition so
//  tests and fixtures can source it from the same content configuration.
//

enum GossipEventStatus: String, Equatable, Codable, Sendable, CaseIterable {
    case offered
    case deferred
    case investigating
    case verified
    case resolvedRelay = "resolved_relay"
    case resolvedCorrected = "resolved_corrected"
    case expired

    var isTerminal: Bool {
        switch self {
        case .resolvedRelay, .resolvedCorrected, .expired:
            return true
        case .offered, .deferred, .investigating, .verified:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .offered: return "待回应"
        case .deferred: return "已暂缓"
        case .investigating: return "核实中"
        case .verified: return "已核实"
        case .resolvedRelay: return "已转述（未核实）"
        case .resolvedCorrected: return "已纠正"
        case .expired: return "已过期"
        }
    }
}

enum GossipTransitionTable {
    /// Statuses reachable from a given status. Deadline expiry is modelled here
    /// too so both player actions and `expireDueEvents` share one legal table.
    static let allowed: [GossipEventStatus: Set<GossipEventStatus>] = [
        .offered: [.resolvedRelay, .deferred, .investigating, .expired],
        .deferred: [.expired],
        .investigating: [.verified, .expired],
        .verified: [.resolvedCorrected, .expired],
        .resolvedRelay: [],
        .resolvedCorrected: [],
        .expired: [],
    ]

    static func isLegal(from: GossipEventStatus, to: GossipEventStatus) -> Bool {
        allowed[from]?.contains(to) ?? false
    }
}

enum GossipInteractionSelector: String, Equatable, Sendable {
    case triggerNpc = "trigger_npc"
    case fixedNpc = "fixed_npc"
}

enum GossipRewardPolicy: String, Equatable, Sendable {
    case applyConfigured = "apply_configured"
    case watershedElseRelationship = "watershed_else_relationship"
}

enum ConditionGroupMode: String, Equatable, Sendable {
    case all
    case any
}

enum GossipConditionKind: String, Equatable, Sendable {
    /// The event itself supplies an observable clue once verification started.
    case observedEvidence = "observed_evidence"
    /// Neighbour C has permanently endorsed the player.
    case endorsementFlag = "endorsement_flag"
}

struct GossipConditionDefinition: Equatable, Sendable {
    var id: String
    var kind: GossipConditionKind
    var requiredStatus: GossipEventStatus?
    var npcID: String
}

struct ConditionGroupDefinition: Equatable, Sendable {
    var id: String
    var mode: ConditionGroupMode
    var conditionIDs: [String]
}

enum RelationshipTargetSelector: String, Equatable, Sendable {
    case claimTarget = "claim_target"
    case fixedNpc = "fixed_npc"
}

enum EffectStackPolicy: String, Equatable, Sendable {
    case replace
    case max
    case reject
}

struct RelationshipEffectDefinition: Equatable, Sendable {
    var id: String
    var targetSelector: RelationshipTargetSelector
    var fixedNpcID: String?
    /// Zeroes any further growth for the target on the submission day.
    var zeroGrowthToday: Bool
    /// Basis points applied to the daily first talk; 0.50 is written as 5000.
    var firstTalkMultiplierBP: Int
    var firstTalkStartOffsetDays: Int
    var durationDays: Int
    /// One-off subpoints; +3.00 display points is written as 300.
    var flatBonusSubpoints: Int
    var stackPolicy: EffectStackPolicy

    var hasFirstTalkModifier: Bool {
        durationDays > 0 && firstTalkMultiplierBP != CommunityBalanceDefinition.neutralBasisPoints
    }
}

struct GossipActionDefinition: Equatable, Sendable {
    var id: String
    var choiceTextKey: String
    var choiceText: String
    var interactionSelector: GossipInteractionSelector
    var fixedNpcID: String?
    var requiredStatus: GossipEventStatus
    var conditionGroupID: String?
    var standingDelta: Int
    var relationshipEffectID: String?
    var questEffectID: String?
    var watershedEffectID: String?
    var rewardPolicy: GossipRewardPolicy
    var nextStatus: GossipEventStatus

    /// Last dot segment, i.e. the stable action name required by the design
    /// (`relay_unverified`, `defer_judgment`, ...).
    var shortName: String {
        String(id.split(separator: ".").last ?? "")
    }
}

struct GossipClaimDefinition: Equatable, Sendable {
    var id: String
    var rumorTextKey: String
    var rumorText: String
    var verifiedTextKey: String
    var verifiedText: String
    /// Function NPC affected by the rumour.
    var targetNpcID: String
    /// Neighbour that keeps relaying the claim and has to be corrected.
    var relayNpcID: String
    var verificationRuleID: String
}

struct GossipEventDefinition: Equatable, Sendable {
    var id: String
    var claimID: String
    var triggerNpcID: String
    /// Scripted VS-1 trigger day.
    var triggerDay: Int
    var cooldownDays: Int
    /// VS-1 is 1: offered on day 2, due on day 3.
    var deadlineOffsetDays: Int
    var deadlineMinute: Int
    var prerequisiteIDs: [String]
    var actionIDs: [String]
}

struct StandingBandDefinition: Equatable, Sendable {
    var id: String
    var lowerBound: Int
    var upperBound: Int
    /// Basis points applied to trust growth; 10000 means no modifier.
    var trustMultiplierBP: Int
    var label: String

    func contains(_ standing: Int) -> Bool {
        standing >= lowerBound && standing <= upperBound
    }
}

struct CommunityBalanceDefinition: Equatable, Sendable {
    static let neutralBasisPoints = 10_000
    /// Upper bound accepted by save validation for any stored basis-point value.
    static let maxBasisPoints = 100_000

    var newGameStanding: Int
    var minStanding: Int
    var maxStanding: Int
    var baseFirstTalkSubpoints: Int
    var maxTrustSubpoints: Int
    /// `standing_bp * first_talk_bp`; the fixed-point divisor for trust growth.
    var fixedPointScale: Int
    var bands: [StandingBandDefinition]

    func band(for standing: Int) -> StandingBandDefinition? {
        bands.first { $0.contains(standing) }
    }

    func trustMultiplierBP(for standing: Int) -> Int {
        band(for: standing)?.trustMultiplierBP ?? Self.neutralBasisPoints
    }

    func standingLabel(for standing: Int) -> String {
        band(for: standing)?.label ?? "未知区间"
    }

    func clampStanding(_ value: Int) -> Int {
        min(max(value, minStanding), maxStanding)
    }

    func clampTrustSubpoints(_ value: Int) -> Int {
        min(max(value, 0), maxTrustSubpoints)
    }
}
