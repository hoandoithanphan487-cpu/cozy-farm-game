import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

final class N004ProcessingEvidenceTests: XCTestCase {
    func testSmokePathCapturesProcessingEvidence() throws {
        let evidence = try evidenceDirectory()
        let screenshots = evidence.appendingPathComponent("screenshots", isDirectory: true)
        let hudDir = evidence.appendingPathComponent("hud", isDirectory: true)
        let saves = evidence.appendingPathComponent("saves", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hudDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)

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
        XCTAssertEqual(scene.gameState.clock.day, 1)
        XCTAssertEqual(scene.gameState.economy.balance, 720)
        XCTAssertTrue(scene.hudText.contains("第 1 天"))
        XCTAssertTrue(scene.hudText.contains("木蜜灶台") || scene.hudText.contains("加工面板"))
        try writeScenePNG(scene, name: "01-newgame.png", to: screenshots)
        try writeHud(scene, name: "01-newgame.txt", to: hudDir)

        scene.selectTool(.harvest)
        walkToward(scene, x: 4, y: 4, thenFace: .down)
        scene.performAction()
        walkToward(scene, x: 5, y: 4, thenFace: .down)
        scene.performAction()
        walkToward(scene, x: 6, y: 4, thenFace: .down)
        scene.performAction()
        XCTAssertEqual(InventoryService.count(scene.gameState.inventory, itemID: ContentID.mistRadishItem), 3)
        scene.depositShipping()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(scene.gameState.economy.shipping.pendingQuantity, 3)
        try writeScenePNG(scene, name: "02-deposit-radish.png", to: screenshots)
        try writeHud(scene, name: "02-deposit.txt", to: hudDir)

        scene.selectTool(.hoe)
        walkToward(scene, x: 2, y: 2, thenFace: .up)
        scene.performAction()
        scene.selectTool(.seed)
        scene.performAction()
        scene.selectTool(.water)
        scene.performAction()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)

        walkToward(scene, x: 8, y: 5, thenFace: .up)
        scene.talkToNpc()
        finishDialogue(scene)
        scene.sleepAndSettle()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(scene.gameState.economy.balance, 894, scene.lastFeedback)
        XCTAssertTrue(scene.lastFeedback.contains("174") || scene.hudText.contains("174"), scene.lastFeedback)
        try writeScenePNG(scene, name: "03-sleep-174-894.png", to: screenshots)
        try writeHud(scene, name: "03-after-sleep.txt", to: hudDir)

        #if DEBUG
        scene.grantDebugMaterials()
        XCTAssertEqual(InventoryService.count(scene.gameState.inventory, itemID: ContentID.creekGreensItem), 2)
        #endif
        var hops = 0
        while scene.gameState.selectedRecipeID != ContentID.woodhoneyHearthRecipe, hops < 12 {
            scene.cycleRecipe()
            hops += 1
        }
        XCTAssertEqual(scene.gameState.selectedRecipeID, ContentID.woodhoneyHearthRecipe)
        scene.craftSelectedRecipe()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(InventoryService.count(scene.gameState.inventory, itemID: ContentID.woodhoneyHearthItem), 1)

