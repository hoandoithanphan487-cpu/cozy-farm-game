enum ProgressionCatalog {
    static let gatherNodes: [String: GatherNodeDefinition] = Dictionary(
        uniqueKeysWithValues: gatherNodeList.map { ($0.id, $0) }
    )

    static let quests: [String: QuestDefinition] = [
        ContentID.restoreOldCanalQuest: restoreOldCanalQuest,
        ContentID.marketNoticeQuest: marketNoticeQuest,
        ContentID.evidenceOneStepQuest: evidenceOneStepQuest,
    ]

    static let contributions: [String: WatershedContributionDefinition] = Dictionary(
        uniqueKeysWithValues: contributionList.map { ($0.id, $0) }
    )

    static let dialogues: [String: DialogueDefinition] = Dictionary(
        uniqueKeysWithValues: dialogueList.map { ($0.id, $0) }
    )

    static let displayNames: [String: String] = [
        "item.rain_barrel": "雨水桶",
        "recipe.rain_barrel": "雨水桶",
        "quest.restore_old_canal": "让旧水渠再次流动",
        "quest.market_notice_board": "邻里告示板：溪岸互助",
        "quest.evidence_one_step": "可选恢复：把观察痕迹交给青砚",
    ]

    static let gatherNodeList: [GatherNodeDefinition] = [
        GatherNodeDefinition(
            id: ContentID.farmWoodGather,
            mapID: ContentID.farmHomestead,
            position: GridPosition(x: 1, y: 6),
            label: "溪木堆",
            yields: [RecipeStack(itemID: ContentID.creekWood, quantity: 8)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.farmMossGather,
            mapID: ContentID.farmHomestead,
            position: GridPosition(x: 12, y: 6),
            label: "苔石堆",
            yields: [RecipeStack(itemID: ContentID.mossStone, quantity: 4)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.farmReedGather,
            mapID: ContentID.farmHomestead,
            position: GridPosition(x: 11, y: 1),
            label: "芦丛",
            yields: [RecipeStack(itemID: ContentID.reedFiber, quantity: 6)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.marketWoodGather,
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 6, y: 4),
            label: "漂木架",
            yields: [RecipeStack(itemID: ContentID.creekWood, quantity: 6)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.marketMossGather,
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 13, y: 4),
            label: "埠头苔石",
            yields: [RecipeStack(itemID: ContentID.mossStone, quantity: 8)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.marketReedGather,
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 12, y: 4),
            label: "浅滩芦丛",
            yields: [RecipeStack(itemID: ContentID.reedFiber, quantity: 6)],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: nil
        ),
        GatherNodeDefinition(
            id: ContentID.restoredBrookGather,
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 13, y: 3),
            label: "回水浅滩",
            yields: [
                RecipeStack(itemID: ContentID.creekWood, quantity: 4),
                RecipeStack(itemID: ContentID.mossStone, quantity: 2),
            ],
            oneTime: true,
            staminaCost: 2,
            requiredUnlockID: ContentID.restoredBrookGather
        ),
    ]

    static let contributionList: [WatershedContributionDefinition] = [
        WatershedContributionDefinition(
            id: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            points: 12,
            prerequisiteIDs: [],
            oneTime: true,
            countsTowardMainline: true
        ),
        WatershedContributionDefinition(
            id: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            points: 8,
            prerequisiteIDs: [ContentID.placeCanalContribution],
            oneTime: true,
            countsTowardMainline: true
        ),
        // Social bonus for `correct_d`. Never part of the guaranteed 12+8 path.
        WatershedContributionDefinition(
            id: ContentID.correctDBonusContribution,
            sourceEventID: ContentID.correctDBonusEvent,
            points: 2,
            prerequisiteIDs: [],
            oneTime: true,
            countsTowardMainline: false
        ),
    ]

    static let restoreOldCanalQuest = QuestDefinition(
        id: ContentID.restoreOldCanalQuest,
        titleKey: "quest.restore_old_canal",
        title: "让旧水渠再次流动",
        isMainline: true,
        oneTime: true,
        minStanding: nil,
        objectives: [
            QuestObjectiveDefinition(
                id: "brookseed.objective.place_canal_segment",
                kind: .build,
                targetID: ContentID.canalSegmentObject,
                quantity: 1,
                consumesItems: false
            ),
            QuestObjectiveDefinition(
                id: "brookseed.objective.deliver_canal_repair",
                kind: .deliver,
                targetID: ContentID.waterApprentice,
                quantity: 1,
                consumesItems: false
            ),
        ],
        completionEventID: ContentID.deliverCanalEvent
    )

    /// Optional bonus node used to demonstrate the `min_standing` boundary.
    /// It pauses below 41 and resumes above it; it never gates the canal line.
    static let marketNoticeQuest = QuestDefinition(
        id: ContentID.marketNoticeQuest,
        titleKey: "quest.market_notice_board",
        title: "邻里告示板：溪岸互助",
        isMainline: false,
        oneTime: true,
        minStanding: 41,
        recoveryPathIDs: [
            ContentID.correctDAction,
            ContentID.evidenceOneStepQuest,
        ],
        standingReward: 0,
        objectives: [
            QuestObjectiveDefinition(
                id: "brookseed.objective.read_market_notice",
                kind: .talk,
                targetID: ContentID.creekWarden,
                quantity: 1,
                consumesItems: false
            ),
        ],
        completionEventID: "brookseed.event.read_market_notice"
    )

    /// Neighbour C's single-step personal request. No standing gate, so it stays
    /// available as a recovery path; completing it grants +5 standing once.
    static let evidenceOneStepQuest = QuestDefinition(
        id: ContentID.evidenceOneStepQuest,
        titleKey: "quest.evidence_one_step",
        title: "可选恢复：把观察痕迹交给青砚",
        isMainline: false,
        oneTime: true,
        minStanding: nil,
        recoveryPathIDs: [],
        standingReward: 5,
        objectives: [
            QuestObjectiveDefinition(
                id: "brookseed.objective.show_observed_trace",
                kind: .talk,
                targetID: ContentID.neighborEvidence,
                quantity: 1,
                consumesItems: false
            ),
        ],
        completionEventID: "brookseed.event.evidence_one_step"
    )

    static let dialogueList: [DialogueDefinition] = [
        DialogueDefinition(
            id: ContentID.waterApprenticeQuestOffer,
            speakerName: "水工学徒",
            lines: [
                "旧铜闸还是干的。你若愿意，就接这个活：让旧水渠再次流动。",
                "农场杂物和溪岸浅滩都有保底材料。做成水渠接片，安到农舍铜闸边。",
                "接片安好后再来找我回报施工结果，不必再交材料。",
            ],
            completedReply: "接片还没安上。材料在农场杂物和溪岸都能找到。"
        ),
        DialogueDefinition(
            id: ContentID.waterApprenticeQuestProgress,
            speakerName: "水工学徒",
            lines: [
                "接片还没安上。溪木和苔石够做一个水渠接片就行。",
                "放到农舍铜闸边，渠口才会重新咬合。",
            ],
            completedReply: "先把接片安上，再来回报。"
        ),
        DialogueDefinition(
            id: ContentID.waterApprenticeQuestTurnIn,
            speakerName: "水工学徒",
            lines: [
                "铜闸接上了。我记下这次修复，不再收你手里的材料。",
                "水脉会再醒一截。你听，干渠里该有流水层了。",
            ],
            completedReply: "水已经从旧渠口回来了。"
        ),
        DialogueDefinition(
            id: ContentID.waterApprenticeQuestDone,
            speakerName: "水工学徒",
            lines: [
                "水已经从旧渠口回来了。雨水桶的做法也可以试。",
            ],
            completedReply: "渠口还在淌。雨水桶配方已经解开。"
        ),
    ]
}
