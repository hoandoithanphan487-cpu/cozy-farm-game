import SpriteKit

/// Explicit filenames keep the B4 consumer surface auditable without teaching
/// the static audit to evaluate string interpolation in WorldCatalog.
enum BuildingRuntimeArtKey: String, CaseIterable, Sendable {
    case farmHouseBase = "building_farm_house_base.png"
    case farmHouseStructure = "building_farm_house_structure.png"
    case farmHouseRoof = "building_farm_house_roof.png"
    case farmHouseDetail = "building_farm_house_detail.png"
    case farmHouseInteraction = "building_farm_house_interaction.png"
    case farmHouseStateFX = "building_farm_house_state_fx.png"
    case farmSluiceBase = "building_farm_sluice_base.png"
    case farmSluiceStructure = "building_farm_sluice_structure.png"
    case farmSluiceRoof = "building_farm_sluice_roof.png"
    case farmSluiceDetail = "building_farm_sluice_detail.png"
    case farmSluiceInteraction = "building_farm_sluice_interaction.png"
    case farmSluiceStateFX = "building_farm_sluice_state_fx.png"
    case marketWharfBase = "building_market_wharf_base.png"
    case marketWharfStructure = "building_market_wharf_structure.png"
    case marketWharfRoof = "building_market_wharf_roof.png"
    case marketWharfDetail = "building_market_wharf_detail.png"
    case marketWharfInteraction = "building_market_wharf_interaction.png"
    case marketWharfStateFX = "building_market_wharf_state_fx.png"
    case marketSeedShedBase = "building_market_seed_shed_base.png"
    case marketSeedShedStructure = "building_market_seed_shed_structure.png"
    case marketSeedShedRoof = "building_market_seed_shed_roof.png"
    case marketSeedShedDetail = "building_market_seed_shed_detail.png"
    case marketSeedShedInteraction = "building_market_seed_shed_interaction.png"
    case marketSeedShedStateFX = "building_market_seed_shed_state_fx.png"
    case marketWardenPostBase = "building_market_warden_post_base.png"
    case marketWardenPostStructure = "building_market_warden_post_structure.png"
    case marketWardenPostRoof = "building_market_warden_post_roof.png"
    case marketWardenPostDetail = "building_market_warden_post_detail.png"
    case marketWardenPostInteraction = "building_market_warden_post_interaction.png"
    case marketWardenPostStateFX = "building_market_warden_post_state_fx.png"
}

/// Composes a production building from its six transparent B4 runtime layers.
/// Collision and interaction remain authoritative in `MapDefinition`.
enum BuildingVisualPresenter {
    static func makeNode(
        building: MapBuildingDefinition,
        cellSize: CGFloat,
        playerPosition: GridPosition,
        watershedRestored: Bool,
        assetStore: PixelAssetStore = .shared
    ) -> SKNode {
        let root = SKNode()
        root.name = "building-\(building.id)"
        let scale = PixelMetrics.integerScale(cellSize: cellSize)
        if building.id == "brookseed.landmark.market_wharf",
           let texture = assetStore.texture(named: "building_market_wharf_r2") {
            // N-019 R6: the original B4 wharf layers depict an oversized crop
            // bed. Keep those packaged as audited fallbacks, but use one compact
            // versioned sluice sprite so the landmark reads as waterworks and
            // its bottom-centred mouth aligns with the creek connector.
            let sprite = SKSpriteNode(
                texture: texture,
                size: CGSize(width: 144 * scale, height: 96 * scale)
            )
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.texture?.filteringMode = .nearest
            sprite.name = "building-layer-wharf-r2"
            sprite.zPosition = RuntimeRenderLayer.buildingBase.rawValue
            root.addChild(sprite)
            root.position = CGPoint(
                x: CGFloat(building.renderOffsetX) * scale,
                y: CGFloat(building.renderOffsetY) * scale
            )
            return root
        }
        for layer in building.layers.sorted(by: { $0.order < $1.order }) {
            guard let texture = assetStore.texture(named: layer.assetID) else { continue }
            let sprite = SKSpriteNode(
                texture: texture,
                size: CGSize(
                    width: CGFloat(layer.nativeWidth) * scale,
                    height: CGFloat(layer.nativeHeight) * scale
                )
            )
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.texture?.filteringMode = .nearest
            sprite.name = "building-layer-\(layer.semantic)"
            sprite.zPosition = RuntimeRenderLayer.buildingBase.rawValue + CGFloat(layer.order) * 0.1
            if layer.semantic == "roof", building.occlusionCells.contains(playerPosition) {
                sprite.zPosition = RuntimeRenderLayer.buildingOccluder.rawValue
            }
            if layer.semantic == "state_fx" {
                let active = building.id == "brookseed.landmark.farm_sluice"
                    ? watershedRestored
                    : building.id == "brookseed.landmark.market_wharf"
                sprite.alpha = active ? 0.72 : 0.18
            }
            root.addChild(sprite)
        }
        root.position = CGPoint(
            x: CGFloat(building.renderOffsetX) * scale,
            y: CGFloat(building.renderOffsetY) * scale
        )
        return root
    }
}
