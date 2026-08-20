struct ContentValidationError: Error, Equatable, CustomStringConvertible {
    var reason: String

    var description: String { reason }
}

enum ContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        try validateKeysMatchIDs(catalog)
        try validate(
            maps: Array(catalog.maps.values),
            npcs: Array(catalog.npcs.values),
            dialogues: Array(catalog.dialogues.values),
            farmSpawns: catalog.scenario.startingNpcSpawns,
            scenario: catalog.scenario
        )
        try validateProgression(catalog)
        try validateCommunity(catalog)
    }

    static func validate(
        maps: [MapDefinition],
        npcs: [NpcDefinition],
        dialogues: [DialogueDefinition],
        farmSpawns: [InitialNpcSpawn] = [],
        scenario: NewGameScenarioDefinition? = nil
    ) throws {
        var seen = Set<String>()
        func claim(_ id: String, kind: String) throws {
            guard ContentID.isValid(id) else {
                throw ContentValidationError(reason: "非法\(kind) ID：\(id)")
            }
            guard seen.insert(id).inserted else {
                throw ContentValidationError(reason: "重复 ID：\(id)")
            }
        }

        for map in maps {
            try claim(map.id, kind: "地图")
            guard map.columns > 0, map.rows > 0 else {
                throw ContentValidationError(reason: "地图边界非法：\(map.id)")
            }
            for cell in map.blockedCells {
                guard map.contains(cell) else {
                    throw ContentValidationError(reason: "阻挡格越界：\(map.id)")
                }
            }
            for landmark in map.landmarks {
                try claim(landmark.id, kind: "地标")
                guard map.contains(landmark.position) else {
                    throw ContentValidationError(reason: "地标越界：\(landmark.id)")
                }
            }
            for spawn in map.spawns {
                try claim(spawn.id, kind: "出生点")
                try validateOccupancy(spawn.position, on: map, kind: "出生点 \(spawn.id)")
            }
            guard !map.exits.isEmpty else {
                throw ContentValidationError(reason: "地图缺少出口：\(map.id)")
            }
            for exit in map.exits {
                try claim(exit.id, kind: "出口")
                try validateOccupancy(exit.cell, on: map, kind: "出口 \(exit.id)")
                guard maps.contains(where: { $0.id == exit.destinationMapID }) else {
                    throw ContentValidationError(reason: "出口引用缺失地图：\(exit.destinationMapID)")
                }
            }
        }

        for dialogue in dialogues {
            try claim(dialogue.id, kind: "对白")
            guard !dialogue.lines.isEmpty else {
                throw ContentValidationError(reason: "对白缺少行：\(dialogue.id)")
            }
        }

        var npcCells: [String: Set<GridPosition>] = [:]
        for npc in npcs {
            try claim(npc.id, kind: "角色")
            guard maps.contains(where: { $0.id == npc.mapID }) else {
                throw ContentValidationError(reason: "角色引用缺失地图：\(npc.mapID)")
            }
            guard dialogues.contains(where: { $0.id == npc.dialoguePoolID }) else {
                throw ContentValidationError(reason: "角色引用缺失对白：\(npc.dialoguePoolID)")
            }
            if npc.role == .neighbor {
                guard npc.personalityArchetype != nil else {
                    throw ContentValidationError(reason: "邻居缺少性格：\(npc.id)")
                }
            } else {
                guard npc.personalityArchetype == nil else {
                    throw ContentValidationError(reason: "职能角色不应有邻居性格：\(npc.id)")
                }
            }
            guard let map = maps.first(where: { $0.id == npc.mapID }) else {
                continue
            }
            try validateOccupancy(npc.position, on: map, kind: "角色 \(npc.id)")
            var occupied = npcCells[npc.mapID, default: []]
            guard occupied.insert(npc.position).inserted else {
                throw ContentValidationError(reason: "角色位置重叠：\(npc.id)")
            }
            npcCells[npc.mapID] = occupied
        }

        for spawn in farmSpawns {
            guard ContentID.isValid(spawn.npcID) else {
                throw ContentValidationError(reason: "非法角色 ID：\(spawn.npcID)")
            }
            guard dialogues.contains(where: { $0.id == spawn.dialogueID }) else {
                throw ContentValidationError(reason: "角色引用缺失对白：\(spawn.dialogueID)")
            }
            if let farm = maps.first(where: { $0.id == ContentID.farmHomestead }) {
                try validateOccupancy(spawn.position, on: farm, kind: "农场角色 \(spawn.npcID)")
            }
        }

        for map in maps {
            for exit in map.exits {
                guard let destination = maps.first(where: { $0.id == exit.destinationMapID }) else {
                    throw ContentValidationError(reason: "出口引用缺失地图：\(exit.destinationMapID)")
                }
                guard destination.spawn(id: exit.destinationSpawnID) != nil else {
                    throw ContentValidationError(reason: "出口引用缺失出生点：\(exit.destinationSpawnID)")
                }
                let hasReturn = destination.exits.contains { returning in
                    returning.destinationMapID == map.id
                }
                guard hasReturn else {
                    throw ContentValidationError(reason: "出口不是双向：\(exit.id)")
                }
            }

            let npcBlocked = npcCells[map.id, default: []]
            var blocked = map.blockedCells
            blocked.formUnion(npcBlocked)
            for spawn in map.spawns {
                for exit in map.exits {
                    guard canReach(exit.cell, from: spawn.position, map: map, blocked: blocked) else {
                        throw ContentValidationError(reason: "角色或障碍阻断唯一出口：\(map.id)")
                    }
                }
            }
        }

        if let scenario {
            guard maps.contains(where: { $0.id == ContentID.farmHomestead }) else {
                throw ContentValidationError(reason: "缺失地图：\(ContentID.farmHomestead)")
            }
            guard maps.contains(where: { $0.id == ContentID.creekMarket }) else {
                throw ContentValidationError(reason: "缺失地图：\(ContentID.creekMarket)")
            }
            if let farm = maps.first(where: { $0.id == ContentID.farmHomestead }) {
                guard farm.contains(scenario.playerStart) else {
                    throw ContentValidationError(reason: "出生点越界：玩家")
                }
                guard farm.exit(at: scenario.exitCell) != nil else {
                    throw ContentValidationError(reason: "场景出口与地图出口不一致")
                }
            }
        }
    }

    static func validateProgression(_ catalog: ContentCatalog) throws {
        var seen = Set<String>()
        seen.formUnion(catalog.maps.keys)
        seen.formUnion(catalog.npcs.keys)
        seen.formUnion(catalog.dialogues.keys)
        for map in catalog.maps.values {
            seen.formUnion(map.landmarks.map(\.id))
            seen.formUnion(map.spawns.map(\.id))
            seen.formUnion(map.exits.map(\.id))
        }

        func claim(_ id: String, kind: String) throws {
            guard ContentID.isValid(id) else {
                throw ContentValidationError(reason: "非法\(kind) ID：\(id)")
            }
            guard seen.insert(id).inserted else {
                throw ContentValidationError(reason: "重复 ID：\(id)")
            }
        }

        var occupied: [String: Set<GridPosition>] = [:]
        for npc in catalog.npcs.values {
            occupied[npc.mapID, default: []].insert(npc.position)
        }
        for spawn in catalog.scenario.startingNpcSpawns {
            occupied[ContentID.farmHomestead, default: []].insert(spawn.position)
        }

        for node in catalog.gatherNodes.values {
            try claim(node.id, kind: "采集点")
            guard let map = catalog.map(id: node.mapID) else {
                throw ContentValidationError(reason: "采集点引用缺失地图：\(node.id)")
            }
            try validateOccupancy(node.position, on: map, kind: "采集点 \(node.id)")
            if map.exit(at: node.position) != nil {
                throw ContentValidationError(reason: "采集点占用出口：\(node.id)")
            }
            if occupied[node.mapID, default: []].contains(node.position) {
                throw ContentValidationError(reason: "采集点位置重叠：\(node.id)")
            }
            occupied[node.mapID, default: []].insert(node.position)
            guard node.oneTime else {
                throw ContentValidationError(reason: "保底采集点必须一次性：\(node.id)")
            }
            guard node.staminaCost >= 0 else {
                throw ContentValidationError(reason: "采集体力非法：\(node.id)")
            }
            guard !node.yields.isEmpty else {
                throw ContentValidationError(reason: "采集点缺少产出：\(node.id)")
            }
            for yield in node.yields {
                guard catalog.knowsItemID(yield.itemID), yield.quantity >= 1 else {
                    throw ContentValidationError(reason: "采集产出非法：\(node.id)")
                }
            }
            if let unlockID = node.requiredUnlockID, !ContentID.isValid(unlockID) {
                throw ContentValidationError(reason: "采集解锁 ID 非法：\(node.id)")
            }
        }

        try validateGuaranteedYields(catalog)

        for quest in catalog.quests.values {
            try claim(quest.id, kind: "任务")
            if quest.isMainline, quest.minStanding != nil {
                throw ContentValidationError(reason: "主线禁止 min_standing：\(quest.id)")
            }
            guard !quest.objectives.isEmpty else {
                throw ContentValidationError(reason: "任务缺少目标：\(quest.id)")
            }
            for objective in quest.objectives {
                try claim(objective.id, kind: "任务目标")
                if quest.isMainline, objective.kind == .deliver, objective.consumesItems {
                    throw ContentValidationError(reason: "主线交付不得消耗物品：\(objective.id)")
                }
            }
        }

        var mainlinePoints = 0
        for contribution in catalog.watershedContributions.values {
            try claim(contribution.id, kind: "水脉贡献")
            guard ContentID.isValid(contribution.sourceEventID) else {
                throw ContentValidationError(reason: "贡献来源非法：\(contribution.id)")
            }
            guard contribution.points >= 0 else {
                throw ContentValidationError(reason: "贡献点数非法：\(contribution.id)")
            }
            guard contribution.oneTime else {
                throw ContentValidationError(reason: "VS-1 贡献必须一次性：\(contribution.id)")
            }
            for prerequisite in contribution.prerequisiteIDs {
                guard catalog.knowsContributionID(prerequisite) else {
                    throw ContentValidationError(reason: "贡献前置缺失：\(prerequisite)")
                }
            }
            if contribution.countsTowardMainline {
                mainlinePoints += contribution.points
            }
        }
        guard catalog.contribution(id: ContentID.placeCanalContribution)?.points == 12 else {
            throw ContentValidationError(reason: "放置贡献必须为 12")
        }
        guard catalog.contribution(id: ContentID.deliverCanalContribution)?.points == 8 else {
            throw ContentValidationError(reason: "回报贡献必须为 8")
        }
        guard catalog.contribution(id: ContentID.deliverCanalContribution)?
            .prerequisiteIDs.contains(ContentID.placeCanalContribution) == true else {
            throw ContentValidationError(reason: "回报贡献缺少放置前置")
        }
        guard mainlinePoints == 20 else {
            throw ContentValidationError(reason: "主线保底水脉必须为 20")
        }
        if catalog.watershedContributions["brookseed.contribution.correct_d_bonus"]?.countsTowardMainline == true {
            throw ContentValidationError(reason: "correct_d_bonus 不得计入主线保底")
        }

        guard let canal = catalog.recipe(id: ContentID.canalSegmentRecipe) else {
            throw ContentValidationError(reason: "缺失水渠接片配方")
        }
        guard canal.inputs.contains(where: { $0.itemID == ContentID.creekWood && $0.quantity == 6 }),
              canal.inputs.contains(where: { $0.itemID == ContentID.mossStone && $0.quantity == 4 }) else {
            throw ContentValidationError(reason: "水渠接片配方材料不符")
        }
        guard let rainBarrel = catalog.recipe(id: ContentID.rainBarrelRecipe) else {
            throw ContentValidationError(reason: "缺失雨水桶配方")
        }
        guard rainBarrel.requiredUnlockID == ContentID.rainBarrelUnlock else {
            throw ContentValidationError(reason: "雨水桶必须在水脉 20 后解锁")
        }
        guard catalog.gatherNode(id: ContentID.restoredBrookGather)?.requiredUnlockID != nil else {
            throw ContentValidationError(reason: "新采集点必须有解锁条件")
        }
    }

    /// M3-003 community content: balance table, event, claim, five actions,
    /// conditions, effects and the ungated recovery paths behind every
    /// standing-gated optional node.
    static func validateCommunity(_ catalog: ContentCatalog) throws {
        try validateCommunityKeysMatchIDs(catalog)
        try validateDisplayNames(catalog)
        try validateBalance(catalog.communityBalance)
        try validateTransitionTable()
        try validateRelationshipEffects(catalog)
        try validateConditions(catalog)
        try validateActions(catalog)
        try validateClaims(catalog)
        try validateEvents(catalog)
        try validateStandingGates(catalog)
    }

    private static func validateCommunityKeysMatchIDs(_ catalog: ContentCatalog) throws {
        for (key, definition) in catalog.gossipEvents where key != definition.id {
            throw ContentValidationError(reason: "社区事件键与 ID 不一致：\(key)")
        }
        for (key, definition) in catalog.gossipClaims where key != definition.id {
            throw ContentValidationError(reason: "说法键与 ID 不一致：\(key)")
        }
        for (key, definition) in catalog.gossipActions where key != definition.id {
            throw ContentValidationError(reason: "社区行动键与 ID 不一致：\(key)")
        }
        for (key, definition) in catalog.gossipConditions where key != definition.id {
            throw ContentValidationError(reason: "条件键与 ID 不一致：\(key)")
        }
        for (key, definition) in catalog.conditionGroups where key != definition.id {
            throw ContentValidationError(reason: "条件组键与 ID 不一致：\(key)")
        }
        for (key, definition) in catalog.relationshipEffects where key != definition.id {
            throw ContentValidationError(reason: "关系效果键与 ID 不一致：\(key)")
        }
    }

    private static func validateDisplayNames(_ catalog: ContentCatalog) throws {
        for retired in ContentID.retiredNeighborDisplayNames {
            if catalog.displayNames.values.contains(retired) {
                throw ContentValidationError(reason: "禁止使用旧显示名：\(retired)")
            }
            if catalog.npcs.values.contains(where: { $0.displayName == retired }) {
                throw ContentValidationError(reason: "禁止使用旧显示名：\(retired)")
            }
        }
        for (npcID, expected) in ContentID.requiredNeighborDisplayNames {
            guard let npc = catalog.npc(id: npcID) else {
                throw ContentValidationError(reason: "缺失邻居：\(npcID)")
            }
            guard npc.displayName == expected,
                  catalog.displayName(forNameKey: npc.nameKey) == expected else {
                throw ContentValidationError(reason: "邻居显示名必须为 \(expected)：\(npcID)")
            }
        }
    }

    private static func validateBalance(_ balance: CommunityBalanceDefinition) throws {
        guard balance.minStanding == 0, balance.maxStanding == 100 else {
            throw ContentValidationError(reason: "风评区间必须为 0...100")
        }
        guard (balance.minStanding...balance.maxStanding).contains(balance.newGameStanding) else {
            throw ContentValidationError(reason: "新档风评越界")
        }
        guard balance.baseFirstTalkSubpoints > 0, balance.maxTrustSubpoints > 0 else {
            throw ContentValidationError(reason: "信任基础数值非法")
        }
        let neutral = CommunityBalanceDefinition.neutralBasisPoints
        guard balance.fixedPointScale == neutral * neutral else {
            throw ContentValidationError(reason: "定点除数必须等于 standing_bp × first_talk_bp")
        }
        guard !balance.bands.isEmpty else {
            throw ContentValidationError(reason: "缺少风评区间表")
        }
        var seenBandIDs = Set<String>()
        var expectedLower = balance.minStanding
        for band in balance.bands.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard ContentID.isValid(band.id), seenBandIDs.insert(band.id).inserted else {
                throw ContentValidationError(reason: "风评区间 ID 非法或重复：\(band.id)")
            }
            guard band.lowerBound == expectedLower, band.upperBound >= band.lowerBound else {
                throw ContentValidationError(reason: "风评区间不连续：\(band.id)")
            }
            guard (0...CommunityBalanceDefinition.maxBasisPoints).contains(band.trustMultiplierBP) else {
                throw ContentValidationError(reason: "风评区间倍率非法：\(band.id)")
            }
            guard !band.label.isEmpty else {
                throw ContentValidationError(reason: "风评区间缺少文案：\(band.id)")
            }
            expectedLower = band.upperBound + 1
        }
        guard expectedLower == balance.maxStanding + 1 else {
            throw ContentValidationError(reason: "风评区间未覆盖 0...100")
        }
    }

    /// The state machine must reach every declared status from `offered` and
    /// must never leave a terminal status.
    private static func validateTransitionTable() throws {
        for status in GossipEventStatus.allCases {
            guard GossipTransitionTable.allowed[status] != nil else {
                throw ContentValidationError(reason: "状态缺少迁移表条目：\(status.rawValue)")
            }
            if status.isTerminal {
                guard GossipTransitionTable.allowed[status]?.isEmpty == true else {
                    throw ContentValidationError(reason: "终态不得继续迁移：\(status.rawValue)")
                }
            }
        }
        var reachable: Set<GossipEventStatus> = [.offered]
        var frontier: [GossipEventStatus] = [.offered]
        while let current = frontier.popLast() {
            for next in GossipTransitionTable.allowed[current] ?? [] where reachable.insert(next).inserted {
                frontier.append(next)
            }
        }
        for status in GossipEventStatus.allCases where !reachable.contains(status) {
            throw ContentValidationError(reason: "状态不可达：\(status.rawValue)")
        }
    }

    private static func validateRelationshipEffects(_ catalog: ContentCatalog) throws {
        for effect in catalog.relationshipEffects.values {
            guard ContentID.isValid(effect.id) else {
                throw ContentValidationError(reason: "关系效果 ID 非法：\(effect.id)")
            }
            switch effect.targetSelector {
            case .claimTarget:
                guard effect.fixedNpcID == nil else {
                    throw ContentValidationError(reason: "claim_target 效果不应指定固定角色：\(effect.id)")
                }
            case .fixedNpc:
                guard let npcID = effect.fixedNpcID, catalog.npc(id: npcID) != nil else {
                    throw ContentValidationError(reason: "关系效果引用缺失角色：\(effect.id)")
                }
            }
            guard effect.durationDays >= 0,
                  effect.firstTalkStartOffsetDays >= 0,
                  (0...CommunityBalanceDefinition.maxBasisPoints).contains(effect.firstTalkMultiplierBP) else {
                throw ContentValidationError(reason: "关系效果时长或倍率非法：\(effect.id)")
            }
            guard effect.flatBonusSubpoints >= 0,
                  effect.flatBonusSubpoints <= catalog.communityBalance.maxTrustSubpoints else {
                throw ContentValidationError(reason: "一次性信任奖励非法：\(effect.id)")
            }
            guard effect.zeroGrowthToday || effect.hasFirstTalkModifier || effect.flatBonusSubpoints > 0 else {
                throw ContentValidationError(reason: "关系效果没有任何作用：\(effect.id)")
            }
        }
    }

    private static func validateConditions(_ catalog: ContentCatalog) throws {
        for condition in catalog.gossipConditions.values {
            guard ContentID.isValid(condition.id) else {
                throw ContentValidationError(reason: "条件 ID 非法：\(condition.id)")
            }
            guard catalog.npc(id: condition.npcID) != nil else {
                throw ContentValidationError(reason: "条件引用缺失角色：\(condition.id)")
            }
            switch condition.kind {
            case .observedEvidence:
                guard condition.requiredStatus != nil else {
                    throw ContentValidationError(reason: "证据条件缺少状态：\(condition.id)")
                }
            case .endorsementFlag:
                guard condition.requiredStatus == nil else {
                    throw ContentValidationError(reason: "背书条件不应绑定状态：\(condition.id)")
                }
            }
        }
        for group in catalog.conditionGroups.values {
            guard ContentID.isValid(group.id) else {
                throw ContentValidationError(reason: "条件组 ID 非法：\(group.id)")
            }
            guard !group.conditionIDs.isEmpty else {
                throw ContentValidationError(reason: "条件组为空：\(group.id)")
            }
            for conditionID in group.conditionIDs {
                guard catalog.gossipCondition(id: conditionID) != nil else {
                    throw ContentValidationError(reason: "条件组引用缺失条件：\(conditionID)")
                }
            }
        }
    }

    private static func validateActions(_ catalog: ContentCatalog) throws {
        let names = ContentID.gossipActionIDs.compactMap { catalog.gossipAction(id: $0)?.shortName }
        guard names == ContentID.requiredGossipActionNames else {
            throw ContentValidationError(reason: "五个社区行动名称或顺序不符")
        }
        for action in catalog.gossipActions.values {
            guard ContentID.isValid(action.id) else {
                throw ContentValidationError(reason: "社区行动 ID 非法：\(action.id)")
            }
            guard !action.choiceText.isEmpty,
                  catalog.displayName(forNameKey: action.choiceTextKey) == action.choiceText else {
                throw ContentValidationError(reason: "社区行动缺少可读文案：\(action.id)")
            }
            guard GossipTransitionTable.isLegal(from: action.requiredStatus, to: action.nextStatus) else {
                throw ContentValidationError(reason: "社区行动状态迁移非法：\(action.id)")
            }
            switch action.interactionSelector {
            case .triggerNpc:
                guard action.fixedNpcID == nil else {
                    throw ContentValidationError(reason: "trigger_npc 行动不应指定固定角色：\(action.id)")
                }
            case .fixedNpc:
                guard let npcID = action.fixedNpcID, catalog.isNeighbor(npcID) else {
                    throw ContentValidationError(reason: "社区行动引用缺失邻居：\(action.id)")
                }
            }
            if let groupID = action.conditionGroupID {
                guard catalog.conditionGroup(id: groupID) != nil else {
                    throw ContentValidationError(reason: "社区行动引用缺失条件组：\(action.id)")
                }
            }
            if let effectID = action.relationshipEffectID {
                guard catalog.relationshipEffect(id: effectID) != nil else {
                    throw ContentValidationError(reason: "社区行动引用缺失关系效果：\(action.id)")
                }
            }
            if let questID = action.questEffectID {
                guard catalog.quest(id: questID) != nil else {
                    throw ContentValidationError(reason: "社区行动引用缺失任务：\(action.id)")
                }
            }
            if let contributionID = action.watershedEffectID {
                guard let contribution = catalog.contribution(id: contributionID) else {
                    throw ContentValidationError(reason: "社区行动引用缺失水脉贡献：\(action.id)")
                }
                guard !contribution.countsTowardMainline else {
                    throw ContentValidationError(reason: "社区行动不得替代主线水脉：\(action.id)")
                }
            }
            let balance = catalog.communityBalance
            guard abs(action.standingDelta) <= balance.maxStanding - balance.minStanding else {
                throw ContentValidationError(reason: "社区行动风评变化越界：\(action.id)")
            }
            if action.rewardPolicy == .watershedElseRelationship {
                guard action.watershedEffectID != nil, action.relationshipEffectID != nil else {
                    throw ContentValidationError(reason: "二选一奖励需要同时配置两条来源：\(action.id)")
                }
            }
        }
    }

    private static func validateClaims(_ catalog: ContentCatalog) throws {
        for claim in catalog.gossipClaims.values {
            guard ContentID.isValid(claim.id) else {
                throw ContentValidationError(reason: "说法 ID 非法：\(claim.id)")
            }
            guard !claim.rumorText.isEmpty, !claim.verifiedText.isEmpty,
                  claim.rumorText != claim.verifiedText else {
                throw ContentValidationError(reason: "说法缺少可读的传闻/核实文案：\(claim.id)")
            }
            guard catalog.isQuestGiver(claim.targetNpcID) else {
                throw ContentValidationError(reason: "说法目标必须是职能角色：\(claim.id)")
            }
            guard catalog.isNeighbor(claim.relayNpcID) else {
                throw ContentValidationError(reason: "转述者必须是邻居：\(claim.id)")
            }
            guard catalog.conditionGroup(id: claim.verificationRuleID) != nil else {
                throw ContentValidationError(reason: "说法引用缺失核实规则：\(claim.id)")
            }
        }
    }

    private static func validateEvents(_ catalog: ContentCatalog) throws {
        guard let sluice = catalog.gossipEvent(id: ContentID.sluicePlankEvent) else {
            throw ContentValidationError(reason: "缺失闸板社区事件")
        }
        guard sluice.triggerDay == 2,
              sluice.deadlineOffsetDays == 1,
              sluice.deadlineMinute == GameClock.dayEndMinute else {
            throw ContentValidationError(reason: "闸板事件必须第 2 天触发、第 3 天 23:30 截止")
        }
        for event in catalog.gossipEvents.values {
            guard ContentID.isValid(event.id) else {
                throw ContentValidationError(reason: "社区事件 ID 非法：\(event.id)")
            }
            guard catalog.gossipClaim(id: event.claimID) != nil else {
                throw ContentValidationError(reason: "社区事件引用缺失说法：\(event.id)")
            }
            guard catalog.isNeighbor(event.triggerNpcID) else {
                throw ContentValidationError(reason: "社区事件触发者必须是邻居：\(event.id)")
            }
            guard event.triggerDay >= 1, event.cooldownDays >= 0, event.deadlineOffsetDays >= 0 else {
                throw ContentValidationError(reason: "社区事件日程非法：\(event.id)")
            }
            guard (0...1439).contains(event.deadlineMinute) else {
                throw ContentValidationError(reason: "社区事件截止分钟越界：\(event.id)")
            }
            guard event.actionIDs == ContentID.gossipActionIDs else {
                throw ContentValidationError(reason: "社区事件必须提供五个稳定行动：\(event.id)")
            }
            var seenActionIDs = Set<String>()
            for actionID in event.actionIDs {
                guard let action = catalog.gossipAction(id: actionID) else {
                    throw ContentValidationError(reason: "社区事件引用缺失行动：\(actionID)")
                }
                guard seenActionIDs.insert(actionID).inserted else {
                    throw ContentValidationError(reason: "社区事件行动重复：\(actionID)")
                }
                if action.interactionSelector == .triggerNpc {
                    guard catalog.isNeighbor(event.triggerNpcID) else {
                        throw ContentValidationError(reason: "社区事件触发者不可提交该行动：\(actionID)")
                    }
                }
            }
            for prerequisiteID in event.prerequisiteIDs {
                guard ContentID.isValid(prerequisiteID) else {
                    throw ContentValidationError(reason: "社区事件前置非法：\(event.id)")
                }
            }
            // Every terminal status must stay reachable through the offered actions.
            var reachable: Set<GossipEventStatus> = [.offered, .expired]
            var changed = true
            while changed {
                changed = false
                for actionID in event.actionIDs {
                    guard let action = catalog.gossipAction(id: actionID),
                          reachable.contains(action.requiredStatus) else {
                        continue
                    }
                    if reachable.insert(action.nextStatus).inserted {
                        changed = true
                    }
                }
            }
            for status in GossipEventStatus.allCases where !reachable.contains(status) {
                throw ContentValidationError(reason: "社区事件无法到达状态 \(status.rawValue)：\(event.id)")
            }
        }
    }

    /// Mainline quests must never be standing-gated, and every gated optional
    /// node needs at least one recovery path that is itself ungated.
    private static func validateStandingGates(_ catalog: ContentCatalog) throws {
        let balance = catalog.communityBalance
        for quest in catalog.quests.values {
            guard let minStanding = quest.minStanding else {
                guard quest.recoveryPathIDs.isEmpty else {
                    throw ContentValidationError(reason: "无门槛任务不应声明恢复路径：\(quest.id)")
                }
                continue
            }
            guard !quest.isMainline else {
                throw ContentValidationError(reason: "主线禁止 min_standing：\(quest.id)")
            }
            guard (balance.minStanding...balance.maxStanding).contains(minStanding) else {
                throw ContentValidationError(reason: "min_standing 越界：\(quest.id)")
            }
            guard !quest.recoveryPathIDs.isEmpty else {
                throw ContentValidationError(reason: "受门槛可选节点缺少恢复路径：\(quest.id)")
            }
            for recoveryID in quest.recoveryPathIDs {
                if let recoveryQuest = catalog.quest(id: recoveryID) {
                    guard recoveryQuest.minStanding == nil else {
                        throw ContentValidationError(reason: "恢复路径本身有门槛：\(recoveryID)")
                    }
                    continue
                }
                if let action = catalog.gossipAction(id: recoveryID) {
                    guard action.standingDelta > 0 else {
                        throw ContentValidationError(reason: "恢复路径无法提升风评：\(recoveryID)")
                    }
                    continue
                }
                throw ContentValidationError(reason: "恢复路径引用缺失：\(recoveryID)")
            }
        }
    }

    private static func validateGuaranteedYields(_ catalog: ContentCatalog) throws {
        let guaranteedIDs = catalog.scenario.guaranteedGatherNodeIDs
        guard !guaranteedIDs.isEmpty else {
            throw ContentValidationError(reason: "场景缺少保证采集点")
        }
        var guaranteed: [String: Int] = [:]
        var farm: [String: Int] = [:]
        var market: [String: Int] = [:]
        for id in guaranteedIDs {
            guard let node = catalog.gatherNode(id: id) else {
                throw ContentValidationError(reason: "保证采集点缺失：\(id)")
            }
            guard node.requiredUnlockID == nil else {
                throw ContentValidationError(reason: "保证采集点不可上锁：\(id)")
            }
            for yield in node.yields {
                guaranteed[yield.itemID, default: 0] += yield.quantity
                if node.mapID == ContentID.farmHomestead {
                    farm[yield.itemID, default: 0] += yield.quantity
                } else if node.mapID == ContentID.creekMarket {
                    market[yield.itemID, default: 0] += yield.quantity
                }
            }
        }
        guard (guaranteed[ContentID.creekWood] ?? 0) >= 6,
              (guaranteed[ContentID.mossStone] ?? 0) >= 4 else {
            throw ContentValidationError(reason: "保证采集点不足以制作水渠接片")
        }
        guard (farm[ContentID.creekWood] ?? 0) >= 8,
              (farm[ContentID.mossStone] ?? 0) >= 4,
              (farm[ContentID.reedFiber] ?? 0) >= 6 else {
            throw ContentValidationError(reason: "农场保底采集不足")
        }
        guard (market[ContentID.creekWood] ?? 0) >= 6,
              (market[ContentID.mossStone] ?? 0) >= 8,
              (market[ContentID.reedFiber] ?? 0) >= 6 else {
            throw ContentValidationError(reason: "溪岸保底采集不足")
        }
    }

    private static func validateKeysMatchIDs(_ catalog: ContentCatalog) throws {
        for (key, map) in catalog.maps where key != map.id {
            throw ContentValidationError(reason: "地图键与 ID 不一致：\(key)")
        }
        for (key, npc) in catalog.npcs where key != npc.id {
            throw ContentValidationError(reason: "角色键与 ID 不一致：\(key)")
        }
        for (key, dialogue) in catalog.dialogues where key != dialogue.id {
            throw ContentValidationError(reason: "对白键与 ID 不一致：\(key)")
        }
        for (key, node) in catalog.gatherNodes where key != node.id {
            throw ContentValidationError(reason: "采集点键与 ID 不一致：\(key)")
        }
        for (key, quest) in catalog.quests where key != quest.id {
            throw ContentValidationError(reason: "任务键与 ID 不一致：\(key)")
        }
        for (key, contribution) in catalog.watershedContributions where key != contribution.id {
            throw ContentValidationError(reason: "贡献键与 ID 不一致：\(key)")
        }
    }

    private static func validateOccupancy(
        _ position: GridPosition,
        on map: MapDefinition,
        kind: String
    ) throws {
        guard map.contains(position) else {
            throw ContentValidationError(reason: "\(kind)越界")
        }
        guard !map.isBlocked(position) else {
            throw ContentValidationError(reason: "\(kind)落在阻挡格")
        }
    }

    private static func canReach(
        _ destination: GridPosition,
        from start: GridPosition,
        map: MapDefinition,
        blocked: Set<GridPosition>
    ) -> Bool {
        guard map.contains(start), map.contains(destination) else {
            return false
        }
        guard !blocked.contains(start), !blocked.contains(destination) else {
            return false
        }
        if start == destination {
            return true
        }
        var visited: Set<GridPosition> = [start]
        var queue: [GridPosition] = [start]
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        while let current = queue.first {
            queue.removeFirst()
            for delta in deltas {
                let next = GridPosition(x: current.x + delta.0, y: current.y + delta.1)
                guard map.contains(next), !blocked.contains(next), !visited.contains(next) else {
                    continue
                }
                if next == destination {
                    return true
                }
                visited.insert(next)
                queue.append(next)
            }
        }
        return false
    }
}
