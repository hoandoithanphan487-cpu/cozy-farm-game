enum ContentID {
    static let mistRadishCrop = "brookseed.crop.mist_radish"
    static let mistRadishSeed = "brookseed.item.mist_radish_seed"
    static let mistRadishItem = "brookseed.item.mist_radish"

    static let vs0Scenario = "brookseed.scenario.vs1"

    static let creekWood = "brookseed.item.creek_wood"
    static let mossStone = "brookseed.item.moss_stone"
    static let reedFiber = "brookseed.item.reed_fiber"
    static let woodenCrateItem = "brookseed.item.wooden_crate"
    static let stonePathItem = "brookseed.item.stone_path"
    static let compostRackItem = "brookseed.item.compost_rack"
    static let canalSegmentItem = "brookseed.item.canal_segment"
    static let rainBarrelItem = "brookseed.item.rain_barrel"

    static let woodenCrateRecipe = "brookseed.recipe.wooden_crate"
    static let stonePathRecipe = "brookseed.recipe.stone_path"
    static let compostRackRecipe = "brookseed.recipe.compost_rack"
    static let canalSegmentRecipe = "brookseed.recipe.canal_segment"
    static let rainBarrelRecipe = "brookseed.recipe.rain_barrel"

    static let woodenCrateObject = "brookseed.placed.wooden_crate"
    static let stonePathObject = "brookseed.placed.stone_path"
    static let compostRackObject = "brookseed.placed.compost_rack"
    static let canalSegmentObject = "brookseed.placed.canal_segment"
    static let rainBarrelObject = "brookseed.placed.rain_barrel"

    static let restoreOldCanalQuest = "brookseed.quest.restore_old_canal"
    static let marketNoticeQuest = "brookseed.quest.market_notice_board"
    static let evidenceOneStepQuest = "brookseed.quest.evidence_one_step"

    static let placeCanalContribution = "brookseed.contribution.place_canal_segment"
    static let deliverCanalContribution = "brookseed.contribution.deliver_canal_repair"
    static let correctDBonusContribution = "brookseed.contribution.correct_d_bonus"

    static let placedCanalEvent = "brookseed.event.placed_canal_segment"
    static let deliverCanalEvent = "brookseed.event.deliver_canal_repair"
    static let correctDBonusEvent = "brookseed.event.correct_d_bonus"

    static let canalSegmentProject = "brookseed.watershed.canal_segment_01"
    static let restoredChannelUnlock = "brookseed.world.restored_channel"
    static let flowingWaterAmbience = "brookseed.audio.flowing_water"
    static let dryChannelAmbience = "brookseed.audio.dry_channel"
    static let rainBarrelUnlock = "brookseed.recipe.rain_barrel"

    static let farmWoodGather = "brookseed.gather.farm_wood_cache"
    static let farmMossGather = "brookseed.gather.farm_moss_cache"
    static let farmReedGather = "brookseed.gather.farm_reed_cache"
    static let marketWoodGather = "brookseed.gather.market_wood_cache"
    static let marketMossGather = "brookseed.gather.market_moss_cache"
    static let marketReedGather = "brookseed.gather.market_reed_cache"
    static let restoredBrookGather = "brookseed.gather.restored_brook_cache"

    static let waterApprenticeQuestOffer = "brookseed.dialogue.water_apprentice.quest_offer"
    static let waterApprenticeQuestProgress = "brookseed.dialogue.water_apprentice.quest_progress"
    static let waterApprenticeQuestTurnIn = "brookseed.dialogue.water_apprentice.quest_turn_in"
    static let waterApprenticeQuestDone = "brookseed.dialogue.water_apprentice.quest_done"

    static let watershedThreshold = 20

    static let watershedThresholdUnlockIDs: [String] = [
        canalSegmentProject,
        restoredChannelUnlock,
        flowingWaterAmbience,
        rainBarrelUnlock,
        restoredBrookGather,
    ]

    static let guaranteedGatherNodeIDs: [String] = [
        farmWoodGather,
        farmMossGather,
        farmReedGather,
        marketWoodGather,
        marketMossGather,
        marketReedGather,
    ]

    static let migrationGrantReason = "migration.grant"
    static let shippingSettleReason = "shipping.settle"
    static let debugGrantReason = "debug.grant"

    static let farmHomestead = "brookseed.map.farm_homestead"
    static let creekMarket = "brookseed.map.creek_market"
    static let farmToMarketExit = "brookseed.exit.farm_to_market"
    static let marketToFarmExit = "brookseed.exit.market_to_farm"
    static let farmWakeSpawn = "brookseed.spawn.farm_wake"
    static let farmFromMarketSpawn = "brookseed.spawn.farm_from_market"
    static let marketFromFarmSpawn = "brookseed.spawn.market_from_farm"

    static let waterApprentice = "brookseed.npc.water_apprentice"
    static let seedSteward = "brookseed.npc.seed_steward"
    static let creekWarden = "brookseed.npc.creek_warden"
    static let neighborHearsay = "brookseed.npc.neighbor_hearsay"
    static let neighborStoryteller = "brookseed.npc.neighbor_storyteller"
    static let neighborEvidence = "brookseed.npc.neighbor_evidence"
    static let neighborConsensus = "brookseed.npc.neighbor_consensus"

    static let waterApprenticeVs0Dialogue = "brookseed.dialogue.water_apprentice.vs0_01"
    static let waterApprenticeMarketDialogue = "brookseed.dialogue.water_apprentice.market_01"
    static let seedStewardDialogue = "brookseed.dialogue.seed_steward.intro_01"
    static let creekWardenDialogue = "brookseed.dialogue.creek_warden.intro_01"
    static let neighborHearsayDialogue = "brookseed.dialogue.neighbor_hearsay.intro_01"
    static let neighborStorytellerDialogue = "brookseed.dialogue.neighbor_storyteller.intro_01"
    static let neighborEvidenceDialogue = "brookseed.dialogue.neighbor_evidence.intro_01"
    static let neighborConsensusDialogue = "brookseed.dialogue.neighbor_consensus.intro_01"

    // MARK: - M3-003 community message event

    static let sluicePlankEvent = "brookseed.gossip.event.sluice_plank"
    static let sluicePlankClaim = "brookseed.gossip.claim.sluice_plank"

    static let relayUnverifiedAction = "brookseed.gossip.action.relay_unverified"
    static let deferJudgmentAction = "brookseed.gossip.action.defer_judgment"
    static let startVerificationAction = "brookseed.gossip.action.start_verification"
    static let verifyWithCAction = "brookseed.gossip.action.verify_with_c"
    static let correctDAction = "brookseed.gossip.action.correct_d"

    /// Stable submission order used by content validation and the HUD.
    static let gossipActionIDs: [String] = [
        relayUnverifiedAction,
        deferJudgmentAction,
        startVerificationAction,
        verifyWithCAction,
        correctDAction,
    ]

    /// Design-mandated action names; the last dot segment of each action ID.
    static let requiredGossipActionNames: [String] = [
        "relay_unverified",
        "defer_judgment",
        "start_verification",
        "verify_with_c",
        "correct_d",
    ]

    static let observedEvidenceCondition = "brookseed.condition.sluice_plank_evidence"
    static let endorsementCondition = "brookseed.condition.evidence_endorsement"
    static let verifyEvidenceConditionGroup = "brookseed.condition_group.verify_evidence"

    static let relayMisunderstandingEffect = "brookseed.effect.relay_misunderstanding"
    static let correctDTrustEffect = "brookseed.effect.correct_d_trust"
    static let correctDWatershedEffect = "brookseed.effect.correct_d_watershed"

    /// Display names the community cast must use. NPC IDs stay stable.
    static let requiredNeighborDisplayNames: [String: String] = [
        neighborEvidence: "青砚",
        neighborConsensus: "絮宁",
    ]

    /// Earlier drafts used these names; content validation rejects them.
    static let retiredNeighborDisplayNames: [String] = ["老耿", "阿棉"]

    static let standingBandLow = "brookseed.standing_band.low"
    static let standingBandNeutral = "brookseed.standing_band.neutral"
    static let standingBandHigh = "brookseed.standing_band.high"

    static func gossipInstanceID(definitionID: String, offeredDay: Int) -> String {
        "\(definitionID).instance.day\(offeredDay)"
    }

    static let tutorialHarvest = "brookseed.tutorial.harvest"
    static let tutorialDeposit = "brookseed.tutorial.deposit"
    static let tutorialTill = "brookseed.tutorial.till"
    static let tutorialPlant = "brookseed.tutorial.plant"
    static let tutorialWater = "brookseed.tutorial.water"
    static let tutorialTalk = "brookseed.tutorial.talk"
    static let tutorialSave = "brookseed.tutorial.save"
    static let tutorialSleep = "brookseed.tutorial.sleep"
    static let tutorialNextDay = "brookseed.tutorial.next_day"

    static let tutorialStepIDs: [String] = [
        tutorialHarvest,
        tutorialDeposit,
        tutorialTill,
        tutorialPlant,
        tutorialWater,
        tutorialTalk,
        tutorialSave,
        tutorialSleep,
        tutorialNextDay,
    ]

    static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 120 else {
            return false
        }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else {
            return false
        }
        return segments.allSatisfy { segment in
            isIdentifier(segment)
        }
    }

    private static func isIdentifier(_ segment: Substring) -> Bool {
        guard let first = segment.first, first.isLetter || first == "_" else {
            return false
        }
        return segment.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_"
        }
    }
}
