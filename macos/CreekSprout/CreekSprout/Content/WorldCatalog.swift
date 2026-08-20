enum WorldCatalog {
    static let maps: [String: MapDefinition] = Dictionary(
        uniqueKeysWithValues: mapList.map { ($0.id, $0) }
    )

    static let npcs: [String: NpcDefinition] = Dictionary(
        uniqueKeysWithValues: npcList.map { ($0.id, $0) }
    )

    static let dialogues: [String: DialogueDefinition] = Dictionary(
        uniqueKeysWithValues: dialogueList.map { ($0.id, $0) }
    )

    static let displayNames: [String: String] = [
        "map.farm_homestead": "农场与农舍",
        "map.creek_market": "溪岸集市",
        "npc.water_apprentice": "水工学徒",
        "npc.seed_steward": "种源管理员",
        "npc.creek_warden": "溪岸巡护员",
        "npc.neighbor_hearsay": "涧麦婶",
        "npc.neighbor_storyteller": "石灯",
        "npc.neighbor_evidence": "青砚",
        "npc.neighbor_consensus": "絮宁",
    ]

    static let mapList: [MapDefinition] = [farmHomestead, creekMarket]
    static let npcList: [NpcDefinition] = [
        waterApprentice,
        seedSteward,
        creekWarden,
        neighborHearsay,
        neighborStoryteller,
        neighborEvidence,
        neighborConsensus,
    ]
    static let dialogueList: [DialogueDefinition] = [
        waterApprenticeMarket,
        seedStewardDialogue,
        creekWardenDialogue,
        neighborHearsayDialogue,
        neighborStorytellerDialogue,
        neighborEvidenceDialogue,
        neighborConsensusDialogue,
    ]

    static let farmHomestead = MapDefinition(
        id: ContentID.farmHomestead,
        nameKey: "map.farm_homestead",
        displayName: "农场与农舍",
        columns: GridPosition.columnCount,
        rows: GridPosition.rowCount,
        blockedCells: [
            GridPosition(x: 0, y: 4),
            GridPosition(x: 1, y: 4),
            GridPosition(x: 0, y: 5),
            GridPosition(x: 1, y: 5),
            GridPosition(x: 8, y: 5),
            GridPosition(x: 9, y: 5),
        ],
        landmarks: [
            MapLandmarkDefinition(id: "brookseed.landmark.farm_house", label: "木构农舍", position: GridPosition(x: 0, y: 5)),
            MapLandmarkDefinition(id: "brookseed.landmark.farm_beds", label: "湿土苗床", position: GridPosition(x: 5, y: 1)),
            MapLandmarkDefinition(id: "brookseed.landmark.farm_sluice", label: "铜闸工位", position: GridPosition(x: 9, y: 5)),
            MapLandmarkDefinition(id: "brookseed.landmark.farm_steps", label: "石阶溪口", position: GridPosition(x: 5, y: 0)),
        ],
        spawns: [
            MapSpawnDefinition(id: ContentID.farmWakeSpawn, position: GridPosition(x: 5, y: 4)),
            MapSpawnDefinition(id: ContentID.farmFromMarketSpawn, position: GridPosition(x: 5, y: 2)),
        ],
        exits: [
            MapExitDefinition(
                id: ContentID.farmToMarketExit,
                cell: GridPosition(x: 5, y: 0),
                destinationMapID: ContentID.creekMarket,
                destinationSpawnID: ContentID.marketFromFarmSpawn
            ),
        ]
    )

    static let creekMarket = MapDefinition(
        id: ContentID.creekMarket,
        nameKey: "map.creek_market",
        displayName: "溪岸集市",
        columns: 10,
        rows: 8,
        blockedCells: [
            GridPosition(x: 0, y: 0),
            GridPosition(x: 1, y: 0),
            GridPosition(x: 8, y: 0),
            GridPosition(x: 9, y: 0),
            GridPosition(x: 0, y: 6),
            GridPosition(x: 0, y: 7),
            GridPosition(x: 1, y: 7),
            GridPosition(x: 8, y: 7),
            GridPosition(x: 9, y: 6),
            GridPosition(x: 9, y: 7),
        ],
        landmarks: [
            MapLandmarkDefinition(id: "brookseed.landmark.market_wharf", label: "苔石埠头", position: GridPosition(x: 0, y: 0)),
            MapLandmarkDefinition(id: "brookseed.landmark.market_seed_shed", label: "种源棚", position: GridPosition(x: 0, y: 7)),
            MapLandmarkDefinition(id: "brookseed.landmark.market_warden_post", label: "巡护亭", position: GridPosition(x: 9, y: 7)),
            MapLandmarkDefinition(id: "brookseed.landmark.market_table", label: "邻里石桌", position: GridPosition(x: 5, y: 4)),
            MapLandmarkDefinition(id: "brookseed.landmark.market_blocked_mouth", label: "阻塞水口", position: GridPosition(x: 9, y: 0)),
            MapLandmarkDefinition(id: "brookseed.landmark.market_steps", label: "回农场石阶", position: GridPosition(x: 5, y: 0)),
        ],
        spawns: [
            MapSpawnDefinition(id: ContentID.marketFromFarmSpawn, position: GridPosition(x: 5, y: 1)),
        ],
        exits: [
            MapExitDefinition(
                id: ContentID.marketToFarmExit,
                cell: GridPosition(x: 5, y: 0),
                destinationMapID: ContentID.farmHomestead,
                destinationSpawnID: ContentID.farmFromMarketSpawn
            ),
        ]
    )

    static let waterApprentice = NpcDefinition(
        id: ContentID.waterApprentice,
        nameKey: "npc.water_apprentice",
        displayName: "水工学徒",
        role: .questGiver,
        personalityArchetype: nil,
        dialoguePoolID: ContentID.waterApprenticeMarketDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 1, y: 3)
    )

    static let seedSteward = NpcDefinition(
        id: ContentID.seedSteward,
        nameKey: "npc.seed_steward",
        displayName: "种源管理员",
        role: .questGiver,
        personalityArchetype: nil,
        dialoguePoolID: ContentID.seedStewardDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 8, y: 3)
    )

    static let creekWarden = NpcDefinition(
        id: ContentID.creekWarden,
        nameKey: "npc.creek_warden",
        displayName: "溪岸巡护员",
        role: .questGiver,
        personalityArchetype: nil,
        dialoguePoolID: ContentID.creekWardenDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 7, y: 6)
    )

    static let neighborHearsay = NpcDefinition(
        id: ContentID.neighborHearsay,
        nameKey: "npc.neighbor_hearsay",
        displayName: "涧麦婶",
        role: .neighbor,
        personalityArchetype: .helpfulHearsay,
        dialoguePoolID: ContentID.neighborHearsayDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 2, y: 6)
    )

    static let neighborStoryteller = NpcDefinition(
        id: ContentID.neighborStoryteller,
        nameKey: "npc.neighbor_storyteller",
        displayName: "石灯",
        role: .neighbor,
        personalityArchetype: .dramaticStoryteller,
        dialoguePoolID: ContentID.neighborStorytellerDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 3, y: 4)
    )

    static let neighborEvidence = NpcDefinition(
        id: ContentID.neighborEvidence,
        nameKey: "npc.neighbor_evidence",
        displayName: "青砚",
        role: .neighbor,
        personalityArchetype: .evidenceMinded,
        dialoguePoolID: ContentID.neighborEvidenceDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 6, y: 4)
    )

    static let neighborConsensus = NpcDefinition(
        id: ContentID.neighborConsensus,
        nameKey: "npc.neighbor_consensus",
        displayName: "絮宁",
        role: .neighbor,
        personalityArchetype: .consensusFollower,
        dialoguePoolID: ContentID.neighborConsensusDialogue,
        mapID: ContentID.creekMarket,
        position: GridPosition(x: 2, y: 2)
    )

    static let waterApprenticeMarket = DialogueDefinition(
        id: ContentID.waterApprenticeMarketDialogue,
        speakerName: "水工学徒",
        lines: [
            "我是驻溪岸的水工学徒，看管旧铜闸和农舍那边的渠口。",
            "集市这条石阶连着农场。水还没通，先别下到阻塞的水口去。",
            "种源棚和巡护亭的人更熟这里的路，有疑问可以问他们。",
            "等渠口重新淌水，雾气会先从农舍后头那排湿土散开。",
        ],
        completedReply: "渠口还没通。有空再来石阶这边坐坐。"
    )

    static let seedStewardDialogue = DialogueDefinition(
        id: ContentID.seedStewardDialogue,
        speakerName: "种源管理员",
        lines: [
            "我是种源管理员，棚里记着溪谷能活过春潮的种子名录。",
            "雾萝卜耐湿，溪叶菜要浅水，琥珀豆得等土温稳住才播。",
            "今天只开放询问，不摆摊、不接订单。",
            "你若从农场来，先把自家苗床的湿度摸熟，再来对名录。",
        ],
        completedReply: "名录还在。先把农场的土摸熟再来。"
    )

    static let creekWardenDialogue = DialogueDefinition(
        id: ContentID.creekWardenDialogue,
        speakerName: "溪岸巡护员",
        lines: [
            "我是溪岸巡护员，沿着埠头和芦丛看水位、看有没有塌石。",
            "阻塞水口那边先别采，石缝还不稳。",
            "集市的路标都写了字，不靠颜色分辨方向。",
            "看到异常痕迹就来巡护亭说一声，我会记在水纹册上。",
        ],
        completedReply: "水口仍旧堵住。有痕迹再来巡护亭。"
    )

    static let neighborHearsayDialogue = DialogueDefinition(
        id: ContentID.neighborHearsayDialogue,
        speakerName: "涧麦婶",
        lines: [
            "叫我涧麦婶就行。谁家渠口响一声，我这边茶还没凉就听说了。",
            "今早有人讲埠头漂来一截旧闸板，是邻桌转给我的，我没亲眼看见。",
            "你要是想听新鲜事，我可以原样学一遍；真假得你自己再问，也可以先立成核对再去找青砚对痕迹。",
            "被追问的时候我会说：这还只是听来的，得找着实的痕迹才算数。",
            "石阶那头要是有新动静，我多半又会先知道一耳朵。",
        ],
        completedReply: "还是那些听来的话。真假你自己再问。"
    )

    static let neighborStorytellerDialogue = DialogueDefinition(
        id: ContentID.neighborStorytellerDialogue,
        speakerName: "石灯",
        lines: [
            "我是石灯。故事在我这儿会发光，有时也容易把影子拉得太长。",
            "我记得去年春水把整座巡护亭抬起来转了半圈——也许只是台阶湿了。",
            "记忆和推测在我嘴里常常坐同一张石凳，你听着乐就行，别当册子抄。",
            "跟我聊天不会挨罚，你要是存疑，去问爱看痕迹的人。",
            "等会儿我可能把闸板说成铜龙，你记得敲一敲我的话。",
        ],
        completedReply: "故事还是那些。别把影子当成闸板。"
    )

    static let neighborEvidenceDialogue = DialogueDefinition(
        id: ContentID.neighborEvidenceDialogue,
        speakerName: "青砚",
        lines: [
            "我叫青砚。空口结论我收下当风，看见的痕迹才入册。",
            "你要说埠头有闸板，得指出它靠着哪块苔石、湿痕朝哪边。",
            "没有可观察的一步，我不会帮你把听说写成事实。",
            "对得上痕迹，我会给一句明白判断，不含糊。",
            "先把这桩听说立成正在核对的事，再来我这儿对痕迹入册。",
        ],
        completedReply: "还是那句话：先有痕迹，再下判断。"
    )

    static let neighborConsensusDialogue = DialogueDefinition(
        id: ContentID.neighborConsensusDialogue,
        speakerName: "絮宁",
        lines: [
            "我是絮宁。大家觉得靠谱的说法，我会先放在心上。",
            "刚才听涧麦婶讲闸板，我还没改口；要是有人拿出更稳的证据，我会跟着改。",
            "更新之后，我也会把新说法带给邻桌，免得各说各的。",
            "我不是要你跟谁站队，只是想让集市里的话能对上同一条溪。",
            "你要是带来更清楚的观察，我明天就会换一套说法去转述。",
        ],
        completedReply: "我还是听大家眼下最靠谱的那一版。"
    )
}
