import AppKit
import Foundation
import OSLog

/// N-019 presentation-only "world life" layer.
///
/// Sources (all already Product Owner approved):
/// - N-005 approved world-life candidate set (ambient animals, shrubs, flowers)
/// - N-006 runtime R0 candidate pack (same art at 24×24 / 32×48 runtime size)
/// - N-014 approved cat-bbq HD set (溪火猫食铺 + three cat staff, 2048×2048)
///
/// Everything here is decorative and NEVER written to save data, never blocks
/// movement, never changes NPC behaviour, and never replaces production PNGs.
/// Placements are deterministic constants; nothing is random at runtime.
enum WorldLifeKind: String, Sendable, CaseIterable {
    case bird = "wl_bird"
    case duck = "wl_duck"
    case frog = "wl_frog"
    case hedgehog = "wl_hedgehog"
    case rabbit = "wl_rabbit"
    case squirrel = "wl_squirrel"
    case flower01 = "wl_flower_01"
    case flower02 = "wl_flower_02"
    case flower03 = "wl_flower_03"
    case flower04 = "wl_flower_04"
    case shrub01 = "wl_shrub_01"
    case shrub02 = "wl_shrub_02"
    case shrub03 = "wl_shrub_03"
    case shrub04 = "wl_shrub_04"
    case treeMaple = "wl_tree_maple"
    case treeHoneyPear = "wl_tree_honey_pear"
    case treeMistPine = "wl_tree_mist_pine"
    case treeCreekWillow = "wl_tree_creek_willow"
    case farmHen = "wl_farm_hen"
    case farmCow = "wl_farm_cow"
    case farmSheep = "wl_farm_sheep"
    case farmGoat = "wl_farm_goat"
    case farmPig = "wl_farm_pig"
    case farmGoose = "wl_farm_goose"
    case catBbqShop = "wl_cat_bbq_shop"
    case catBlack = "wl_cat_black"
    case catCalico = "wl_cat_calico"
    case catRagdoll = "wl_cat_ragdoll"
    case gardenBed = "tile_tilled_watered_r2"
    case cropMistRadish = "crop_mist_radish_stage_3"
    case cropStreamLeaf = "crop_stream_leaf_stage_3"
    case cropAmberBean = "crop_amber_bean_stage_3"
    case cropBellBerry = "crop_bell_berry_stage_3"
    case cropHoneyMelon = "crop_honey_melon_stage_3"
    case fenceHorizontal = "wl_fence_horizontal_r1"
    case fenceVertical = "wl_fence_vertical_r1"
    case fenceCornerNW = "wl_fence_corner_nw_r1"
    case fenceCornerNE = "wl_fence_corner_ne_r1"
    case fenceCornerSW = "wl_fence_corner_sw_r1"
    case fenceCornerSE = "wl_fence_corner_se_r1"
    case fencePost = "wl_fence_post_r1"
    case pastureGrass01 = "wl_pasture_grass_01_r1"
    case pastureGrass02 = "wl_pasture_grass_02_r1"
    case pastureGrass03 = "wl_pasture_grass_03_r1"
    case pastureGrass04 = "wl_pasture_grass_04_r1"
    case farmMountainBackdrop = "wl_backdrop_farm_mountain_r1"
    case marketCreekValleyBackdrop = "wl_backdrop_market_creek_valley_r1"
    case riverStone01 = "wl_river_stone_01_r1"
    case riverStone02 = "wl_river_stone_02_r1"
    case riverStone03 = "wl_river_stone_03_r1"
    case riverStone04 = "wl_river_stone_04_r1"
    case flowerMeadow = "wl_flower_meadow_r1"
    case sunflowerField = "wl_sunflower_field_r1"
    case haystack = "wl_haystack_r1"
    case farmDiningSet = "wl_farm_dining_set_r1"
    case marketGreenhouse = "wl_market_greenhouse_r1"
    case marketScenicLake = "wl_market_scenic_lake_f00_r1"
    case scenicTilled = "tile_tilled_r2"
    case bankNorth01 = "wl_bank_north_01_r1"
    case bankNorth02 = "wl_bank_north_02_r1"
    case bankNorth03 = "wl_bank_north_03_r1"
    case bankNorth04 = "wl_bank_north_04_r1"
    case bankSouth01 = "wl_bank_south_01_r1"
    case bankSouth02 = "wl_bank_south_02_r1"
    case bankSouth03 = "wl_bank_south_03_r1"
    case bankSouth04 = "wl_bank_south_04_r1"

