import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

final class N003PixelPipelineEvidenceTests: XCTestCase {
    func testSmokePathCapturesPixelPipelineEvidence() throws {
        let evidence = try evidenceDirectory()
        let screenshots = evidence.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)

        try writeTexturedLineup(to: screenshots)
        try writeCropAndTileCatalog(to: screenshots)
        try writeMotionFrames(to: screenshots)
        try writeNFR007Magnification(to: evidence)

        let scene = FarmScene(size: CGSize(width: 960, height: 640))
        scene.scaleMode = .resizeFill
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 960, height: 640))
        let window = NSWindow(
            contentRect: view.bounds,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderBack(nil)
        view.presentScene(scene)
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        defer { window.close() }

        scene.applySettings(.defaults)
        try writeScenePNG(scene, name: "01-newgame-farm-tiles-crops.png", to: screenshots)

        scene.selectTool(.harvest)
        walk(scene, [.down, .down])
        scene.performAction()
        XCTAssertTrue(scene.lastFeedback.contains("1/3") || scene.lastFeedback.contains("收获"))
        XCTAssertEqual(scene.audioService.events.last { $0.kind == "sfx" }?.name, "harvest")
        try writeScenePNG(scene, name: "02-harvest-pixel-crop.png", to: screenshots)

        walk(scene, [.left, .up, .down])
        scene.performAction()
        try writeScenePNG(scene, name: "02-harvest-2.png", to: screenshots)

        walk(scene, [.right, .right, .up, .down])
        scene.performAction()
        try writeScenePNG(scene, name: "02-harvest-3.png", to: screenshots)

        scene.depositShipping()
        XCTAssertTrue(scene.lastFeedbackIsSuccess)

        walkToward(scene, x: 6, y: 1, thenFace: .down)
        scene.talkToNpc()
        XCTAssertTrue(scene.hudText.contains("【对话】"), scene.lastFeedback)
        try writeScenePNG(scene, name: "03-talk-badge-expression.png", to: screenshots)
        finishDialogue(scene)
        XCTAssertFalse(scene.hudText.contains("【对话】"))

        scene.sleepAndSettle()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(scene.gameState.clock.day, 2, scene.lastFeedback)
        XCTAssertEqual(scene.audioService.weatherLayer, .rain)

        walkToward(scene, x: 5, y: 0)
        scene.performAction()
        XCTAssertEqual(scene.gameState.currentMapID, ContentID.creekMarket, scene.lastFeedback)
        try writeScenePNG(scene, name: "04-market-textured-roles.png", to: screenshots)
        try writeScenePNG(scene, name: "05-rain-market.png", to: screenshots)
    }

    private func writeTexturedLineup(to directory: URL) throws {
        let canvas = CGSize(width: 720, height: 280)
        let scene = SKScene(size: canvas)
        scene.backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
        let ids = [ContentID.waterApprentice, ContentID.seedSteward, ContentID.creekWarden]
        for (index, id) in ids.enumerated() {
            let node = CharacterVisualNode(
                definition: CharacterVisualCatalog.visual(for: id),
                cellSize: 72,
                showsTalkBadge: true
            )
            node.setMotionAllowed(false)
            node.applySnapshotPose(.idle)
            XCTAssertTrue(node.usesPixelTexture, id)
            node.position = CGPoint(x: 120 + CGFloat(index) * 200, y: 130)
            scene.addChild(node)
        }
        try writePNG(scene, size: canvas, to: directory.appendingPathComponent("00-three-textured-roles.png"))
    }

    private func writeCropAndTileCatalog(to directory: URL) throws {
        let canvas = CGSize(width: 880, height: 220)
        let scene = SKScene(size: canvas)
        scene.backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
        let kinds: [PixelAssetKind] = [
            .tileGrass, .tileTilled, .tileWaterEdge,
            .cropMistRadish, .cropStreamLeaf, .cropAmberBean, .cropBellBerry, .cropHoneyMelon,
        ]
        for (index, kind) in kinds.enumerated() {
            let sprite = try XCTUnwrap(PixelAssetStore.shared.makeSprite(kind: kind, cellSize: 72), kind.rawValue)
            sprite.position = CGPoint(x: 60 + CGFloat(index) * 100, y: 120)
            scene.addChild(sprite)
            let label = SKLabelNode(text: kind.rawValue)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = .white
            label.position = CGPoint(x: sprite.position.x, y: 28)
            scene.addChild(label)
        }
        try writePNG(scene, size: canvas, to: directory.appendingPathComponent("00-crops-and-tiles.png"))
    }

    private func writeMotionFrames(to directory: URL) throws {
        let apprentice = CharacterVisualNode(
            definition: CharacterVisualCatalog.visual(for: ContentID.waterApprentice),
            cellSize: 72,
            showsTalkBadge: true
        )
        apprentice.setMotionAllowed(false)
        XCTAssertTrue(apprentice.usesPixelTexture)
        apprentice.applySnapshotPose(.idle)
        try writePNG(apprentice, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-walk-0-idle.png"))
        apprentice.applySnapshotPose(.walking, walkTilt: -0.28)
        try writePNG(apprentice, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-walk-1-left.png"))
        apprentice.applySnapshotPose(.walking, walkTilt: 0.28)
        try writePNG(apprentice, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-walk-2-right.png"))
        apprentice.applySnapshotPose(.idle)
        try writePNG(apprentice, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-talk-0-idle.png"))
        apprentice.applySnapshotPose(.talking)
        try writePNG(apprentice, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-talk-1-open.png"))

        let player = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: 72,
            showsTalkBadge: false,
            showsName: true
        )
        player.setMotionAllowed(false)
        player.applySnapshotPose(.idle)
        try writePNG(player, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-harvest-0-idle.png"))
        player.applySnapshotPose(.harvesting, harvestLift: 16)
        try writePNG(player, canvas: CGSize(width: 240, height: 320), to: directory.appendingPathComponent("motion-harvest-1-lift.png"))
    }

    private func writeNFR007Magnification(to evidence: URL) throws {
        let screenshots = evidence.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        let kinds: [PixelAssetKind] = [.charWaterApprentice, .cropMistRadish, .tileGrass]
        let factor = 8
        let columnWidth = 32 * factor + 48
        let canvas = NSImage(size: NSSize(width: columnWidth * kinds.count, height: 48 * factor + 40))
        canvas.lockFocus()
        NSColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1).setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: canvas.size))

        for (index, kind) in kinds.enumerated() {
            let magnified = try XCTUnwrap(PixelAssetStore.shared.magnifyNearest(kind: kind, factor: factor))
            let native = kind.nativeSize
            let directory = try XCTUnwrap(PixelAssetStore.shared.assetsDirectory())
            let original = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent(kind.fileName)))
            let originX = CGFloat(index * columnWidth) + 16
            original.draw(
                in: NSRect(x: originX, y: canvas.size.height - native.height - 24, width: native.width, height: native.height)
            )
            magnified.draw(
                in: NSRect(
                    x: originX + native.width + 12,
                    y: canvas.size.height - CGFloat(magnified.pixelsHigh) - 24,
                    width: CGFloat(magnified.pixelsWide),
                    height: CGFloat(magnified.pixelsHigh)
                )
            )
        }
        canvas.unlockFocus()
        let tiff = try XCTUnwrap(canvas.tiffRepresentation)
        let png = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        try PresentationSnapshot.writePNG(png, to: screenshots.appendingPathComponent("nfr-007-nearest-8x.png"))
        try PresentationSnapshot.writePNG(png, to: evidence.appendingPathComponent("nfr-007-nearest-8x.png"))
    }

    private func walk(_ scene: FarmScene, _ steps: [Direction]) {
        for step in steps {
            _ = scene.tryMove(step)
        }
    }

    private func walkToward(_ scene: FarmScene, x: Int, y: Int, thenFace: Direction? = nil) {
        for _ in 0..<24 {
            let pos = scene.gameState.position
            if pos.x == x, pos.y == y { break }
            if pos.x < x { _ = scene.tryMove(.right) }
            else if pos.x > x { _ = scene.tryMove(.left) }
            else if pos.y < y { _ = scene.tryMove(.up) }
            else { _ = scene.tryMove(.down) }
        }
        guard let thenFace else { return }
        switch thenFace {
        case .down:
            _ = scene.tryMove(.up)
            _ = scene.tryMove(.down)
        case .up:
            _ = scene.tryMove(.down)
            _ = scene.tryMove(.up)
        case .left:
            _ = scene.tryMove(.right)
            _ = scene.tryMove(.left)
        case .right:
            _ = scene.tryMove(.left)
            _ = scene.tryMove(.right)
        }
    }

    private func finishDialogue(_ scene: FarmScene) {
        for _ in 0..<8 where scene.hudText.contains("【对话】") {
            scene.talkToNpc()
        }
    }

    private func writeScenePNG(_ scene: FarmScene, name: String, to directory: URL) throws {
        RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        let data = PresentationSnapshot.pngData(from: scene, size: scene.size)
        XCTAssertNotNil(data, "missing scene snapshot \(name)")
        if let data {
            try PresentationSnapshot.writePNG(data, to: directory.appendingPathComponent(name))
        }
    }

    private func writePNG(_ scene: SKScene, size: CGSize, to url: URL) throws {
        let data = PresentationSnapshot.pngData(from: scene, size: size)
        XCTAssertNotNil(data, "missing snapshot \(url.lastPathComponent)")
        if let data {
            try PresentationSnapshot.writePNG(data, to: url)
        }
    }

    private func writePNG(_ node: SKNode, canvas: CGSize, to url: URL) throws {
        let data = PresentationSnapshot.pngData(
            from: node,
            canvas: canvas,
            background: SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
        )
        XCTAssertNotNil(data, "missing snapshot \(url.lastPathComponent)")
        if let data {
            try PresentationSnapshot.writePNG(data, to: url)
        }
    }

    private func evidenceDirectory() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["N003_EVIDENCE_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("macos/CreekSprout/CreekSprout.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                let preferred = url.appendingPathComponent("artifacts/integration/n-003-pixel", isDirectory: true)
                if canWrite(to: preferred) {
                    return preferred
                }
                break
            }
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CreekSprout/n-003-export", isDirectory: true)
        try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    private func canWrite(to directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent(".write-probe")
            try Data("ok".utf8).write(to: probe)
            try FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }
}
