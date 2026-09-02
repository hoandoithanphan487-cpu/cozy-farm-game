import SpriteKit
import XCTest
@testable import CreekSprout

@MainActor
final class N015RuntimeArtAndHudTests: XCTestCase {
    func testRuntimeCatalogDescribesExactlyTheFortyNineUnblockedAssets() {
        XCTAssertEqual(RuntimeArtKey.allCases.count, 50)
        XCTAssertEqual(RuntimeArtCatalog.descriptors.count, 50)
        XCTAssertFalse(RuntimeArtKey.allCases.contains { $0.rawValue.hasPrefix("building_") })
        for key in RuntimeArtKey.allCases {
            let descriptor = RuntimeArtCatalog.descriptor(for: key)
            XCTAssertEqual(descriptor.filename, key.rawValue + ".png")
            XCTAssertTrue(descriptor.nearestNeighbor)
            XCTAssertNotNil(PixelAssetStore.shared.texture(descriptor: descriptor), key.rawValue)
        }
    }

    func testEightWalkSheetsUseFourDirectionsAndFourFramesWithStableFeet() throws {
        let characterIDs = [
            PlayerVisualID.sprout,
            ContentID.waterApprentice,
            ContentID.seedSteward,
            ContentID.creekWarden,
            ContentID.neighborHearsay,
            ContentID.neighborStoryteller,
            ContentID.neighborEvidence,
            ContentID.neighborConsensus,
        ]
        XCTAssertEqual(Set(characterIDs.compactMap(RuntimeArtCatalog.walkKey(for:))).count, 8)
        for characterID in characterIDs {
            let key = try XCTUnwrap(RuntimeArtCatalog.walkKey(for: characterID))
            let descriptor = RuntimeArtCatalog.descriptor(for: key)
            XCTAssertTrue(SpriteSheetAnimator.isValidCharacterSheet(descriptor))
            XCTAssertEqual(descriptor.frameSize, PixelMetrics.characterNative)
            XCTAssertEqual(descriptor.anchor, .bottomCenter)
            XCTAssertEqual(SpriteSheetAnimator.frameTextures(descriptor: descriptor)?.count, 16)
        }
    }

    func testDirectionRowsAndFrameBoundsAreDeterministic() throws {
        XCTAssertEqual(CharacterFrameDirection(.down), .down)
        XCTAssertEqual(CharacterFrameDirection(.left), .left)
        XCTAssertEqual(CharacterFrameDirection(.right), .right)
        XCTAssertEqual(CharacterFrameDirection(.up), .up)
        XCTAssertEqual(
            try XCTUnwrap(SpriteSheetAnimator.normalizedFrameRect(column: 0, direction: .down)),
            CGRect(x: 0, y: 0.75, width: 0.25, height: 0.25)
        )
        XCTAssertEqual(
            try XCTUnwrap(SpriteSheetAnimator.normalizedFrameRect(column: 3, direction: .up)),
            CGRect(x: 0.75, y: 0, width: 0.25, height: 0.25)
        )
        XCTAssertNil(SpriteSheetAnimator.normalizedFrameRect(column: 4, direction: .down))
    }

    func testMalformedCharacterSheetFailsClosed() {
        let approved = RuntimeArtCatalog.descriptor(for: .charPlayerWalk)
        let malformed = RuntimeArtDescriptor(
            key: approved.key,
            filename: approved.filename,
            nativeSize: CGSize(width: 127, height: 192),
            frameGrid: approved.frameGrid,
            anchor: approved.anchor,
            renderLayer: approved.renderLayer,
            nearestNeighbor: approved.nearestNeighbor,
            fallbackAssetID: approved.fallbackAssetID,
            provenance: approved.provenance
        )
        XCTAssertFalse(SpriteSheetAnimator.isValidCharacterSheet(malformed))
        XCTAssertNil(PixelAssetStore().texture(descriptor: malformed))
    }

