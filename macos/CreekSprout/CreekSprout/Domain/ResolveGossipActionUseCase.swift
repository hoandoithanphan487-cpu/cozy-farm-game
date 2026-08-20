//
//  ResolveGossipActionUseCase.swift
//  CreekSprout
//
//  Single transactional entry point for submitting a community event action.
//  Every service (gossip, relationship, quest, watershed) validates and writes
//  into one candidate copy of `GameState`; the caller's state is replaced only
//  after all of them succeed, so a rejected reward can never leave a half
//  applied standing change or a dangling action record behind.
//

struct GossipSubmitOutcome: Equatable, Sendable {
    var actionID: String
    var event: GossipEventState
    var didApply: Bool
    var standingBefore: Int
    var standingAfter: Int
    var watershedPointsAwarded: Int
    var trustSubpointsAwarded: Int
    var grantedEffectIDs: [String]
}

enum ResolveGossipActionUseCase {
    static func submit(
        state: inout GameState,
        actionID: String,
        npcID: String,
        catalog: ContentCatalog
    ) -> Result<GossipSubmitOutcome, GossipFailure> {
        guard let action = catalog.gossipAction(id: actionID) else {
            return .failure(.unknownAction)
        }

        // Deadline processing precedes any action submitted in the same minute
        // and is committed even when the action itself is then rejected.
        _ = GossipService.expireDueEvents(state: &state)
        var next = state

        // A replayed action is an idempotent success: no second reward, no
        // second history record, and the already-recorded event is returned.
        if let recorded = next.community.allEvents.first(where: { event in
            event.actionHistory.contains { $0.actionID == actionID }
        }) {
            return .success(
                GossipSubmitOutcome(
                    actionID: actionID,
                    event: recorded,
                    didApply: false,
                    standingBefore: next.community.standing,
                    standingAfter: next.community.standing,
                    watershedPointsAwarded: 0,
                    trustSubpointsAwarded: 0,
                    grantedEffectIDs: []
                )
            )
        }

        guard var event = GossipService.activeEvent(state: next) else {
            return .failure(.noActiveEvent)
        }
        guard let definition = catalog.gossipEvent(id: event.definitionID),
              let claim = catalog.gossipClaim(id: event.claimID) else {
            return .failure(.invalidContent)
        }
        guard definition.actionIDs.contains(action.id) else {
            return .failure(.unknownAction)
        }
        guard !event.isDue(day: next.clock.day, minute: next.clock.minute) else {
            return .failure(.deadlinePassed)
        }
        guard GossipService.expectedNpcID(for: action, definition: definition) == npcID else {
            return .failure(.wrongInteractionNpc)
        }
        guard event.status == action.requiredStatus,
              GossipTransitionTable.isLegal(from: event.status, to: action.nextStatus) else {
            return .failure(.illegalTransition)
        }
        if action.nextStatus == .resolvedCorrected, !event.truthVerified {
            return .failure(.illegalTransition)
        }
        guard GossipService.conditionsSatisfied(
            action,
            event: event,
            state: next,
            catalog: catalog
        ) else {
            return .failure(.conditionsNotMet)
        }

        let standingBefore = next.community.standing
        var watershedAwarded = 0
        var trustAwarded = 0
        var grantedNow: [String] = []
        let alreadyRewarded = !event.grantedEffectIDs.isEmpty

        switch action.rewardPolicy {
        case .applyConfigured:
            if let effectID = action.relationshipEffectID {
                guard let effect = catalog.relationshipEffect(id: effectID) else {
                    return .failure(.invalidContent)
                }
                let targetID = relationshipTargetID(effect: effect, claim: claim)
                guard let targetID else {
                    return .failure(.invalidContent)
                }
                if !alreadyRewarded {
                    switch RelationshipService.applyEffect(
                        state: &next,
                        effectID: effectID,
                        npcID: targetID,
                        catalog: catalog
                    ) {
                    case .failure:
                        return .failure(.invalidContent)
                    case .success:
                        grantedNow.append(effectID)
                    }
                    if effect.flatBonusSubpoints != 0 {
                        switch RelationshipService.applyFlatBonus(
                            state: &next,
                            npcID: targetID,
                            subpoints: effect.flatBonusSubpoints,
                            catalog: catalog
                        ) {
                        case .failure:
                            return .failure(.invalidContent)
                        case .success:
                            trustAwarded += effect.flatBonusSubpoints
                        }
                    }
                }
            }
            if let contributionID = action.watershedEffectID, !alreadyRewarded {
                switch applyWatershed(state: &next, contributionID: contributionID, catalog: catalog) {
                case .failure(let failure):
                    return .failure(failure)
                case .success(let points):
                    watershedAwarded += points
                    grantedNow.append(ContentID.correctDWatershedEffect)
                }
            }

        case .watershedElseRelationship:
            // Exactly one of the two rewards is ever granted, and only once.
            if !alreadyRewarded {
                let canalCompleted = QuestService.status(
                    of: ContentID.restoreOldCanalQuest,
                    in: next
                ) == .completed
                if canalCompleted {
                    guard let effectID = action.relationshipEffectID,
                          let effect = catalog.relationshipEffect(id: effectID),
                          let targetID = relationshipTargetID(effect: effect, claim: claim) else {
                        return .failure(.invalidContent)
                    }
                    switch RelationshipService.applyFlatBonus(
                        state: &next,
                        npcID: targetID,
                        subpoints: effect.flatBonusSubpoints,
                        catalog: catalog
                    ) {
                    case .failure:
                        return .failure(.invalidContent)
                    case .success:
                        trustAwarded += effect.flatBonusSubpoints
                        grantedNow.append(effectID)
                    }
                } else {
                    guard let contributionID = action.watershedEffectID else {
                        return .failure(.invalidContent)
                    }
                    switch applyWatershed(state: &next, contributionID: contributionID, catalog: catalog) {
                    case .failure(let failure):
                        return .failure(failure)
                    case .success(let points):
                        watershedAwarded += points
                        grantedNow.append(ContentID.correctDWatershedEffect)
                    }
                }
            }
        }

        if let questEffectID = action.questEffectID {
            switch QuestService.accept(state: next, questID: questEffectID, catalog: catalog) {
            case .failure:
                return .failure(.invalidContent)
            case .success(let updated):
                next = updated
            }
        }

        let standingAfter = GossipService.applyStandingDelta(
            state: &next,
            delta: action.standingDelta,
            catalog: catalog
        )

        event.actionHistory.append(
            GossipActionRecord(
                sequence: event.nextSequence,
                actionID: action.id,
                npcID: npcID,
                day: next.clock.day,
                minute: next.clock.minute
            )
        )
        event.status = action.nextStatus
        if action.nextStatus == .verified || action.nextStatus == .resolvedCorrected {
            event.truthVerified = true
        }
        event.grantedEffectIDs = Array(Set(event.grantedEffectIDs).union(grantedNow)).sorted()
        if action.nextStatus.isTerminal {
            event.resolvedDay = next.clock.day
            next.community.retireEvent(event)
        } else {
            next.community.replaceActiveEvent(event)
        }

        switch action.nextStatus {
        case .resolvedRelay:
            GossipService.setStance(state: &next, npcID: claim.relayNpcID, stance: .relayingUnverified)
        case .resolvedCorrected:
            GossipService.setStance(state: &next, npcID: claim.relayNpcID, stance: .relayingVerified)
        default:
            break
        }

        state = next
        return .success(
            GossipSubmitOutcome(
                actionID: action.id,
                event: event,
                didApply: true,
                standingBefore: standingBefore,
                standingAfter: standingAfter,
                watershedPointsAwarded: watershedAwarded,
                trustSubpointsAwarded: trustAwarded,
                grantedEffectIDs: event.grantedEffectIDs
            )
        )
    }