    var assetName: String {
        switch self {
        case .catBbqShop: return "wl_cat_bbq_shop_r3"
        case .catBlack: return "wl_cat_black_r2"
        case .catCalico: return "wl_cat_calico_r2"
        case .catRagdoll: return "wl_cat_ragdoll_r2"
        case .shrub01: return "wl_shrub_01_r2"
        case .shrub02: return "wl_shrub_02_r2"
        case .shrub03: return "wl_shrub_03_r2"
        case .shrub04: return "wl_shrub_04_r2"
        case .cropMistRadish: return "crop_mist_radish_stage_3_r3"
        case .cropStreamLeaf: return "crop_stream_leaf_stage_3_r3"
        case .cropAmberBean: return "crop_amber_bean_stage_3_r3"
        case .cropBellBerry: return "crop_bell_berry_stage_3_r3"
        case .cropHoneyMelon: return "crop_honey_melon_stage_3_r3"
        case .fenceCornerNW: return "wl_fence_corner_nw_r2"
        case .fenceCornerNE: return "wl_fence_corner_ne_r2"
        case .fenceCornerSW: return "wl_fence_corner_sw_r2"
        case .fenceCornerSE: return "wl_fence_corner_se_r2"
        case .farmMountainBackdrop: return "wl_backdrop_farm_north_horizon_r6"
        case .marketCreekValleyBackdrop: return "wl_backdrop_market_north_horizon_r6"
        case .flowerMeadow: return "wl_flower_meadow_r2"
        case .sunflowerField: return "wl_sunflower_field_r2"
        case .haystack: return "wl_haystack_r2"
        case .bankNorth01: return "wl_bank_north_01_r2"
        case .bankNorth02: return "wl_bank_north_02_r2"
        case .bankNorth03: return "wl_bank_north_03_r2"
        case .bankNorth04: return "wl_bank_north_04_r2"
        case .bankSouth01: return "wl_bank_south_01_r2"
        case .bankSouth02: return "wl_bank_south_02_r2"
        case .bankSouth03: return "wl_bank_south_03_r2"
        case .bankSouth04: return "wl_bank_south_04_r2"
        default: return rawValue
        }
    }

    var isCatStaff: Bool {
        switch self {
        case .catBlack, .catCalico, .catRagdoll: return true
        default: return false
        }
    }

    var isShrub: Bool {
        switch self {
        case .shrub01, .shrub02, .shrub03, .shrub04: return true
        default: return false
        }
    }

    var isGardenBed: Bool { self == .gardenBed }

    var isBackdrop: Bool {
        switch self {
        case .farmMountainBackdrop, .marketCreekValleyBackdrop:
            return true
        default: return false
        }
    }

    /// The single north-horizon strip stays behind paths, buildings and actors.
    /// It begins at the map boundary and grows only into the camera bleed, so
    /// the blue sky and distant ridge can never wrap around a house.
    var backdropLayerZ: CGFloat {
        switch self {
        case .farmMountainBackdrop, .marketCreekValleyBackdrop: return -4.45
        default: return -4.1
        }
    }

    var isFieldPatch: Bool {
        self == .flowerMeadow || self == .sunflowerField
    }

    var isHaystack: Bool { self == .haystack }

    var isDiningSet: Bool { self == .farmDiningSet }

    var isGreenhouse: Bool { self == .marketGreenhouse }

    var isScenicLake: Bool { self == .marketScenicLake }

    var isScenicTilled: Bool { self == .scenicTilled }

    var isShoreInset: Bool {
        switch self {
        case .bankNorth01, .bankNorth02, .bankNorth03, .bankNorth04,
             .bankSouth01, .bankSouth02, .bankSouth03, .bankSouth04:
            return true
        default:
            return false
        }
    }

    /// North-bank pieces sit against the visually distant bank of the creek.
    var isFarShoreInset: Bool {
        switch self {
        case .bankNorth01, .bankNorth02, .bankNorth03, .bankNorth04: return true
        default: return false
        }
    }

    /// South-bank pieces overlap the camera-facing bank and form foreground.
    var isNearShoreInset: Bool {
        switch self {
        case .bankSouth01, .bankSouth02, .bankSouth03, .bankSouth04: return true
        default: return false
        }
    }

