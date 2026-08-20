//
//  CommunityCatalog.swift
//  CreekSprout
//
//  VS-1 community message event content. All standing, trust and reward numbers
//  live here; domain services and tests read them from this configuration and
//  never redeclare their own copies.
//

enum CommunityCatalog {
    static let balance = CommunityBalanceDefinition(
        newGameStanding: 50,
        minStanding: 0,
        maxStanding: 100,
        baseFirstTalkSubpoints: 300,
        maxTrustSubpoints: 10_000,
        fixedPointScale: 100_000_000,
        bands: [
            StandingBandDefinition(
                id: ContentID.standingBandLow,
                lowerBound: 0,
                upperBound: 40,
                trustMultiplierBP: 8_500,
                label: "低风评（信任增长 −15%）"
            ),
            StandingBandDefinition(
                id: ContentID.standingBandNeutral,
                lowerBound: 41,
                upperBound: 69,
                trustMultiplierBP: 10_000,
                label: "常规区间（信任增长无修正）"
            ),
            StandingBandDefinition(
                id: ContentID.standingBandHigh,
                lowerBound: 70,
                upperBound: 100,
                trustMultiplierBP: 11_000,
                label: "高风评（信任增长 +10%）"
            ),
        ]
    )

    static let events: [String: GossipEventDefinition] = Dictionary(
        uniqueKeysWithValues: eventList.map { ($0.id, $0) }
    )

    static let claims: [String: GossipClaimDefinition] = Dictionary(
        uniqueKeysWithValues: claimList.map { ($0.id, $0) }
    )

    static let actions: [String: GossipActionDefinition] = Dictionary(
        uniqueKeysWithValues: actionList.map { ($0.id, $0) }
    )

    static let conditions: [String: GossipConditionDefinition] = Dictionary(
        uniqueKeysWithValues: conditionList.map { ($0.id, $0) }
    )

    static let conditionGroups: [String: ConditionGroupDefinition] = Dictionary(
        uniqueKeysWithValues: conditionGroupList.map { ($0.id, $0) }
    )

    static let relationshipEffects: [String: RelationshipEffectDefinition] = Dictionary(
        uniqueKeysWithValues: relationshipEffectList.map { ($0.id, $0) }
    )

    static let displayNames: [String: String] = [
        "gossip.claim.sluice_plank": "埠头闸板的说法",
        "gossip.action.relay_unverified": "未经核实便转述",
        "gossip.action.defer_judgment": "暂不判断",
        "gossip.action.start_verification": "开始核实",
        "gossip.action.verify_with_c": "向青砚核实",
        "gossip.action.correct_d": "纠正絮宁",
        "quest.market_notice_board": "邻里告示板：溪岸互助",
        "quest.evidence_one_step": "可选恢复：把观察痕迹交给青砚",
    ]

    static let eventList: [GossipEventDefinition] = [
        GossipEventDefinition(
            id: ContentID.sluicePlankEvent,
            claimID: ContentID.sluicePlankClaim,
            triggerNpcID: ContentID.neighborHearsay,
            triggerDay: 2,
            cooldownDays: 2,
            deadlineOffsetDays: 1,
            deadlineMinute: GameClock.dayEndMinute,
            prerequisiteIDs: [],
            actionIDs: ContentID.gossipActionIDs
        ),
    ]

    static let claimList: [GossipClaimDefinition] = [
        GossipClaimDefinition(
            id: ContentID.sluicePlankClaim,
            rumorTextKey: "gossip.claim.sluice_plank.rumor",
            rumorText: "有人说水工学徒把旧闸板丢在埠头，才害得渠口一直不通。",
            verifiedTextKey: "gossip.claim.sluice_plank.verified",
            verifiedText: "闸板是春潮从上游冲下来的：苔石背面留着新的撞痕，与学徒无关。",
            targetNpcID: ContentID.waterApprentice,
            relayNpcID: ContentID.neighborConsensus,
            verificationRuleID: ContentID.verifyEvidenceConditionGroup
        ),
    ]

    static let conditionList: [GossipConditionDefinition] = [
        GossipConditionDefinition(
            id: ContentID.observedEvidenceCondition,
            kind: .observedEvidence,
            requiredStatus: .investigating,
            npcID: ContentID.neighborEvidence
        ),
        GossipConditionDefinition(
            id: ContentID.endorsementCondition,
            kind: .endorsementFlag,
            requiredStatus: nil,
            npcID: ContentID.neighborEvidence
        ),
    ]

