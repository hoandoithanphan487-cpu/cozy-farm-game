enum StorySceneID {
    static let oldWaterway = "brookseed.story.journey.old_waterway"
    static let mistRidgeFork = "brookseed.story.journey.mist_ridge_fork"
    static let greygateFarm = "brookseed.story.journey.greygate_farm"
    static let endingDeparture = "brookseed.story.scene.ending_departure"
}

enum StoryAnchorCatalog {
    static let endingDepartureAnchorID = "brookseed.story.anchor.ending_departure"

    static let worldGridAnchors: [WorldGridStoryAnchor] = [
        world("farm.entry", ContentID.farmHomestead, 7, 1, .entry),
        world("farm.main_south", ContentID.farmHomestead, 7, 2, .playerWaypoint),
        world("farm.field_west", ContentID.farmHomestead, 5, 6, .interaction),
        world("farm.field_east", ContentID.farmHomestead, 9, 6, .interaction),
        world("farm.field_edge", ContentID.farmHomestead, 6, 5, .playerWaypoint),
        world("farm.main_center", ContentID.farmHomestead, 7, 7, .playerWaypoint),
        world("farm.workyard", ContentID.farmHomestead, 8, 7, .playerWaypoint),
        world("farm.house_interaction", ContentID.farmHomestead, 3, 7, .interaction, landmarkID: "brookseed.landmark.farm_house", requiresInteraction: true),
        world("farm.sluice_interaction", ContentID.farmHomestead, 12, 7, .interaction, landmarkID: "brookseed.landmark.farm_sluice", requiresInteraction: true),
        world("farm.canal_bank_north", ContentID.farmHomestead, 12, 6, .interaction),
        world("farm.canal_bank_mid", ContentID.farmHomestead, 12, 4, .interaction),
        world("farm.canal_tail", ContentID.farmHomestead, 12, 2, .interaction),
        world("farm.stone_steps", ContentID.farmHomestead, 7, 1, .exit),
        world("farm.camera", ContentID.farmHomestead, 8, 7, .camera, requiresWalkable: false),

        world("market.entry", ContentID.creekMarket, 9, 11, .entry),
        world("market.steps", ContentID.creekMarket, 9, 11, .exit),
        world("market.axis_north", ContentID.creekMarket, 9, 9, .playerWaypoint),
        world("market.axis_center", ContentID.creekMarket, 9, 8, .playerWaypoint),
        world("market.axis_south", ContentID.creekMarket, 9, 5, .playerWaypoint),
        world("market.table_west", ContentID.creekMarket, 5, 7, .interaction),
        world("market.table_south", ContentID.creekMarket, 6, 6, .interaction),
        world("market.record_table", ContentID.creekMarket, 11, 6, .interaction),
        world("market.waterside_walk", ContentID.creekMarket, 8, 5, .playerWaypoint),
        world("market.cat_shop_front", ContentID.creekMarket, 14, 5, .interaction),
        world("market.cat_shop_side", ContentID.creekMarket, 13, 5, .interaction),
        world("market.cat_shop_curtain", ContentID.creekMarket, 15, 5, .interaction),
        world("market.seed_shed", ContentID.creekMarket, 1, 8, .interaction, landmarkID: "brookseed.landmark.market_seed_shed", requiresInteraction: true),
        world("market.warden_post", ContentID.creekMarket, 16, 8, .interaction, landmarkID: "brookseed.landmark.market_warden_post", requiresInteraction: true),
        WorldGridStoryAnchor(
            id: endingDepartureAnchorID,
            mapID: ContentID.creekMarket,
            cell: GridPosition(x: 3, y: 5),
            landmarkID: "brookseed.landmark.market_wharf",
            purpose: .interaction,
            requiresWalkableCell: true,
            requiresInteractionCell: true
        ),
        world("market.camera", ContentID.creekMarket, 9, 8, .camera, requiresWalkable: false),
    ]

