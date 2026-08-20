//
//  RelationshipService.swift
//  CreekSprout
//
//  Owns trust subpoints, multiplier remainders and timed relationship effects.
//  Computation order is fixed (TDD 7.9) so the same save plus the same choice
//  sequence always reproduces the same numbers:
//
//    1. read the base first-talk subpoints from content;
//    2. a zero-growth-today effect short-circuits to 0 and keeps the remainder;
//    3. read the standing band multiplier in basis points;
//    4. read the misunderstanding first-talk multiplier in basis points;
//    5. numerator = base * standing_bp * first_talk_bp + saved_remainder,
//       gain = numerator / scale, remainder = numerator % scale (Int64 math);
//    6. flat one-off bonuses are applied separately and never multiplied.
//

enum RelationshipFailure: Equatable, Error, Sendable {
    case unknownNpc
    case unknownEffect
    case invalidConfiguration
}

struct TrustGrant: Equatable, Sendable {
    var npcID: String
    var awardedSubpoints: Int
    var totalSubpoints: Int
    var remainder: Int
    var standingMultiplierBP: Int
    var firstTalkMultiplierBP: Int
    var wasZeroGrowth: Bool
    var didApply: Bool
}

enum RelationshipService {
    // MARK: - Daily first talk

    /// Grants the daily first-talk trust for `npcID`. Repeated talks on the same
    /// day are a no-op, so ordinary conversation cannot farm trust.
    static func applyDailyFirstTalk(
        state: inout GameState,
        npcID: String,
        catalog: ContentCatalog
    ) -> Result<TrustGrant, RelationshipFailure> {
        guard catalog.npc(id: npcID) != nil else {
            return .failure(.unknownNpc)
        }
        let balance = catalog.communityBalance
        guard balance.fixedPointScale > 0, balance.baseFirstTalkSubpoints >= 0 else {
            return .failure(.invalidConfiguration)
        }

        let day = state.clock.day
        var record = state.relationships.record(npcID) ?? TrustRecord(npcID: npcID)
        guard record.lastFirstTalkDay != day else {
            return .success(
                TrustGrant(
                    npcID: npcID,
                    awardedSubpoints: 0,
                    totalSubpoints: record.subpoints,
                    remainder: record.remainder,
                    standingMultiplierBP: balance.trustMultiplierBP(for: state.community.standing),
                    firstTalkMultiplierBP: CommunityBalanceDefinition.neutralBasisPoints,
                    wasZeroGrowth: false,
                    didApply: false
                )
            )
        }

        var next = state
        let standingBP = balance.trustMultiplierBP(for: next.community.standing)
        let zeroGrowth = next.relationships
            .activeEffects(for: npcID)
            .contains { $0.zeroesGrowth(on: day) }

        if zeroGrowth {
            // Step 2: growth is zeroed and the saved remainder must not move.
            record.lastFirstTalkDay = day
            next.relationships.upsert(record)
            state = next
            return .success(
                TrustGrant(
                    npcID: npcID,
                    awardedSubpoints: 0,
                    totalSubpoints: record.subpoints,
                    remainder: record.remainder,
                    standingMultiplierBP: standingBP,
                    firstTalkMultiplierBP: CommunityBalanceDefinition.neutralBasisPoints,
                    wasZeroGrowth: true,
                    didApply: true
                )
            )
        }

        let misunderstanding = next.relationships
            .activeEffects(for: npcID)
            .filter { $0.appliesFirstTalkMultiplier(on: day) }
            .min { $0.firstTalkMultiplierBP < $1.firstTalkMultiplierBP }
        let firstTalkBP = misunderstanding?.firstTalkMultiplierBP
            ?? CommunityBalanceDefinition.neutralBasisPoints

        let computed = computeGain(
            baseSubpoints: balance.baseFirstTalkSubpoints,
            standingBP: standingBP,
            firstTalkBP: firstTalkBP,
            savedRemainder: record.remainder,
            scale: balance.fixedPointScale
        )
        record.subpoints = balance.clampTrustSubpoints(record.subpoints + computed.gain)
        record.remainder = computed.remainder
        record.lastFirstTalkDay = day
        next.relationships.upsert(record)
        if let misunderstanding {
            // The 0.50 misunderstanding multiplier is applied exactly once.
            next.relationships.consumeFirstTalkModifier(
                effectID: misunderstanding.effectID,
                npcID: npcID
            )
        }
        state = next
        return .success(
            TrustGrant(
                npcID: npcID,
                awardedSubpoints: computed.gain,
                totalSubpoints: record.subpoints,
                remainder: record.remainder,
                standingMultiplierBP: standingBP,
                firstTalkMultiplierBP: firstTalkBP,
                wasZeroGrowth: false,
                didApply: true
            )
        )
    }

