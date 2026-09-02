import AppKit
import os
import SpriteKit

/// Pixel-art native sizes from PRD 7.1. Scaling must stay integer.
enum PixelMetrics {
    static let tileNative: CGFloat = 24
    static let cropNative = CGSize(width: 32, height: 32)
    static let characterNative = CGSize(width: 32, height: 48)

    /// Snap a raw cell size down to a multiple of 24 so tiles fill the cell
    /// without half-pixel interpolation.
    static func snappedCellSize(fitting raw: CGFloat) -> CGFloat {
        max(tileNative, floor(raw / tileNative) * tileNative)
    }

    /// Shared integer zoom: `cellSize / 24`. Always ≥ 1.
    static func integerScale(cellSize: CGFloat) -> CGFloat {
        max(1, floor(cellSize / tileNative))
    }

    static func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x.rounded(), y: point.y.rounded())
    }

    static func snap(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.rounded(), height: size.height.rounded())
    }
}

/// Filenames match `Assets/generation-log.md` (no extension).
enum PixelAssetKind: String, Equatable, CaseIterable, Sendable {
    case charPlayer = "char_player"
    case charWaterApprentice = "char_water_apprentice"
    case charSeedSteward = "char_seed_steward"
    case charCreekWarden = "char_creek_warden"
    case charNeighborHearsay = "char_neighbor_hearsay"
    case charNeighborEvidence = "char_neighbor_evidence"
    case charNeighborConsensus = "char_neighbor_consensus"
    case charNeighborStoryteller = "char_neighbor_storyteller"
    case cropMistRadish = "crop_mist_radish"
    case cropStreamLeaf = "crop_stream_leaf"
    case cropAmberBean = "crop_amber_bean"
    case cropBellBerry = "crop_bell_berry"
    case cropHoneyMelon = "crop_honey_melon"
    case tileGrass = "tile_grass"
    case tileGrassA = "tile_grass_a"
    case tileGrassB = "tile_grass_b"
    case tileGrassC = "tile_grass_c"
    case tileTilled = "tile_tilled"
    case tileTilledWatered = "tile_tilled_watered"
    case tileTilledR2 = "tile_tilled_r2"
    case tileTilledWateredR2 = "tile_tilled_watered_r2"
    case tileWaterEdge = "tile_water_edge"

    var fileName: String { rawValue + ".png" }

    var nativeSize: CGSize {
        switch self {
        case .charPlayer, .charWaterApprentice, .charSeedSteward, .charCreekWarden,
             .charNeighborHearsay, .charNeighborEvidence, .charNeighborConsensus,
             .charNeighborStoryteller:
            return PixelMetrics.characterNative
        case .cropMistRadish, .cropStreamLeaf, .cropAmberBean, .cropBellBerry, .cropHoneyMelon:
            return PixelMetrics.cropNative
        case .tileGrass, .tileGrassA, .tileGrassB, .tileGrassC,
             .tileTilled, .tileTilledWatered, .tileTilledR2,
             .tileTilledWateredR2, .tileWaterEdge:
            return CGSize(width: PixelMetrics.tileNative, height: PixelMetrics.tileNative)
        }
    }

    var isCharacter: Bool {
        switch self {
        case .charPlayer, .charWaterApprentice, .charSeedSteward, .charCreekWarden,
             .charNeighborHearsay, .charNeighborEvidence, .charNeighborConsensus,
             .charNeighborStoryteller:
            return true
        default:
            return false
        }
    }
}

/// NPC / crop / terrain ID → pixel filename. Missing mappings fall back to procedural.
enum PixelAssetCatalog {
    static func characterKind(for characterID: String) -> PixelAssetKind? {
        switch characterID {
        case PlayerVisualID.sprout: return .charPlayer
        case ContentID.waterApprentice: return .charWaterApprentice
        case ContentID.seedSteward: return .charSeedSteward
        case ContentID.creekWarden: return .charCreekWarden
        case ContentID.neighborHearsay: return .charNeighborHearsay
        case ContentID.neighborEvidence: return .charNeighborEvidence
        case ContentID.neighborConsensus: return .charNeighborConsensus
        case ContentID.neighborStoryteller: return .charNeighborStoryteller
        default: return nil
        }
    }

