struct ContentCatalog: Equatable, Sendable {
    var items: [String: ItemDefinition]
    var crops: [String: CropDefinition]
    var recipes: [String: RecipeDefinition]
    var placedObjects: [String: PlacedObjectDefinition]
    var scenario: NewGameScenarioDefinition
    var displayNames: [String: String]
    var tutorialSteps: [TutorialStepDefinition]
    var dialogues: [String: DialogueDefinition]
    var maps: [String: MapDefinition]
    var npcs: [String: NpcDefinition]
    var gatherNodes: [String: GatherNodeDefinition]
    var quests: [String: QuestDefinition]
    var watershedContributions: [String: WatershedContributionDefinition]
    var gossipEvents: [String: GossipEventDefinition] = [:]
    var gossipClaims: [String: GossipClaimDefinition] = [:]
    var gossipActions: [String: GossipActionDefinition] = [:]
    var gossipConditions: [String: GossipConditionDefinition] = [:]
    var conditionGroups: [String: ConditionGroupDefinition] = [:]
    var relationshipEffects: [String: RelationshipEffectDefinition] = [:]
    var communityBalance: CommunityBalanceDefinition = CommunityCatalog.balance

    static let m1Placeholder = ContentCatalog(
        items: [
            ContentID.mistRadishSeed: ItemDefinition(
                id: ContentID.mistRadishSeed,
                nameKey: "item.mist_radish_seed",
                category: "seed",
                stackLimit: 99
            ),
            ContentID.mistRadishItem: ItemDefinition(
                id: ContentID.mistRadishItem,
                nameKey: "item.mist_radish",
                category: "crop",
                stackLimit: 99,
                baseSellPrice: 58
            ),
        ],
        crops: [
            ContentID.mistRadishCrop: CropDefinition(
                id: ContentID.mistRadishCrop,
                seedItemID: ContentID.mistRadishSeed,
                harvestItemID: ContentID.mistRadishItem,
                stageDays: [1, 1, 1],
                matureStageIndex: 2,
                yield: 1
            ),
        ],
        recipes: [:],
        placedObjects: [:],
        scenario: .vs0,
        displayNames: ContentCatalog.vs0DisplayNames,
        tutorialSteps: ContentCatalog.vs0TutorialSteps,
        dialogues: ContentCatalog.vs0Dialogues,
        maps: WorldCatalog.maps,
        npcs: [:],
        gatherNodes: [:],
        quests: [:],
        watershedContributions: [:]
    )

    static let vs0 = ContentCatalog(
        items: ContentCatalog.vs0Items.merging(ContentCatalog.processingItems) { current, _ in current },
        crops: ContentCatalog.vs0Crops,
        recipes: ContentCatalog.vs0Recipes.merging(ContentCatalog.processingRecipes) { current, _ in current },
        placedObjects: ContentCatalog.vs0PlacedObjects.merging(ContentCatalog.processingPlacedObjects) { current, _ in current },
        scenario: .vs0,
        displayNames: ContentCatalog.vs0DisplayNames
            .merging(ContentCatalog.processingDisplayNames) { current, _ in current }
            .merging(WorldCatalog.displayNames) { current, _ in current }
            .merging(ProgressionCatalog.displayNames) { current, _ in current }
            .merging(CommunityCatalog.displayNames) { current, _ in current },
        tutorialSteps: ContentCatalog.vs0TutorialSteps,
        dialogues: ContentCatalog.vs0Dialogues
            .merging(WorldCatalog.dialogues) { current, _ in current }
            .merging(ProgressionCatalog.dialogues) { current, _ in current },
        maps: WorldCatalog.maps,
        npcs: WorldCatalog.npcs,
        gatherNodes: ProgressionCatalog.gatherNodes,
        quests: ProgressionCatalog.quests,
        watershedContributions: ProgressionCatalog.contributions,
        gossipEvents: CommunityCatalog.events,
        gossipClaims: CommunityCatalog.claims,
        gossipActions: CommunityCatalog.actions,
        gossipConditions: CommunityCatalog.conditions,
        conditionGroups: CommunityCatalog.conditionGroups,
        relationshipEffects: CommunityCatalog.relationshipEffects,
        communityBalance: CommunityCatalog.balance
    )