    func testWaterResolverUsesAllApprovedEdgesAndCorners() {
        let cells: Set<GridPosition> = [GridPosition(x: 8, y: 0), GridPosition(x: 9, y: 0)]
        let visuals = cells.map { WorldVisualCatalog.waterBorder(at: $0, waterCells: cells) }
        let edges = Set(visuals.flatMap(\.edgeKeys))
        let corners = Set(visuals.flatMap(\.cornerKeys))
        XCTAssertEqual(edges, Set([.tileWaterEdgeN, .tileWaterEdgeE, .tileWaterEdgeS, .tileWaterEdgeW]))
        XCTAssertEqual(corners, Set([.tileWaterCornerNE, .tileWaterCornerSE, .tileWaterCornerSW, .tileWaterCornerNW]))
    }

    func testPresentationCatalogMatchesDec035WorldTopology() {
        XCTAssertEqual(WorldCatalog.farmHomestead.buildings.count, 2)
        XCTAssertEqual(WorldCatalog.creekMarket.buildings.count, 3)
        XCTAssertEqual(WorldCatalog.farmHomestead.buildings.flatMap(\.layers).count, 12)
        XCTAssertEqual(WorldCatalog.creekMarket.buildings.flatMap(\.layers).count, 18)
        XCTAssertEqual(WorldCatalog.farmHomestead.exits.first?.cell, GridPosition(x: 7, y: 0))
        XCTAssertEqual(WorldCatalog.creekMarket.exits.first?.cell, GridPosition(x: 9, y: 12))
        XCTAssertEqual(WorldCatalog.npcList.count, 7)
    }

    func testWorldEffectOwnsExplicitCleanupAndReducedMotionUsesStaticFrame() throws {
        let parent = SKNode()
        let animated = try XCTUnwrap(WorldEffectPresenter.addTransient(
            keys: RuntimeArtCatalog.harvestFrames,
            at: .zero,
            to: parent,
            cellSize: 48,
            motionAllowed: true
        ))
        XCTAssertNotNil(animated.action(forKey: WorldEffectPresenter.animationActionKey))
        XCTAssertNotNil(animated.action(forKey: "transient-cleanup"))
        let staticFrame = try XCTUnwrap(WorldEffectPresenter.makeAnimatedSprite(
            keys: RuntimeArtCatalog.waterFrames,
            cellSize: 48,
            timePerFrame: 0.1,
            loops: true,
            motionAllowed: false,
            name: "reduced-motion"
        ))
        XCTAssertNil(staticFrame.action(forKey: WorldEffectPresenter.animationActionKey))
    }

    func testHUDIsStructuredFourSlotStateAndTracksInputDevice() {
        let scene = FarmScene.makeDefault()
        let keyboard = scene.hudPresentationState
        XCTAssertEqual(keyboard.toolbelt.count, 4)
        XCTAssertEqual(keyboard.toolbelt.filter(\.isSelected).map(\.id), ["hoe"])
        XCTAssertEqual(keyboard.prompt.bindingLabel, "空格")
        XCTAssertFalse(keyboard.prompt.usesGamepad)
        XCTAssertFalse(keyboard.questLine.isEmpty)
        scene.updateInputDevice(.gamepad)
        let gamepad = scene.hudPresentationState
        XCTAssertTrue(gamepad.prompt.usesGamepad)
        XCTAssertEqual(gamepad.prompt.bindingLabel, "手柄 A")
    }

    func testFiveHDBuildingsAreCataloguedWithoutChangingTopology() {
        XCTAssertEqual(BuildingPresentationCatalog.entries.count, 5)
        for entry in BuildingPresentationCatalog.entries {
            XCTAssertTrue(BuildingPresentationCatalog.contains(entry.landmarkID))
            XCTAssertNotNil(BuildingPresentationCatalog.image(for: entry.landmarkID), entry.assetName)
        }
        XCTAssertEqual(WorldCatalog.farmHomestead.landmarks.count, 4)
        XCTAssertEqual(WorldCatalog.creekMarket.landmarks.count, 6)
    }
}