    /// 64-bit fixed-point step 5. `scale` equals standing_bp × first_talk_bp.
    static func computeGain(
        baseSubpoints: Int,
        standingBP: Int,
        firstTalkBP: Int,
        savedRemainder: Int,
        scale: Int
    ) -> (gain: Int, remainder: Int) {
        guard scale > 0 else {
            return (0, savedRemainder)
        }
        let numerator = Int64(baseSubpoints) * Int64(standingBP) * Int64(firstTalkBP)
            + Int64(savedRemainder)
        let scale64 = Int64(scale)
        return (Int(numerator / scale64), Int(numerator % scale64))
    }

    // MARK: - Flat bonuses and effects

    /// One-off subpoints that bypass every multiplier and leave the remainder
    /// untouched (step 6).
    static func applyFlatBonus(
        state: inout GameState,
        npcID: String,
        subpoints: Int,
        catalog: ContentCatalog
    ) -> Result<Int, RelationshipFailure> {
        guard catalog.npc(id: npcID) != nil else {
            return .failure(.unknownNpc)
        }
        var record = state.relationships.record(npcID) ?? TrustRecord(npcID: npcID)
        record.subpoints = catalog.communityBalance.clampTrustSubpoints(record.subpoints + subpoints)
        state.relationships.upsert(record)
        return .success(record.subpoints)
    }

    static func applyEffect(
        state: inout GameState,
        effectID: String,
        npcID: String,
        catalog: ContentCatalog
    ) -> Result<Void, RelationshipFailure> {
        guard let definition = catalog.relationshipEffect(id: effectID) else {
            return .failure(.unknownEffect)
        }
        guard catalog.npc(id: npcID) != nil else {
            return .failure(.unknownNpc)
        }
        guard definition.durationDays >= 0,
              definition.firstTalkStartOffsetDays >= 0,
              definition.firstTalkMultiplierBP >= 0 else {
            return .failure(.invalidConfiguration)
        }
        guard definition.zeroGrowthToday || definition.hasFirstTalkModifier else {
            // Pure flat-bonus definitions carry no timed state.
            return .success(())
        }

        let day = state.clock.day
        let firstTalkStartDay = definition.hasFirstTalkModifier
            ? day + definition.firstTalkStartOffsetDays
            : 0
        let lastActiveDay = definition.hasFirstTalkModifier
            ? firstTalkStartDay + max(definition.durationDays - 1, 0)
            : day
        let effect = RelationshipEffectState(
            effectID: definition.id,
            npcID: npcID,
            startDay: day,
            endDay: max(lastActiveDay, day),
            zeroGrowthDay: definition.zeroGrowthToday ? day : 0,
            firstTalkMultiplierBP: definition.hasFirstTalkModifier
                ? definition.firstTalkMultiplierBP
                : CommunityBalanceDefinition.neutralBasisPoints,
            firstTalkStartDay: firstTalkStartDay,
            firstTalkConsumed: false
        )
        state.relationships.upsert(effect, policy: definition.stackPolicy)
        return .success(())
    }

    /// Drops effects whose window closed. Called from day start, never from
    /// save decoding, so a loaded save is byte-identical to what was written.
    static func pruneExpiredEffects(state: inout GameState) {
        state.relationships.pruneExpiredEffects(on: state.clock.day)
    }

    static func reconcile(_ state: GameState) -> GameState {
        var next = state
        next.relationships.sortAll()
        return next
    }
}
