import CoreGraphics
import Foundation
import SpriteKit

/// Semantic z-order shared by world presenters. Values are presentation-only
/// and never enter domain state or save data.
enum RuntimeRenderLayer: CGFloat, CaseIterable, Sendable {
    case ground = 0
    case groundDetail = 1
    case cropOrPropBase = 3
    case buildingBase = 5
    case actor = 10
    case buildingOccluder = 12
    case interactionFx = 20
    case worldPrompt = 30
    case hud = 100
    case debug = 200
}

enum RuntimeArtProvenance: String, Sendable {
    case n006Base = "n006_base"
    case n003ApprovedOverride = "n003_approved_override"
    case dec033ApprovedAddition = "dec033_approved_addition"
}

struct RuntimeFrameGrid: Equatable, Sendable {
    let columns: Int
    let rows: Int

    static let single = RuntimeFrameGrid(columns: 1, rows: 1)
    static let fourDirectionsFourFrames = RuntimeFrameGrid(columns: 4, rows: 4)
}

struct RuntimeSpriteAnchor: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat

    static let center = RuntimeSpriteAnchor(x: 0.5, y: 0.5)
    static let bottomCenter = RuntimeSpriteAnchor(x: 0.5, y: 0)
}

struct RuntimeArtDescriptor: Equatable, Sendable {
    let key: RuntimeArtKey
    let filename: String
    let nativeSize: CGSize
    let frameGrid: RuntimeFrameGrid
    let anchor: RuntimeSpriteAnchor
    let renderLayer: RuntimeRenderLayer
    let nearestNeighbor: Bool
    let fallbackAssetID: String?
    let provenance: RuntimeArtProvenance

    var assetID: String { String(filename.dropLast(4)) }
    var frameSize: CGSize {
        CGSize(
            width: nativeSize.width / CGFloat(frameGrid.columns),
            height: nativeSize.height / CGFloat(frameGrid.rows)
        )
    }
}

/// N-015 B2/B3/HUD keys that were previously planned. Building-layer keys are
/// deliberately absent: B4 remains blocked by the Product Owner topology choice,
/// so merely describing those filenames here must not make the audit call them integrated.
enum RuntimeArtKey: String, CaseIterable, Sendable {
    // 8 character walk sheets
    case charPlayerWalk = "char_player_walk"
    case charWaterApprenticeWalk = "char_water_apprentice_walk"
    case charSeedStewardWalk = "char_seed_steward_walk"
    case charCreekWardenWalk = "char_creek_warden_walk"
    case charNeighborHearsayWalk = "char_neighbor_hearsay_walk"
    case charNeighborStorytellerWalk = "char_neighbor_storyteller_walk"
    case charNeighborEvidenceWalk = "char_neighbor_evidence_walk"
    case charNeighborConsensusWalk = "char_neighbor_consensus_walk"

    // Player action sheets
    case charPlayerActionHoe = "char_player_action_hoe"
    case charPlayerActionWateringCan = "char_player_action_watering_can"
    case charPlayerActionHarvestGlove = "char_player_action_harvest_glove"

    // Terrain and water
    case tileWaterF00 = "tile_water_f00"
    case tileWaterF01 = "tile_water_f01"
    case tileWaterF02 = "tile_water_f02"
    case tileWaterF03 = "tile_water_f03"
    case tileWaterEdgeN = "tile_water_edge_n"
    case tileWaterEdgeE = "tile_water_edge_e"
    case tileWaterEdgeS = "tile_water_edge_s"
    case tileWaterEdgeW = "tile_water_edge_w"
    case tileWaterCornerNE = "tile_water_corner_ne"
    case tileWaterCornerSE = "tile_water_corner_se"
    case tileWaterCornerSW = "tile_water_corner_sw"
    case tileWaterCornerNW = "tile_water_corner_nw"
    case tileStonePath = "tile_stone_path"
    case tileCanalNS = "tile_canal_ns"
    case tileCanalEW = "tile_canal_ew"

    // Gatherables and the second placed-canal direction
    case gatherCreekWood = "gather_creek_wood"
    case gatherCreekWoodR2 = "gather_creek_wood_r2"
    case gatherMossStone = "gather_moss_stone"
    case gatherReedFiber = "gather_reed_fiber"
    case propCanalSegmentEW = "prop_canal_segment_ew"

    // World effects
    case fxTargetValidF00 = "fx_target_valid_f00"
    case fxTargetValidF01 = "fx_target_valid_f01"
    case fxTargetInvalidF00 = "fx_target_invalid_f00"
    case fxTargetInvalidF01 = "fx_target_invalid_f01"
    case fxWaterSplashF00 = "fx_water_splash_f00"
    case fxWaterSplashF01 = "fx_water_splash_f01"
    case fxWaterSplashF02 = "fx_water_splash_f02"
    case fxWaterSplashF03 = "fx_water_splash_f03"
    case fxHarvestF00 = "fx_harvest_f00"
    case fxHarvestF01 = "fx_harvest_f01"
    case fxHarvestF02 = "fx_harvest_f02"
    case fxHarvestF03 = "fx_harvest_f03"
    case fxCanalFlowF00 = "fx_canal_flow_f00"
    case fxCanalFlowF01 = "fx_canal_flow_f01"
    case fxCanalFlowF02 = "fx_canal_flow_f02"
    case fxCanalFlowF03 = "fx_canal_flow_f03"

