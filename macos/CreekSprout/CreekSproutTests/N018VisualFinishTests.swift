import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

@MainActor
final class N018VisualFinishTests: XCTestCase {
    func testIntegerZoomFillsPrimaryAndCompactWindows() {
        XCTAssertEqual(WorldCamera.cellSize(for: CGSize(width: 1_280, height: 800)), 72)
        XCTAssertEqual(WorldCamera.integerZoom(for: CGSize(width: 960, height: 640)), 2)
        XCTAssertEqual(WorldCamera.cellSize(for: CGSize(width: 960, height: 640)), 48)

        let large = presentedScene(size: CGSize(width: 1_280, height: 800))
        XCTAssertEqual(large.presentationCellSize, 72)
        XCTAssertNotNil(large.childNode(withName: "//world-root"))
        XCTAssertGreaterThanOrEqual(coverage(columns: 16, rows: 15, cellSize: 72, viewport: CGSize(width: 1_280, height: 800)), 0.85)

        let compact = presentedScene(size: CGSize(width: 960, height: 640))
        XCTAssertEqual(compact.presentationCellSize, 48)
        XCTAssertGreaterThanOrEqual(coverage(columns: 16, rows: 15, cellSize: 48, viewport: CGSize(width: 960, height: 640)), 0.78)
    }

    func testAtmospherePaletteSplitsFarmMarketAndRain() {
        let farmSun = WorldCamera.atmosphereColor(mapID: ContentID.farmHomestead, isRain: false, restored: false)
        let farmRain = WorldCamera.atmosphereColor(mapID: ContentID.farmHomestead, isRain: true, restored: false)
        let marketSun = WorldCamera.atmosphereColor(mapID: ContentID.creekMarket, isRain: false, restored: false)
        let marketRain = WorldCamera.atmosphereColor(mapID: ContentID.creekMarket, isRain: true, restored: false)
        XCTAssertNotEqual(farmSun, farmRain)
        XCTAssertNotEqual(farmSun, marketSun)
        XCTAssertNotEqual(marketSun, marketRain)
    }

    func testWeatherWashPreservesPixelContrast() {
        let farmClear = WorldCamera.weatherWash(isRain: false, isMarket: false)
        let marketClear = WorldCamera.weatherWash(isRain: false, isMarket: true)
        let farmRain = WorldCamera.weatherWash(isRain: true, isMarket: false)
        let marketRain = WorldCamera.weatherWash(isRain: true, isMarket: true)

        XCTAssertLessThanOrEqual(farmClear.alphaComponent, 0.03)
        XCTAssertLessThanOrEqual(marketClear.alphaComponent, 0.03)
        XCTAssertLessThanOrEqual(farmRain.alphaComponent, 0.16)
        XCTAssertLessThanOrEqual(marketRain.alphaComponent, 0.19)
    }

    func testTalkingExpressionKeepsPixelCharacterAtOneToOneScale() throws {
        let definition = CharacterVisualCatalog.visual(for: CharacterVisualCatalog.playerID)
        let node = CharacterVisualNode(
            definition: definition,
            cellSize: 72,
            showsTalkBadge: false
        )
        let sprite = try XCTUnwrap(node.childNode(withName: "//pixel-sprite"))
        node.setTalking(true)
        XCTAssertEqual(sprite.xScale, 1)
        XCTAssertEqual(sprite.yScale, 1)
    }

    func testPlayerToastKeepsSuccessFailureWithoutDebugMarks() {
        let success = HudCopy.playerToast(message: "浇水完成。", isSuccess: true)
        let failure = HudCopy.playerToast(message: "无法交谈。", isSuccess: false)
        XCTAssertTrue(success.contains("成功"))
        XCTAssertTrue(failure.contains("失败"))
        XCTAssertFalse(success.contains("[+]"))
        XCTAssertFalse(failure.contains("[!]"))
        XCTAssertTrue(HudCopy.feedbackLine(message: "浇水完成。", isSuccess: true).contains("成功："))
    }

    func testDefaultCompactHudUsesFourToolsAndHidesDialogueToast() {
        let scene = presentedScene(size: CGSize(width: 1_280, height: 800))
        let hud = scene.hudPresentationState
        XCTAssertEqual(hud.toolbelt.map(\.id), ["hoe", "seed", "water", "harvest"])
        XCTAssertNil(hud.dialogue)
        XCTAssertFalse(hud.questLine.contains("brookseed."))
        XCTAssertFalse(hud.calendar.mapName.contains("brookseed."))
    }

    func testCameraFollowsPlayerWithoutChangingSpawnContract() {
        let scene = presentedScene(size: CGSize(width: 1_280, height: 800))
        let originAtSpawn = scene.childNode(withName: "world-root")?.position
        XCTAssertEqual(scene.gameState.position, GridPosition(x: 7, y: 6))
        XCTAssertTrue(scene.tryMove(.up))
        XCTAssertEqual(scene.gameState.position, GridPosition(x: 7, y: 7))
        let originAfterMove = scene.childNode(withName: "world-root")?.position
        XCTAssertNotEqual(originAtSpawn, originAfterMove)
        XCTAssertEqual(WorldCatalog.farmHomestead.spawn(id: ContentID.farmWakeSpawn)?.position, GridPosition(x: 7, y: 6))
    }

