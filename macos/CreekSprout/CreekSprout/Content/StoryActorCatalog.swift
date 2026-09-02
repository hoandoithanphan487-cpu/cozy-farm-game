enum StoryActorID {
    static let waterApprentice = "brookseed.npc.water_apprentice"
    static let seedSteward = "brookseed.npc.seed_steward"
    static let creekWarden = "brookseed.npc.creek_warden"
    static let neighborHearsay = "brookseed.npc.neighbor_hearsay"
    static let neighborStoryteller = "brookseed.npc.neighbor_storyteller"
    static let neighborEvidence = "brookseed.npc.neighbor_evidence"
    static let neighborConsensus = "brookseed.npc.neighbor_consensus"

    static let catShopBlack = "brookseed.npc.cat_shop_black"
    static let catShopCalico = "brookseed.npc.cat_shop_calico"
    static let catShopRagdoll = "brookseed.npc.cat_shop_ragdoll"

    static let bellPrincess = "brookseed.npc.bell_princess"
    static let greygateRepresentative = "brookseed.npc.greygate_representative"
    static let greygateFarmer = "brookseed.npc.greygate_farmer"

    static let system = "brookseed.story.speaker.system"
    static let ledger = "brookseed.story.speaker.ledger"
}

enum StoryActorCatalog {
    static let all: [StoryActorDefinition] = [
        npc(StoryActorID.waterApprentice, "水工学徒"),
        npc(StoryActorID.seedSteward, "种源管理员"),
        npc(StoryActorID.creekWarden, "溪岸巡护员"),
        npc(StoryActorID.neighborHearsay, "涧麦婶"),
        npc(StoryActorID.neighborStoryteller, "石灯"),
        npc(StoryActorID.neighborEvidence, "青砚"),
        npc(StoryActorID.neighborConsensus, "絮宁"),
        npc(StoryActorID.catShopBlack, "黑猫店员"),
        npc(StoryActorID.catShopCalico, "三花店员"),
        npc(StoryActorID.catShopRagdoll, "布偶猫店员"),
        npc(StoryActorID.bellPrincess, "绒铃"),
        npc(StoryActorID.greygateRepresentative, "灰栅代表"),
        npc(StoryActorID.greygateFarmer, "灰栅农场主"),
        StoryActorDefinition(
            id: StoryActorID.system,
            displayName: "系统",
            portraitID: nil,
            kind: .system,
            isConspirator: false
        ),
        StoryActorDefinition(
            id: StoryActorID.ledger,
            displayName: "账簿",
            portraitID: nil,
            kind: .ledger,
            isConspirator: false
        ),
    ]

    static let byID: [String: StoryActorDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    /// Every named main-story participant other than the player is knowingly
    /// involved. System copy and the ledger are presentation voices, not cast.
    static let conspiratorRoster: [String] = [
        StoryActorID.waterApprentice,
        StoryActorID.seedSteward,
        StoryActorID.creekWarden,
        StoryActorID.neighborHearsay,
        StoryActorID.neighborStoryteller,
        StoryActorID.neighborEvidence,
        StoryActorID.neighborConsensus,
        StoryActorID.catShopBlack,
        StoryActorID.catShopCalico,
        StoryActorID.catShopRagdoll,
        StoryActorID.bellPrincess,
        StoryActorID.greygateRepresentative,
        StoryActorID.greygateFarmer,
    ]

    private static func npc(_ id: String, _ displayName: String) -> StoryActorDefinition {
        StoryActorDefinition(
            id: id,
            displayName: displayName,
            portraitID: id,
            kind: .npc,
            isConspirator: true
        )
    }
}