    func item(id: String) -> ItemDefinition? {
        items[id]
    }

    func crop(id: String) -> CropDefinition? {
        crops[id]
    }

    func crop(seedItemID: String) -> CropDefinition? {
        crops.values.first { $0.seedItemID == seedItemID }
    }

    func recipe(id: String) -> RecipeDefinition? {
        recipes[id]
    }

    func placedObject(id: String) -> PlacedObjectDefinition? {
        placedObjects[id]
    }

    func stackLimit(for itemID: String) -> Int {
        item(id: itemID)?.stackLimit ?? 99
    }

    func knowsItemID(_ id: String) -> Bool {
        items[id] != nil
    }

    func knowsCropID(_ id: String) -> Bool {
        crops[id] != nil
    }

    func knowsRecipeID(_ id: String) -> Bool {
        recipes[id] != nil
    }

    func knowsPlacedObjectID(_ id: String) -> Bool {
        placedObjects[id] != nil
    }

    func displayName(forItemID itemID: String) -> String {
        guard let nameKey = item(id: itemID)?.nameKey else {
            return itemID
        }
        return displayNames[nameKey] ?? nameKey
    }

    func displayName(forNameKey nameKey: String) -> String {
        displayNames[nameKey] ?? nameKey
    }

    func tutorialStep(id: String) -> TutorialStepDefinition? {
        tutorialSteps.first { $0.id == id }
    }

    func knowsTutorialStepID(_ id: String) -> Bool {
        tutorialStep(id: id) != nil
    }

    func dialogue(id: String) -> DialogueDefinition? {
        dialogues[id]
    }

    func map(id: String) -> MapDefinition? {
        maps[id]
    }

    func knowsMapID(_ id: String) -> Bool {
        maps[id] != nil
    }

    func npc(id: String) -> NpcDefinition? {
        npcs[id]
    }

    func gatherNode(id: String) -> GatherNodeDefinition? {
        gatherNodes[id]
    }

    func knowsGatherNodeID(_ id: String) -> Bool {
        gatherNodes[id] != nil
    }

    func quest(id: String) -> QuestDefinition? {
        quests[id]
    }

    func contribution(id: String) -> WatershedContributionDefinition? {
        watershedContributions[id]
    }

    func knowsContributionID(_ id: String) -> Bool {
        watershedContributions[id] != nil
    }

    func gossipEvent(id: String) -> GossipEventDefinition? {
        gossipEvents[id]
    }

    func gossipClaim(id: String) -> GossipClaimDefinition? {
        gossipClaims[id]
    }

    func gossipAction(id: String) -> GossipActionDefinition? {
        gossipActions[id]
    }

    func gossipCondition(id: String) -> GossipConditionDefinition? {
        gossipConditions[id]
    }

    func conditionGroup(id: String) -> ConditionGroupDefinition? {
        conditionGroups[id]
    }

    func relationshipEffect(id: String) -> RelationshipEffectDefinition? {
        relationshipEffects[id]
    }

    /// Effect IDs a `GossipEventState.granted_effect_ids` entry may reference.
    var knownGrantEffectIDs: Set<String> {
        var ids = Set(relationshipEffects.keys)
        ids.insert(ContentID.correctDWatershedEffect)
        return ids
    }

    func neighborIDs() -> [String] {
        npcs.values.filter { $0.role == .neighbor }.map(\.id).sorted()
    }

    func isNeighbor(_ npcID: String) -> Bool {
        npcs[npcID]?.role == .neighbor
    }

    func isQuestGiver(_ npcID: String) -> Bool {
        npcs[npcID]?.role == .questGiver
    }