    func testCameraUsesTheActualHudSafeArea() {
        let viewport = CGSize(width: 1_280, height: 800)
        let hudRect = HudSafeZoneLayout.resolve(viewport: viewport).worldSafeRectDefault
        let sceneRect = WorldCamera.sceneSafeRect(fromHudSafeRect: hudRect, viewport: viewport)
        XCTAssertEqual(sceneRect, CGRect(x: 16, y: 152, width: 1_248, height: 556))

        let player = GridPosition(x: 7, y: 6)
        let cellSize = WorldCamera.cellSize(for: viewport)
        let origin = WorldCamera.worldOrigin(
            viewport: viewport,
            mapColumns: 16,
            mapRows: 15,
            cellSize: cellSize,
            player: player,
            safeRect: sceneRect
        )
        let playerPoint = CGPoint(
            x: origin.x + (CGFloat(player.x) + 0.5) * cellSize,
            y: origin.y + (CGFloat(player.y) + 0.5) * cellSize
        )
        XCTAssertTrue(sceneRect.contains(playerPoint))
        XCTAssertGreaterThan(playerPoint.y, viewport.height / 2)
    }

    func testNpcContextMarkersCanBeHiddenWithoutHidingTheSprite() throws {
        let node = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.waterApprentice),
            cellSize: 72,
            showsTalkBadge: true
        )
        node.setContextVisibility(nameVisible: false, badgeVisible: false)
        XCTAssertEqual(node.childNode(withName: "display-name")?.isHidden, true)
        XCTAssertEqual(node.childNode(withName: "talk-badge")?.isHidden, true)
        XCTAssertNotNil(node.childNode(withName: "//pixel-sprite"))
    }

    func testCompactGoalRemovesRepeatedHeadingAndKeepsHintHierarchy() {
        XCTAssertEqual(
            HudCopy.compactGoal("当前目标：收获 3 株作物  面向成熟作物按空格"),
            "收获 3 株作物 · 面向成熟作物按空格"
        )
    }

    func testDemoFixtureUsesReadableCropRowsAndOnlyFarmUtilityProps() throws {
        let state = DemoSessionFixture.makeInitialState()
        XCTAssertEqual(DemoSessionFixture.matureTeachingCropCount(state), 3)
        let expectedColumns: [Int: String] = [
            1: ContentID.mistRadishCrop,
            2: ContentID.streamLeafCrop,
            3: ContentID.amberBeanCrop,
            4: ContentID.bellBerryCrop,
            5: ContentID.honeyMelonCrop,
        ]
        for (x, cropID) in expectedColumns {
            for y in 2...5 {
                let cell = try XCTUnwrap(state.farmCells[GridPosition(x: x, y: y)])
                XCTAssertEqual(cell.cropID, cropID)
                XCTAssertTrue(cell.hasCrop)
                XCTAssertTrue(cell.readyToHarvest || cell.cropStage == 2)
            }
        }
        let mainBed = Set((1...5).flatMap { x in
            (2...5).map { y in GridPosition(x: x, y: y) }
        })
        XCTAssertEqual(
            Set(state.farmCells.keys),
            mainBed.union(FarmCultivationCatalog.rearCultivableCells)
        )
        let propIDs = Set(state.placedObjects.map(\.definitionID))
        XCTAssertEqual(propIDs, Set([
            ContentID.woodhoneyHearthObject,
            ContentID.compostRackObject,
            ContentID.woodenCrateObject,
            ContentID.rainBarrelObject,
        ]))
        try SaveValidation.validate(state, catalog: .vs0)
    }

    func testFarmCanalJoinConsumesEastWestTile() {
        let scene = presentedDemoScene(size: CGSize(width: 1_280, height: 800))
        XCTAssertTrue(PixelAssetStore.shared.loadedAssetIDs.contains("tile_canal_ns"))
        XCTAssertTrue(PixelAssetStore.shared.loadedAssetIDs.contains("tile_canal_ew"))
        XCTAssertTrue(PixelAssetStore.shared.loadedAssetIDs.contains("tile_water_edge"))
        XCTAssertEqual(scene.characterInfoCharacterID, CharacterVisualCatalog.playerID)
        XCTAssertNotNil(scene.childNode(withName: "//pixel-sprite"))
    }

    func testIdleSpriteAndWalkSheetAreBothPresentForPlayer() {
        let node = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: 72,
            showsTalkBadge: false,
            showsName: false
        )
        XCTAssertTrue(node.usesPixelTexture)
        XCTAssertNotNil(node.childNode(withName: ".//pixel-sprite"))
        XCTAssertNotNil(node.childNode(withName: ".//character-spritesheet"))
    }

    private func coverage(columns: Int, rows: Int, cellSize: CGFloat, viewport: CGSize) -> CGFloat {
        let visibleW = min(CGFloat(columns) * cellSize, viewport.width)
        let visibleH = min(CGFloat(rows) * cellSize, viewport.height)
        return (visibleW * visibleH) / (viewport.width * viewport.height)
    }

    private func presentedScene(size: CGSize) -> FarmScene {
        let scene = FarmScene(size: size)
        scene.scaleMode = .resizeFill
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        return scene
    }

    private func presentedDemoScene(size: CGSize) -> FarmScene {
        let scene = presentedScene(size: size)
        scene.replaceSessionState(DemoSessionFixture.makeInitialState())
        return scene
    }
}
