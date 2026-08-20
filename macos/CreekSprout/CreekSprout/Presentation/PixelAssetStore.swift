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
    case charWaterApprentice = "char_water_apprentice"
    case charSeedSteward = "char_seed_steward"
    case charCreekWarden = "char_creek_warden"
    case cropMistRadish = "crop_mist_radish"
    case cropStreamLeaf = "crop_stream_leaf"
    case cropAmberBean = "crop_amber_bean"
    case cropBellBerry = "crop_bell_berry"
    case cropHoneyMelon = "crop_honey_melon"
    case tileGrass = "tile_grass"
    case tileTilled = "tile_tilled"
    case tileWaterEdge = "tile_water_edge"

    var fileName: String { rawValue + ".png" }

    var nativeSize: CGSize {
        switch self {
        case .charWaterApprentice, .charSeedSteward, .charCreekWarden:
            return PixelMetrics.characterNative
        case .cropMistRadish, .cropStreamLeaf, .cropAmberBean, .cropBellBerry, .cropHoneyMelon:
            return PixelMetrics.cropNative
        case .tileGrass, .tileTilled, .tileWaterEdge:
            return CGSize(width: PixelMetrics.tileNative, height: PixelMetrics.tileNative)
        }
    }

    var isCharacter: Bool {
        switch self {
        case .charWaterApprentice, .charSeedSteward, .charCreekWarden: return true
        default: return false
        }
    }
}

/// NPC / crop / terrain ID → pixel filename. Missing mappings fall back to procedural.
enum PixelAssetCatalog {
    static func characterKind(for characterID: String) -> PixelAssetKind? {
        switch characterID {
        case ContentID.waterApprentice: return .charWaterApprentice
        case ContentID.seedSteward: return .charSeedSteward
        case ContentID.creekWarden: return .charCreekWarden
        default: return nil
        }
    }

    /// `brookseed.crop.mist_radish` → `crop_mist_radish`. Unknown slugs return nil.
    static func cropKind(for cropID: String) -> PixelAssetKind? {
        guard let slug = cropID.split(separator: ".").last else { return nil }
        return PixelAssetKind(rawValue: "crop_\(slug)")
    }

    static func tileKind(prepared: Bool, isWaterEdge: Bool) -> PixelAssetKind {
        if isWaterEdge { return .tileWaterEdge }
        return prepared ? .tileTilled : .tileGrass
    }
}

/// Loads PNGs from `Assets/` into cached `SKTexture`s with nearest-neighbor filtering.
///
/// Loading order (declared for N-003):
/// 1. App / test-host bundle subdirectory `Assets/`
/// 2. Bundle root (`char_….png`)
/// 3. Source-tree `CreekSprout/Assets/` via `#filePath` (XCTest without resource copy)
///
/// Uses `NSImage(contentsOf:)` + `SKTexture(image:)` so `filteringMode` is set
/// before any SpriteKit default linear sampler can blur the texels.
final class PixelAssetStore {
    static let shared = PixelAssetStore()

    private var cache: [String: SKTexture] = [:]
    private(set) var missingRequests: [String] = []
    private let logger = Logger(subsystem: "com.brookseed.CreekSprout", category: "PixelAssets")

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

    private func loadImage(named assetID: String) -> NSImage? {
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