    func isRecipeUnlocked(_ recipeID: String, watershed: WatershedState) -> Bool {
        guard let recipe = recipe(id: recipeID) else {
            return false
        }
        guard let required = recipe.requiredUnlockID else {
            return true
        }
        return watershed.unlockedNodes.contains(required)
    }

    func availableRecipeIDs(for state: GameState) -> [String] {
        let starting = scenario.startingRecipeIDs.filter { id in
            isRecipeUnlocked(id, watershed: state.watershed) && !(recipe(id: id)?.isProcessingRecipe ?? false)
        }
        let extra = recipes.keys
            .filter { id in
                !starting.contains(id)
                    && isRecipeUnlocked(id, watershed: state.watershed)
                    && !(recipe(id: id)?.isProcessingRecipe ?? false)
            }
            .sorted()
        return starting + extra
    }

    func availableProcessingRecipeIDs(for state: GameState) -> [String] {
        let ordered = ContentID.processingRecipeIDs.filter { isRecipeUnlocked($0, watershed: state.watershed) }
        let extra = recipes.values
            .filter { recipe in
                recipe.isProcessingRecipe
                    && !ordered.contains(recipe.id)
                    && isRecipeUnlocked(recipe.id, watershed: state.watershed)
            }
            .map(\.id)
            .sorted()
        return ordered + extra
    }

    func visibleGatherNodes(on mapID: String, state: GameState) -> [GatherNodeDefinition] {
        gatherNodes.values
            .filter { node in
                node.mapID == mapID && isGatherNodeUnlocked(node, watershed: state.watershed)
            }
            .sorted { $0.id < $1.id }
    }

    func gatherNode(at position: GridPosition, mapID: String, state: GameState) -> GatherNodeDefinition? {
        visibleGatherNodes(on: mapID, state: state).first { $0.position == position }
    }

    func isGatherNodeUnlocked(_ node: GatherNodeDefinition, watershed: WatershedState) -> Bool {
        guard let required = node.requiredUnlockID else {
            return true
        }
        return watershed.unlockedNodes.contains(required)
    }
}

extension NewGameScenarioDefinition {
    static let vs0 = NewGameScenarioDefinition(
        id: ContentID.vs0Scenario,
        startDay: 1,
        startMinute: GameClock.dayStartMinute,
        startingCurrency: 720,
        startingInventoryCapacity: 16,
        playerStart: GridPosition(x: 7, y: 6),
        playerFacing: .down,
        exitCell: GridPosition(x: 7, y: 0),
        startingItems: [
            InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 8),
            InventoryQuantity(itemID: ContentID.streamLeafSeed, quantity: 2),
            InventoryQuantity(itemID: ContentID.amberBeanSeed, quantity: 2),
            InventoryQuantity(itemID: ContentID.bellBerrySeed, quantity: 2),
            InventoryQuantity(itemID: ContentID.honeyMelonSeed, quantity: 2),
        ],
        startingFarmCells: [
            InitialFarmCell(position: GridPosition(x: 4, y: 3), cell: .matureMistRadish(plantedDay: 1)),
            InitialFarmCell(position: GridPosition(x: 5, y: 3), cell: .matureMistRadish(plantedDay: 1)),
            InitialFarmCell(position: GridPosition(x: 6, y: 3), cell: .matureMistRadish(plantedDay: 1)),
        ],
        startingRecipeIDs: [
            ContentID.woodenCrateRecipe,
            ContentID.stonePathRecipe,
            ContentID.compostRackRecipe,
            ContentID.canalSegmentRecipe,
            ContentID.woodhoneyHearthRecipe,
        ],
        startingNpcSpawns: [
            InitialNpcSpawn(
                npcID: ContentID.waterApprentice,
                displayName: "水工学徒",
                position: GridPosition(x: 8, y: 6),
                dialogueID: ContentID.waterApprenticeVs0Dialogue
            ),
        ],
        guaranteedGatherNodeIDs: ContentID.guaranteedGatherNodeIDs,
        scriptedWeatherByDay: [2: .rain]
    )
}

