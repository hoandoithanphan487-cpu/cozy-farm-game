import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CreekSprout

@MainActor
final class N015RuntimeVisualEvidenceTests: XCTestCase {
    func testExportsCombinedRuntimeAndPresentationEvidence() throws {
        let root = try evidenceDirectory()
        let runtime = root.appendingPathComponent("runtime-screenshots", isDirectory: true)
        let characters = root.appendingPathComponent("b2", isDirectory: true)
        let buildings = root.appendingPathComponent("building", isDirectory: true)
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: characters, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildings, withIntermediateDirectories: true)

        var farmHouseState = GameState.vs0NewGame()
        farmHouseState.position = GridPosition(x: 2, y: 5)
        farmHouseState.facing = .left
        try capturePlayable(
            state: farmHouseState,
            compact: true,
            size: CGSize(width: 960, height: 640),
            to: runtime.appendingPathComponent("01-compact-hud-farmhouse-960x640.png")
        )
        try capturePlayable(
            state: farmHouseState,
            compact: false,
            size: CGSize(width: 960, height: 640),
            to: runtime.appendingPathComponent("02-expanded-debug-hud-960x640.png")
        )

        var restored = GameState.vs0NewGame()
        restored.position = GridPosition(x: 8, y: 4)
        restored.facing = .up
        restored.watershed = WatershedState(
            restorationPoints: ContentID.watershedThreshold,
            unlockedNodes: [],
            completedProjects: [],
            appliedContributionIDs: []
        )
        try capturePlayable(
            state: restored,
            compact: true,
            size: CGSize(width: 1280, height: 800),
            to: runtime.appendingPathComponent("03-restored-water-sluice-1280x800.png")
        )

        var market = restored
        market.currentMapID = ContentID.creekMarket
        market.position = GridPosition(x: 2, y: 0)
        market.facing = .left
        try capturePlayable(
            state: market,
            compact: true,
            size: CGSize(width: 1280, height: 800),
            to: runtime.appendingPathComponent("04-market-water-wharf-1280x800.png")
        )

        try capturePlayerFrames(to: characters)
        for (index, entry) in BuildingPresentationCatalog.entries.enumerated() {
            try captureView(
                BuildingPresentationCard(expanded: true, landmarkID: entry.landmarkID)
                    .frame(width: 400, height: 440)
                    .background(Color(red: 0.12, green: 0.17, blue: 0.15)),
                size: CGSize(width: 400, height: 440),
                to: buildings.appendingPathComponent(
                    String(format: "%02d-%@.png", index + 1, entry.assetName)
                )
            )
        }
    }

    private func capturePlayable(
        state: GameState,
        compact: Bool,
        size: CGSize,
        to url: URL
    ) throws {
        let scene = FarmScene(size: size)
        scene.scaleMode = .resizeFill
        #if DEBUG
        scene.installN015PresentationEvidenceState(state)
        #endif
        scene.applySettings(.defaults)
        let runtimeView = SKView(frame: CGRect(origin: .zero, size: size))
        let runtimeWindow = NSWindow(
            contentRect: runtimeView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        runtimeWindow.isReleasedWhenClosed = false
        runtimeWindow.contentView = runtimeView
        runtimeWindow.orderBack(nil)
        runtimeView.presentScene(scene)
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        let runtimeData = try XCTUnwrap(PresentationSnapshot.pngData(from: scene, size: size))
        let runtimeImage = try XCTUnwrap(NSImage(data: runtimeData))
        runtimeWindow.close()
        let host = N015PlayableEvidenceHost(
            scene: scene,
            runtimeImage: runtimeImage,
            compact: compact,
            size: size
        )
        try captureView(host, size: size, to: url, settle: 0.20)
    }

    private func capturePlayerFrames(to directory: URL) throws {
        let size = CGSize(width: 260, height: 300)
        for direction in CharacterFrameDirection.allCases {
            let animator = try XCTUnwrap(SpriteSheetAnimator(
                walkKey: .charPlayerWalk,
                cellSize: 72,
                motionAllowed: false
            ))
            animator.idle(facing: direction)
            try captureNode(
                animator.sprite,
                canvas: size,
                to: directory.appendingPathComponent("player-idle-\(direction.rawValue).png")
            )
        }
        for key in [
            RuntimeArtKey.charPlayerActionHoe,
            .charPlayerActionWateringCan,
            .charPlayerActionHarvestGlove,
        ] {
            let animator = try XCTUnwrap(SpriteSheetAnimator(
                walkKey: .charPlayerWalk,
                cellSize: 72,
                motionAllowed: false
            ))
            XCTAssertTrue(animator.playAction(key: key, facing: .down))
            try captureNode(
                animator.sprite,
                canvas: size,
                to: directory.appendingPathComponent("player-action-\(key.rawValue).png")
            )
        }
    }

    private func captureNode(_ node: SKNode, canvas: CGSize, to url: URL) throws {
        let data = try XCTUnwrap(PresentationSnapshot.pngData(
            from: node,
            canvas: canvas,
            background: SKColor(red: 0.12, green: 0.17, blue: 0.15, alpha: 1)
        ))
        try data.write(to: url, options: .atomic)
        XCTAssertGreaterThan(data.count, 1_000)
    }

    private func captureView<Content: View>(
        _ view: Content,
        size: CGSize,
        to url: URL,
        settle: TimeInterval = 0.08
    ) throws {
        let hosting = NSHostingView(rootView: view)
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
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        let bounds = hosting.bounds
        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: bounds))
        hosting.cacheDisplay(in: bounds, to: rep)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: url, options: .atomic)
        XCTAssertGreaterThan(data.count, 8_000, url.lastPathComponent)
    }

    private func evidenceDirectory() throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "CreekSprout-n015-visual-evidence",
            isDirectory: true
        )
    }
}

private struct N015PlayableEvidenceHost: View {
    let scene: FarmScene
    let runtimeImage: NSImage
    let compact: Bool
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: runtimeImage)
                .resizable()
                .interpolation(.none)
                .frame(width: size.width, height: size.height)
            if compact {
                CompactFarmHudView(state: scene.hudPresentationState, scale: 1)
                    .allowsHitTesting(false)
            } else {
                Text(scene.hudText(compact: false))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(10)
                    .frame(maxWidth: 690, alignment: .topLeading)
            }
            if let landmarkID = scene.buildingPresentationLandmarkID {
                VStack {
                    HStack {
                        Spacer()
                        BuildingPresentationCard(expanded: false, landmarkID: landmarkID)
                            .padding(.top, 76)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
