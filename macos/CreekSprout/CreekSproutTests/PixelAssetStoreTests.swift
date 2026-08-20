import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

final class PixelAssetStoreTests: XCTestCase {
    let store = PixelAssetStore.shared

    func testAllElevenAssetsLoadWithSpecSizesAndNearestFilter() throws {
        XCTAssertEqual(PixelAssetKind.allCases.count, 11)
        let directory = try XCTUnwrap(store.assetsDirectory())
        for kind in PixelAssetKind.allCases {
            let url = directory.appendingPathComponent(kind.fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), kind.fileName)

            let texture = try XCTUnwrap(store.texture(kind: kind), kind.rawValue)
            XCTAssertEqual(texture.filteringMode, .nearest, kind.rawValue)

            let image = try XCTUnwrap(NSImage(contentsOf: url), kind.fileName)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
            XCTAssertEqual(bitmap.pixelsWide, Int(kind.nativeSize.width), kind.fileName)
            XCTAssertEqual(bitmap.pixelsHigh, Int(kind.nativeSize.height), kind.fileName)
        }
    }

    func testCacheReturnsTheSameTextureInstance() throws {
        let first = try XCTUnwrap(store.texture(kind: .charWaterApprentice))
        let second = try XCTUnwrap(store.texture(named: PixelAssetKind.charWaterApprentice.rawValue))
        XCTAssertTrue(first === second)
        XCTAssertEqual(first.filteringMode, .nearest)
    }

    func testMissingAssetReturnsNilAndLogs() {
        let before = store.missingRequests.count
        XCTAssertNil(store.texture(named: "char_does_not_exist"))
        XCTAssertGreaterThan(store.missingRequests.count, before)
        XCTAssertEqual(store.missingRequests.last, "char_does_not_exist")
    }

    func testIntegerScaleSnapsToTileMultiple() {
        XCTAssertEqual(PixelMetrics.snappedCellSize(fitting: 89), 72)
        XCTAssertEqual(PixelMetrics.integerScale(cellSize: 72), 3)
        XCTAssertEqual(PixelMetrics.snappedCellSize(fitting: 23), 24)
        XCTAssertEqual(PixelMetrics.integerScale(cellSize: 24), 1)
        let origin = PixelMetrics.snap(CGPoint(x: 10.4, y: 10.6))
        XCTAssertEqual(origin.x, 10)
        XCTAssertEqual(origin.y, 11)
    }

    func testSpriteSizeIsIntegerMultipleOfNative() throws {
        let sprite = try XCTUnwrap(store.makeSprite(kind: .tileGrass, cellSize: 72))
        XCTAssertEqual(sprite.size.width, 72)
        XCTAssertEqual(sprite.size.height, 72)
        XCTAssertEqual(sprite.texture?.filteringMode, .nearest)

        let character = try XCTUnwrap(store.makeSprite(kind: .charSeedSteward, cellSize: 72))
        XCTAssertEqual(character.size.width, 96)
        XCTAssertEqual(character.size.height, 144)
        XCTAssertEqual(character.size.width.truncatingRemainder(dividingBy: 1), 0)
        XCTAssertEqual(character.size.height.truncatingRemainder(dividingBy: 1), 0)
    }

    func testNearestMagnificationKeepsSolidTexelBlocks() throws {
        let factor = 8
        let bitmap = try XCTUnwrap(store.magnifyNearest(kind: .charWaterApprentice, factor: factor))
        let directory = try XCTUnwrap(store.assetsDirectory())
        let sourceImage = try XCTUnwrap(
            NSImage(contentsOf: directory.appendingPathComponent(PixelAssetKind.charWaterApprentice.fileName))
        )
        let source = try XCTUnwrap(NSBitmapImageRep(data: sourceImage.tiffRepresentation ?? Data()))

        var pair: (x: Int, y: Int)?
        search: for y in 0..<(source.pixelsHigh - 1) {
            for x in 0..<(source.pixelsWide - 1) {
                let a = rgba(source.colorAt(x: x, y: y))
                let b = rgba(source.colorAt(x: x + 1, y: y))
                if max(abs(a.0 - b.0), abs(a.1 - b.1), abs(a.2 - b.2)) > 0.08 {
                    pair = (x, y)
                    break search
                }
            }
        }
        let origin = try XCTUnwrap(pair, "source sprite needs at least one horizontal color edge")

        assertSolidBlock(bitmap, originX: origin.x * factor, originY: origin.y * factor, factor: factor)
        assertSolidBlock(bitmap, originX: (origin.x + 1) * factor, originY: origin.y * factor, factor: factor)

        let left = rgba(bitmap.colorAt(x: origin.x * factor, y: origin.y * factor))
        let right = rgba(bitmap.colorAt(x: (origin.x + 1) * factor, y: origin.y * factor))
        let delta = max(abs(left.0 - right.0), abs(left.1 - right.1), abs(left.2 - right.2))
        XCTAssertGreaterThan(delta, 0.08, "8x nearest must keep a sharp edge, not a blended mid-tone")
    }

    func testFunctionalRolesUsePixelTextureAndNeighborsFallback() {
        let apprentice = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.waterApprentice),
            cellSize: 48,
            showsTalkBadge: true
        )
        XCTAssertTrue(apprentice.usesPixelTexture)
        XCTAssertNotNil(apprentice.childNode(withName: "talk-badge"))
        XCTAssertEqual((apprentice.childNode(withName: "talk-badge-label") as? SKLabelNode)?.text, "谈")
        XCTAssertEqual((apprentice.childNode(withName: "display-name") as? SKLabelNode)?.text, "水工学徒")

        let steward = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.seedSteward),
            cellSize: 48,
            showsTalkBadge: true
        )
        XCTAssertTrue(steward.usesPixelTexture)

        let warden = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.creekWarden),
            cellSize: 48,
            showsTalkBadge: true
        )
        XCTAssertTrue(warden.usesPixelTexture)

        let neighbor = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.neighborHearsay),
            cellSize: 48,
            showsTalkBadge: true
        )
        XCTAssertFalse(neighbor.usesPixelTexture)
        XCTAssertNotNil(neighbor.childNode(withName: "talk-badge"))
        XCTAssertEqual((neighbor.childNode(withName: "talk-badge-label") as? SKLabelNode)?.text, "谈")

        let player = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: 48,
            showsTalkBadge: false,
            showsName: false
        )
        XCTAssertFalse(player.usesPixelTexture)
    }

    func testCropIDMapsToExistingAssetWithoutNewContentIDs() {
        XCTAssertEqual(
            PixelAssetCatalog.cropKind(for: ContentID.mistRadishCrop),
            .cropMistRadish
        )
        XCTAssertEqual(
            PixelAssetCatalog.cropKind(for: "brookseed.crop.stream_leaf"),
            .cropStreamLeaf
        )
        XCTAssertNil(PixelAssetCatalog.cropKind(for: "brookseed.crop.unknown_crop"))
        XCTAssertNil(PixelAssetCatalog.characterKind(for: ContentID.neighborEvidence))
    }

    private func assertSolidBlock(_ bitmap: NSBitmapImageRep, originX: Int, originY: Int, factor: Int) {
        let sample = rgba(bitmap.colorAt(x: originX, y: originY))
        for dy in 0..<factor {
            for dx in 0..<factor {
                let pixel = rgba(bitmap.colorAt(x: originX + dx, y: originY + dy))
                let delta = max(
                    abs(pixel.0 - sample.0),
                    abs(pixel.1 - sample.1),
                    abs(pixel.2 - sample.2)
                )
                XCTAssertLessThan(delta, 0.02, "texel block \(originX),\(originY) should be uniform after \(factor)x nearest")
            }
        }
    }

    private func rgba(_ color: NSColor?) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        guard let converted = color?.usingColorSpace(.deviceRGB) else {
            return (0, 0, 0, 0)
        }
        return (
            converted.redComponent,
            converted.greenComponent,
            converted.blueComponent,
            converted.alphaComponent
        )
    }
}