private extension FarmCell {
    static func matureMistRadish(plantedDay: Int) -> FarmCell {
        FarmCell(
            prepared: true,
            wateredToday: false,
            fertility: 0,
            cropID: ContentID.mistRadishCrop,
            cropStage: 2,
            stageProgressDays: 3,
            plantedDay: plantedDay,
            readyToHarvest: true
        )
    }
}

private extension ContentCatalog {
    static let vs0DisplayNames: [String: String] = [
        "item.mist_radish_seed": "雾萝卜种子",
        "item.mist_radish": "雾萝卜",
        "item.stream_leaf_seed": "溪叶菜种子",
        "item.amber_bean_seed": "琥珀豆种子",
        "item.bell_berry_seed": "铃莓种子",
        "item.honey_melon_seed": "蜜穗瓜种子",
        "item.creek_wood": "溪木",
        "item.moss_stone": "苔石",
        "item.reed_fiber": "芦纤维",
        "item.wooden_crate": "木箱",
        "item.stone_path": "小径",
        "item.compost_rack": "堆肥架",
        "item.canal_segment": "水渠接片",
        "item.rain_barrel": "雨水桶",
        "recipe.wooden_crate": "简易木箱",
        "recipe.stone_path": "碎石小径",
        "recipe.compost_rack": "堆肥架",
        "recipe.canal_segment": "水渠接片",
        "recipe.rain_barrel": "雨水桶",
        "quest.restore_old_canal": "让旧水渠再次流动",
    ]

    static let vs0TutorialSteps: [TutorialStepDefinition] = [
        TutorialStepDefinition(
            id: ContentID.tutorialHarvest,
            title: "收获 3 株成熟雾萝卜",
            hint: "[4]收获 [空格]动作",
            completionFeedback: "已收获 3 株成熟雾萝卜。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialDeposit,
            title: "按 I 把雾萝卜投入出售箱",
            hint: "[I]投入出售箱",
            completionFeedback: "已投入出售箱，待结算 3。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialTill,
            title: "用锄头（1）翻一块地",
            hint: "[1]锄头 [空格]动作",
            completionFeedback: "翻土完成，可以播种了。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialPlant,
            title: "用种子（2）播种雾萝卜",
            hint: "[2]种子 [空格]动作",
            completionFeedback: "播种完成，记得浇水。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialWater,
            title: "用水壶（3）浇水",
            hint: "[3]水壶 [空格]动作",
            completionFeedback: "浇水完成。去农场入口找水工学徒吧。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialTalk,
            title: "与农场入口的水工学徒交谈",
            hint: "[T]交谈",
            completionFeedback: "已与水工学徒交谈。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialSave,
            title: "按 K 手动保存",
            hint: "[K]保存",
            completionFeedback: "保存成功，教学进度已写入存档。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialSleep,
            title: "按 N 提前睡眠结算",
            hint: "[N]睡眠",
            completionFeedback: "日结完成：雾萝卜×3 = 174。余额 894。"
        ),
        TutorialStepDefinition(
            id: ContentID.tutorialNextDay,
            title: "明天继续照料新种下的雾萝卜",
            hint: "第 2 天会下雨自动浇水；到溪岸找涧麦婶，用 Y/B「开始核实」后再「向青砚核实」（不要按 V）",
            completionFeedback: "VS-0 教学路径已走完。"
        ),
    ]