    /// `brookseed.crop.mist_radish` → `crop_mist_radish`. Unknown slugs return nil.
    static func cropKind(for cropID: String) -> PixelAssetKind? {
        guard let slug = cropID.split(separator: ".").last else { return nil }
        return PixelAssetKind(rawValue: "crop_\(slug)")
    }

    static func tileKind(
        prepared: Bool,
        watered: Bool,
        isWaterEdge: Bool,
        position: GridPosition
    ) -> PixelAssetKind {
        if isWaterEdge { return .tileWaterEdge }
        if prepared { return watered ? .tileTilledWateredR2 : .tileTilledR2 }
        switch abs(position.x * 31 + position.y * 17) % 4 {
        case 1: return .tileGrassA
        case 2: return .tileGrassB
        case 3: return .tileGrassC
        default: return .tileGrass
        }
    }

    static func cropStageAssetID(cropID: String, stage: Int, readyToHarvest: Bool) -> String? {
        guard let slug = cropID.split(separator: ".").last,
              PixelAssetKind(rawValue: "crop_\(slug)") != nil else { return nil }
        let visualStage = readyToHarvest ? 3 : min(max(stage, 0), 2)
        // R9 replaces the mixed-source growth art with one coherent atlas.
        // Earlier N-006/R6 assets remain packaged as audited fallbacks.
        return "crop_\(slug)_stage_\(visualStage)_r3"
    }

    static func placedObjectAssetID(for definitionID: String) -> String? {
        switch definitionID {
        case ContentID.woodhoneyHearthObject: return "prop_woodhoney_hearth_r2"
        case ContentID.woodenCrateObject: return "prop_wooden_crate_r2"
        case ContentID.stonePathObject: return "prop_stone_path"
        case ContentID.compostRackObject: return "prop_compost_bin_r2"
        case ContentID.canalSegmentObject: return "prop_canal_segment_ns"
        case ContentID.rainBarrelObject: return "prop_rain_barrel_r2"
        default: return nil
        }
    }
}

/// Loads PNGs into cached `SKTexture`s with nearest-neighbor filtering.
///
/// Loading order:
/// 1. N-019 display-R2 override for the world-surface IDs listed below
/// 2. App / test-host bundle subdirectory `Assets/`
/// 3. Bundle root (`char_….png`)
/// 4. Source-tree `CreekSprout/Assets/` via `#filePath` (XCTest without resource copy)
///
/// Uses `NSImage(contentsOf:)` + `SKTexture(image:)` so `filteringMode` is set
/// before any SpriteKit default linear sampler can blur the texels.
final class PixelAssetStore {
    static let shared = PixelAssetStore()