    static let conditionGroupList: [ConditionGroupDefinition] = [
        ConditionGroupDefinition(
            id: ContentID.verifyEvidenceConditionGroup,
            mode: .any,
            conditionIDs: [
                ContentID.observedEvidenceCondition,
                ContentID.endorsementCondition,
            ]
        ),
    ]

    static let relationshipEffectList: [RelationshipEffectDefinition] = [
        RelationshipEffectDefinition(
            id: ContentID.relayMisunderstandingEffect,
            targetSelector: .claimTarget,
            fixedNpcID: nil,
            zeroGrowthToday: true,
            firstTalkMultiplierBP: 5_000,
            firstTalkStartOffsetDays: 1,
            durationDays: 1,
            flatBonusSubpoints: 0,
            stackPolicy: .replace
        ),
        RelationshipEffectDefinition(
            id: ContentID.correctDTrustEffect,
            targetSelector: .claimTarget,
            fixedNpcID: nil,
            zeroGrowthToday: false,
            firstTalkMultiplierBP: CommunityBalanceDefinition.neutralBasisPoints,
            firstTalkStartOffsetDays: 0,
            durationDays: 0,
            flatBonusSubpoints: 300,
            stackPolicy: .reject
        ),
    ]

    static let actionList: [GossipActionDefinition] = [
        GossipActionDefinition(
            id: ContentID.relayUnverifiedAction,
            choiceTextKey: "gossip.action.relay_unverified",
            choiceText: "未经核实便转述",
            interactionSelector: .triggerNpc,
            fixedNpcID: nil,
            requiredStatus: .offered,
            conditionGroupID: nil,
            standingDelta: -8,
            relationshipEffectID: ContentID.relayMisunderstandingEffect,
            questEffectID: nil,
            watershedEffectID: nil,
            rewardPolicy: .applyConfigured,
            nextStatus: .resolvedRelay
        ),
        GossipActionDefinition(
            id: ContentID.deferJudgmentAction,
            choiceTextKey: "gossip.action.defer_judgment",
            choiceText: "暂不判断",
            interactionSelector: .triggerNpc,
            fixedNpcID: nil,
            requiredStatus: .offered,
            conditionGroupID: nil,
            standingDelta: 0,
            relationshipEffectID: nil,
            questEffectID: nil,
            watershedEffectID: nil,
            rewardPolicy: .applyConfigured,
            nextStatus: .deferred
        ),
        GossipActionDefinition(
            id: ContentID.startVerificationAction,
            choiceTextKey: "gossip.action.start_verification",
            choiceText: "开始核实",
            interactionSelector: .triggerNpc,
            fixedNpcID: nil,
            requiredStatus: .offered,
            conditionGroupID: nil,
            standingDelta: 0,
            relationshipEffectID: nil,
            questEffectID: nil,
            watershedEffectID: nil,
            rewardPolicy: .applyConfigured,
            nextStatus: .investigating
        ),
        GossipActionDefinition(
            id: ContentID.verifyWithCAction,
            choiceTextKey: "gossip.action.verify_with_c",
            choiceText: "向青砚核实",
            interactionSelector: .fixedNpc,
            fixedNpcID: ContentID.neighborEvidence,
            requiredStatus: .investigating,
            conditionGroupID: ContentID.verifyEvidenceConditionGroup,
            standingDelta: 0,
            relationshipEffectID: nil,
            questEffectID: nil,
            watershedEffectID: nil,
            rewardPolicy: .applyConfigured,
            nextStatus: .verified
        ),
        GossipActionDefinition(
            id: ContentID.correctDAction,
            choiceTextKey: "gossip.action.correct_d",
            choiceText: "纠正絮宁",
            interactionSelector: .fixedNpc,
            fixedNpcID: ContentID.neighborConsensus,
            requiredStatus: .verified,
            conditionGroupID: nil,
            standingDelta: 8,
            relationshipEffectID: ContentID.correctDTrustEffect,
            questEffectID: nil,
            watershedEffectID: ContentID.correctDBonusContribution,
            rewardPolicy: .watershedElseRelationship,
            nextStatus: .resolvedCorrected
        ),
    ]
}