    static let vs0Dialogues: [String: DialogueDefinition] = [
        ContentID.waterApprenticeVs0Dialogue: DialogueDefinition(
            id: ContentID.waterApprenticeVs0Dialogue,
            speakerName: "水工学徒",
            lines: [
                "我是驻在农场入口的水工学徒。先把地里这几株新芽安顿好就行。",
                "雾萝卜进了出售箱，夜里才会结成溪票。先按 K 保存，再按 N 睡觉。",
                "保存之后就算先离开，待结算也不会丢。睡一觉就能看到今天的收获。",
            ],
            completedReply: "保存、睡眠，结算就会到账。我还在入口这儿。"
        ),
    ]

    static let vs0Items: [String: ItemDefinition] = [
        ContentID.mistRadishSeed: ItemDefinition(
            id: ContentID.mistRadishSeed,
            nameKey: "item.mist_radish_seed",
            category: "seed",
            stackLimit: 99
        ),
        ContentID.mistRadishItem: ItemDefinition(
            id: ContentID.mistRadishItem,
            nameKey: "item.mist_radish",
            category: "crop",
            stackLimit: 99,
            baseSellPrice: 58
        ),
        ContentID.streamLeafSeed: ItemDefinition(
            id: ContentID.streamLeafSeed,
            nameKey: "item.stream_leaf_seed",
            category: "seed",
            stackLimit: 99
        ),
        ContentID.amberBeanSeed: ItemDefinition(
            id: ContentID.amberBeanSeed,
            nameKey: "item.amber_bean_seed",
            category: "seed",
            stackLimit: 99
        ),
        ContentID.bellBerrySeed: ItemDefinition(
            id: ContentID.bellBerrySeed,
            nameKey: "item.bell_berry_seed",
            category: "seed",
            stackLimit: 99
        ),
        ContentID.honeyMelonSeed: ItemDefinition(
            id: ContentID.honeyMelonSeed,
            nameKey: "item.honey_melon_seed",
            category: "seed",
            stackLimit: 99
        ),
        ContentID.creekWood: ItemDefinition(
            id: ContentID.creekWood,
            nameKey: "item.creek_wood",
            category: "material",
            stackLimit: 99
        ),
        ContentID.mossStone: ItemDefinition(
            id: ContentID.mossStone,
            nameKey: "item.moss_stone",
            category: "material",
            stackLimit: 99
        ),
        ContentID.reedFiber: ItemDefinition(
            id: ContentID.reedFiber,
            nameKey: "item.reed_fiber",
            category: "material",
            stackLimit: 99
        ),
        ContentID.woodenCrateItem: ItemDefinition(
            id: ContentID.woodenCrateItem,
            nameKey: "item.wooden_crate",
            category: "placeable",
            stackLimit: 99
        ),
        ContentID.stonePathItem: ItemDefinition(
            id: ContentID.stonePathItem,
            nameKey: "item.stone_path",
            category: "placeable",
            stackLimit: 99
        ),
        ContentID.compostRackItem: ItemDefinition(
            id: ContentID.compostRackItem,
            nameKey: "item.compost_rack",
            category: "placeable",
            stackLimit: 99
        ),
        ContentID.canalSegmentItem: ItemDefinition(
            id: ContentID.canalSegmentItem,
            nameKey: "item.canal_segment",
            category: "placeable",
            stackLimit: 99
        ),
        ContentID.rainBarrelItem: ItemDefinition(
            id: ContentID.rainBarrelItem,
            nameKey: "item.rain_barrel",
            category: "placeable",
            stackLimit: 99
        ),
    ]