    static let journeyLocalAnchors: [JourneyLocalStoryAnchor] = [
        journey("old_waterway.entry", StorySceneID.oldWaterway, 0.08, 0.50, .entry, paired: "brookseed.story.anchor.journey.old_waterway.exit"),
        journey("old_waterway.exit", StorySceneID.oldWaterway, 0.92, 0.50, .exit, paired: "brookseed.story.anchor.journey.old_waterway.entry"),
        journey("old_waterway.sluice", StorySceneID.oldWaterway, 0.32, 0.34, .interaction),
        journey("old_waterway.drain", StorySceneID.oldWaterway, 0.70, 0.66, .interaction),
        journey("old_waterway.camera", StorySceneID.oldWaterway, 0.50, 0.12, .camera),

        journey("mist_ridge.entry", StorySceneID.mistRidgeFork, 0.08, 0.78, .entry, paired: "brookseed.story.anchor.journey.mist_ridge.exit"),
        journey("mist_ridge.exit", StorySceneID.mistRidgeFork, 0.92, 0.18, .exit, paired: "brookseed.story.anchor.journey.mist_ridge.entry"),
        journey("mist_ridge.white_stone", StorySceneID.mistRidgeFork, 0.30, 0.62, .playerWaypoint),
        journey("mist_ridge.track", StorySceneID.mistRidgeFork, 0.44, 0.40, .interaction),
        journey("mist_ridge.burnt_paper", StorySceneID.mistRidgeFork, 0.58, 0.62, .interaction),
        journey("mist_ridge.broken_bell", StorySceneID.mistRidgeFork, 0.73, 0.37, .interaction),
        journey("mist_ridge.evidence_route", StorySceneID.mistRidgeFork, 0.80, 0.24, .playerWaypoint),
        journey("mist_ridge.trade_route", StorySceneID.mistRidgeFork, 0.77, 0.48, .playerWaypoint),
        journey("mist_ridge.waterway_route", StorySceneID.mistRidgeFork, 0.67, 0.78, .playerWaypoint),
        journey("mist_ridge.camera", StorySceneID.mistRidgeFork, 0.50, 0.10, .camera),

        journey("greygate.entry", StorySceneID.greygateFarm, 0.08, 0.50, .entry, paired: "brookseed.story.anchor.journey.greygate.exit"),
        journey("greygate.exit", StorySceneID.greygateFarm, 0.92, 0.50, .exit, paired: "brookseed.story.anchor.journey.greygate.entry"),
        journey("greygate.evidence_table", StorySceneID.greygateFarm, 0.34, 0.28, .interaction),
        journey("greygate.trade_yard", StorySceneID.greygateFarm, 0.48, 0.72, .interaction),
        journey("greygate.waterway_outlet", StorySceneID.greygateFarm, 0.66, 0.70, .interaction),
        journey("greygate.bell_princess", StorySceneID.greygateFarm, 0.74, 0.34, .interaction),
        journey("greygate.camera", StorySceneID.greygateFarm, 0.54, 0.10, .camera),
    ]

    static let journeyScenes: [StoryJourneySceneDefinition] = [
        StoryJourneySceneDefinition(
            id: StorySceneID.oldWaterway,
            displayName: "旧水路",
            entryAnchorID: "brookseed.story.anchor.journey.old_waterway.entry",
            exitAnchorID: "brookseed.story.anchor.journey.old_waterway.exit",
            localCollision: [
                StoryCollisionRect(minX: 0.43, minY: 0.43, maxX: 0.56, maxY: 0.57),
            ]
        ),
        StoryJourneySceneDefinition(
            id: StorySceneID.mistRidgeFork,
            displayName: "雾岭岔路",
            entryAnchorID: "brookseed.story.anchor.journey.mist_ridge.entry",
            exitAnchorID: "brookseed.story.anchor.journey.mist_ridge.exit",
            localCollision: [
                StoryCollisionRect(minX: 0.47, minY: 0.47, maxX: 0.54, maxY: 0.55),
            ]
        ),
        StoryJourneySceneDefinition(
            id: StorySceneID.greygateFarm,
            displayName: "灰栅农场",
            entryAnchorID: "brookseed.story.anchor.journey.greygate.entry",
            exitAnchorID: "brookseed.story.anchor.journey.greygate.exit",
            localCollision: [
                StoryCollisionRect(minX: 0.52, minY: 0.42, maxX: 0.61, maxY: 0.59),
            ]
        ),
    ]

    static let all: [StoryAnchorDefinition] =
        worldGridAnchors.map(StoryAnchorDefinition.worldGrid)
        + journeyLocalAnchors.map(StoryAnchorDefinition.journeyLocal)

    static let byID: [String: StoryAnchorDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func anchor(id: String) -> StoryAnchorDefinition? { byID[id] }

    private static func world(
        _ suffix: String,
        _ mapID: String,
        _ x: Int,
        _ y: Int,
        _ purpose: StoryAnchorPurpose,
        landmarkID: String? = nil,
        requiresWalkable: Bool = true,
        requiresInteraction: Bool = false
    ) -> WorldGridStoryAnchor {
        WorldGridStoryAnchor(
            id: "brookseed.story.anchor.\(suffix)",
            mapID: mapID,
            cell: GridPosition(x: x, y: y),
            landmarkID: landmarkID,
            purpose: purpose,
            requiresWalkableCell: requiresWalkable,
            requiresInteractionCell: requiresInteraction
        )
    }

    private static func journey(
        _ suffix: String,
        _ sceneID: String,
        _ x: Double,
        _ y: Double,
        _ purpose: StoryAnchorPurpose,
        paired: String? = nil
    ) -> JourneyLocalStoryAnchor {
        JourneyLocalStoryAnchor(
            id: "brookseed.story.anchor.journey.\(suffix)",
            sceneID: sceneID,
            point: StoryNormalizedPoint(x: x, y: y),
            purpose: purpose,
            pairedAnchorID: paired
        )
    }
}

