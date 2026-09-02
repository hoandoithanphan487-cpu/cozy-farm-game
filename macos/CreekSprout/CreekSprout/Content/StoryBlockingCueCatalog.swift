enum StoryBlockingCueCatalog {
    static let all: [StoryBlockingCueDefinition] = StoryArcID.allCases.flatMap { arcID in
        (1...5).map { cue(arcID, $0) }
    }

    static let byID: [String: StoryBlockingCueDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    private struct CuePlan {
        var sceneID: String
        var entry: String
        var starts: [String: String]
        var waypoints: [String]
        var interaction: String
        var crossing: StoryCrossingOrInterruptDefinition
        var branches: [String: [String]]
        var exits: [String: String]
        var reveal: StoryRevealCameraOrPropDefinition
    }

    private static func cue(_ arcID: StoryArcID, _ index: Int) -> StoryBlockingCueDefinition {
        let plan = plan(for: arcID, index: index)
        let number = twoDigits(index)
        return StoryBlockingCueDefinition(
            id: "\(arcID.rawValue).cue.blk_\(number)",
            arcID: arcID,
            sceneID: plan.sceneID,
            sourceBlockingID: "Q\(twoDigits(arcID.sequence))_BLK_\(number)",
            entryAnchor: plan.entry,
            npcStartAnchors: plan.starts,
            playerWaypoints: plan.waypoints,
            interactionAnchor: plan.interaction,
            crossingOrInterrupt: plan.crossing,
            branchMovement: plan.branches,
            npcExitAnchors: plan.exits,
            temporarilyBlockedCells: [],
            revealCameraOrProp: plan.reveal
        )
    }

    private static func plan(for arcID: StoryArcID, index: Int) -> CuePlan {
        switch arcID {
        case .q01: q01(index)
        case .q02: q02(index)
        case .q03: q03(index)
        case .q04: q04(index)
        case .q05: q05(index)
        case .q06: q06(index)
        case .q07: q07(index)
        case .q08: q08(index)
        case .q09: q09(index)
        case .q10: q10(index)
        }
    }

    private static func q01(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.waterApprentice, StoryActorID.creekWarden, StoryActorID.neighborEvidence]
        switch index {
        case 1:
            return worldPlan(ContentID.farmHomestead, "farm.entry", actors, ["farm.main_south", "farm.field_west"], "farm.field_west")
        case 2:
            return worldPlan(ContentID.farmHomestead, "farm.main_center", actors, ["farm.field_west", "farm.canal_bank_north", "farm.sluice_interaction", "farm.canal_tail"], "farm.sluice_interaction", crossingActor: StoryActorID.neighborStoryteller)
        case 3:
            return worldPlan(
                ContentID.farmHomestead,
                "farm.main_center",
                actors,
                ["farm.field_west", "farm.sluice_interaction", "farm.canal_tail"],
                "farm.sluice_interaction",
                branches: branchMap(.q01, [
                    .fieldFirst: ["farm.field_west", "farm.sluice_interaction"],
                    .reedFirst: ["farm.canal_tail", "farm.sluice_interaction"],
                    .inspectFirst: ["farm.sluice_interaction", "farm.field_east"],
                ])
            )
        case 4:
            return worldPlan(ContentID.farmHomestead, "farm.sluice_interaction", actors, ["farm.main_center", "farm.field_west"], "farm.field_west")
        default:
            return revealWorldPlan(.q01, ContentID.farmHomestead, "farm.camera", actors, "brookseed.story.prop.sluice_marks")
        }
    }

    private static func q02(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.waterApprentice, StoryActorID.creekWarden, StoryActorID.seedSteward]
        switch index {
        case 1:
            return worldPlan(ContentID.farmHomestead, "farm.house_interaction", actors, ["farm.workyard", "farm.field_west", "farm.sluice_interaction"], "farm.sluice_interaction")
        case 2:
            return worldPlan(ContentID.farmHomestead, "farm.entry", actors, ["farm.main_south", "farm.main_center"], "farm.main_center", crossingActor: StoryActorID.neighborHearsay)
        case 3:
            return worldPlan(
                ContentID.farmHomestead,
                "farm.main_center",
                actors,
                ["farm.field_west", "farm.workyard", "farm.field_edge"],
                "farm.workyard",
                branches: branchMap(.q02, [
                    .harvest: ["farm.field_west", "farm.field_edge"],
                    .sandbag: ["farm.workyard", "farm.house_interaction"],
                    .patrol: ["farm.field_edge", "farm.field_east"],
                    .livestock: ["farm.main_south", "farm.field_east"],
                ])
            )
        case 4:
            return worldPlan(ContentID.farmHomestead, "farm.field_west", actors, ["farm.main_center", "farm.workyard"], "farm.workyard")
        default:
            return revealWorldPlan(.q02, ContentID.farmHomestead, "farm.camera", actors, "brookseed.story.prop.precarved_canal_keeper_sign")
        }
    }

    private static func q03(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.neighborHearsay, StoryActorID.neighborEvidence, StoryActorID.catShopBlack]
        switch index {
        case 1:
            return worldPlan(ContentID.creekMarket, "market.entry", actors, ["market.table_west", "market.record_table", "market.cat_shop_front"], "market.cat_shop_front")
        case 2:
            return worldPlan(ContentID.creekMarket, "market.entry", actors, ["market.table_south", "market.record_table", "market.cat_shop_front"], "market.record_table")
        case 3:
            return worldPlan(
                ContentID.creekMarket,
                "market.cat_shop_front",
                actors,
                ["market.record_table", "market.table_west", "market.cat_shop_side"],
                "market.record_table",
                branches: branchMap(.q03, [
                    .cutTest: ["market.record_table", "market.cat_shop_front"],
                    .traceRumor: ["market.table_west", "market.table_south", "market.cat_shop_front"],
                    .protectInventory: ["market.cat_shop_side", "market.cat_shop_front"],
                ])
            )
        case 4:
            return worldPlan(ContentID.creekMarket, "market.record_table", actors, ["market.table_west", "market.steps"], "market.steps")
        default:
            return revealWorldPlan(.q03, ContentID.creekMarket, "market.camera", actors, "brookseed.story.prop.berry_refusal_slip")
        }
    }

    private static func q04(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.seedSteward, StoryActorID.creekWarden, StoryActorID.neighborEvidence]
        switch index {
        case 1:
            return worldPlan(ContentID.creekMarket, "market.seed_shed", actors, ["market.axis_center", "market.steps"], "market.seed_shed")
        case 2:
            return worldPlan(ContentID.farmHomestead, "farm.entry", actors, ["farm.field_west", "farm.field_edge", "farm.field_east"], "farm.field_edge")
        case 3:
            return worldPlan(
                ContentID.farmHomestead,
                "farm.field_west",
                actors,
                ["farm.field_west", "farm.field_edge", "farm.field_east"],
                "farm.field_edge",
                branches: branchMap(.q04, [
                    .regroup: ["farm.field_west", "farm.field_east"],
                    .parallelCrop: ["farm.field_edge", "farm.main_center"],
                    .publishMissingPage: ["farm.field_east", "farm.entry"],
                ])
            )
        case 4:
            return worldPlan(ContentID.creekMarket, "market.seed_shed", actors, ["market.axis_center", "market.steps"], "market.seed_shed")
        default:
            return revealWorldPlan(.q04, ContentID.farmHomestead, "farm.camera", actors, "brookseed.story.prop.swapped_seed_labels")
        }
    }

    private static func q05(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.catShopBlack, StoryActorID.neighborEvidence, StoryActorID.greygateRepresentative]
        switch index {
        case 1:
            return worldPlan(ContentID.creekMarket, "market.entry", actors, ["market.axis_center", "market.cat_shop_front"], "market.cat_shop_front")
        case 2:
            return worldPlan(ContentID.creekMarket, "market.cat_shop_front", actors, ["market.cat_shop_side", "market.axis_center"], "market.cat_shop_side")
        case 3:
            return worldPlan(
                ContentID.creekMarket,
                "market.axis_center",
                actors,
                ["market.cat_shop_side", "market.cat_shop_front"],
                "market.cat_shop_side",
                branches: branchMap(.q05, [
                    .publicOrder: ["market.cat_shop_front", "market.axis_center"],
                    .coop: ["market.steps", "market.cat_shop_front"],
                    .delay: ["market.cat_shop_side", "market.cat_shop_front"],
                ])
            )
        case 4:
            return worldPlan(ContentID.creekMarket, "market.cat_shop_front", actors, ["market.axis_center", "market.steps"], "market.axis_center")
        default:
            return revealWorldPlan(.q05, ContentID.creekMarket, "market.camera", actors, "brookseed.story.prop.greygate_exclusive_contract")
        }
    }

    private static func q06(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.neighborEvidence, StoryActorID.neighborConsensus, StoryActorID.neighborStoryteller]
        switch index {
        case 1:
            return worldPlan(ContentID.creekMarket, "market.record_table", actors, ["market.waterside_walk", "market.axis_south"], "market.record_table")
        case 2:
            return worldPlan(ContentID.creekMarket, "market.table_west", actors, ["market.record_table", "market.waterside_walk", "market.table_south"], "market.waterside_walk", crossingActor: StoryActorID.neighborStoryteller)
        case 3:
            return worldPlan(
                ContentID.creekMarket,
                "market.waterside_walk",
                actors,
                ["market.table_south", "market.record_table"],
                "market.waterside_walk",
                branches: branchMap(.q06, [
                    .talk: ["market.waterside_walk", "market.record_table"],
                    .noSide: ["market.table_south", "market.record_table"],
                    .pause: ["market.record_table", "market.axis_center"],
                ])
            )
        case 4:
            return worldPlan(
                ContentID.creekMarket,
                "market.record_table",
                actors,
                ["market.waterside_walk", "market.axis_center"],
                "market.waterside_walk",
                branches: branchMap(.q06, [
                    .love: ["market.waterside_walk", "market.axis_south"],
                    .tender: ["market.record_table", "market.waterside_walk"],
                    .friend: ["market.record_table", "market.axis_center"],
                ])
            )
        default:
            return revealWorldPlan(.q06, ContentID.creekMarket, "market.camera", actors, "brookseed.story.prop.public_watermark_page")
        }
    }

    private static func q07(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.catShopBlack, StoryActorID.catShopCalico, StoryActorID.neighborConsensus]
        switch index {
        case 1:
            return worldPlan(ContentID.creekMarket, "market.cat_shop_front", actors, ["market.cat_shop_side", "market.axis_center"], "market.cat_shop_front")
        case 2:
            return worldPlan(ContentID.creekMarket, "market.cat_shop_side", actors, ["market.axis_center", "market.cat_shop_curtain"], "market.cat_shop_curtain")
        case 3:
            return worldPlan(
                ContentID.creekMarket,
                "market.cat_shop_front",
                actors,
                ["market.cat_shop_side", "market.steps"],
                "market.cat_shop_front",
                branches: branchMap(.q07, [
                    .menu: ["market.cat_shop_side", "market.cat_shop_front"],
                    .inventory: ["market.cat_shop_curtain", "market.cat_shop_front"],
                    .harvest: ["market.steps", "market.table_south"],
                    .livestock: ["market.steps", "market.cat_shop_front"],
                ])
            )
        case 4:
            return worldPlan(ContentID.creekMarket, "market.cat_shop_side", actors, ["market.axis_center", "market.cat_shop_front"], "market.cat_shop_front")
        default:
            return revealWorldPlan(.q07, ContentID.creekMarket, "market.camera", actors, "brookseed.story.prop.three_hero_shawls")
        }
    }

    private static func q08(_ index: Int) -> CuePlan {
        switch index {
        case 1:
            return worldPlan(
                ContentID.creekMarket,
                "market.table_west",
                [StoryActorID.waterApprentice, StoryActorID.creekWarden, StoryActorID.neighborStoryteller],
                ["market.axis_center", "market.cat_shop_front", "market.cat_shop_side"],
                "market.cat_shop_side"
            )
        case 2:
            return worldPlan(
                ContentID.farmHomestead,
                "farm.entry",
                [StoryActorID.waterApprentice, StoryActorID.seedSteward, StoryActorID.neighborEvidence],
                ["farm.field_west", "farm.sluice_interaction", "farm.house_interaction", "farm.stone_steps"],
                "farm.stone_steps"
            )
        case 3:
            return journeyPlan(
                StorySceneID.mistRidgeFork,
                "mist_ridge.entry",
                [StoryActorID.neighborStoryteller: "mist_ridge.white_stone"],
                ["mist_ridge.white_stone", "mist_ridge.track", "mist_ridge.burnt_paper", "mist_ridge.broken_bell"],
                "mist_ridge.track",
                branches: branchMap(.q08, [
                    .evidence: ["mist_ridge.evidence_route", "greygate.evidence_table"],
                    .tradeUnion: ["mist_ridge.trade_route", "greygate.trade_yard"],
                    .oldWaterway: ["mist_ridge.waterway_route", "old_waterway.entry", "old_waterway.sluice", "old_waterway.exit", "greygate.waterway_outlet"],
                ]),
                destinationSceneID: StorySceneID.greygateFarm
            )
        case 4:
            return journeyPlan(
                StorySceneID.greygateFarm,
                "greygate.entry",
                [
                    StoryActorID.bellPrincess: "greygate.bell_princess",
                    StoryActorID.greygateFarmer: "greygate.trade_yard",
                ],
                ["greygate.evidence_table", "greygate.trade_yard", "greygate.waterway_outlet", "greygate.bell_princess"],
                "greygate.bell_princess",
                branches: branchMap(.q08, [
                    .evidence: ["greygate.evidence_table", "greygate.bell_princess", "greygate.exit"],
                    .tradeUnion: ["greygate.trade_yard", "greygate.bell_princess", "greygate.exit"],
                    .oldWaterway: ["greygate.waterway_outlet", "greygate.bell_princess", "greygate.exit"],
                ])
            )
        default:
            return revealJourneyPlan(
                .q08,
                StorySceneID.mistRidgeFork,
                "mist_ridge.camera",
                [StoryActorID.bellPrincess, StoryActorID.greygateFarmer],
                "brookseed.story.prop.staged_mist_ridge_markers"
            )
        }
    }

    private static func q09(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.catShopBlack, StoryActorID.catShopCalico, StoryActorID.catShopRagdoll]
        switch index {
        case 1:
            return finaleWorldPlan(ContentID.creekMarket, "market.cat_shop_front", actors, ["market.cat_shop_curtain", "market.cat_shop_side"], "market.cat_shop_curtain", "brookseed.story.prop.amusement_ledger")
        case 2:
            return finaleWorldPlan(ContentID.creekMarket, "market.cat_shop_curtain", actors, ["market.cat_shop_side", "market.axis_center"], "market.cat_shop_curtain", "brookseed.story.prop.loosened_curtain_knot")
        case 3:
            return finaleWorldPlan(
                ContentID.creekMarket,
                "market.cat_shop_curtain",
                actors,
                ["market.cat_shop_front", "market.axis_center"],
                "market.cat_shop_curtain",
                "brookseed.story.prop.amusement_ledger",
                branches: branchMap(.q09, [
                    .takeLedger: ["market.cat_shop_front", "market.axis_center"],
                    .keepReading: ["market.cat_shop_curtain", "market.cat_shop_side"],
                    .closeLedger: ["market.cat_shop_curtain", "market.cat_shop_front"],
                    .returnTitles: ["market.cat_shop_side", "market.cat_shop_front"],
                ])
            )
        case 4:
            return finaleWorldPlan(ContentID.creekMarket, "market.cat_shop_front", [StoryActorID.neighborEvidence, StoryActorID.neighborConsensus, StoryActorID.neighborHearsay], ["market.record_table", "market.table_west", "market.waterside_walk"], "market.record_table", "brookseed.story.prop.named_ledger_index")
        default:
            return finaleWorldPlan(ContentID.creekMarket, "market.axis_center", [StoryActorID.seedSteward, StoryActorID.creekWarden], ["market.seed_shed", "market.warden_post"], "market.axis_center", "brookseed.story.prop.seed_bags_and_missing_page")
        }
    }

    private static func q10(_ index: Int) -> CuePlan {
        let actors = [StoryActorID.neighborEvidence, StoryActorID.neighborConsensus, StoryActorID.catShopBlack]
        switch index {
        case 1:
            return finaleWorldPlan(ContentID.creekMarket, "market.cat_shop_front", actors, ["market.record_table", "market.table_west", "market.axis_center"], "market.cat_shop_side", "brookseed.story.prop.seed_bags_and_missing_page")
        case 2:
            return finaleWorldPlan(
                ContentID.creekMarket,
                "market.cat_shop_front",
                actors,
                ["market.cat_shop_front", "market.record_table", "market.cat_shop_side"],
                "market.cat_shop_side",
                "brookseed.story.prop.hero_titles",
                branches: branchMap(.q10, [
                    .whyMe: ["market.cat_shop_front", "market.cat_shop_side"],
                    .anyTruth: ["market.record_table", "market.cat_shop_side"],
                    .silence: ["market.cat_shop_curtain", "market.cat_shop_side"],
                    .breakTitles: ["market.cat_shop_side", "market.cat_shop_front"],
                ])
            )
        case 3:
            return finaleWorldPlan(ContentID.creekMarket, "market.table_west", actors, ["market.record_table", "market.seed_shed", "market.cat_shop_side"], "market.cat_shop_side", "brookseed.story.prop.three_evidence_groups")
        case 4:
            return finaleWorldPlan(ContentID.creekMarket, "market.cat_shop_side", actors, ["market.axis_center", "market.steps"], "market.steps", "brookseed.story.prop.closed_half_curtain")
        default:
            return finaleWorldPlan(
                ContentID.farmHomestead,
                "farm.entry",
                [StoryActorID.waterApprentice, StoryActorID.neighborEvidence],
                ["farm.main_south", "farm.main_center", "farm.field_west"],
                "farm.field_west",
                "brookseed.story.prop.final_watering_or_departure",
                branches: branchMap(.q10, [
                    .water: ["farm.main_center", "farm.field_west"],
                    .leave: ["farm.stone_steps", "ending_departure"],
                ]),
                destinationSceneID: StorySceneID.endingDeparture
            )
        }
    }

    private static func worldPlan(
        _ mapID: String,
        _ entry: String,
        _ actors: [String],
        _ waypoints: [String],
        _ interaction: String,
        crossingActor: String? = nil,
        branches: [String: [String]] = [:]
    ) -> CuePlan {
        let startCandidates = waypoints.isEmpty ? [entry] : waypoints
        let exitCandidates = waypoints.isEmpty ? [entry] : Array(waypoints.reversed())
        var starts: [String: String] = [:]
        var exits: [String: String] = [:]
        for (offset, actor) in actors.prefix(3).enumerated() {
            starts[actor] = world(startCandidates[offset % startCandidates.count])
            exits[actor] = world(exitCandidates[offset % exitCandidates.count])
        }
        return CuePlan(
            sceneID: mapID,
            entry: world(entry),
            starts: starts,
            waypoints: waypoints.map { world($0) },
            interaction: world(interaction),
            crossing: StoryCrossingOrInterruptDefinition(
                kind: crossingActor == nil ? .none : .crossing,
                actorID: crossingActor,
                atAnchorID: crossingActor == nil ? nil : world(interaction),
                destinationSceneID: nil
            ),
            branches: branches,
            exits: exits,
            reveal: StoryRevealCameraOrPropDefinition(
                policy: .never,
                cameraAnchorID: nil,
                propID: nil,
                accessibleDescription: nil
            )
        )
    }

    private static func finaleWorldPlan(
        _ mapID: String,
        _ entry: String,
        _ actors: [String],
        _ waypoints: [String],
        _ interaction: String,
        _ propID: String,
        branches: [String: [String]] = [:],
        destinationSceneID: String? = nil
    ) -> CuePlan {
        var plan = worldPlan(mapID, entry, actors, waypoints, interaction, branches: branches)
        plan.crossing = StoryCrossingOrInterruptDefinition(
            kind: destinationSceneID == nil ? .interrupt : .fadeCut,
            actorID: nil,
            atAnchorID: world(interaction),
            destinationSceneID: destinationSceneID
        )
        plan.reveal = StoryRevealCameraOrPropDefinition(
            policy: .finaleOnly,
            cameraAnchorID: world(mapID == ContentID.farmHomestead ? "farm.camera" : "market.camera"),
            propID: propID,
            accessibleDescription: "可检查的终局证物与替代机位"
        )
        return plan
    }

    private static func revealWorldPlan(
        _ arcID: StoryArcID,
        _ mapID: String,
        _ camera: String,
        _ actors: [String],
        _ propID: String
    ) -> CuePlan {
        var plan = worldPlan(mapID, camera, actors, [camera], camera)
        plan.reveal = StoryRevealCameraOrPropDefinition(
            policy: .finaleOnly,
            cameraAnchorID: world(camera),
            propID: propID,
            accessibleDescription: "\(arcID.rawValue) 终局回看机位与证物"
        )
        return plan
    }

    private static func journeyPlan(
        _ sceneID: String,
        _ entry: String,
        _ starts: [String: String],
        _ waypoints: [String],
        _ interaction: String,
        branches: [String: [String]] = [:],
        destinationSceneID: String? = nil
    ) -> CuePlan {
        CuePlan(
            sceneID: sceneID,
            entry: journey(entry),
            starts: starts.mapValues { journey($0) },
            waypoints: waypoints.map { journey($0) },
            interaction: journey(interaction),
            crossing: StoryCrossingOrInterruptDefinition(
                kind: destinationSceneID == nil ? .none : .fadeCut,
                actorID: nil,
                atAnchorID: journey(interaction),
                destinationSceneID: destinationSceneID
            ),
            branches: branches,
            exits: starts.mapValues { _ in journey(waypoints.last ?? entry) },
            reveal: StoryRevealCameraOrPropDefinition(
                policy: .never,
                cameraAnchorID: nil,
                propID: nil,
                accessibleDescription: nil
            )
        )
    }

    private static func revealJourneyPlan(
        _ arcID: StoryArcID,
        _ sceneID: String,
        _ camera: String,
        _ actors: [String],
        _ propID: String
    ) -> CuePlan {
        let starts = Dictionary(uniqueKeysWithValues: actors.enumerated().map { offset, actor in
            (actor, offset == 0 ? "mist_ridge.track" : "mist_ridge.broken_bell")
        })
        var plan = journeyPlan(sceneID, "mist_ridge.entry", starts, ["mist_ridge.white_stone", camera], camera)
        plan.reveal = StoryRevealCameraOrPropDefinition(
            policy: .finaleOnly,
            cameraAnchorID: journey(camera),
            propID: propID,
            accessibleDescription: "\(arcID.rawValue) 终局旅程回看机位与证物"
        )
        return plan
    }

    private static func branchMap(
        _ arcID: StoryArcID,
        _ values: [StoryChoiceID: [String]]
    ) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: values.map { choice, anchors in
            let resolved = anchors.map { suffix in
                if suffix == "ending_departure" { return StoryAnchorCatalog.endingDepartureAnchorID }
                if suffix.hasPrefix("mist_ridge.")
                    || suffix.hasPrefix("old_waterway.")
                    || suffix.hasPrefix("greygate.") {
                    return journey(suffix)
                }
                return world(suffix)
            }
            return (choice.stableID(in: arcID), resolved)
        })
    }

    private static func world(_ suffix: String) -> String {
        "brookseed.story.anchor.\(suffix)"
    }

    private static func journey(_ suffix: String) -> String {
        "brookseed.story.anchor.journey.\(suffix)"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }
}