    /// Presentation-only replacements for the surfaces called out in N-019.
    /// Stable gameplay IDs stay unchanged; the original N-015 files remain
    /// intact as audited fallbacks.
    static let displayR2OverrideAssetIDs: Set<String> = [
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

    /// R3 replaces only the four ambiguous grass surfaces. The prior R2
    /// files remain packaged and are used if an R3 resource is unavailable.
    static let displayR3OverrideAssetIDs: Set<String> = [
        "tile_grass", "tile_grass_a", "tile_grass_b", "tile_grass_c",
    ]

    /// R4 is the N-019 natural-landscape pass: rounded stepping stones and a
    /// four-frame directional creek. R2 remains the immediate safe fallback.
    static let displayR4OverrideAssetIDs: Set<String> = [
        "tile_stone_path",
        "tile_water_f00", "tile_water_f01", "tile_water_f02", "tile_water_f03",
    ]

    static func displayR4AssetID(for assetID: String) -> String? {
        displayR4OverrideAssetIDs.contains(assetID) ? "r4_\(assetID)" : nil
    }

    static func displayR3AssetID(for assetID: String) -> String? {
        displayR3OverrideAssetIDs.contains(assetID) ? "r3_\(assetID)" : nil
    }

    static func displayR2AssetID(for assetID: String) -> String? {
        displayR2OverrideAssetIDs.contains(assetID) ? "r2_\(assetID)" : nil
    }

    private var cache: [String: SKTexture] = [:]
    private(set) var missingRequests: [String] = []
    private(set) var validationFailures: [String] = []
    private let logger = Logger(subsystem: "com.brookseed.CreekSprout", category: "PixelAssets")

    var loadedAssetIDs: [String] { cache.keys.sorted() }

    func texture(kind: PixelAssetKind) -> SKTexture? {
        texture(named: kind.rawValue)
    }

    /// Returns the same `SKTexture` instance for a repeated id. Missing assets
    /// return nil, log, and never throw.
    func texture(named assetID: String) -> SKTexture? {
        if let cached = cache[assetID] {
            return cached
        }
        guard let image = loadImage(named: assetID) else {
            recordMissing(assetID)
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cache[assetID] = texture
        return texture
    }

    /// Loads a catalogued runtime asset only when its pixel dimensions match
    /// the approved descriptor. A malformed sheet therefore cannot produce an
    /// out-of-bounds frame or silently alter character scale.
    func texture(descriptor: RuntimeArtDescriptor) -> SKTexture? {
        let assetID = descriptor.assetID
        if let cached = cache[assetID] {
            return cached
        }
        guard let image = loadImage(named: assetID) else {
            recordMissing(assetID)
            return nil
        }
        guard let pixels = Self.bitmap(from: image),
              pixels.pixelsWide == Int(descriptor.nativeSize.width),
              pixels.pixelsHigh == Int(descriptor.nativeSize.height) else {
            let actual = Self.bitmap(from: image).map { "\($0.pixelsWide)x\($0.pixelsHigh)" } ?? "unreadable"
            let expected = "\(Int(descriptor.nativeSize.width))x\(Int(descriptor.nativeSize.height))"
            recordValidationFailure("\(assetID): expected \(expected), found \(actual)")
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = descriptor.nearestNeighbor ? .nearest : .linear
        cache[assetID] = texture
        return texture
    }

    func makeSprite(kind: PixelAssetKind, cellSize: CGFloat) -> SKSpriteNode? {
        guard let texture = texture(kind: kind) else { return nil }
        let scale = PixelMetrics.integerScale(cellSize: cellSize)
        let native = kind.nativeSize
        let sprite = SKSpriteNode(
            texture: texture,
            size: CGSize(width: native.width * scale, height: native.height * scale)
        )
        sprite.texture?.filteringMode = .nearest
        sprite.name = "pixel-sprite"
        return sprite
    }

    func makeSprite(descriptor: RuntimeArtDescriptor, cellSize: CGFloat) -> SKSpriteNode? {
        guard descriptor.frameGrid == .single,
              let texture = texture(descriptor: descriptor) else { return nil }
        let scale = PixelMetrics.integerScale(cellSize: cellSize)
        let sprite = SKSpriteNode(
            texture: texture,
            size: CGSize(
                width: descriptor.nativeSize.width * scale,
                height: descriptor.nativeSize.height * scale
            )
        )
        sprite.anchorPoint = CGPoint(x: descriptor.anchor.x, y: descriptor.anchor.y)
        sprite.texture?.filteringMode = descriptor.nearestNeighbor ? .nearest : .linear
        sprite.name = "runtime-art-\(descriptor.assetID)"
        sprite.zPosition = descriptor.renderLayer.rawValue
        return sprite
    }

    /// Nearest-neighbor integer magnification for NFR-007 evidence.
    func magnifyNearest(kind: PixelAssetKind, factor: Int) -> NSBitmapImageRep? {
        guard factor >= 1, let image = loadImage(named: kind.rawValue) else { return nil }
        return Self.magnifyNearest(image: image, factor: factor)
    }

    static func magnifyNearest(image: NSImage, factor: Int) -> NSBitmapImageRep? {
        guard factor >= 1 else { return nil }
        guard let source = bitmap(from: image) else { return nil }
        let width = source.pixelsWide
        let height = source.pixelsHigh
        guard width > 0, height > 0,
              let dest = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width * factor,
                pixelsHigh: height * factor,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 32
              ) else {
            return nil
        }
        dest.size = NSSize(width: width * factor, height: height * factor)
        for y in 0..<height {
            for x in 0..<width {
                let color = source.colorAt(x: x, y: y) ?? NSColor.clear
                for dy in 0..<factor {
                    for dx in 0..<factor {
                        dest.setColor(color, atX: x * factor + dx, y: y * factor + dy)
                    }
                }
            }
        }
        return dest
    }

    func assetsDirectory() -> URL? {
        Self.resolveAssetsDirectory()
    }

    // MARK: - Private

    private func recordMissing(_ assetID: String) {
        missingRequests.append(assetID)
        let message = "[PixelAssetStore] missing texture: \(assetID) — falling back to procedural"
        print(message)
        logger.warning("missing texture \(assetID, privacy: .public); procedural fallback")
    }

    private func recordValidationFailure(_ message: String) {
        validationFailures.append(message)
        print("[PixelAssetStore] invalid runtime art: \(message) — falling back safely")
        logger.error("invalid runtime art \(message, privacy: .public); safe fallback")
    }

    private func loadImage(named assetID: String) -> NSImage? {
        if let overrideID = Self.displayR4AssetID(for: assetID),
           let image = loadDisplayR2Image(named: overrideID) {
            return image
        }
        if let overrideID = Self.displayR3AssetID(for: assetID),
           let image = loadDisplayR2Image(named: overrideID) {
            return image
        }
        if let overrideID = Self.displayR2AssetID(for: assetID),
           let image = loadDisplayR2Image(named: overrideID) {
            return image
        }
        let fileName = assetID + ".png"
        let bundles = [Bundle.main, Bundle(for: PixelAssetStore.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: assetID, withExtension: "png", subdirectory: "Assets")
                ?? bundle.url(forResource: assetID, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        if let directory = Self.resolveAssetsDirectory() {
            let url = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private func loadDisplayR2Image(named assetID: String) -> NSImage? {
        let bundles = [Bundle.main, Bundle(for: PixelAssetStore.self)]
        for bundle in bundles {
            if let url = bundle.url(
                forResource: assetID,
                withExtension: "png",
                subdirectory: "Presentation/DisplayR2"
            ) ?? bundle.url(forResource: assetID, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        if let directory = Self.resolveDisplayR2Directory() {
            let url = directory.appendingPathComponent(assetID + ".png")
            if FileManager.default.fileExists(atPath: url.path),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func resolveAssetsDirectory() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            let assets = url.appendingPathComponent("Assets")
            let marker = assets.appendingPathComponent("generation-log.md")
            if FileManager.default.fileExists(atPath: marker.path) {
                return assets
            }
            let nested = url.appendingPathComponent("macos/CreekSprout/CreekSprout/Assets")
            if FileManager.default.fileExists(atPath: nested.appendingPathComponent("generation-log.md").path) {
                return nested
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private static func resolveDisplayR2Directory() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            let direct = url.appendingPathComponent("DisplayR2")
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
            let nested = url.appendingPathComponent(
                "macos/CreekSprout/CreekSprout/Presentation/DisplayR2"
            )
            if FileManager.default.fileExists(atPath: nested.path) {
                return nested
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private static func bitmap(from image: NSImage) -> NSBitmapImageRep? {
        if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
            return bitmap
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage)
    }
}