    /// Completes neighbour C's optional single-step objective. It has no
    /// standing gate, so it always stays usable as a recovery path.
    @discardableResult
    static func completeEvidenceObjective(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> Result<Int, GossipFailure> {
        guard let quest = catalog.quest(id: ContentID.evidenceOneStepQuest) else {
            return .failure(.invalidContent)
        }
        guard quest.minStanding == nil else {
            return .failure(.invalidContent)
        }
        var next = state
        if QuestService.status(of: quest.id, in: next) == .completed {
            state = next
            return .success(next.community.standing)
        }
        guard case .success(let accepted) = QuestService.accept(
            state: next,
            questID: quest.id,
            catalog: catalog
        ) else {
            return .failure(.invalidContent)
        }
        next = accepted
        next.questLog.setStatus(.readyToTurnIn, for: quest.id)
        guard case .success(let completed) = QuestService.complete(
            state: next,
            questID: quest.id,
            catalog: catalog
        ) else {
            return .failure(.invalidContent)
        }
        next = completed
        let standing = GossipService.applyStandingDelta(
            state: &next,
            delta: quest.standingReward,
            catalog: catalog
        )
        GossipService.setEndorsement(state: &next, npcID: ContentID.neighborEvidence, unlocked: true)
        state = next
        return .success(standing)
    }

    private static func relationshipTargetID(
        effect: RelationshipEffectDefinition,
        claim: GossipClaimDefinition
    ) -> String? {
        switch effect.targetSelector {
        case .claimTarget:
            return claim.targetNpcID
        case .fixedNpc:
            return effect.fixedNpcID
        }
    }

    private static func applyWatershed(
        state: inout GameState,
        contributionID: String,
        catalog: ContentCatalog
    ) -> Result<Int, GossipFailure> {
        guard let contribution = catalog.contribution(id: contributionID) else {
            return .failure(.invalidContent)
        }
        guard !contribution.countsTowardMainline else {
            return .failure(.invalidContent)
        }
        switch WatershedService.apply(
            state: state,
            contributionID: contributionID,
            sourceEventID: contribution.sourceEventID,
            catalog: catalog
        ) {
        case .failure:
            return .failure(.invalidContent)
        case .success(let applied):
            state = applied.state
            return .success(applied.pointsAwarded)
        }
    }
}