    var isRiverStone: Bool {
        switch self {
        case .riverStone01, .riverStone02, .riverStone03, .riverStone04: return true
        default: return false
        }
    }

    var isFence: Bool {
        switch self {
        case .fenceHorizontal, .fenceVertical,
             .fenceCornerNW, .fenceCornerNE, .fenceCornerSW, .fenceCornerSE, .fencePost:
            return true
        default:
            return false
        }
    }

    var isPastureGround: Bool {
        switch self {
        case .pastureGrass01, .pastureGrass02, .pastureGrass03, .pastureGrass04:
            return true
        default:
            return false
        }
    }

    var isCropDisplay: Bool {
        switch self {
        case .cropMistRadish, .cropStreamLeaf, .cropAmberBean, .cropBellBerry, .cropHoneyMelon:
            return true
        default:
            return false
        }
    }

    var isFlower: Bool {
        switch self {
        case .flower01, .flower02, .flower03, .flower04: return true
        default: return false
        }
    }

    var isTree: Bool {
        switch self {
        case .treeMaple, .treeHoneyPear, .treeMistPine, .treeCreekWillow: return true
        default: return false
        }
    }

    var isAnimal: Bool {
        switch self {
        case .bird, .duck, .frog, .hedgehog, .rabbit, .squirrel,
             .farmHen, .farmCow, .farmSheep, .farmGoat, .farmPig, .farmGoose:
            return true
        default: return false
        }
    }
}

struct WorldLifePlacement: Equatable, Sendable {
    let kind: WorldLifeKind
    let cell: GridPosition
}

/// Deterministic decorative placements for N-019.
///
/// `placements(mapID:)` returns only decorations that sit on walkable,
/// non-path, non-building, non-gather, non-NPC, non-spawn/exit cells of the
/// current map contract. `edgeBand(mapID:)` returns the map-edge landscape
/// band (shrubs/flowers) used to finish the border so no raw background shows.
enum WorldLifeCatalog {
    private static let logger = Logger(subsystem: "com.brookseed.CreekSprout", category: "WorldLife")
    private static let directory = "Presentation/WorldLife"
    static let marketScenicLakeFrameAssetNames = (0..<4).map {
        String(format: "wl_market_scenic_lake_f%02d_r1", $0)
    }
    /// Presentation-only retreat: half a tile moves the greenhouse toward the
    /// horizon without changing its catalog cell, collision, or reachability.
    static let marketGreenhouseRetreatInTiles: CGFloat = 0.5
    private static let northBankCycle: [WorldLifeKind] = [
        .bankNorth01, .bankNorth02, .bankNorth03, .bankNorth04,
    ]
    private static let southBankCycle: [WorldLifeKind] = [
        .bankSouth01, .bankSouth02, .bankSouth03, .bankSouth04,
    ]

    private static func shorelinePlacements(
        northColumns: [Int],
        southColumns: [Int],
        northRow: Int,
        southRow: Int
    ) -> [WorldLifePlacement] {
        northColumns.enumerated().map { index, column in
            WorldLifePlacement(
                kind: northBankCycle[index % northBankCycle.count],
                cell: GridPosition(x: column, y: northRow)
            )
        } + southColumns.enumerated().map { index, column in
            WorldLifePlacement(
                kind: southBankCycle[(index + 2) % southBankCycle.count],
                cell: GridPosition(x: column, y: southRow)
            )
        }
    }

    // MARK: - Placement tables (hand-authored, deterministic)

    private static let farmPlacements: [WorldLifePlacement] = [
        // 灌木（西侧与东侧空地）
        WorldLifePlacement(kind: .shrub04, cell: GridPosition(x: 15, y: 8)),
        WorldLifePlacement(kind: .shrub01, cell: GridPosition(x: 6, y: 9)),
        WorldLifePlacement(kind: .shrub02, cell: GridPosition(x: 9, y: 10)),
        WorldLifePlacement(kind: .shrub04, cell: GridPosition(x: 11, y: 0)),
        // 花丛
        WorldLifePlacement(kind: .flower03, cell: GridPosition(x: 10, y: 0)),
        WorldLifePlacement(kind: .flower03, cell: GridPosition(x: 0, y: 10)),
        WorldLifePlacement(kind: .flower01, cell: GridPosition(x: 15, y: 10)),
        // 旧 bird/duck/frog/rabbit/squirrel/hedgehog 轮廓无法清晰辨认，
        // 已从玩家画面清除。农场只使用当前正式农场动物像素资源。
        WorldLifePlacement(kind: .farmHen, cell: GridPosition(x: 9, y: 2)),
        WorldLifePlacement(kind: .farmCow, cell: GridPosition(x: 15, y: 4)),
        WorldLifePlacement(kind: .farmSheep, cell: GridPosition(x: 14, y: 5)),
        WorldLifePlacement(kind: .farmGoat, cell: GridPosition(x: 15, y: 6)),
        // PO R20: one table and exactly three stools in the lower-left dining
        // clearing. The composite is presentation-only and leaves the exit.
        WorldLifePlacement(kind: .farmDiningSet, cell: GridPosition(x: 3, y: 0)),
    ]