    /// Growth totals preserve the existing PRD economy baseline:
    /// 2/4/6/7/8 watered days. Mist radish retains its frozen M1 behavior;
    /// the four DEC-033 crops use all four world-art stages (0...3).
    static let vs0Crops: [String: CropDefinition] = [
        ContentID.mistRadishCrop: CropDefinition(
            id: ContentID.mistRadishCrop,
            seedItemID: ContentID.mistRadishSeed,
            harvestItemID: ContentID.mistRadishItem,
            stageDays: [1, 1, 1],
            matureStageIndex: 2,
            yield: 1
        ),
        ContentID.streamLeafCrop: CropDefinition(
            id: ContentID.streamLeafCrop,
            seedItemID: ContentID.streamLeafSeed,
            harvestItemID: ContentID.creekGreensItem,
            stageDays: [1, 1, 2],
            matureStageIndex: 3,
            yield: 1
        ),
        ContentID.amberBeanCrop: CropDefinition(
            id: ContentID.amberBeanCrop,
            seedItemID: ContentID.amberBeanSeed,
            harvestItemID: ContentID.amberBeanItem,
            stageDays: [2, 2, 2],
            matureStageIndex: 3,
            yield: 1
        ),
        ContentID.bellBerryCrop: CropDefinition(
            id: ContentID.bellBerryCrop,
            seedItemID: ContentID.bellBerrySeed,
            harvestItemID: ContentID.bellBerryItem,
            stageDays: [2, 2, 3],
            matureStageIndex: 3,
            yield: 2
        ),
        ContentID.honeyMelonCrop: CropDefinition(
            id: ContentID.honeyMelonCrop,
            seedItemID: ContentID.honeyMelonSeed,
            harvestItemID: ContentID.honeyMelonItem,
            stageDays: [2, 3, 3],
            matureStageIndex: 3,
            yield: 1
        ),
    ]

    static let vs0Recipes: [String: RecipeDefinition] = [
        ContentID.woodenCrateRecipe: RecipeDefinition(
            id: ContentID.woodenCrateRecipe,
            nameKey: "recipe.wooden_crate",
            inputs: [RecipeStack(itemID: ContentID.creekWood, quantity: 12)],
            outputs: [RecipeStack(itemID: ContentID.woodenCrateItem, quantity: 1)],
            placedObjectID: ContentID.woodenCrateObject
        ),
        ContentID.stonePathRecipe: RecipeDefinition(
            id: ContentID.stonePathRecipe,
            nameKey: "recipe.stone_path",
            inputs: [RecipeStack(itemID: ContentID.mossStone, quantity: 4)],
            outputs: [RecipeStack(itemID: ContentID.stonePathItem, quantity: 4)],
            placedObjectID: ContentID.stonePathObject
        ),
        ContentID.compostRackRecipe: RecipeDefinition(
            id: ContentID.compostRackRecipe,
            nameKey: "recipe.compost_rack",
            inputs: [
                RecipeStack(itemID: ContentID.creekWood, quantity: 10),
                RecipeStack(itemID: ContentID.reedFiber, quantity: 6),
            ],
            outputs: [RecipeStack(itemID: ContentID.compostRackItem, quantity: 1)],
            placedObjectID: ContentID.compostRackObject
        ),
        ContentID.canalSegmentRecipe: RecipeDefinition(
            id: ContentID.canalSegmentRecipe,
            nameKey: "recipe.canal_segment",
            inputs: [
                RecipeStack(itemID: ContentID.creekWood, quantity: 6),
                RecipeStack(itemID: ContentID.mossStone, quantity: 4),
            ],
            outputs: [RecipeStack(itemID: ContentID.canalSegmentItem, quantity: 1)],
            placedObjectID: ContentID.canalSegmentObject
        ),
        ContentID.rainBarrelRecipe: RecipeDefinition(
            id: ContentID.rainBarrelRecipe,
            nameKey: "recipe.rain_barrel",
            inputs: [
                RecipeStack(itemID: ContentID.creekWood, quantity: 12),
                RecipeStack(itemID: ContentID.mossStone, quantity: 6),
            ],
            outputs: [RecipeStack(itemID: ContentID.rainBarrelItem, quantity: 1)],
            placedObjectID: ContentID.rainBarrelObject,
            requiredUnlockID: ContentID.rainBarrelUnlock
        ),
    ]

