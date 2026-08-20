//
//  RelationshipState.swift
//  CreekSprout
//
//  Trust is stored in hundredths of a display point ("subpoints"): 1 visible
//  trust point equals 100 subpoints. Each NPC keeps its own multiplier remainder
//  so repeated +10% / −15% modifiers never drift or round away.
//

import Foundation

struct TrustRecord: Equatable, Codable, Sendable {
    var npcID: String
    var subpoints: Int
    /// Saved numerator remainder of the fixed-point multiplier, `0 ..< scale`.
    var remainder: Int
    /// Game day of the most recent first-talk grant; 0 means "never".
    var lastFirstTalkDay: Int

    enum CodingKeys: String, CodingKey {
        case npcID = "npc_id"
        case subpoints
        case remainder
        case lastFirstTalkDay = "last_first_talk_day"
    }

    init(npcID: String, subpoints: Int = 0, remainder: Int = 0, lastFirstTalkDay: Int = 0) {
        self.npcID = npcID
        self.subpoints = subpoints
        self.remainder = remainder
        self.lastFirstTalkDay = lastFirstTalkDay
    }

    /// Display value with two decimals, e.g. 330 subpoints reads as `3.30`.
    var displayPoints: String {
        let whole = subpoints / 100
        let fraction = abs(subpoints % 100)
        return String(format: "%d.%02d", whole, fraction)
    }
}

struct RelationshipEffectState: Equatable, Codable, Sendable {
    var effectID: String
    var npcID: String
    var startDay: Int
    /// Inclusive last day the effect can still be read.
    var endDay: Int
    /// Day on which further growth for this NPC is zeroed; 0 means "none".
    var zeroGrowthDay: Int
    var firstTalkMultiplierBP: Int
    /// First day the multiplier may apply; 0 means "no first-talk modifier".
    var firstTalkStartDay: Int
    var firstTalkConsumed: Bool

    enum CodingKeys: String, CodingKey {
        case effectID = "effect_id"
        case npcID = "npc_id"
        case startDay = "start_day"
        case endDay = "end_day"
        case zeroGrowthDay = "zero_growth_day"
        case firstTalkMultiplierBP = "first_talk_multiplier_bp"
        case firstTalkStartDay = "first_talk_start_day"
        case firstTalkConsumed = "first_talk_consumed"
    }

    func zeroesGrowth(on day: Int) -> Bool {
        zeroGrowthDay > 0 && zeroGrowthDay == day
    }

    func appliesFirstTalkMultiplier(on day: Int) -> Bool {
        guard !firstTalkConsumed, firstTalkStartDay > 0 else {
            return false
        }
        return day >= firstTalkStartDay && day <= endDay
    }

    func isExpired(on day: Int) -> Bool {
        day > endDay
    }
}

struct RelationshipState: Equatable, Codable, Sendable {
    var trust: [TrustRecord]
    var effects: [RelationshipEffectState]

    enum CodingKeys: String, CodingKey {
        case trust
        case effects
    }

    static let empty = RelationshipState(trust: [], effects: [])

    func record(_ npcID: String) -> TrustRecord? {
        trust.first { $0.npcID == npcID }
    }

    func subpoints(_ npcID: String) -> Int {
        record(npcID)?.subpoints ?? 0
    }

    func remainder(_ npcID: String) -> Int {
        record(npcID)?.remainder ?? 0
    }

    func lastFirstTalkDay(_ npcID: String) -> Int {
        record(npcID)?.lastFirstTalkDay ?? 0
    }

    func activeEffects(for npcID: String) -> [RelationshipEffectState] {
        effects.filter { $0.npcID == npcID }
    }

    mutating func upsert(_ record: TrustRecord) {
        if let index = trust.firstIndex(where: { $0.npcID == record.npcID }) {
            trust[index] = record
        } else {
            trust.append(record)
        }
        trust.sort { $0.npcID < $1.npcID }
    }

    mutating func upsert(_ effect: RelationshipEffectState, policy: EffectStackPolicy) {
        let index = effects.firstIndex {
            $0.effectID == effect.effectID && $0.npcID == effect.npcID
        }
        switch policy {
        case .replace:
            if let index {
                effects[index] = effect
            } else {
                effects.append(effect)
            }
        case .max:
            if let index {
                if effect.endDay > effects[index].endDay {
                    effects[index] = effect
                }
            } else {
                effects.append(effect)
            }
        case .reject:
            if index == nil {
                effects.append(effect)
            }
        }
        sortEffects()
    }

    mutating func consumeFirstTalkModifier(effectID: String, npcID: String) {
        guard let index = effects.firstIndex(where: {
            $0.effectID == effectID && $0.npcID == npcID
        }) else {
            return
        }
        effects[index].firstTalkConsumed = true
    }

    mutating func pruneExpiredEffects(on day: Int) {
        effects.removeAll { $0.isExpired(on: day) }
        sortEffects()
    }

    mutating func sortEffects() {
        effects.sort { lhs, rhs in
            if lhs.npcID != rhs.npcID {
                return lhs.npcID < rhs.npcID
            }
            if lhs.effectID != rhs.effectID {
                return lhs.effectID < rhs.effectID
            }
            return lhs.startDay < rhs.startDay
        }
    }

    mutating func sortAll() {
        trust.sort { $0.npcID < $1.npcID }
        sortEffects()
    }
}