    private static let farmTreePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .treeMaple, cell: GridPosition(x: 0, y: 9)),
        WorldLifePlacement(kind: .treeHoneyPear, cell: GridPosition(x: 15, y: 9)),
    ]

    /// The farm has one extra map row, so its horizon starts on that topmost
    /// unreachable row and then grows into the north bleed. This compensates
    /// for camera framing and keeps the visible ridge in the same screen band
    /// as the market without bringing it near any rear house.
    private static let farmNorthBackdropPlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .farmMountainBackdrop, cell: GridPosition(x: 7, y: 14)),
    ]

    /// The meadow remains decorative, but the four rear soil cells are now
    /// real farmland. R22 moves the meadow one cell toward the camera, removes
    /// the isolated fence beside the rear approach, and fills only the two PO
    /// marked horizon clearings with existing native sunflower patches.
    private static let farmRearFieldPlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .flowerMeadow, cell: GridPosition(x: 0, y: 8)),
        WorldLifePlacement(kind: .fenceCornerSW, cell: GridPosition(x: 6, y: 11)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 12)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 13)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 9, y: 13)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 5, y: 12)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 12, y: 12)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 14, y: 12)),
        WorldLifePlacement(kind: .haystack, cell: GridPosition(x: 11, y: 5)),
    ]

    /// Sparse creek-worn stones break the straight water-grid silhouette. They
    /// sit on the presentation layer only; water collision and topology remain
    /// fully authoritative in `WorldCatalog`.
    private static let farmRiverStonePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .riverStone01, cell: GridPosition(x: 12, y: 1)),
        WorldLifePlacement(kind: .riverStone02, cell: GridPosition(x: 14, y: 1)),
        WorldLifePlacement(kind: .riverStone03, cell: GridPosition(x: 13, y: 0)),
    ]

    private static let farmShorelinePlacements = shorelinePlacements(
        northColumns: [12, 14],
        southColumns: [13],
        northRow: 1,
        southRow: 0
    )

    /// The opening field is one full cell away from the central road. The
    /// east opening at (6, 3) faces that road; the two-cell north opening
    /// keeps the existing creek-wood gather point readable and reachable.
    private static let farmFencePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .fenceCornerSW, cell: GridPosition(x: 0, y: 1)),
        WorldLifePlacement(kind: .fenceCornerSE, cell: GridPosition(x: 6, y: 1)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 1, y: 1)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 2, y: 1)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 3, y: 1)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 4, y: 1)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 5, y: 1)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 0, y: 2)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 0, y: 3)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 0, y: 4)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 0, y: 5)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 2)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 4)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 6, y: 5)),
        WorldLifePlacement(kind: .fenceCornerNW, cell: GridPosition(x: 0, y: 6)),
        // x=3 remains open for the work-yard service spur.
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 4, y: 6)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 5, y: 6)),
        WorldLifePlacement(kind: .fenceCornerNE, cell: GridPosition(x: 6, y: 6)),
    ]

    /// The pasture is intentionally on the farm's east bank, in the narrow
    /// strip selected by the Product Owner. The east-side gap at (15, 5) is
    /// its entrance; the canal and authoritative road remain untouched.
    private static let farmPasturePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .pastureGrass01, cell: GridPosition(x: 14, y: 3)),
        WorldLifePlacement(kind: .pastureGrass02, cell: GridPosition(x: 15, y: 3)),
        WorldLifePlacement(kind: .pastureGrass03, cell: GridPosition(x: 14, y: 4)),
        WorldLifePlacement(kind: .pastureGrass04, cell: GridPosition(x: 15, y: 4)),
        WorldLifePlacement(kind: .pastureGrass02, cell: GridPosition(x: 14, y: 5)),
        WorldLifePlacement(kind: .pastureGrass01, cell: GridPosition(x: 15, y: 5)),
        WorldLifePlacement(kind: .pastureGrass04, cell: GridPosition(x: 14, y: 6)),
        WorldLifePlacement(kind: .pastureGrass03, cell: GridPosition(x: 15, y: 6)),
        WorldLifePlacement(kind: .pastureGrass01, cell: GridPosition(x: 14, y: 7)),
        WorldLifePlacement(kind: .pastureGrass02, cell: GridPosition(x: 15, y: 7)),
        WorldLifePlacement(kind: .fenceCornerSW, cell: GridPosition(x: 14, y: 3)),
        WorldLifePlacement(kind: .fenceCornerSE, cell: GridPosition(x: 15, y: 3)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 14, y: 4)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 14, y: 5)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 14, y: 6)),
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 15, y: 4)),
        // (15, 5) is the deliberate entrance.
        WorldLifePlacement(kind: .fenceVertical, cell: GridPosition(x: 15, y: 6)),
        WorldLifePlacement(kind: .fenceCornerNW, cell: GridPosition(x: 14, y: 7)),
        WorldLifePlacement(kind: .fenceCornerNE, cell: GridPosition(x: 15, y: 7)),
    ]

    private static let marketTreePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .treeMistPine, cell: GridPosition(x: 0, y: 9)),
        WorldLifePlacement(kind: .treeCreekWillow, cell: GridPosition(x: 17, y: 9)),
    ]

    /// The market uses the same sharp sky-and-ridge horizon in its three north
    /// bleed rows. Its low central saddle preserves the north visual corridor.
    private static let marketNorthBackdropPlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .marketCreekValleyBackdrop, cell: GridPosition(x: 8, y: 14)),
    ]

    private static let marketRiverStonePlacements: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .riverStone02, cell: GridPosition(x: 1, y: 2)),
        WorldLifePlacement(kind: .riverStone04, cell: GridPosition(x: 5, y: 2)),
        WorldLifePlacement(kind: .riverStone01, cell: GridPosition(x: 13, y: 2)),
        WorldLifePlacement(kind: .riverStone03, cell: GridPosition(x: 16, y: 2)),
    ]

    private static let marketShorelinePlacements = shorelinePlacements(
        northColumns: [0, 1, 4, 5, 6, 10, 11, 14, 17],
        southColumns: [2, 3, 7, 8, 9, 12, 15, 16],
        northRow: 2,
        southRow: 0
    )

    private static let marketPlacements: [WorldLifePlacement] = [
        // R20 upper-scene additions. Both are visual-only canvases: the long
        // greenhouse stops before the central exit axis, and the animated
        // irregular lake occupies the east scenic strip without water collision.
        WorldLifePlacement(kind: .marketGreenhouse, cell: GridPosition(x: 5, y: 12)),
        WorldLifePlacement(kind: .marketScenicLake, cell: GridPosition(x: 15, y: 11)),
        // 入口右侧独立猫食铺：72×72 → 3×3 格。入口中线 x=8...9
        // 完全留空，右侧与巡护亭之间保留 x=13 的景观缓冲格。
        WorldLifePlacement(kind: .catBbqShop, cell: GridPosition(x: 11, y: 10)),
        // 黑猫站在店铺左前侧；店铺右侧与巡护亭之间仍保留原 NPC。
        WorldLifePlacement(kind: .catBlack, cell: GridPosition(x: 10, y: 9)),
        WorldLifePlacement(kind: .catCalico, cell: GridPosition(x: 13, y: 6)),
        WorldLifePlacement(kind: .catRagdoll, cell: GridPosition(x: 10, y: 6)),
        // 新原生像素鸟兽；旧 bird/duck/frog/rabbit/squirrel 占位不再用于集市。
        WorldLifePlacement(kind: .farmHen, cell: GridPosition(x: 16, y: 5)),
        WorldLifePlacement(kind: .farmGoose, cell: GridPosition(x: 1, y: 6)),
        WorldLifePlacement(kind: .farmPig, cell: GridPosition(x: 12, y: 3)),
        // 入口左前方五格湿土展示圃：格位、湿土和占地保持不变；
        // R21 仅把五种成熟作物的视觉逐格替换成四类原生花丛。
        WorldLifePlacement(kind: .gardenBed, cell: GridPosition(x: 4, y: 6)),
        WorldLifePlacement(kind: .gardenBed, cell: GridPosition(x: 5, y: 6)),
        WorldLifePlacement(kind: .gardenBed, cell: GridPosition(x: 6, y: 6)),
        WorldLifePlacement(kind: .gardenBed, cell: GridPosition(x: 3, y: 7)),
        WorldLifePlacement(kind: .gardenBed, cell: GridPosition(x: 4, y: 7)),
        WorldLifePlacement(kind: .flower01, cell: GridPosition(x: 4, y: 6)),
        WorldLifePlacement(kind: .flower02, cell: GridPosition(x: 5, y: 6)),
        WorldLifePlacement(kind: .flower03, cell: GridPosition(x: 6, y: 6)),
        WorldLifePlacement(kind: .flower04, cell: GridPosition(x: 3, y: 7)),
        WorldLifePlacement(kind: .flower02, cell: GridPosition(x: 4, y: 7)),
        // 手工景观节点：种植圃收边、猫店与巡护亭之间的软隔断、集市中段花簇。
        WorldLifePlacement(kind: .flower02, cell: GridPosition(x: 5, y: 11)),
        WorldLifePlacement(kind: .flower03, cell: GridPosition(x: 12, y: 7)),
        // 左屋右侧人物身后的花田；左下向日葵田与河岸之间保留原栅栏。
        // 东侧按 Product Owner 蓝框复用同一 48×36 向日葵簇，以相同
        // 单位密度铺满 x=14.5...18.5 的展示带；不新增道路或栅栏。
        WorldLifePlacement(kind: .flowerMeadow, cell: GridPosition(x: 5, y: 10)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 6, y: 3)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 15, y: 3)),
        WorldLifePlacement(kind: .sunflowerField, cell: GridPosition(x: 17, y: 3)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 6, y: 3)),
        WorldLifePlacement(kind: .fenceHorizontal, cell: GridPosition(x: 7, y: 3)),
        // Every landmark tree receives a deliberate flower-and-shrub foot.
        WorldLifePlacement(kind: .flower02, cell: GridPosition(x: 0, y: 8)),
        WorldLifePlacement(kind: .flower04, cell: GridPosition(x: 17, y: 8)),
    ]

    /// Hand-authored market entrance landscape. Clusters frame the arrival
    /// path and landmarks while leaving deliberate breathing room; the old
    /// every-cell hedge row made the plants read as a dead repeating border.
    private static let marketEdgeLandscape: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .shrub01, cell: GridPosition(x: 0, y: 3)),
        WorldLifePlacement(kind: .flower02, cell: GridPosition(x: 0, y: 4)),
        WorldLifePlacement(kind: .shrub02, cell: GridPosition(x: 0, y: 10)),
        WorldLifePlacement(kind: .flower01, cell: GridPosition(x: 0, y: 11)),
        WorldLifePlacement(kind: .shrub03, cell: GridPosition(x: 0, y: 12)),
        WorldLifePlacement(kind: .shrub01, cell: GridPosition(x: 17, y: 10)),
        // R21: the former (2,13) shrub and (3,13) flower rendered above the
        // greenhouse's left roof because landscape uses a higher world z.
        // Removing only those two decorations exposes the normal grass tile
        // and restores the complete greenhouse silhouette.
    ]

    /// Farm north edge uses two hand-authored side clusters. The previous
    /// generated every-cell row floated above the ridge like a decoration bar.
    private static let farmEdgeLandscape: [WorldLifePlacement] = [
        WorldLifePlacement(kind: .shrub01, cell: GridPosition(x: 0, y: 12)),
        WorldLifePlacement(kind: .flower03, cell: GridPosition(x: 1, y: 12)),
        WorldLifePlacement(kind: .shrub02, cell: GridPosition(x: 0, y: 13)),
        WorldLifePlacement(kind: .flower01, cell: GridPosition(x: 1, y: 14)),
        // R22 reserves x=11...15, y=12...13 for a continuous sunflower
        // horizon, so the former isolated shrub and flower are removed.
        WorldLifePlacement(kind: .shrub04, cell: GridPosition(x: 15, y: 14)),
    ]

    /// Edge landscape band: fills environment-boundary cells with a dense
    /// shrub/hedge look so no flat background colour is visible at map edges.
    /// Building canvases already cover part of the farm north band; those
    /// cells are skipped by the caller's mask.
    static func edgeBand(mapID: String) -> [WorldLifePlacement] {
        guard WorldCatalog.maps[mapID] != nil else { return [] }
        if mapID == ContentID.creekMarket { return marketEdgeLandscape }
        return mapID == ContentID.farmHomestead ? farmEdgeLandscape : []
    }

    static func placements(mapID: String) -> [WorldLifePlacement] {
        switch mapID {
        case ContentID.farmHomestead:
            return farmPlacements + farmTreePlacements + farmFencePlacements
                + farmPasturePlacements + farmNorthBackdropPlacements + farmRiverStonePlacements
                + farmRearFieldPlacements + farmShorelinePlacements
        case ContentID.creekMarket:
            return marketPlacements + marketTreePlacements + marketNorthBackdropPlacements
                + marketRiverStonePlacements + marketShorelinePlacements
        default: return []
        }
    }

    /// Complete N-014 cat-shop presentation set, in player-facing tour order.
    static let catBbqTourKinds: [WorldLifeKind] = [
        .catBbqShop, .catBlack, .catCalico, .catRagdoll,
    ]

    /// Presentation-only visit zone in front of the market shop canvas.
    /// It changes neither collision nor map topology and is never persisted.
    static func isNearCatBbqShop(mapID: String, position: GridPosition) -> Bool {
        guard mapID == ContentID.creekMarket else { return false }
        return (9...13).contains(position.x) && (7...12).contains(position.y)
    }

    private static func treePlacements(mapID: String) -> [WorldLifePlacement] {
        switch mapID {
        case ContentID.farmHomestead: return farmTreePlacements
        case ContentID.creekMarket: return marketTreePlacements
        default: return []
        }
    }

    // MARK: - Validation helpers (used by focused tests)

    /// Every placement must be on a walkable, non-occupied cell so the
    /// decorative layer never visually collides with gameplay affordances.
    static func conflicts(
        mapID: String,
        placements: [WorldLifePlacement],
        npcPositions: Set<GridPosition>,
        gatherPositions: Set<GridPosition>
    ) -> [String] {
        guard let map = WorldCatalog.maps[mapID] else { return ["unknown map \(mapID)"] }
        var problems: [String] = []
        for placement in placements {
            let cell = placement.cell
            if placement.kind.isBackdrop {
                // Wide north-edge panoramas are visual-only canvases. Their
                // anchor cell is used for vertical placement, not occupancy.
                continue
            }
            let isIntentionalWaterDetail = (placement.kind.isRiverStone || placement.kind.isShoreInset)
                && map.waterCells.contains(where: { $0.cell == cell })
            if placement.kind == .catBbqShop {
                // 画布级检查：R3 的 3×3 格画布必须在当前地图画布内。
                let canvasX = cell.x - 1...cell.x + 1
                let canvasY = cell.y...cell.y + 2
                if canvasX.lowerBound < 0 || canvasX.upperBound >= map.columns
                    || canvasY.upperBound >= map.rows {
                    problems.append("catBbqShop canvas out of map bounds (anchor \(cell))")
                }
                continue
            }
            if !map.contains(cell) {
                problems.append("\(placement.kind.rawValue) out of bounds \(cell)")
                continue
            }
            let isIntentionalLandscapeBoundary = map.environmentBoundaryCells.contains(cell)
                && (placement.kind.isTree || placement.kind.isShrub
                    || placement.kind.isFlower || placement.kind.isFence
                    || placement.kind.isFieldPatch || placement.kind.isScenicTilled)
            if map.isBlocked(cell) && !isIntentionalLandscapeBoundary && !isIntentionalWaterDetail {
                problems.append("\(placement.kind.rawValue) on blocked cell \(cell)")
            }
            if WorldVisualCatalog.isStonePath(cell, mapID: mapID) && !placement.kind.isPastureGround {
                problems.append("\(placement.kind.rawValue) on path \(cell)")
            }
            if npcPositions.contains(cell) {
                problems.append("\(placement.kind.rawValue) on NPC \(cell)")
            }
            if gatherPositions.contains(cell) {
                problems.append("\(placement.kind.rawValue) on gather \(cell)")
            }
            if map.exits.contains(where: { $0.cell == cell }) {
                problems.append("\(placement.kind.rawValue) on exit \(cell)")
            }
            if map.spawns.contains(where: { $0.position == cell }) {
                problems.append("\(placement.kind.rawValue) on spawn \(cell)")
            }
        }
        return problems
    }

    // MARK: - Asset loading

    static func image(for kind: WorldLifeKind, bundle: Bundle = .main) -> NSImage? {
        let url = bundle.url(
            forResource: kind.assetName,
            withExtension: "png",
            subdirectory: directory
        ) ?? bundle.url(forResource: kind.assetName, withExtension: "png")
        guard let url, let image = NSImage(contentsOf: url) else {
            logger.error("Missing world-life resource: \(kind.assetName, privacy: .public)")
            return nil
        }
        return image
    }

    static func marketScenicLakeFrames(bundle: Bundle = .main) -> [NSImage] {
        marketScenicLakeFrameAssetNames.compactMap { assetName in
            let url = bundle.url(
                forResource: assetName,
                withExtension: "png",
                subdirectory: directory
            ) ?? bundle.url(forResource: assetName, withExtension: "png")
            guard let url, let image = NSImage(contentsOf: url) else {
                logger.error("Missing scenic lake frame: \(assetName, privacy: .public)")
                return nil
            }
            return image
        }
    }

    /// HD cat-bbq set (N-014 approved 2048×2048 displays).
    static func catBbqHDAssetName(for kind: WorldLifeKind) -> String? {
        switch kind {
        case .catBbqShop: return "cat_bbq_shop_display_2048"
        case .catBlack: return "cat_black_fullbody_2048"
        case .catCalico: return "cat_calico_fullbody_2048"
        case .catRagdoll: return "cat_ragdoll_fullbody_2048"
        default: return nil
        }
    }

    static func catBbqHDImage(for kind: WorldLifeKind, bundle: Bundle = .main) -> NSImage? {
        guard let assetName = catBbqHDAssetName(for: kind) else { return nil }
        let url = bundle.url(
            forResource: assetName,
            withExtension: "png",
            subdirectory: directory
        ) ?? bundle.url(forResource: assetName, withExtension: "png")
        guard let url, let image = NSImage(contentsOf: url) else {
            logger.error("Missing cat-bbq HD resource: \(assetName, privacy: .public)")
            return nil
        }
        return image
    }

    static let catBbqDisplayName: [WorldLifeKind: String] = [
        .catBbqShop: "溪火猫食铺",
        .catBlack: "酷黑猫",
        .catCalico: "漂亮三花",
        .catRagdoll: "白色布偶",
    ]

    static let natureDisplayName: [WorldLifeKind: String] = [
        .bird: "溪蓝雀",
        .duck: "青溪鸭",
        .frog: "苔斑蛙",
        .hedgehog: "苔背刺猬",
        .rabbit: "溪原兔",
        .squirrel: "铜尾松鼠",
        .flower01: "溪白雏菊",
        .flower02: "雾铃花",
        .flower03: "铜阳万寿菊",
        .flower04: "溪星野花",
        .shrub01: "苔叶灌木",
        .shrub02: "柳叶灌木",
        .shrub03: "雾花灌木",
        .shrub04: "琥珀果灌木",
        .treeMaple: "溪枫",
        .treeHoneyPear: "蜜梨树",
        .treeMistPine: "雾针松",
        .treeCreekWillow: "溪柳",
        .farmHen: "谷羽鸡",
        .farmCow: "木蜜奶牛",
        .farmSheep: "雾绒羊",
        .farmGoat: "石铃山羊",
        .farmPig: "铜鼻猪",
        .farmGoose: "溪岸鹅",
    ]

    static func displayName(for kind: WorldLifeKind) -> String {
        catBbqDisplayName[kind] ?? natureDisplayName[kind] ?? kind.rawValue
    }

    static func livestockDefinitionID(for kind: WorldLifeKind) -> String? {
        switch kind {
        case .farmCow: return ContentID.livestockCow
        case .farmSheep: return ContentID.livestockSheep
        case .farmGoat: return ContentID.livestockGoat
        default: return nil
        }
    }

    static func shouldRender(_ kind: WorldLifeKind, livestock: LivestockState) -> Bool {
        guard let definitionID = livestockDefinitionID(for: kind) else {
            return true
        }
        return livestock.contains(definitionID: definitionID)
    }
}