    static let vs0PlacedObjects: [String: PlacedObjectDefinition] = [
        ContentID.woodenCrateObject: PlacedObjectDefinition(
            id: ContentID.woodenCrateObject,
            nameKey: "item.wooden_crate",
            itemID: ContentID.woodenCrateItem,
            category: "storage",
            footprint: [GridPosition(x: 0, y: 0)]
        ),
        ContentID.stonePathObject: PlacedObjectDefinition(
            id: ContentID.stonePathObject,
            nameKey: "item.stone_path",
            itemID: ContentID.stonePathItem,
            category: "path",
            footprint: [GridPosition(x: 0, y: 0)]
        ),
        ContentID.compostRackObject: PlacedObjectDefinition(
            id: ContentID.compostRackObject,
            nameKey: "item.compost_rack",
            itemID: ContentID.compostRackItem,
            category: "facility",
            footprint: [GridPosition(x: 0, y: 0), GridPosition(x: 1, y: 0)]
        ),
        ContentID.canalSegmentObject: PlacedObjectDefinition(
            id: ContentID.canalSegmentObject,
            nameKey: "item.canal_segment",
            itemID: ContentID.canalSegmentItem,
            category: "canal",
            footprint: [GridPosition(x: 0, y: 0)]
        ),
        ContentID.rainBarrelObject: PlacedObjectDefinition(
            id: ContentID.rainBarrelObject,
            nameKey: "item.rain_barrel",
            itemID: ContentID.rainBarrelItem,
            category: "facility",
            footprint: [GridPosition(x: 0, y: 0)]
        ),
    ]

    /// N-004 processing crops, finished goods, station, and recipes.
    /// Crop sell prices copy PRD 6.8.3; finished goods are new +35% list prices.
    static let processingItems: [String: ItemDefinition] = [
        ContentID.creekGreensItem: ItemDefinition(
            id: ContentID.creekGreensItem,
            nameKey: "item.creek_greens",
            category: "crop",
            stackLimit: 99,
            baseSellPrice: 92
        ),
        ContentID.amberBeanItem: ItemDefinition(
            id: ContentID.amberBeanItem,
            nameKey: "item.amber_bean",
            category: "crop",
            stackLimit: 99,
            baseSellPrice: 48
        ),
        ContentID.bellBerryItem: ItemDefinition(
            id: ContentID.bellBerryItem,
            nameKey: "item.bell_berry",
            category: "crop",
            stackLimit: 99,
            baseSellPrice: 44
        ),
        ContentID.honeyMelonItem: ItemDefinition(
            id: ContentID.honeyMelonItem,
            nameKey: "item.honey_melon",
            category: "crop",
            stackLimit: 99,
            baseSellPrice: 205
        ),
        ContentID.honeySearedCreekGreensItem: ItemDefinition(
            id: ContentID.honeySearedCreekGreensItem,
            nameKey: "item.honey_seared_creek_greens",
            category: "processed",
            stackLimit: 99,
            baseSellPrice: 124
        ),
        ContentID.honeySearedAmberBeanItem: ItemDefinition(
            id: ContentID.honeySearedAmberBeanItem,
            nameKey: "item.honey_seared_amber_bean",
            category: "processed",
            stackLimit: 99,
            baseSellPrice: 65
        ),
        ContentID.honeyPreservedBellBerryItem: ItemDefinition(
            id: ContentID.honeyPreservedBellBerryItem,
            nameKey: "item.honey_preserved_bell_berry",
            category: "processed",
            stackLimit: 99,
            baseSellPrice: 59
        ),
        ContentID.honeySearedHoneyMelonItem: ItemDefinition(
            id: ContentID.honeySearedHoneyMelonItem,
            nameKey: "item.honey_seared_honey_melon",
            category: "processed",
            stackLimit: 99,
            baseSellPrice: 277
        ),
        ContentID.woodhoneyHearthItem: ItemDefinition(
            id: ContentID.woodhoneyHearthItem,
            nameKey: "item.woodhoney_hearth",
            category: "placeable",
            stackLimit: 99
        ),
    ]

