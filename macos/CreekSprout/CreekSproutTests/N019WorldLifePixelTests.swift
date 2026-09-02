import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

final class N019WorldLifePixelTests: XCTestCase {
    func testWorldLifeCatalogIncludesCompleteNatureSet() {
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isFlower).count, 4)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isShrub).count, 4)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isTree).count, 4)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isAnimal).count, 12)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isFence).count, 7)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isPastureGround).count, 4)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isBackdrop).count, 2)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isRiverStone).count, 4)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isFieldPatch).count, 2)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isShoreInset).count, 8)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isHaystack).count, 1)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isScenicTilled).count, 1)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isDiningSet).count, 1)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isGreenhouse).count, 1)
        XCTAssertEqual(WorldLifeKind.allCases.filter(\.isScenicLake).count, 1)
        XCTAssertEqual(WorldLifeKind.allCases.count, 66)
    }

    func testNewNativePixelAssetsLoadAtLockedSizes() throws {
        let expected: [WorldLifeKind: (Int, Int)] = [
            .flower01: (24, 24),
            .flower02: (24, 24),
            .flower03: (24, 24),
            .flower04: (24, 24),
            .treeMaple: (96, 96),
            .treeHoneyPear: (96, 96),
            .treeMistPine: (96, 96),
            .treeCreekWillow: (96, 96),
            .farmHen: (32, 32),
            .farmCow: (48, 32),
            .farmSheep: (48, 32),
            .farmGoat: (48, 32),
            .farmPig: (48, 32),
            .farmGoose: (32, 32),
            .fenceHorizontal: (24, 24),
            .fenceVertical: (24, 24),
            .fenceCornerNW: (24, 24),
            .fenceCornerNE: (24, 24),
            .fenceCornerSW: (24, 24),
            .fenceCornerSE: (24, 24),
            .fencePost: (24, 24),
            .pastureGrass01: (24, 24),
            .pastureGrass02: (24, 24),
            .pastureGrass03: (24, 24),
            .pastureGrass04: (24, 24),
            .farmMountainBackdrop: (528, 72),
            .marketCreekValleyBackdrop: (576, 72),
            .riverStone01: (24, 24),
            .riverStone02: (24, 24),
            .riverStone03: (24, 24),
            .riverStone04: (24, 24),
            .flowerMeadow: (72, 36),
            .sunflowerField: (48, 36),
            .haystack: (32, 32),
            .farmDiningSet: (96, 48),
            .marketGreenhouse: (144, 48),
            .marketScenicLake: (144, 96),
            .scenicTilled: (24, 24),
            .bankNorth01: (24, 24),
            .bankNorth02: (24, 24),
            .bankNorth03: (24, 24),
            .bankNorth04: (24, 24),
            .bankSouth01: (24, 24),
            .bankSouth02: (24, 24),
            .bankSouth03: (24, 24),
            .bankSouth04: (24, 24),
        ]

        for (kind, size) in expected {
            let image = try XCTUnwrap(
                WorldLifeCatalog.image(for: kind),
                "missing runtime pixel resource \(kind.rawValue)"
            )
            XCTAssertEqual(Int(image.size.width), size.0, kind.rawValue)
            XCTAssertEqual(Int(image.size.height), size.1, kind.rawValue)
        }
    }

    func testFarmCoherenceR9AssetsLoadAtLockedNativeSizes() throws {
        var expected: [String: (Int, Int)] = [
            "tile_tilled_r2": (24, 24),
            "tile_tilled_watered_r2": (24, 24),
            "gather_creek_wood_r2": (24, 24),
            "prop_compost_bin_r2": (48, 48),
            "prop_rain_barrel_r2": (24, 32),
            "prop_wooden_crate_r2": (24, 24),
            "prop_woodhoney_hearth_r2": (48, 48),
        ]
        for crop in ["mist_radish", "stream_leaf", "amber_bean", "bell_berry", "honey_melon"] {
            for stage in 0...3 {
                expected["crop_\(crop)_stage_\(stage)_r3"] = (32, 32)
            }
        }

        for (assetID, size) in expected {
            let texture = try XCTUnwrap(PixelAssetStore.shared.texture(named: assetID), assetID)
            XCTAssertEqual(Int(texture.size().width), size.0, assetID)
            XCTAssertEqual(Int(texture.size().height), size.1, assetID)
        }
        XCTAssertEqual(
            PixelAssetCatalog.cropStageAssetID(
                cropID: ContentID.mistRadishCrop,
                stage: 1,
                readyToHarvest: false
            ),
            "crop_mist_radish_stage_1_r3"
        )
        XCTAssertEqual(
            PixelAssetCatalog.placedObjectAssetID(for: ContentID.compostRackObject),
            "prop_compost_bin_r2"
        )
    }

    func testBothMapsUseCurrentFarmAnimalsInsteadOfLegacyAmbientPlaceholders() {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            + WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        let kinds = Set(placements.map(\.kind))
        let legacy: Set<WorldLifeKind> = [.bird, .duck, .frog, .rabbit, .squirrel, .hedgehog]
        let current: Set<WorldLifeKind> = [.farmHen, .farmCow, .farmSheep, .farmGoat, .farmPig, .farmGoose]

        XCTAssertTrue(kinds.isDisjoint(with: legacy))
        XCTAssertTrue(current.isSubset(of: kinds))
    }

    func testLegacyAmbientAnimalPlaceholdersHaveNoPlayerVisiblePlacement() {
        let placedKinds = Set(
            (WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
                + WorldLifeCatalog.placements(mapID: ContentID.creekMarket))
                .map(\.kind)
        )
        let legacy: Set<WorldLifeKind> = [.bird, .duck, .frog, .rabbit, .squirrel, .hedgehog]
        XCTAssertTrue(placedKinds.isDisjoint(with: legacy))
    }

    func testCatShopTourIncludesEveryPixelAndHDAsset() throws {
        XCTAssertEqual(
            WorldLifeCatalog.catBbqTourKinds,
            [.catBbqShop, .catBlack, .catCalico, .catRagdoll]
        )
        for kind in WorldLifeCatalog.catBbqTourKinds {
            XCTAssertNotNil(WorldLifeCatalog.image(for: kind), "missing pixel layer: \(kind.rawValue)")
            let hd = try XCTUnwrap(
                WorldLifeCatalog.catBbqHDImage(for: kind),
                "missing HD tour layer: \(kind.rawValue)"
            )
            XCTAssertEqual(Int(hd.size.width), 2_048, kind.rawValue)
            XCTAssertEqual(Int(hd.size.height), 2_048, kind.rawValue)
        }
    }

    func testCatShopTourOnlyAppearsInsideTheMarketVisitZone() {
        XCTAssertFalse(WorldLifeCatalog.isNearCatBbqShop(
            mapID: ContentID.farmHomestead,
            position: GridPosition(x: 13, y: 9)
        ))
        XCTAssertTrue(WorldLifeCatalog.isNearCatBbqShop(
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 11, y: 10)
        ))
        XCTAssertFalse(WorldLifeCatalog.isNearCatBbqShop(
            mapID: ContentID.creekMarket,
            position: GridPosition(x: 3, y: 9)
        ))
    }

    func testWorldBuildingPixelSetLoadsWithoutProceduralFallbacks() {
        let terrainKinds: [PixelAssetKind] = [
            .tileGrass, .tileGrassA, .tileGrassB, .tileGrassC,
            .tileTilled, .tileTilledWatered, .tileWaterEdge,
        ]
        for kind in terrainKinds {
            XCTAssertNotNil(PixelAssetStore.shared.texture(kind: kind), kind.rawValue)
        }

        let formalKeys: [RuntimeArtKey] = RuntimeArtCatalog.waterFrames + [
            .tileWaterEdgeN, .tileWaterEdgeE, .tileWaterEdgeS, .tileWaterEdgeW,
            .tileWaterCornerNE, .tileWaterCornerSE, .tileWaterCornerSW, .tileWaterCornerNW,
            .tileStonePath, .tileCanalNS, .tileCanalEW,
        ] + RuntimeArtCatalog.canalFlowFrames
        for key in formalKeys {
            XCTAssertNotNil(
                PixelAssetStore.shared.texture(descriptor: RuntimeArtCatalog.descriptor(for: key)),
                key.rawValue
            )
        }

        for assetID in [
            "prop_stone_path", "prop_canal_segment_ns", "prop_canal_segment_ew",
            "prop_compost_rack", "prop_rain_barrel", "prop_wooden_crate",
            "prop_woodhoney_hearth",
        ] {
            XCTAssertNotNil(PixelAssetStore.shared.texture(named: assetID), assetID)
        }
    }

    func testDisplayR2OverridesCoverGroundStoneAndMovingWater() {
        let expected: Set<String> = [
            "tile_grass", "tile_grass_a", "tile_grass_b", "tile_grass_c",
            "tile_stone_path", "prop_stone_path",
            "tile_water_f00", "tile_water_f01", "tile_water_f02", "tile_water_f03",
            "tile_water_edge", "tile_water_edge_n", "tile_water_edge_e",
            "tile_water_edge_s", "tile_water_edge_w",
            "tile_water_corner_ne", "tile_water_corner_se",
            "tile_water_corner_sw", "tile_water_corner_nw",
            "tile_canal_ns", "tile_canal_ew",
            "prop_canal_segment_ns", "prop_canal_segment_ew",
            "fx_canal_flow_f00", "fx_canal_flow_f01",
            "fx_canal_flow_f02", "fx_canal_flow_f03",
        ]
        XCTAssertEqual(PixelAssetStore.displayR2OverrideAssetIDs, expected)
        for assetID in expected {
            XCTAssertEqual(
                PixelAssetStore.displayR2AssetID(for: assetID),
                "r2_\(assetID)"
            )
        }
        XCTAssertNil(PixelAssetStore.displayR2AssetID(for: "char_player"))
    }

    func testDisplayR3ReplacesOnlyAmbiguousGrassSurfaces() {
        let expected: Set<String> = [
            "tile_grass", "tile_grass_a", "tile_grass_b", "tile_grass_c",
        ]
        XCTAssertEqual(PixelAssetStore.displayR3OverrideAssetIDs, expected)
        for assetID in expected {
            XCTAssertEqual(PixelAssetStore.displayR3AssetID(for: assetID), "r3_\(assetID)")
            XCTAssertNotNil(PixelAssetStore.shared.texture(named: assetID), assetID)
        }
        XCTAssertNil(PixelAssetStore.displayR3AssetID(for: "tile_water_f00"))
    }

    func testDisplayR4ReplacesStonePathAndDirectionalWaterOnly() {
        let expected: Set<String> = [
            "tile_stone_path",
            "tile_water_f00", "tile_water_f01", "tile_water_f02", "tile_water_f03",
        ]
        XCTAssertEqual(PixelAssetStore.displayR4OverrideAssetIDs, expected)
        for assetID in expected {
            XCTAssertEqual(PixelAssetStore.displayR4AssetID(for: assetID), "r4_\(assetID)")
            XCTAssertNotNil(PixelAssetStore.shared.texture(named: assetID), assetID)
        }
        XCTAssertNil(PixelAssetStore.displayR4AssetID(for: "tile_water_edge_n"))
    }

    func testAdjacentWaterCellsUseStaggeredPixelAnimationPhases() {
        let first = WorldVisualCatalog.waterAnimationKeys(at: GridPosition(x: 0, y: 0))
        let second = WorldVisualCatalog.waterAnimationKeys(at: GridPosition(x: 1, y: 0))
        XCTAssertEqual(Set(first), Set(RuntimeArtCatalog.waterFrames))
        XCTAssertEqual(Set(second), Set(RuntimeArtCatalog.waterFrames))
        XCTAssertNotEqual(first.first, second.first)
    }

    func testEveryBuildingThresholdVisuallyConnectsToItsAuthoritativeRoad() {
        for map in WorldCatalog.mapList {
            let visibleRoad = WorldVisualCatalog.presentationPathCells(mapID: map.id)
            XCTAssertTrue(map.pathCells.isSubset(of: visibleRoad), map.id)

            for building in map.buildings {
                XCTAssertTrue(visibleRoad.contains(building.door), building.id)
                XCTAssertFalse(
                    building.interactionCells.isDisjoint(with: visibleRoad),
                    "\(building.id) has no road-facing interaction cell"
                )
                XCTAssertTrue(
                    building.interactionCells.contains { interaction in
                        abs(interaction.x - building.door.x) + abs(interaction.y - building.door.y) == 1
                    },
                    "\(building.id) threshold is not adjacent to its road approach"
                )
            }
        }
    }

    func testFarmDemoUsesOneRoadBufferedFencedFieldAndAConnectedWorkYard() {
        let state = DemoSessionFixture.makeInitialState()
        let mainBed = Set((1...5).flatMap { x in
            (2...5).map { y in GridPosition(x: x, y: y) }
        })
        let rearBed = FarmCultivationCatalog.rearCultivableCells
        XCTAssertTrue(mainBed.allSatisfy { state.farmCells[$0]?.prepared == true })
        XCTAssertTrue(mainBed.allSatisfy { state.farmCells[$0]?.hasCrop == true })
        XCTAssertTrue(rearBed.allSatisfy { state.farmCells[$0]?.prepared == true })
        XCTAssertTrue(rearBed.allSatisfy { state.farmCells[$0]?.hasCrop == false })
        XCTAssertEqual(Set(state.farmCells.keys), mainBed.union(rearBed))
        XCTAssertTrue((2...5).allSatisfy { state.farmCells[GridPosition(x: 6, y: $0)] == nil })
        XCTAssertTrue((2...5).allSatisfy { state.farmCells[GridPosition(x: 7, y: $0)] == nil })

        let expectedCropByColumn = [
            1: ContentID.mistRadishCrop,
            2: ContentID.streamLeafCrop,
            3: ContentID.amberBeanCrop,
            4: ContentID.bellBerryCrop,
            5: ContentID.honeyMelonCrop,
        ]
        for (x, cropID) in expectedCropByColumn {
            XCTAssertTrue((2...5).allSatisfy {
                state.farmCells[GridPosition(x: x, y: $0)]?.cropID == cropID
            })
        }

        let fences = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            .filter(\.kind.isFence)
        XCTAssertFalse(fences.contains { $0.cell == GridPosition(x: 6, y: 3) })
        XCTAssertTrue(fences.contains { $0.cell == GridPosition(x: 6, y: 2) })
        XCTAssertTrue(fences.contains { $0.cell == GridPosition(x: 6, y: 4) })
        XCTAssertFalse(fences.contains { $0.cell == GridPosition(x: 1, y: 6) })

        let occupiedWorkYard = Set(state.placedObjects.flatMap { object in
            PlacementService.absoluteFootprint(
                definitionID: object.definitionID,
                origin: object.origin,
                facing: object.facing,
                catalog: .vs0
            )
        })
        XCTAssertEqual(occupiedWorkYard, Set([
            GridPosition(x: 7, y: 4),
            GridPosition(x: 8, y: 4), GridPosition(x: 9, y: 4),
            GridPosition(x: 8, y: 5), GridPosition(x: 9, y: 5),
        ]))
        let crate = state.placedObjects.first { $0.definitionID == ContentID.woodenCrateObject }
        XCTAssertEqual(crate?.origin, GridPosition(x: 7, y: 4))
        XCTAssertFalse(occupiedWorkYard.contains(GridPosition(x: 10, y: 5)))
        XCTAssertFalse(WorldVisualCatalog.farmServicePathCells.contains(WorldVisualCatalog.demoCrateDisplayCell))
        XCTAssertTrue(
            occupiedWorkYard.isSubset(of: WorldVisualCatalog.farmServicePathCells)
        )
        XCTAssertTrue(
            WorldVisualCatalog.farmServicePathCells.contains(GridPosition(x: 9, y: 6))
        )
        XCTAssertTrue(
            WorldVisualCatalog.presentationPathCells(mapID: ContentID.farmHomestead)
                .contains(GridPosition(x: 9, y: 7))
        )
    }

    func testOnlyTheExactDemoCrateRendersAtTheProductOwnerTargetCell() throws {
        let crate = try XCTUnwrap(
            DemoSessionFixture.visualProps().first { $0.definitionID == ContentID.woodenCrateObject }
        )
        XCTAssertEqual(
            WorldVisualCatalog.placedObjectDisplayCell(for: crate, mapID: ContentID.farmHomestead),
            GridPosition(x: 10, y: 5)
        )
        XCTAssertEqual(
            GridPosition(
                x: WorldVisualCatalog.demoCrateDisplayCell.x - crate.origin.x,
                y: WorldVisualCatalog.demoCrateDisplayCell.y - crate.origin.y
            ),
            GridPosition(x: 3, y: 1)
        )

        var differentID = crate
        differentID.instanceID = "player-crate"
        XCTAssertEqual(
            WorldVisualCatalog.placedObjectDisplayCell(for: differentID, mapID: ContentID.farmHomestead),
            differentID.origin
        )
        var differentOrigin = crate
        differentOrigin.origin = GridPosition(x: 6, y: 4)
        XCTAssertEqual(
            WorldVisualCatalog.placedObjectDisplayCell(for: differentOrigin, mapID: ContentID.farmHomestead),
            differentOrigin.origin
        )
        XCTAssertEqual(
            WorldVisualCatalog.placedObjectDisplayCell(for: crate, mapID: ContentID.creekMarket),
            crate.origin
        )
    }

    func testFarmAnimalsStayOutOfOpeningCropBedsAndWorkYard() {
        let protectedCells = Set(DemoSessionFixture.visualGardenCells().keys)
            .union(DemoSessionFixture.visualProps().map(\.origin))
        let farmAnimals = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            .filter { $0.kind.isAnimal }

        XCTAssertTrue(farmAnimals.allSatisfy { !protectedCells.contains($0.cell) })
        XCTAssertEqual(Set(farmAnimals.map(\.kind)), [.farmHen, .farmCow, .farmSheep, .farmGoat])
    }

    func testMarketSluiceMouthConnectsWharfToCreekWithoutChangingTopology() throws {
        let mouth = WorldVisualCatalog.marketSluiceMouth
        let apron = WorldVisualCatalog.marketSluiceApron
        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.creekMarket])
        XCTAssertEqual(mouth, GridPosition(x: 3, y: 2))
        XCTAssertEqual(apron, GridPosition(x: 3, y: 3))
        XCTAssertTrue(map.waterCells.contains(where: { $0.cell == mouth }))
        let building = try XCTUnwrap(
            map.buildings.first(where: { $0.id == "brookseed.landmark.market_wharf" })
        )
        XCTAssertTrue(building.footprint.contains(apron))
        XCTAssertEqual(apron.y, mouth.y + 1)
        XCTAssertEqual(
            WorldVisualCatalog.sluiceConnectionKeys(at: mouth, mapID: ContentID.creekMarket),
            [.tileCanalNS]
        )
        XCTAssertTrue(
            WorldVisualCatalog.sluiceConnectionKeys(at: mouth, mapID: ContentID.farmHomestead).isEmpty
        )
        let wharf = try XCTUnwrap(PixelAssetStore.shared.texture(named: "building_market_wharf_r2"))
        XCTAssertEqual(Int(wharf.size().width), 144)
        XCTAssertEqual(Int(wharf.size().height), 96)
        XCTAssertEqual(wharf.filteringMode, .nearest)
        let node = BuildingVisualPresenter.makeNode(
            building: building,
            cellSize: 48,
            playerPosition: GridPosition(x: 3, y: 5),
            watershedRestored: false
        )
        XCTAssertNotNil(node.childNode(withName: "building-layer-wharf-r2"))
        XCTAssertNil(node.childNode(withName: "building-layer-roof"))
    }

    func testFarmSluiceApronConnectsTheAnimatedCanalWithoutChangingTopology() throws {
        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.farmHomestead])
        let apron = WorldVisualCatalog.farmSluiceApron
        XCTAssertEqual(apron, GridPosition(x: 13, y: 8))
        XCTAssertEqual(
            Set(map.canalCells.map(\.cell)),
            Set((2...7).map { GridPosition(x: 13, y: $0) })
        )
        XCTAssertEqual(map.canalCells.count, 6)
        XCTAssertEqual(apron.x, 13)
        XCTAssertEqual(apron.y, 7 + 1)

        let sluice = try XCTUnwrap(
            map.buildings.first { $0.id == "brookseed.landmark.farm_sluice" }
        )
        XCTAssertTrue(sluice.footprint.contains(apron))
        XCTAssertEqual(sluice.door, GridPosition(x: 12, y: 8))
        XCTAssertEqual(sluice.interactionCells, [GridPosition(x: 12, y: 7)])
        XCTAssertEqual(
            WorldVisualCatalog.farmSluiceConnectionKeys(
                at: apron,
                mapID: ContentID.farmHomestead
            ),
            [.tileCanalNS]
        )
        XCTAssertTrue(
            WorldVisualCatalog.farmSluiceConnectionKeys(
                at: apron,
                mapID: ContentID.creekMarket
            ).isEmpty
        )

        let first = WorldVisualCatalog.canalAnimationKeys(at: GridPosition(x: 13, y: 2))
        let next = WorldVisualCatalog.canalAnimationKeys(at: GridPosition(x: 13, y: 3))
        XCTAssertEqual(Set(first), Set(RuntimeArtCatalog.canalFlowFrames))
        XCTAssertEqual(Set(next), Set(RuntimeArtCatalog.canalFlowFrames))
        XCTAssertNotEqual(first.first, next.first)

        let scene = FarmScene(size: CGSize(width: 1_280, height: 800))
        scene.scaleMode = .resizeFill
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_280, height: 800))
        view.presentScene(scene)
        scene.replaceSessionState(DemoSessionFixture.makeInitialState())
        XCTAssertNotNil(scene.childNode(withName: ".//formal-farm-sluice-apron"))
        XCTAssertNotNil(scene.childNode(withName: ".//formal-farm-sluice-apron-flow"))
        XCTAssertNotNil(scene.childNode(withName: ".//formal-canal-cast-shadow"))
        XCTAssertNotNil(scene.childNode(withName: ".//formal-canal-sunlit-rim"))
        XCTAssertNotNil(scene.childNode(withName: ".//formal-farm-sluice-mouth-shadow"))
    }

    func testCatShopUsesCompactR3EntranceSprite() throws {
        XCTAssertEqual(WorldLifeKind.catBbqShop.assetName, "wl_cat_bbq_shop_r3")
        let image = try XCTUnwrap(WorldLifeCatalog.image(for: .catBbqShop))
        XCTAssertEqual(Int(image.size.width), 72)
        XCTAssertEqual(Int(image.size.height), 72)
    }

    func testMarketEntranceKeepsGreenhouseRoofClearWithoutRestoringADeadPlantRow() throws {
        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.creekMarket])
        let edge = WorldLifeCatalog.edgeBand(mapID: ContentID.creekMarket)
        XCTAssertLessThan(edge.count, map.environmentBoundaryCells.count)

        let entrySightline = Set((7...11).map { GridPosition(x: $0, y: 13) })
        XCTAssertTrue(Set(edge.map(\.cell)).isDisjoint(with: entrySightline))

        let topClusters = edge.filter { $0.cell.y == 13 }.map(\.cell.x).sorted()
        XCTAssertTrue(topClusters.isEmpty)
        XCTAssertFalse(edge.contains { $0.cell == GridPosition(x: 2, y: 13) })
        XCTAssertFalse(edge.contains { $0.cell == GridPosition(x: 3, y: 13) })
    }

    func testCatShopAndStaffHaveAnIndependentEntranceForecourt() throws {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        let shop = try XCTUnwrap(placements.first { $0.kind == .catBbqShop })
        XCTAssertEqual(shop.cell, GridPosition(x: 11, y: 10))

        let staff = placements.filter(\.kind.isCatStaff)
        XCTAssertEqual(Set(staff.map(\.cell)), Set([
            GridPosition(x: 10, y: 9),
            GridPosition(x: 13, y: 6),
            GridPosition(x: 10, y: 6),
        ]))
        XCTAssertEqual(
            staff.first(where: { $0.kind == .catBlack })?.cell,
            GridPosition(x: 10, y: 9)
        )

        let shopCanvas = Set((10...12).flatMap { x in
            (10...12).map { y in GridPosition(x: x, y: y) }
        })
        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.creekMarket])
        XCTAssertFalse(shopCanvas.contains(GridPosition(x: 9, y: 12)))
        for building in map.buildings {
            XCTAssertTrue(shopCanvas.isDisjoint(with: building.footprint), building.id)
        }
        XCTAssertFalse(shopCanvas.contains(GridPosition(x: 10, y: 9)))
    }

    func testMarketSeedGardenReplacesFiveCropSpritesWithFlowersInPlace() throws {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        let beds = placements.filter { $0.kind.isGardenBed }
        let crops = placements.filter { $0.kind.isCropDisplay }
        let bedCells = Set(beds.map(\.cell))
        let flowers = placements.filter { $0.kind.isFlower && bedCells.contains($0.cell) }
        XCTAssertEqual(beds.count, 5)
        XCTAssertTrue(crops.isEmpty)
        XCTAssertEqual(flowers.count, 5)
        XCTAssertEqual(bedCells, Set(flowers.map(\.cell)))
        XCTAssertEqual(bedCells, Set([
            GridPosition(x: 4, y: 6),
            GridPosition(x: 5, y: 6),
            GridPosition(x: 6, y: 6),
            GridPosition(x: 3, y: 7),
            GridPosition(x: 4, y: 7),
        ]))
        XCTAssertEqual(Set(flowers.map(\.kind)), [.flower01, .flower02, .flower03, .flower04])
        XCTAssertEqual(WorldLifeKind.gardenBed.assetName, "tile_tilled_watered_r2")
        for placement in flowers {
            let image = try XCTUnwrap(WorldLifeCatalog.image(for: placement.kind))
            XCTAssertEqual(Int(image.size.width), 24, placement.kind.rawValue)
            XCTAssertEqual(Int(image.size.height), 24, placement.kind.rawValue)
        }
    }

    func testCatStaffUseReadableR2PixelSprites() throws {
        let expected: [WorldLifeKind: String] = [
            .catBlack: "wl_cat_black_r2",
            .catCalico: "wl_cat_calico_r2",
            .catRagdoll: "wl_cat_ragdoll_r2",
        ]
        for (kind, assetName) in expected {
            XCTAssertEqual(kind.assetName, assetName)
            let image = try XCTUnwrap(WorldLifeCatalog.image(for: kind))
            XCTAssertEqual(Int(image.size.width), 32, assetName)
            XCTAssertEqual(Int(image.size.height), 48, assetName)
        }
    }

    func testShrubsUseReadableR2PixelSprites() throws {
        let expected: [WorldLifeKind: String] = [
            .shrub01: "wl_shrub_01_r2",
            .shrub02: "wl_shrub_02_r2",
            .shrub03: "wl_shrub_03_r2",
            .shrub04: "wl_shrub_04_r2",
        ]
        for (kind, assetName) in expected {
            XCTAssertEqual(kind.assetName, assetName)
            let image = try XCTUnwrap(WorldLifeCatalog.image(for: kind))
            XCTAssertEqual(Int(image.size.width), 24, assetName)
            XCTAssertEqual(Int(image.size.height), 24, assetName)
        }
    }

    func testPastureMovedToFarmEastBankWithMeadowFenceAndEntrance() {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
        let pasture = placements.filter(\.kind.isPastureGround)
        let pastureFences = placements.filter {
            $0.kind.isFence && (14...15).contains($0.cell.x) && (3...7).contains($0.cell.y)
        }

        XCTAssertEqual(Set(pasture.map(\.cell)), Set([
            GridPosition(x: 14, y: 3), GridPosition(x: 15, y: 3),
            GridPosition(x: 14, y: 4), GridPosition(x: 15, y: 4),
            GridPosition(x: 14, y: 5), GridPosition(x: 15, y: 5),
            GridPosition(x: 14, y: 6), GridPosition(x: 15, y: 6),
            GridPosition(x: 14, y: 7), GridPosition(x: 15, y: 7),
        ]))
        XCTAssertFalse(pastureFences.contains { $0.cell == GridPosition(x: 15, y: 5) })
        XCTAssertTrue(pastureFences.contains { $0.cell == GridPosition(x: 15, y: 4) })
        XCTAssertTrue(pastureFences.contains { $0.cell == GridPosition(x: 15, y: 6) })

        let pastureAnimals = placements.filter {
            $0.kind.isAnimal && (14...15).contains($0.cell.x) && (3...7).contains($0.cell.y)
        }
        XCTAssertEqual(Set(pastureAnimals.map(\.kind)), [.farmCow, .farmSheep, .farmGoat])

        let marketPlacements = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        XCTAssertTrue(marketPlacements.filter(\.kind.isPastureGround).isEmpty)
        XCTAssertEqual(
            Set(marketPlacements.filter(\.kind.isFence).map(\.cell)),
            Set((6...7).map { GridPosition(x: $0, y: 3) })
        )
    }

    func testSharpSkyRidgesStayInTopScreenBandWithoutChangingWaterTopology() throws {
        let farm = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            .filter(\.kind.isBackdrop)
        let market = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
            .filter(\.kind.isBackdrop)

        XCTAssertEqual(farm, [
            WorldLifePlacement(
                kind: .farmMountainBackdrop,
                cell: GridPosition(x: 7, y: 14)
            ),
        ])
        XCTAssertEqual(market, [
            WorldLifePlacement(
                kind: .marketCreekValleyBackdrop,
                cell: GridPosition(x: 8, y: 14)
            ),
        ])

        let farmImage = try XCTUnwrap(WorldLifeCatalog.image(for: .farmMountainBackdrop))
        let marketImage = try XCTUnwrap(WorldLifeCatalog.image(for: .marketCreekValleyBackdrop))
        XCTAssertEqual(
            Int(farmImage.size.width),
            (WorldCatalog.farmHomestead.columns + 2 * WorldCamera.bleedCells) * 24
        )
        XCTAssertEqual(
            Int(marketImage.size.width),
            (WorldCatalog.creekMarket.columns + 2 * WorldCamera.bleedCells) * 24
        )
        XCTAssertEqual(Int(farmImage.size.height), 3 * 24)
        XCTAssertEqual(Int(marketImage.size.height), 3 * 24)
        XCTAssertEqual(
            WorldLifeKind.farmMountainBackdrop.assetName,
            "wl_backdrop_farm_north_horizon_r6"
        )
        XCTAssertEqual(
            WorldLifeKind.marketCreekValleyBackdrop.assetName,
            "wl_backdrop_market_north_horizon_r6"
        )

        let farmRearHouseRow = try XCTUnwrap(
            WorldCatalog.farmHomestead.buildings.flatMap(\.footprint).map(\.y).max()
        )
        let marketRearHouseRow = try XCTUnwrap(
            WorldCatalog.creekMarket.buildings.flatMap(\.footprint).map(\.y).max()
        )
        XCTAssertGreaterThan(try XCTUnwrap(farm.first?.cell.y), farmRearHouseRow)
        XCTAssertGreaterThan(try XCTUnwrap(market.first?.cell.y), marketRearHouseRow)
        XCTAssertEqual(try XCTUnwrap(farm.first?.cell.y), WorldCatalog.farmHomestead.rows - 1)
        XCTAssertEqual(try XCTUnwrap(market.first?.cell.y), WorldCatalog.creekMarket.rows)

        try assertSharpOpaqueSkyRidge(farmImage, name: "farm")
        try assertSharpOpaqueSkyRidge(marketImage, name: "market")

        XCTAssertEqual(WorldCatalog.farmHomestead.waterCells.count, 6)
        XCTAssertEqual(WorldCatalog.farmHomestead.canalCells.count, 6)
        XCTAssertEqual(WorldCatalog.creekMarket.waterCells.count, 54)
        XCTAssertTrue(WorldCatalog.creekMarket.canalCells.isEmpty)
        XCTAssertEqual(
            WorldCatalog.creekMarket.exits.first?.cell,
            GridPosition(x: 9, y: 12)
        )
    }

    private func assertSharpOpaqueSkyRidge(_ image: NSImage, name: String) throws {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(data: image.tiffRepresentation ?? Data()),
            "\(name) ridge bitmap"
        )
        var palette = Set<UInt32>()
        var fullySkyRows = 0
        var mountainPixels = 0
        for y in 0..<bitmap.pixelsHigh {
            var fullSkyRow = true
            for x in 0..<bitmap.pixelsWide {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y), "\(name) pixel")
                XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.001, "\(name) sky must replace bleed grass")
                let red = Int(round(color.redComponent * 255))
                let green = Int(round(color.greenComponent * 255))
                let blue = Int(round(color.blueComponent * 255))
                palette.insert(UInt32(red << 16 | green << 8 | blue))
                let isSky = green + blue - 2 * red >= 50
                fullSkyRow = fullSkyRow && isSky
                mountainPixels += isSky ? 0 : 1
            }
            fullySkyRows += fullSkyRow ? 1 : 0
        }

        var nonUniformAlignedBlocks = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh - 1, by: 2) {
            for x in stride(from: 0, to: bitmap.pixelsWide - 1, by: 2) {
                let colors = try [
                    bitmap.colorAt(x: x, y: y),
                    bitmap.colorAt(x: x + 1, y: y),
                    bitmap.colorAt(x: x, y: y + 1),
                    bitmap.colorAt(x: x + 1, y: y + 1),
                ].map { color -> UInt32 in
                    let value = try XCTUnwrap(color, "\(name) 2x detail pixel")
                    let red = UInt32(round(value.redComponent * 255))
                    let green = UInt32(round(value.greenComponent * 255))
                    let blue = UInt32(round(value.blueComponent * 255))
                    return red << 16 | green << 8 | blue
                }
                nonUniformAlignedBlocks += Set(colors).count > 1 ? 1 : 0
            }
        }

        XCTAssertGreaterThanOrEqual(fullySkyRows, 20, "\(name) needs visible blue sky above its ridge")
        XCTAssertGreaterThan(mountainPixels, bitmap.pixelsWide * 8, "\(name) ridge cannot be empty")
        XCTAssertGreaterThanOrEqual(palette.count, 12, "\(name) needs distinct sky, foliage and stone planes")
        XCTAssertLessThanOrEqual(palette.count, 24, "\(name) must keep a limited pixel palette")
        XCTAssertGreaterThan(
            nonUniformAlignedBlocks,
            bitmap.pixelsWide,
            "\(name) must contain native 1px detail, not an R16-style 2x enlargement"
        )
    }

    func testProductOwnerMarketAnchorsKeepLandmarksAndAddFields() throws {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        XCTAssertTrue(placements.contains(WorldLifePlacement(
            kind: .flowerMeadow,
            cell: GridPosition(x: 5, y: 10)
        )))
        XCTAssertEqual(
            Set(placements.filter { $0.kind == .sunflowerField }.map(\.cell)),
            Set([
                GridPosition(x: 6, y: 3),
                GridPosition(x: 15, y: 3),
                GridPosition(x: 17, y: 3),
            ])
        )
        XCTAssertEqual(
            Set(placements.filter(\.kind.isFence).map(\.cell)),
            Set((6...7).map { GridPosition(x: $0, y: 3) })
        )

        let rightFieldCells: Set<GridPosition> = [
            GridPosition(x: 15, y: 3),
            GridPosition(x: 17, y: 3),
        ]
        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.creekMarket])
        XCTAssertTrue(rightFieldCells.isDisjoint(with: map.pathCells))
        XCTAssertTrue(rightFieldCells.isDisjoint(with: Set(map.exits.map(\.cell))))
        XCTAssertTrue(rightFieldCells.isDisjoint(with: Set(
            WorldCatalog.npcs.values
                .filter { $0.mapID == ContentID.creekMarket }
                .map(\.position)
        )))

        let seedSteward = try XCTUnwrap(WorldCatalog.npcs[ContentID.seedSteward])
        let creekWarden = try XCTUnwrap(WorldCatalog.npcs[ContentID.creekWarden])
        let neighborConsensus = try XCTUnwrap(WorldCatalog.npcs[ContentID.neighborConsensus])
        XCTAssertEqual(seedSteward.position, GridPosition(x: 4, y: 9))
        XCTAssertEqual(creekWarden.position, GridPosition(x: 13, y: 9))
        XCTAssertEqual(neighborConsensus.id, "brookseed.npc.neighbor_consensus")
        XCTAssertEqual(neighborConsensus.position, GridPosition(x: 7, y: 11))
    }

    func testProductOwnerFarmAnchorsAddRearPlotsAndHaystack() {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
        XCTAssertTrue(placements.contains(WorldLifePlacement(
            kind: .flowerMeadow,
            cell: GridPosition(x: 0, y: 8)
        )))
        XCTAssertFalse(placements.contains(WorldLifePlacement(
            kind: .flowerMeadow,
            cell: GridPosition(x: 0, y: 9)
        )))
        XCTAssertTrue(placements.contains(WorldLifePlacement(
            kind: .treeMaple,
            cell: GridPosition(x: 0, y: 9)
        )))
        XCTAssertTrue(placements.contains(WorldLifePlacement(
            kind: .haystack,
            cell: GridPosition(x: 11, y: 5)
        )))
        XCTAssertTrue(placements.filter(\.kind.isScenicTilled).isEmpty)

        let rearFence = Set(placements.filter {
            $0.kind.isFence && (6...9).contains($0.cell.x) && (11...14).contains($0.cell.y)
        }.map(\.cell))
        let expectedFence: Set<GridPosition> = [
            GridPosition(x: 6, y: 11),
            GridPosition(x: 6, y: 12),
            GridPosition(x: 6, y: 13),
            GridPosition(x: 9, y: 13),
        ]
        XCTAssertEqual(rearFence, expectedFence)

        let removedFencePlacements = [
            WorldLifePlacement(kind: .fenceCornerSE, cell: GridPosition(x: 9, y: 11)),
            WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 9, y: 12)),
            WorldLifePlacement(kind: .fenceCornerNW, cell: GridPosition(x: 6, y: 14)),
            WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 7, y: 14)),
            WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 8, y: 14)),
            WorldLifePlacement(kind: .fenceCornerNE, cell: GridPosition(x: 9, y: 14)),
            WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 8, y: 11)),
        ]
        XCTAssertTrue(removedFencePlacements.allSatisfy { !placements.contains($0) })
        XCTAssertTrue(placements.contains(WorldLifePlacement(
            kind: .fenceVertical,
            cell: GridPosition(x: 9, y: 13)
        )))
        XCTAssertEqual(
            Set(placements.filter { $0.kind == .sunflowerField }.map(\.cell)),
            Set([
                GridPosition(x: 5, y: 12),
                GridPosition(x: 12, y: 12),
                GridPosition(x: 14, y: 12),
            ])
        )
    }

    func testR20DiningPathOpeningAndRearCultivationContract() throws {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
        XCTAssertEqual(
            placements.filter(\.kind.isDiningSet),
            [WorldLifePlacement(kind: .farmDiningSet, cell: GridPosition(x: 3, y: 0))]
        )
        XCTAssertFalse(placements.contains {
            ($0.kind == .shrub03 && $0.cell == GridPosition(x: 2, y: 0))
                || ($0.kind == .flower02 && $0.cell == GridPosition(x: 5, y: 0))
        })

        let expectedApproach: Set<GridPosition> = Set((8...11).map {
            GridPosition(x: 7, y: $0)
        })
        XCTAssertEqual(WorldVisualCatalog.farmRearApproachPathCells, expectedApproach)
        XCTAssertTrue(expectedApproach.isSubset(of: WorldVisualCatalog.farmServicePathCells))

        let map = try XCTUnwrap(WorldCatalog.maps[ContentID.farmHomestead])
        XCTAssertTrue(FarmCultivationCatalog.rearCultivableCells.isDisjoint(
            with: map.environmentBoundaryCells
        ))
        XCTAssertTrue(FarmCultivationCatalog.rearCultivableCells.allSatisfy { !map.isBlocked($0) })
        XCTAssertTrue((0..<map.columns).allSatisfy {
            map.isBlocked(GridPosition(x: $0, y: 14))
        })
        XCTAssertTrue(FarmCultivationCatalog.rearCultivableCells.allSatisfy {
            !$0.isInsideFarm && FarmCultivationCatalog.contains($0)
        })
        XCTAssertFalse(FarmCultivationCatalog.contains(GridPosition(x: 6, y: 12)))
        XCTAssertFalse(FarmCultivationCatalog.contains(GridPosition(x: 9, y: 12)))

        var traversal = DemoSessionFixture.makeInitialState()
        traversal.position = GridPosition(x: 7, y: 7)
        for expectedRow in 8...13 {
            let move = MapTravelService.tryMove(
                state: &traversal,
                direction: .up,
                catalog: .vs0
            )
            XCTAssertTrue(move.didMove, "rear approach stopped before row \(expectedRow)")
            XCTAssertEqual(traversal.position, GridPosition(x: 7, y: expectedRow))
        }
        let blockedAtNorthBuffer = MapTravelService.tryMove(
            state: &traversal,
            direction: .up,
            catalog: .vs0
        )
        XCTAssertFalse(blockedAtNorthBuffer.didMove)
        XCTAssertEqual(traversal.position, GridPosition(x: 7, y: 13))
    }

    func testR21VisualFeedbackKeepsAnchorsWhileReplacingOnlyMarkedContent() throws {
        let placements = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
        XCTAssertEqual(
            placements.filter(\.kind.isGreenhouse),
            [WorldLifePlacement(kind: .marketGreenhouse, cell: GridPosition(x: 5, y: 12))]
        )
        XCTAssertEqual(
            placements.filter(\.kind.isScenicLake),
            [WorldLifePlacement(kind: .marketScenicLake, cell: GridPosition(x: 15, y: 11))]
        )
        XCTAssertEqual(WorldCatalog.creekMarket.waterCells.count, 54)

        let removedLandscape: Set<GridPosition> = [
            GridPosition(x: 2, y: 13),
            GridPosition(x: 3, y: 13),
            GridPosition(x: 13, y: 11),
            GridPosition(x: 17, y: 11),
            GridPosition(x: 17, y: 12),
            GridPosition(x: 14, y: 13),
            GridPosition(x: 15, y: 13),
        ]
        let flowersAndShrubs = placements.filter { $0.kind.isFlower || $0.kind.isShrub }
        XCTAssertTrue(Set(flowersAndShrubs.map(\.cell)).isDisjoint(with: removedLandscape))

        let displayCells: Set<GridPosition> = [
            GridPosition(x: 4, y: 6),
            GridPosition(x: 5, y: 6),
            GridPosition(x: 6, y: 6),
            GridPosition(x: 3, y: 7),
            GridPosition(x: 4, y: 7),
        ]
        XCTAssertEqual(
            Set(placements.filter {
                $0.kind.isFlower && displayCells.contains($0.cell)
            }.map(\.cell)),
            displayCells
        )
        XCTAssertEqual(
            Set(placements.filter {
                $0.kind.isGardenBed && displayCells.contains($0.cell)
            }.map(\.cell)),
            displayCells
        )
        XCTAssertTrue(placements.filter(\.kind.isCropDisplay).isEmpty)
        XCTAssertEqual(WorldLifeCatalog.marketGreenhouseRetreatInTiles, 0.5)

        let frames = WorldLifeCatalog.marketScenicLakeFrames()
        XCTAssertEqual(frames.count, 4)
        let bitmaps = try frames.map { image in
            try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        }
        XCTAssertTrue(bitmaps.allSatisfy { $0.pixelsWide == 144 && $0.pixelsHigh == 96 })
        let masks = try bitmaps.map { bitmap in
            try (0..<bitmap.pixelsHigh).flatMap { y in
                try (0..<bitmap.pixelsWide).map { x in
                    try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent > 0.5
                }
            }
        }
        XCTAssertTrue(masks.dropFirst().allSatisfy { $0 == masks[0] })

        let pixels = try bitmaps.prefix(2).map { bitmap in
            try (0..<bitmap.pixelsHigh).flatMap { y in
                try (0..<bitmap.pixelsWide).map { x -> UInt32 in
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                    let red = UInt32(round(color.redComponent * 255))
                    let green = UInt32(round(color.greenComponent * 255))
                    let blue = UInt32(round(color.blueComponent * 255))
                    return red << 16 | green << 8 | blue
                }
            }
        }
        XCTAssertNotEqual(pixels[0], pixels[1])

        var state = DemoSessionFixture.makeInitialState()
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 9, y: 11)
        let scene = FarmScene(size: CGSize(width: 1_280, height: 800))
        scene.scaleMode = .resizeFill
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_280, height: 800))
        view.presentScene(scene)
        scene.replaceSessionState(state)
        let greenhouse = try XCTUnwrap(
            scene.childNode(withName: ".//world-life-wl_market_greenhouse_r1") as? SKSpriteNode
        )
        let greenhouseAnchorCell = try XCTUnwrap(scene.childNode(withName: ".//cell-5-12"))
        XCTAssertEqual(greenhouse.position.y, greenhouseAnchorCell.position.y, accuracy: 0.001)
        let lake = try XCTUnwrap(
            scene.childNode(withName: ".//world-life-wl_market_scenic_lake_f00_r1") as? SKSpriteNode
        )
        XCTAssertNotNil(lake.action(forKey: "market-scenic-lake-flow"))

        let farBank = try XCTUnwrap(
            scene.childNode(withName: ".//world-life-wl_bank_north_01_r1") as? SKSpriteNode
        )
        let nearBank = try XCTUnwrap(
            scene.childNode(withName: ".//world-life-wl_bank_south_01_r1") as? SKSpriteNode
        )
        XCTAssertLessThan(farBank.size.width, nearBank.size.width)
        XCTAssertLessThan(farBank.zPosition, nearBank.zPosition)
        XCTAssertGreaterThan(farBank.colorBlendFactor, 0)
        XCTAssertGreaterThan(nearBank.colorBlendFactor, 0)

        let farWaterCell = try XCTUnwrap(scene.childNode(withName: ".//cell-0-2"))
        let middleWaterCell = try XCTUnwrap(scene.childNode(withName: ".//cell-0-1"))
        let nearWaterCell = try XCTUnwrap(scene.childNode(withName: ".//cell-0-0"))
        let farWater = try XCTUnwrap(farWaterCell.childNode(withName: "formal-water") as? SKSpriteNode)
        let middleWater = try XCTUnwrap(middleWaterCell.childNode(withName: "formal-water") as? SKSpriteNode)
        let nearWater = try XCTUnwrap(nearWaterCell.childNode(withName: "formal-water") as? SKSpriteNode)
        XCTAssertGreaterThan(farWater.colorBlendFactor, middleWater.colorBlendFactor)
        XCTAssertGreaterThan(nearWater.colorBlendFactor, middleWater.colorBlendFactor)
    }

    func testR22RetractsLakeAndAppliesOnlyTheFourMarkedFarmChanges() throws {
        let farmPlacements = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
        let farmLandscape = farmPlacements
            + WorldLifeCatalog.edgeBand(mapID: ContentID.farmHomestead)

        XCTAssertEqual(
            farmPlacements.filter { $0.kind == .flowerMeadow },
            [WorldLifePlacement(kind: .flowerMeadow, cell: GridPosition(x: 0, y: 8))]
        )
        XCTAssertFalse(farmLandscape.contains(WorldLifePlacement(
            kind: .shrub02,
            cell: GridPosition(x: 0, y: 8)
        )))
        XCTAssertEqual(
            Set(farmPlacements.filter { $0.kind == .sunflowerField }.map(\.cell)),
            Set([
                GridPosition(x: 5, y: 12),
                GridPosition(x: 12, y: 12),
                GridPosition(x: 14, y: 12),
            ])
        )
        XCTAssertFalse(farmLandscape.contains(WorldLifePlacement(
            kind: .shrub03,
            cell: GridPosition(x: 14, y: 13)
        )))
        XCTAssertFalse(farmLandscape.contains(WorldLifePlacement(
            kind: .flower04,
            cell: GridPosition(x: 15, y: 12)
        )))

        XCTAssertFalse(farmPlacements.contains(WorldLifePlacement(
            kind: .fenceHorizontal,
            cell: GridPosition(x: 8, y: 11)
        )))
        for retainedFence in [
            WorldLifePlacement(kind: .fenceCornerSW, cell: GridPosition(x: 6, y: 11)),
            WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 12)),
            WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 13)),
            WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 9, y: 13)),
        ] {
            XCTAssertTrue(farmPlacements.contains(retainedFence))
        }

        let bitmaps = try WorldLifeCatalog.marketScenicLakeFrames().map { image in
            try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        }
        XCTAssertEqual(bitmaps.count, 4)
        var alphaMasks: [[Bool]] = []
        for bitmap in bitmaps {
            XCTAssertEqual(bitmap.pixelsWide, 144)
            XCTAssertEqual(bitmap.pixelsHigh, 96)
            var opaqueXs: [Int] = []
            var opaqueYs: [Int] = []
            var alphaMask: [Bool] = []
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let isOpaque = try XCTUnwrap(
                        bitmap.colorAt(x: x, y: y)
                    ).alphaComponent > 0.5
                    alphaMask.append(isOpaque)
                    if isOpaque {
                        opaqueXs.append(x)
                        opaqueYs.append(y)
                    }
                }
            }
            alphaMasks.append(alphaMask)
            XCTAssertEqual(opaqueXs.min(), 1)
            XCTAssertEqual(opaqueXs.max(), 131)
            let minOpaqueY = try XCTUnwrap(opaqueYs.min())
            let maxOpaqueY = try XCTUnwrap(opaqueYs.max())
            XCTAssertEqual(maxOpaqueY - minOpaqueY + 1, 72)
        }
        let firstMask = try XCTUnwrap(alphaMasks.first)
        XCTAssertTrue(alphaMasks.dropFirst().allSatisfy { $0 == firstMask })
        XCTAssertEqual(WorldCatalog.creekMarket.waterCells.count, 54)
        XCTAssertEqual(FarmCultivationCatalog.rearCultivableCells, Set([
            GridPosition(x: 7, y: 12),
            GridPosition(x: 8, y: 12),
            GridPosition(x: 7, y: 13),
            GridPosition(x: 8, y: 13),
        ]))
    }

    func testIrregularBankInsetsStayPresentationOnlyOnAuthoritativeWater() throws {
        for mapID in [ContentID.farmHomestead, ContentID.creekMarket] {
            let map = try XCTUnwrap(WorldCatalog.maps[mapID])
            let water = Set(map.waterCells.map(\.cell))
            let banks = WorldLifeCatalog.placements(mapID: mapID).filter(\.kind.isShoreInset)
            XCTAssertTrue(banks.allSatisfy { water.contains($0.cell) })
        }

        let farmBanks = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            .filter(\.kind.isShoreInset)
        let marketBanks = WorldLifeCatalog.placements(mapID: ContentID.creekMarket)
            .filter(\.kind.isShoreInset)
        XCTAssertEqual(farmBanks.count, 3)
        XCTAssertEqual(marketBanks.count, 17)
        XCTAssertEqual(WorldCatalog.farmHomestead.waterCells.count, 6)
        XCTAssertEqual(WorldCatalog.creekMarket.waterCells.count, 54)
    }

    func testFenceCornersUseOrthogonalR2AssetsAndCorrectCompassPositions() {
        XCTAssertEqual(WorldLifeKind.fenceCornerNW.assetName, "wl_fence_corner_nw_r2")
        XCTAssertEqual(WorldLifeKind.fenceCornerNE.assetName, "wl_fence_corner_ne_r2")
        XCTAssertEqual(WorldLifeKind.fenceCornerSW.assetName, "wl_fence_corner_sw_r2")
        XCTAssertEqual(WorldLifeKind.fenceCornerSE.assetName, "wl_fence_corner_se_r2")

        let fences = WorldLifeCatalog.placements(mapID: ContentID.farmHomestead)
            .filter(\.kind.isFence)
        XCTAssertTrue(fences.contains(WorldLifePlacement(
            kind: .fenceCornerNW,
            cell: GridPosition(x: 0, y: 6)
        )))
        XCTAssertTrue(fences.contains(WorldLifePlacement(
            kind: .fenceCornerNE,
            cell: GridPosition(x: 6, y: 6)
        )))
        XCTAssertTrue(fences.contains(WorldLifePlacement(
            kind: .fenceCornerSW,
            cell: GridPosition(x: 0, y: 1)
        )))
        XCTAssertTrue(fences.contains(WorldLifePlacement(
            kind: .fenceCornerSE,
            cell: GridPosition(x: 6, y: 1)
        )))
    }

    func testAmbiguousFarmGatherablesUseReadableR2Assets() throws {
        let moss = RuntimeArtCatalog.descriptor(for: .gatherMossStone)
        let reed = RuntimeArtCatalog.descriptor(for: .gatherReedFiber)
        XCTAssertEqual(moss.assetID, "gather_moss_stone_r2")
        XCTAssertEqual(reed.assetID, "gather_reed_fiber_r2")
        for descriptor in [moss, reed] {
            let texture = try XCTUnwrap(
                PixelAssetStore.shared.texture(descriptor: descriptor),
                descriptor.assetID
            )
            XCTAssertEqual(Int(texture.size().width), 24, descriptor.assetID)
            XCTAssertEqual(Int(texture.size().height), 24, descriptor.assetID)
            XCTAssertEqual(texture.filteringMode, .nearest, descriptor.assetID)
        }
    }

    func testEveryTreeHasFlowersAndLowPlantingAtItsFootOnBothMaps() {
        for mapID in [ContentID.farmHomestead, ContentID.creekMarket] {
            let placements = WorldLifeCatalog.placements(mapID: mapID)
                + WorldLifeCatalog.edgeBand(mapID: mapID)
            let trees = placements.filter(\.kind.isTree)
            let lowPlanting = placements.filter { $0.kind.isFlower || $0.kind.isShrub }
            for tree in trees {
                let neighbors = lowPlanting.filter {
                    abs($0.cell.x - tree.cell.x) + abs($0.cell.y - tree.cell.y) == 1
                }
                XCTAssertFalse(neighbors.isEmpty, "bare tree foot: \(mapID) \(tree.kind)")
                XCTAssertTrue(neighbors.contains(where: \.kind.isFlower), "tree has no foot flowers: \(tree.kind)")
            }
        }
    }

    func testDecorationsDoNotOccupyGameplayCells() {
        for mapID in [ContentID.farmHomestead, ContentID.creekMarket] {
            let npcPositions = Set(
                WorldCatalog.npcs.values
                    .filter { $0.mapID == mapID }
                    .map(\.position)
            )
            let gatherPositions = Set(
                ProgressionCatalog.gatherNodeList
                    .filter { $0.mapID == mapID }
                    .map(\.position)
            )
            let placements = WorldLifeCatalog.placements(mapID: mapID)
                + WorldLifeCatalog.edgeBand(mapID: mapID)
            XCTAssertEqual(
                WorldLifeCatalog.conflicts(
                    mapID: mapID,
                    placements: placements,
                    npcPositions: npcPositions,
                    gatherPositions: gatherPositions
                ),
                [],
                mapID
            )
        }
    }

    func testNatureDisplayNamesArePlayerFacing() {
        for kind in WorldLifeKind.allCases where kind.isAnimal || kind.isTree || kind.isFlower || kind.isShrub {
            let name = WorldLifeCatalog.displayName(for: kind)
            XCTAssertFalse(name.hasPrefix("wl_"), kind.rawValue)
            XCTAssertFalse(name.isEmpty, kind.rawValue)
        }
    }
}
