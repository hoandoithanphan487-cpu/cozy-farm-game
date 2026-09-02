import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CreekSprout

final class N011BuildingPresentationEvidenceTests: XCTestCase {
    func testPlayablePageShowsHDFarmHouseWithDec035CollisionAndPixelRuntime() throws {
        let screenshots = try evidenceDirectory().appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)

        try capturePlayablePage(
            expanded: false,
            size: CGSize(width: 960, height: 640),
            to: screenshots.appendingPathComponent("01-farm-hd-farmhouse-visible.png")
        )
        try capturePlayablePage(
            expanded: true,
            size: CGSize(width: 960, height: 640),
            to: screenshots.appendingPathComponent("03-farm-hd-farmhouse-expanded.png")
        )
        try capturePlayablePage(
            expanded: true,
            size: CGSize(width: 1280, height: 800),
            to: screenshots.appendingPathComponent("04-window-resized-no-stretch.png")
        )

        let scene = FarmScene(size: CGSize(width: 960, height: 640))
        scene.scaleMode = .resizeFill
        scene.applySettings(.defaults)
        XCTAssertEqual(scene.gameState.currentMapID, ContentID.farmHomestead)
        XCTAssertEqual(
            WorldCatalog.farmHomestead.landmarks.first { $0.id == BuildingPresentationCatalog.sampleLandmarkID }?.position,
            GridPosition(x: 3, y: 8)
        )
        XCTAssertEqual(
            WorldCatalog.farmHomestead.building(id: BuildingPresentationCatalog.sampleLandmarkID)?.collisionCells.count,
            19
        )

        walkToward(scene, x: 3, y: 7)
        XCTAssertTrue(scene.tryMove(.up), "farm house door must stay walkable")
        XCTAssertFalse(scene.tryMove(.left), "farm house collision cell (2,8) must be impassable")
        XCTAssertEqual(scene.gameState.position, GridPosition(x: 3, y: 8))
        XCTAssertTrue(scene.tryMove(.down), "farm house door must remain a two-way walkable threshold")

        scene.selectTool(.hoe)
        walkToward(scene, x: 5, y: 4)
        scene.performAction()
        XCTAssertFalse(scene.lastFeedback.isEmpty, "hoe interaction must still produce feedback")

        walkToward(scene, x: 7, y: 0)
        XCTAssertEqual(scene.gameState.position, GridPosition(x: 7, y: 0))
        scene.performAction()
        XCTAssertEqual(scene.gameState.currentMapID, ContentID.creekMarket, scene.lastFeedback)
        walkToward(scene, x: 9, y: 12)
        scene.performAction()
        XCTAssertEqual(scene.gameState.currentMapID, ContentID.farmHomestead, scene.lastFeedback)

        try capturePlayablePage(
            scene: scene,
            expanded: false,
            size: CGSize(width: 960, height: 640),
            to: screenshots.appendingPathComponent("02-interaction-exit-still-works.png")
        )

        try assertRuntimePixelAssetUnchanged()
    }

    private func capturePlayablePage(
        scene: FarmScene? = nil,
        expanded: Bool,
        size: CGSize,
        to url: URL
    ) throws {
        let farm = scene ?? {
            let created = FarmScene(size: size)
            created.scaleMode = .resizeFill
            created.applySettings(.defaults)
            return created
        }()
        let host = N011PlayableHost(scene: farm, expanded: expanded, windowSize: size)
        let window = try makeWindow(root: host, size: size)
        defer { window.close() }
        try capture(window, to: url)
    }

    private func assertRuntimePixelAssetUnchanged() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let assets = testsDir
            .deletingLastPathComponent()
            .appendingPathComponent("CreekSprout/Assets/building_farm_house_base.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: assets.path))
        let image = try XCTUnwrap(NSImage(contentsOf: assets))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        XCTAssertNotEqual(bitmap.pixelsWide, 2048)
        XCTAssertLessThan(bitmap.pixelsWide, 256)
        XCTAssertLessThan(bitmap.pixelsHigh, 256)
    }

    private func makeWindow<Content: View>(root: Content, size: CGSize) throws -> NSWindow {
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setContentSize(size)
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.16))
        return window
    }

    private func capture(_ window: NSWindow, to url: URL) throws {
        guard let view = window.contentView else {
            XCTFail("missing content view for \(url.lastPathComponent)")
            return
        }
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            XCTFail("unable to cache \(url.lastPathComponent)")
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        XCTAssertGreaterThan(data.count, 8_000, url.lastPathComponent)
    }

    private func walkToward(_ scene: FarmScene, x: Int, y: Int) {
        for _ in 0..<24 {
            let pos = scene.gameState.position
            if pos.x == x, pos.y == y { break }
            if pos.x < x { _ = scene.tryMove(.right) }
            else if pos.x > x { _ = scene.tryMove(.left) }
            else if pos.y < y { _ = scene.tryMove(.up) }
            else { _ = scene.tryMove(.down) }
        }
    }

    private func evidenceDirectory() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["N011_EVIDENCE_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("macos/CreekSprout/CreekSprout.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                let preferred = url.appendingPathComponent(
                    "artifacts/integration/n-011-building-sample",
                    isDirectory: true
                )
                if canWrite(to: preferred) {
                    return preferred
                }
                break
            }
        }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-n011-export", isDirectory: true)
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

private struct N011PlayableHost: View {
    let scene: FarmScene
    let expanded: Bool
    let windowSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .frame(width: windowSize.width, height: windowSize.height)

            VStack(alignment: .leading, spacing: 1) {
                Text(scene.hudText(compact: true))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(8)
                    .background(Color(red: 0.05, green: 0.07, blue: 0.06).opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(6)
            .allowsHitTesting(false)
            .frame(maxWidth: 520, alignment: .topLeading)

            if scene.gameState.currentMapID == ContentID.farmHomestead {
                VStack {
                    HStack {
                        Spacer()
                        BuildingPresentationCard(expanded: expanded)
                            .padding(16)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
    }
}