    static let processingRecipes: [String: RecipeDefinition] = [
        ContentID.woodhoneyHearthRecipe: RecipeDefinition(
            id: ContentID.woodhoneyHearthRecipe,
            nameKey: "recipe.woodhoney_hearth",
            inputs: [
                RecipeStack(itemID: ContentID.creekWood, quantity: 8),
                RecipeStack(itemID: ContentID.mossStone, quantity: 4),
            ],
            outputs: [RecipeStack(itemID: ContentID.woodhoneyHearthItem, quantity: 1)],
            placedObjectID: ContentID.woodhoneyHearthObject
        ),
        ContentID.honeySearedCreekGreensRecipe: processingRecipe(
            id: ContentID.honeySearedCreekGreensRecipe,
            nameKey: "recipe.honey_seared_creek_greens",
            inputID: ContentID.creekGreensItem,
            outputID: ContentID.honeySearedCreekGreensItem
        ),
        ContentID.honeySearedAmberBeanRecipe: processingRecipe(
            id: ContentID.honeySearedAmberBeanRecipe,
            nameKey: "recipe.honey_seared_amber_bean",
            inputID: ContentID.amberBeanItem,
            outputID: ContentID.honeySearedAmberBeanItem
        ),
        ContentID.honeyPreservedBellBerryRecipe: processingRecipe(
            id: ContentID.honeyPreservedBellBerryRecipe,
            nameKey: "recipe.honey_preserved_bell_berry",
            inputID: ContentID.bellBerryItem,
            outputID: ContentID.honeyPreservedBellBerryItem
        ),
        ContentID.honeySearedHoneyMelonRecipe: processingRecipe(
            id: ContentID.honeySearedHoneyMelonRecipe,
            nameKey: "recipe.honey_seared_honey_melon",
            inputID: ContentID.honeyMelonItem,
            outputID: ContentID.honeySearedHoneyMelonItem
        ),
    ]

    static let processingPlacedObjects: [String: PlacedObjectDefinition] = [
        ContentID.woodhoneyHearthObject: PlacedObjectDefinition(
            id: ContentID.woodhoneyHearthObject,
            nameKey: "item.woodhoney_hearth",
            itemID: ContentID.woodhoneyHearthItem,
            category: "processing",
            footprint: [GridPosition(x: 0, y: 0)]
        ),
    ]

    static let processingDisplayNames: [String: String] = [
        "item.creek_greens": "溪叶菜",
        "item.amber_bean": "琥珀豆",
        "item.bell_berry": "铃花莓",
        "item.honey_melon": "蜜穗瓜",
        "item.honey_seared_creek_greens": "蜜烤溪叶菜",
        "item.honey_seared_amber_bean": "蜜烤琥珀豆",
        "item.honey_preserved_bell_berry": "蜜酿铃花莓",
        "item.honey_seared_honey_melon": "蜜炙蜜穗瓜",
        "item.woodhoney_hearth": "木蜜灶台",
        "recipe.woodhoney_hearth": "木蜜灶台",
        "recipe.honey_seared_creek_greens": "蜜烤溪叶菜",
        "recipe.honey_seared_amber_bean": "蜜烤琥珀豆",
        "recipe.honey_preserved_bell_berry": "蜜酿铃花莓",
        "recipe.honey_seared_honey_melon": "蜜炙蜜穗瓜",
    ]

    private static func processingRecipe(
        id: String,
        nameKey: String,
        inputID: String,
        outputID: String
    ) -> RecipeDefinition {
        RecipeDefinition(
            id: id,
            nameKey: nameKey,
            inputs: [RecipeStack(itemID: inputID, quantity: 1)],
            outputs: [RecipeStack(itemID: outputID, quantity: 1)],
            placedObjectID: nil,
            requiredUnlockID: nil,
            requiredPlacedObjectID: ContentID.woodhoneyHearthObject,
            staminaCost: ContentID.processingStaminaCost
        )
    }
}
