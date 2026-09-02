import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

final class N001PresentationEvidenceTests: XCTestCase {
    func testSmokePathCapturesVisualAndAudioEvidence() throws {
        let evidence = try evidenceDirectory()
        let screenshots = evidence.appendingPathComponent("screenshots", isDirectory: true)
        let audioDir = evidence.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        try writeCharacterLineup(to: screenshots)
        try writeMotionFrames(to: screenshots)

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
        XCTAssertEqual(scene.audioService.mapLayer, .farm)
        try writeScenePNG(scene, name: "01-newgame-farm-player-apprentice.png", to: screenshots)

        scene.selectTool(.harvest)
        walkToward(scene, x: 4, y: 4, thenFace: .down)
        scene.performAction()
        XCTAssertTrue(scene.lastFeedback.contains("1/3") || scene.lastFeedback.contains("收获"))
        try writeScenePNG(scene, name: "02-harvest-1.png", to: screenshots)

        walkToward(scene, x: 5, y: 4, thenFace: .down)
        scene.performAction()
        try writeScenePNG(scene, name: "02-harvest-2.png", to: screenshots)

        walkToward(scene, x: 6, y: 4, thenFace: .down)
        scene.performAction()
        try writeScenePNG(scene, name: "02-harvest-3.png", to: screenshots)

        scene.depositShipping()
        XCTAssertTrue(scene.lastFeedbackIsSuccess)
        try writeScenePNG(scene, name: "03-deposit.png", to: screenshots)

        #if DEBUG
        scene.grantDebugMaterials()
        scene.craftSelectedRecipe()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        #endif

        walkToward(scene, x: 8, y: 5, thenFace: .up)
        scene.talkToNpc()
        XCTAssertTrue(scene.hudText.contains("【对话】"), scene.lastFeedback)
        try writeScenePNG(scene, name: "04-talk-expression.png", to: screenshots)
        finishDialogue(scene)
        XCTAssertFalse(scene.hudText.contains("【对话】"))

        scene.sleepAndSettle()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        let hudAfterSleep = scene.hudText
        XCTAssertTrue(hudAfterSleep.contains("174") || scene.lastFeedback.contains("174"), scene.lastFeedback)
        XCTAssertEqual(scene.gameState.economy.balance, 894, hudAfterSleep)
        try writeScenePNG(scene, name: "05-sleep-settle.png", to: screenshots)
        XCTAssertEqual(scene.gameState.clock.day, 2, scene.lastFeedback)
        XCTAssertEqual(scene.audioService.weatherLayer, .rain)

        walkToward(scene, x: 7, y: 0)
        scene.performAction()
        XCTAssertEqual(scene.gameState.currentMapID, ContentID.creekMarket, scene.lastFeedback)
        XCTAssertEqual(scene.audioService.mapLayer, .creek)
        try writeScenePNG(scene, name: "06-market-seven-npcs.png", to: screenshots)
        XCTAssertEqual(scene.audioService.weatherLayer, .rain)
        try writeScenePNG(scene, name: "07-rain-layer.png", to: screenshots)

        var muted = SettingsState.defaults
        muted.volumes.master = 0
        scene.applySettings(muted)
        XCTAssertTrue(scene.audioService.isSilent(bus: .master))
        scene.audioService.play(.harvest)
        XCTAssertEqual(scene.audioService.events.last { $0.kind == "sfx" }?.gain, 0)

        var restored = muted
        restored.volumes.master = 1
        scene.applySettings(restored)
        XCTAssertGreaterThan(scene.audioService.gain(for: .master), 0)

        let settingsDir = audioDir.appendingPathComponent("settings-roundtrip", isDirectory: true)
        let store = SettingsStore(directory: settingsDir)
        try store.save(muted)
        let before = try Data(contentsOf: store.primaryURL)
        let loaded = store.load()
        XCTAssertEqual(loaded.state.volumes.master, 0)
        XCTAssertEqual(try Data(contentsOf: store.primaryURL), before)
        try before.write(to: audioDir.appendingPathComponent("settings-muted.json"))
        let reloadedURL = audioDir.appendingPathComponent("settings-reloaded.json")
        if FileManager.default.fileExists(atPath: reloadedURL.path) {
            try FileManager.default.removeItem(at: reloadedURL)
        }
        try FileManager.default.copyItem(at: store.primaryURL, to: reloadedURL)

        let logData = try scene.audioService.exportLogJSON()
        try logData.write(to: audioDir.appendingPathComponent("audio-trigger-log.json"))
        try writeCueIndex(audioDir.appendingPathComponent("audio-cue-index.txt"), events: scene.audioService.events)
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

    private func writeCharacterLineup(to directory: URL) throws {
        let canvas = CGSize(width: 1120, height: 220)
        let scene = SKScene(size: canvas)
        scene.backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
        let defs = CharacterVisualCatalog.allNPC
        for (index, definition) in defs.enumerated() {
            let node = CharacterVisualNode(definition: definition, cellSize: 72, showsTalkBadge: true)
            node.setMotionAllowed(false)
            node.applySnapshotPose(.idle)
            node.position = CGPoint(x: 80 + CGFloat(index) * 150, y: 110)
            scene.addChild(node)
        }
        try writePNG(scene, size: canvas, to: directory.appendingPathComponent("00-seven-characters-idle.png"))

        for definition in defs {
            let node = CharacterVisualNode(definition: definition, cellSize: 96, showsTalkBadge: true)
            node.setMotionAllowed(false)
            node.applySnapshotPose(.idle)
            let slug = definition.characterID.split(separator: ".").last.map(String.init) ?? definition.characterID
            try writePNG(
                node,
                canvas: CGSize(width: 220, height: 260),
                to: directory.appendingPathComponent("char-\(slug)-idle.png")
            )
            node.applySnapshotPose(.walking, walkTilt: 0.14)
            try writePNG(
                node,
                canvas: CGSize(width: 220, height: 260),
                to: directory.appendingPathComponent("char-\(slug)-walk.png")
            )
        }
    }

    private func writeMotionFrames(to directory: URL) throws {
        let apprentice = CharacterVisualCatalog.visual(for: ContentID.waterApprentice)
        let node = CharacterVisualNode(definition: apprentice, cellSize: 96, showsTalkBadge: true)
        node.setMotionAllowed(false)
        node.applySnapshotPose(.idle)
        try writePNG(node, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-walk-0-idle.png"))
        node.applySnapshotPose(.walking, walkTilt: -0.28)
        try writePNG(node, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-walk-1-left.png"))
        node.applySnapshotPose(.walking, walkTilt: 0.28)
        try writePNG(node, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-walk-2-right.png"))

        let player = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: 96,
            showsTalkBadge: false,
            showsName: true
        )
        player.setMotionAllowed(false)
        player.applySnapshotPose(.idle)
        try writePNG(player, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-harvest-0-idle.png"))
        player.applySnapshotPose(.harvesting, harvestLift: 16)
        try writePNG(player, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-harvest-1-lift.png"))
        player.applySnapshotPose(.idle)
        try writePNG(player, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-harvest-2-recover.png"))

        node.applySnapshotPose(.idle)
        try writePNG(node, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-talk-0-idle.png"))
        node.applySnapshotPose(.talking)
        try writePNG(node, canvas: CGSize(width: 240, height: 280), to: directory.appendingPathComponent("motion-talk-1-open.png"))
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

    private func writeCueIndex(_ url: URL, events: [AudioLogEvent]) throws {
        let lines = events.map { event in
            "\(event.timestamp)  \(event.kind)/\(event.name)  gain=\(String(format: "%.2f", event.gain))  \(event.detail)"
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func evidenceDirectory() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["N001_EVIDENCE_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("macos/CreekSprout/CreekSprout.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                let preferred = url.appendingPathComponent("artifacts/integration/n-001-xcode", isDirectory: true)
                if canWrite(to: preferred) {
                    return preferred
                }
                break
            }
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CreekSprout/n-001-export", isDirectory: true)
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
