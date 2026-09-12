import AppKit
import SpriteKit
import XCTest
@testable import CreekSprout

/// Temporary parity harness: renders the authoritative native farm frame at
/// the same viewport the web candidate is screenshotted with, so the web port
/// can be diffed against the source of truth byte for byte.
final class ZZWebParitySnapshotTests: XCTestCase {
    func testCaptureFarmFrameForWebParity() throws {
        print("[parity] start")
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("native-parity", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        print("[parity] dir " + out.path)

        let size = CGSize(width: 1280, height: 800)
        let scene = FarmScene(size: size)
        scene.scaleMode = .resizeFill
        let view = SKView(frame: CGRect(origin: .zero, size: size))
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        print("[parity] scene ready size=\(scene.size) player=\(scene.gameState.position.x),\(scene.gameState.position.y)")

        let state = scene.gameState
        let info = "map=\(state.currentMapID) player=\(state.position.x),\(state.position.y) day=\(state.clock.day)"
        try info.write(
            to: out.appendingPathComponent("native-state.txt"),
            atomically: true,
            encoding: String.Encoding.utf8
        )

        guard let data = PresentationSnapshot.pngData(from: scene, size: size) else {
            print("[parity] pngData returned nil")
            XCTFail("missing native scene snapshot")
            return
        }
        print("[parity] png bytes=\(data.count)")
        try PresentationSnapshot.writePNG(data, to: out.appendingPathComponent("native-farm-1280.png"))
        print("[parity] written")
    }
}
