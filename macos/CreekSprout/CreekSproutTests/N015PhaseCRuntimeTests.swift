import AppKit
import XCTest
import SpriteKit
@testable import CreekSprout

@MainActor
final class N015PhaseCRuntimeTests: XCTestCase {
    func testDec035MapsMatchProductionDimensionsAnchorsAndConsumers() throws {
        let farm = WorldCatalog.farmHomestead
        let market = WorldCatalog.creekMarket
        XCTAssertEqual([farm.columns, farm.rows], [16, 15])
        XCTAssertEqual([market.columns, market.rows], [18, 14])
        XCTAssertEqual(farm.spawn(id: ContentID.farmWakeSpawn)?.position, GridPosition(x: 7, y: 6))
        XCTAssertEqual(farm.spawn(id: ContentID.farmFromMarketSpawn)?.position, GridPosition(x: 7, y: 1))
        XCTAssertEqual(market.spawn(id: ContentID.marketFromFarmSpawn)?.position, GridPosition(x: 9, y: 11))
        XCTAssertEqual(farm.exits.first?.cell, GridPosition(x: 7, y: 0))
        XCTAssertEqual(market.exits.first?.cell, GridPosition(x: 9, y: 12))
        XCTAssertEqual(farm.buildings.count + market.buildings.count, 5)
        XCTAssertEqual((farm.buildings + market.buildings).flatMap(\.layers).count, 30)
        XCTAssertEqual(farm.waterCells.count, 6)
        XCTAssertEqual(farm.canalCells.count, 6)
        XCTAssertEqual(market.waterCells.count, 54)
        XCTAssertEqual(market.staticObstacleCells, [GridPosition(x: 6, y: 7)])
        XCTAssertEqual(ContentCatalog.vs0.scenario.startingNpcSpawns.first?.position, GridPosition(x: 8, y: 6))
        XCTAssertEqual(WorldCatalog.waterApprentice.position, GridPosition(x: 3, y: 6))
        XCTAssertEqual(WorldCatalog.creekWarden.position, GridPosition(x: 13, y: 9))
    }

    func testAllRequiredRuntimeTargetsAreReachableFromSpawn() throws {
        for map in [WorldCatalog.farmHomestead, WorldCatalog.creekMarket] {
            let start = try XCTUnwrap(map.spawns.first?.position)
            let reachable = floodFill(from: start, map: map)
            let required = Set(map.exits.map(\.cell))
                .union(map.buildings.flatMap(\.interactionCells))
                .union(ContentCatalog.vs0.gatherNodes.values.filter { $0.mapID == map.id }.map(\.position))
            for target in required {
                XCTAssertTrue(reachable.contains(target), "unreachable \(map.id) \(target)")
            }
        }
    }

    func testSaveDecodeRelocatesUnsafePositionDeterministicallyWithoutSchemaChange() throws {
        var state = GameState.vs0NewGame()
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 5, y: 1)
        let data = try SaveCodec.encode(state)
        let decoded = try SaveCodec.decode(data)
        XCTAssertEqual(decoded.position, GridPosition(x: 6, y: 3))
        XCTAssertEqual(SaveSchema.currentVersion, 10)
        XCTAssertFalse(WorldCatalog.creekMarket.isBlocked(decoded.position))

        var unknown = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        unknown["current_map_id"] = "brookseed.map.unknown"
        let unknownData = try JSONSerialization.data(withJSONObject: unknown)
        XCTAssertThrowsError(try SaveCodec.decode(unknownData))
    }

    func testHudSafeZonesMatchFrozen960And1280Contracts() {
        let compact = HudSafeZoneLayout.resolve(viewport: CGSize(width: 960, height: 640))
        XCTAssertEqual(compact.statusLeft, CGRect(x: 16, y: 16, width: 352, height: 64))
        XCTAssertEqual(compact.statusRight, CGRect(x: 688, y: 16, width: 256, height: 44))
        XCTAssertEqual(compact.toolbelt, CGRect(x: 300, y: 568, width: 360, height: 56))
        XCTAssertEqual(compact.contextPrompt, CGRect(x: 220, y: 516, width: 520, height: 40))
        XCTAssertEqual(compact.toast, compact.contextPrompt)
        XCTAssertEqual(compact.buildingCardNear, CGRect(x: 712, y: 92, width: 232, height: 88))
        XCTAssertEqual(compact.buildingCardExpanded, CGRect(x: 568, y: 92, width: 376, height: 400))
        XCTAssertEqual(compact.worldSafeRectDefault, CGRect(x: 16, y: 92, width: 928, height: 396))

        let large = HudSafeZoneLayout.resolve(viewport: CGSize(width: 1280, height: 800))
        XCTAssertEqual(large.toolbelt, CGRect(x: 456, y: 728, width: 368, height: 56))
        XCTAssertEqual(large.buildingCardExpanded, CGRect(x: 872, y: 92, width: 392, height: 480))
    }

    func testThirtyB4LayersAreRGBAAndBuildingPresenterComposesSix() throws {
        XCTAssertEqual(BuildingRuntimeArtKey.allCases.count, 30)
        let directory = try XCTUnwrap(PixelAssetStore.shared.assetsDirectory())
        for building in WorldCatalog.farmHomestead.buildings + WorldCatalog.creekMarket.buildings {
            XCTAssertEqual(building.layers.count, 6)
            for layer in building.layers {
                let image = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent(layer.filename)))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
                XCTAssertEqual(bitmap.pixelsWide, layer.nativeWidth)
                XCTAssertEqual(bitmap.pixelsHigh, layer.nativeHeight)
                XCTAssertTrue(bitmap.hasAlpha)
            }
            let node = BuildingVisualPresenter.makeNode(
                building: building,
                cellSize: 24,
                playerPosition: building.door,
                watershedRestored: true
            )
            XCTAssertEqual(node.children.count, 6)
        }
    }

    func testCharacterRuntimeScaleIsOneByOnePointFiveTiles() throws {
        let animator = try XCTUnwrap(SpriteSheetAnimator(
            walkKey: .charPlayerWalk,
            cellSize: 24,
            motionAllowed: false
        ))
        XCTAssertEqual(animator.sprite.size, CGSize(width: 24, height: 36))
        XCTAssertLessThanOrEqual(animator.sprite.size.width / 24, 1.15)
        XCTAssertEqual(animator.sprite.anchorPoint, CGPoint(x: 0.5, y: 0))
    }

    private func floodFill(from start: GridPosition, map: MapDefinition) -> Set<GridPosition> {
        var visited: Set<GridPosition> = [start]
        var queue = [start]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for next in [
                GridPosition(x: current.x + 1, y: current.y),
                GridPosition(x: current.x - 1, y: current.y),
                GridPosition(x: current.x, y: current.y + 1),
                GridPosition(x: current.x, y: current.y - 1),
            ] where map.contains(next) && !map.isBlocked(next) && visited.insert(next).inserted {
                queue.append(next)
            }
        }
        return visited
    }
}