    // Remaining formal HUD art
    case uiTime = "ui_time"
    case uiInteractBadge = "ui_interact_badge"
    case uiSlot = "ui_slot"
    case uiSlotSelected = "ui_slot_selected"
}

enum RuntimeArtCatalog {
    static let descriptors: [RuntimeArtKey: RuntimeArtDescriptor] = Dictionary(
        uniqueKeysWithValues: RuntimeArtKey.allCases.map { ($0, makeDescriptor($0)) }
    )

    static func descriptor(for key: RuntimeArtKey) -> RuntimeArtDescriptor {
        // The dictionary is constructed from all enum cases, so this is a safe
        // invariant fallback without an implicitly unwrapped optional.
        descriptors[key] ?? makeDescriptor(key)
    }

    static func walkKey(for characterID: String) -> RuntimeArtKey? {
        switch characterID {
        case PlayerVisualID.sprout: return .charPlayerWalk
        case ContentID.waterApprentice: return .charWaterApprenticeWalk
        case ContentID.seedSteward: return .charSeedStewardWalk
        case ContentID.creekWarden: return .charCreekWardenWalk
        case ContentID.neighborHearsay: return .charNeighborHearsayWalk
        case ContentID.neighborStoryteller: return .charNeighborStorytellerWalk
        case ContentID.neighborEvidence: return .charNeighborEvidenceWalk
        case ContentID.neighborConsensus: return .charNeighborConsensusWalk
        default: return nil
        }
    }

    static func playerActionKey(for event: String?) -> RuntimeArtKey? {
        switch event {
        case "tilled": return .charPlayerActionHoe
        case "watered": return .charPlayerActionWateringCan
        case "harvested": return .charPlayerActionHarvestGlove
        default: return nil
        }
    }

    static func gatherKey(for node: GatherNodeDefinition) -> RuntimeArtKey {
        let itemID = node.yields.first?.itemID
        switch itemID {
        case ContentID.mossStone: return .gatherMossStone
        case ContentID.reedFiber: return .gatherReedFiber
        default: return .gatherCreekWoodR2
        }
    }

    static func placedCanalKey(facing: Direction) -> RuntimeArtKey? {
        switch facing {
        case .left, .right: return .propCanalSegmentEW
        case .up, .down: return nil // Existing approved NS asset remains PixelAssetCatalog-owned.
        }
    }

    static let waterFrames: [RuntimeArtKey] = [.tileWaterF00, .tileWaterF01, .tileWaterF02, .tileWaterF03]
    static let targetValidFrames: [RuntimeArtKey] = [.fxTargetValidF00, .fxTargetValidF01]
    static let targetInvalidFrames: [RuntimeArtKey] = [.fxTargetInvalidF00, .fxTargetInvalidF01]
    static let waterSplashFrames: [RuntimeArtKey] = [.fxWaterSplashF00, .fxWaterSplashF01, .fxWaterSplashF02, .fxWaterSplashF03]
    static let harvestFrames: [RuntimeArtKey] = [.fxHarvestF00, .fxHarvestF01, .fxHarvestF02, .fxHarvestF03]
    static let canalFlowFrames: [RuntimeArtKey] = [.fxCanalFlowF00, .fxCanalFlowF01, .fxCanalFlowF02, .fxCanalFlowF03]

    private static func makeDescriptor(_ key: RuntimeArtKey) -> RuntimeArtDescriptor {
        let isSheet = key.rawValue.hasSuffix("_walk") || key.rawValue.contains("_action_")
        let isCharacter = key.rawValue.hasPrefix("char_")
        let isFX32 = key.rawValue.hasPrefix("fx_water_splash") || key.rawValue.hasPrefix("fx_harvest")
        let isFX = key.rawValue.hasPrefix("fx_")
        let layer: RuntimeRenderLayer = isCharacter ? .actor : (isFX ? .interactionFx : .groundDetail)
        let size: CGSize
        if isSheet {
            size = CGSize(width: 128, height: 192)
        } else if isFX32 {
            size = CGSize(width: 32, height: 32)
        } else {
            size = CGSize(width: 24, height: 24)
        }
        let anchor: RuntimeSpriteAnchor = isCharacter || key.rawValue.hasPrefix("gather_")
            ? .bottomCenter
            : .center
        let fallback: String?
        if key.rawValue.hasSuffix("_walk") || key.rawValue.contains("_action_") {
            fallback = "matching static character or char_player"
        } else if isFX {
            fallback = nil
        } else if key.rawValue.hasPrefix("tile_") {
            fallback = "tile_grass"
        } else if key == .propCanalSegmentEW {
            fallback = "prop_canal_segment_ns"
        } else if key.rawValue.hasPrefix("ui_") {
            fallback = "programmatic accessible HUD shape"
        } else {
            fallback = "programmatic visible glyph"
        }
        let filename: String
        switch key {
        case .gatherMossStone:
            filename = "gather_moss_stone_r2.png"
        case .gatherReedFiber:
            filename = "gather_reed_fiber_r2.png"
        default:
            filename = key.rawValue + ".png"
        }
        return RuntimeArtDescriptor(
            key: key,
            filename: filename,
            nativeSize: size,
            frameGrid: isSheet ? .fourDirectionsFourFrames : .single,
            anchor: anchor,
            renderLayer: layer,
            nearestNeighbor: true,
            fallbackAssetID: fallback,
            provenance: .n006Base
        )
    }
}