        walkToward(scene, x: 14, y: 7, thenFace: .up)
        let hearthBeforeFail = InventoryService.count(scene.gameState.inventory, itemID: ContentID.woodhoneyHearthItem)
        scene.previewPlacement()
        scene.confirmPlacement()
        XCTAssertFalse(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(
            InventoryService.count(scene.gameState.inventory, itemID: ContentID.woodhoneyHearthItem),
            hearthBeforeFail
        )
        try writeScenePNG(scene, name: "04-place-fail.png", to: screenshots)
        try writeHud(scene, name: "04-place-fail.txt", to: hudDir)

        walkToward(scene, x: 9, y: 5, thenFace: .down)
        scene.previewPlacement()
        scene.confirmPlacement()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertTrue(scene.gameState.placedObjects.contains { $0.definitionID == ContentID.woodhoneyHearthObject })
        try writeScenePNG(scene, name: "05-place-hearth.png", to: screenshots)
        try writeHud(scene, name: "05-place-hearth.txt", to: hudDir)

        scene.performAction()
        XCTAssertTrue(scene.isProcessingPanelOpen)
        XCTAssertTrue(scene.lastFeedback.contains("木蜜灶台") || scene.lastFeedback.contains("蜜烤溪叶菜"), scene.lastFeedback)
        XCTAssertTrue(scene.hudText.contains("加工 蜜烤溪叶菜"), scene.hudText)
        scene.craftSelectedRecipe()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertTrue(scene.lastFeedback.contains("✅"), scene.lastFeedback)
        XCTAssertEqual(InventoryService.count(scene.gameState.inventory, itemID: ContentID.creekGreensItem), 1)
        XCTAssertEqual(InventoryService.count(scene.gameState.inventory, itemID: ContentID.honeySearedCreekGreensItem), 1)
        try writeScenePNG(scene, name: "06-process-success.png", to: screenshots)
        try writeHud(scene, name: "06-process-success.txt", to: hudDir)

        let staminaAfterSuccess = scene.gameState.stamina
        let greensAfterSuccess = InventoryService.count(scene.gameState.inventory, itemID: ContentID.creekGreensItem)
        scene.cycleRecipe()
        scene.craftSelectedRecipe()
        XCTAssertFalse(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertTrue(scene.lastFeedback.contains("❌"), scene.lastFeedback)
        XCTAssertEqual(scene.gameState.stamina, staminaAfterSuccess)
        XCTAssertEqual(
            InventoryService.count(scene.gameState.inventory, itemID: ContentID.creekGreensItem),
            greensAfterSuccess
        )
        try writeScenePNG(scene, name: "07-process-fail.png", to: screenshots)
        try writeHud(scene, name: "07-process-fail.txt", to: hudDir)

        scene.depositShipping()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertGreaterThanOrEqual(scene.gameState.economy.shipping.pendingQuantity, 1)
        let savedBalance = scene.gameState.economy.balance
        let savedPending = scene.gameState.economy.shipping.pendingQuantity
        let savedStamina = scene.gameState.stamina
        let savedPlaced = scene.gameState.placedObjects.map(\.definitionID)
        scene.saveGame()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        try copySave(named: "08-save-before-reload.json", to: saves)
        try writeHud(scene, name: "08-before-reload.txt", to: hudDir)

        scene.loadGame()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertEqual(scene.gameState.economy.balance, savedBalance)
        XCTAssertEqual(scene.gameState.economy.shipping.pendingQuantity, savedPending)
        XCTAssertEqual(scene.gameState.stamina, savedStamina)
        XCTAssertEqual(scene.gameState.placedObjects.map(\.definitionID), savedPlaced)
        try copySave(named: "08-save-after-reload.json", to: saves)
        try writeScenePNG(scene, name: "08-reload.png", to: screenshots)
        try writeHud(scene, name: "08-after-reload.txt", to: hudDir)

        scene.sleepAndSettle()
        XCTAssertTrue(scene.lastFeedbackIsSuccess, scene.lastFeedback)
        XCTAssertTrue(
            scene.lastFeedback.contains("蜜烤溪叶菜") || scene.hudText.contains("蜜烤溪叶菜"),
            scene.lastFeedback + "\n" + scene.hudText
        )
        let settledBalance = scene.gameState.economy.balance
        XCTAssertGreaterThan(settledBalance, savedBalance)
        XCTAssertEqual(
            scene.gameState.economy.ledger.filter { $0.reasonID == ContentID.shippingSettleReason }.count,
            2
        )
        try writeScenePNG(scene, name: "09-settle-processed.png", to: screenshots)
        try writeHud(scene, name: "09-settle.txt", to: hudDir)
        scene.saveGame()
        try copySave(named: "09-save-after-sleep.json", to: saves)

        scene.sleepAndSettle()
        XCTAssertEqual(scene.gameState.economy.balance, settledBalance)
        XCTAssertEqual(
            scene.gameState.economy.ledger.filter { $0.reasonID == ContentID.shippingSettleReason }.count,
            2
        )
        try writeHud(scene, name: "09-second-sleep.txt", to: hudDir)

        XCTAssertTrue(scene.hudText.contains("木蜜灶台"))
        XCTAssertTrue(scene.hudText.contains("[C]加工") || scene.hudText.contains("加工面板"))
        XCTAssertEqual(scene.audioService.mapLayer, .farm)
        try writeScenePNG(scene, name: "10-hud-input.png", to: screenshots)
        try writeHud(scene, name: "10-hud-input.txt", to: hudDir)
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

    private func writeHud(_ scene: FarmScene, name: String, to directory: URL) throws {
        try scene.hudText.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func copySave(named name: String, to directory: URL) throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CreekSprout", isDirectory: true)
        let source = appSupport.appendingPathComponent("\(SaveSlotCatalog.manualSlotNames[0]).json")
        if FileManager.default.fileExists(atPath: source.path) {
            let destination = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    private func evidenceDirectory() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["N004_EVIDENCE_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("macos/CreekSprout/CreekSprout.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                let preferred = url.appendingPathComponent("artifacts/integration/n-004-xcode", isDirectory: true)
                if canWrite(to: preferred) {
                    return preferred
                }
                break
            }
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CreekSprout/n-004-export", isDirectory: true)
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
