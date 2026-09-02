//
//  StoryJourneySceneView.swift
//  CreekSprout
//
//  Q08 无损远行的三个剧情专用模态小场景（旧水路 / 雾岭岔路 / 灰栅农场）。
//  Presentation-only: journey-local normalized anchors, local collision rects,
//  paired entry/exit anchors, SKAction-style eased movement and fade-cut scene
//  switches. No A* pathfinding, no GameState mutation from this view.
//

import Combine
import SwiftUI

/// Presentation-only controller for a Q08 journey mini-scene. All coordinates
/// are journey-local normalized points from `StoryAnchorCatalog`. Scene order
/// follows the Q08 checkpoints (old waterway → mist ridge fork → grey fence
/// farm); the presentation layer drives `JourneyService` through the callbacks.
@MainActor
final class StoryJourneySceneController: ObservableObject {
    @Published private(set) var sceneID: String
    @Published private(set) var player: StoryNormalizedPoint
    @Published private(set) var highlightedAnchorID: String?
    @Published private(set) var promptText = ""

    /// True once the current scene's checkpoint was persisted by the domain
    /// layer. The exit anchor stays locked until then.
    @Published private(set) var checkpointResolved = false

    private let catalog = StoryContentCatalog.shared
    private let step: Double = 0.05
    private let interactionRadius: Double = 0.10

    /// Journey scene order, matching `JourneyCheckpointOrder`.
    static let orderedSceneIDs: [String] = [
        StorySceneID.oldWaterway,
        StorySceneID.mistRidgeFork,
        StorySceneID.greygateFarm,
    ]

    init(sceneID: String) {
        self.sceneID = sceneID
        let entry = Self.entryAnchorID(for: sceneID)
        let start = Self.anchors(sceneID: sceneID)
            .first { $0.id == entry }?.point
            ?? StoryNormalizedPoint(x: 0.5, y: 0.5)
        self.player = start
        refreshHighlight()
    }

    /// Marks the current scene's checkpoint as resolved (called by the
    /// presentation layer after `JourneyService.advanceCheckpoint` persisted).
    func markCheckpointResolved() {
        checkpointResolved = true
        refreshHighlight()
    }

    /// Moves to the next scene (checkpoint advanced). Resets the player to the
    /// new scene's entry anchor; the new checkpoint starts unresolved.
    func advanceToNextScene() {
        guard let index = Self.orderedSceneIDs.firstIndex(of: sceneID),
              index + 1 < Self.orderedSceneIDs.count else { return }
        sceneID = Self.orderedSceneIDs[index + 1]
        checkpointResolved = false
        player = startPoint(in: sceneID)
        refreshHighlight()
    }

    /// Moves back to the previous scene (pure presentation; the domain
    /// checkpoint never moves backwards).
    func goBackScene() {
        guard let index = Self.orderedSceneIDs.firstIndex(of: sceneID),
              index > 0 else { return }
        sceneID = Self.orderedSceneIDs[index - 1]
        checkpointResolved = false
        player = startPoint(in: sceneID)
        refreshHighlight()
    }

    /// True when this is the last journey scene (grey fence farm).
    var isFinalScene: Bool {
        sceneID == StorySceneID.greygateFarm
    }

    private func startPoint(in sceneID: String) -> StoryNormalizedPoint {
        let entry = Self.entryAnchorID(for: sceneID)
        return Self.anchors(sceneID: sceneID)
            .first { $0.id == entry }?.point
            ?? StoryNormalizedPoint(x: 0.5, y: 0.5)
    }

    var scene: StoryJourneySceneDefinition? {
        catalog.journeyScenesByID[sceneID]
    }

    var sceneAnchors: [JourneyLocalStoryAnchor] {
        Self.anchors(sceneID: sceneID)
    }

    var highlightedAnchor: JourneyLocalStoryAnchor? {
        guard let highlightedAnchorID else { return nil }
        return sceneAnchors.first { $0.id == highlightedAnchorID }
    }

    /// Moves the player by one eased step; local collision rects block.
    func move(dx: Double, dy: Double) {
        guard let scene else { return }
        var next = StoryNormalizedPoint(
            x: min(0.98, max(0.02, player.x + dx * step)),
            y: min(0.98, max(0.02, player.y + dy * step))
        )
        if scene.localCollision.contains(where: { $0.contains(next) }) {
            // Slide along the blocked axis instead of teleporting through.
            let slideX = StoryNormalizedPoint(x: next.x, y: player.y)
            let slideY = StoryNormalizedPoint(x: player.x, y: next.y)
            if !scene.localCollision.contains(where: { $0.contains(slideX) }) {
                next = slideX
            } else if !scene.localCollision.contains(where: { $0.contains(slideY) }) {
                next = slideY
            } else {
                return
            }
        }
        player = next
        refreshHighlight()
    }

    /// Interact at the highlighted anchor. Returns true when an anchor was
    /// actually acted on (exit → forward, entry → back, interaction → inspect).
    /// The exit anchor stays locked until the scene checkpoint is resolved.
    func interact() -> Bool {
        guard let anchor = highlightedAnchor else { return false }
        switch anchor.purpose {
        case .exit:
            guard checkpointResolved else {
                promptText = "先查看检查点，再从这里离开。"
                return false
            }
            onExit?()
            return true
        case .entry:
            onBack?()
            return true
        case .interaction:
            onInspect?(anchor)
            return true
        default:
            return false
        }
    }

    var onExit: (() -> Void)?
    var onBack: (() -> Void)?
    var onInspect: ((JourneyLocalStoryAnchor) -> Void)?
    var onAbandon: (() -> Void)?

    // MARK: - Presentation helpers

    func anchorLabel(_ anchor: JourneyLocalStoryAnchor) -> String {
        switch anchor.purpose {
        case .entry: return "入口"
        case .exit: return "出口"
        case .interaction: return "检查点"
        case .playerWaypoint: return "路点"
        case .npcStart, .npcExit, .camera, .prop: return ""
        }
    }

    func anchorColor(_ anchor: JourneyLocalStoryAnchor) -> Color {
        switch anchor.purpose {
        case .entry: return .blue.opacity(0.65)
        case .exit: return .green.opacity(0.65)
        case .interaction: return .orange.opacity(0.75)
        case .playerWaypoint: return .white.opacity(0.35)
        case .npcStart, .npcExit, .camera, .prop: return .white.opacity(0.2)
        }
    }

    // MARK: - Private

    private static func entryAnchorID(for sceneID: String) -> String {
        StoryContentCatalog.shared.journeyScenesByID[sceneID]?.entryAnchorID
            ?? "brookseed.story.anchor.journey.unknown.entry"
    }

    private static func anchors(sceneID: String) -> [JourneyLocalStoryAnchor] {
        StoryAnchorCatalog.journeyLocalAnchors.filter { $0.sceneID == sceneID }
    }

    private func refreshHighlight() {
        var nearest: (id: String, distance: Double)?
        for anchor in sceneAnchors {
            guard anchor.purpose == .interaction
                    || anchor.purpose == .entry
                    || anchor.purpose == .exit else { continue }
            let dx = anchor.point.x - player.x
            let dy = anchor.point.y - player.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= interactionRadius,
               nearest == nil || distance < nearest!.distance {
                nearest = (anchor.id, distance)
            }
        }
        highlightedAnchorID = nearest?.id
        if let anchor = highlightedAnchor {
            switch anchor.purpose {
            case .exit:
                promptText = checkpointResolved
                    ? "已到出口 · 空格离开本段"
                    : "先查看检查点，再从这里离开。"
            case .entry:
                promptText = "已到入口 · 空格返回上一段"
            case .interaction:
                promptText = "检查点 · 空格查看"
            default:
                promptText = ""
            }
        } else {
            promptText = "方向键移动 · Esc 返回"
        }
    }
}

/// SwiftUI renderer for a Q08 journey mini-scene. Scene switches fade-cut
/// (opacity transition); movement is eased like an SKAction.
struct StoryJourneySceneView: View {
    @ObservedObject var controller: StoryJourneySceneController
    let scale: CGFloat
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background
                collisionOverlay(in: geometry.size)
                anchorsOverlay(in: geometry.size)
                playerNode(in: geometry.size)
                header
                footer
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.28), value: controller.sceneID)
        .animation(.easeInOut(duration: 0.12), value: controller.player)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("n027.story.journey.layer")
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.16, blue: 0.20),
                Color(red: 0.16, green: 0.22, blue: 0.20),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack {
            HStack {
                Text("旅程 · \(controller.scene?.displayName ?? "未知场景")")
                    .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button("放弃远行") { controller.onAbandon?() }
                    .buttonStyle(.bordered)
                    .focusable(false)
                    .accessibilityIdentifier("n027.story.journey.abandon")
                Button("返回") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
                    .accessibilityIdentifier("n027.story.journey.close")
            }
            .padding(14 * scale)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
            .padding(14 * scale)
            Spacer()
        }
    }

    private var footer: some View {
        VStack {
            Spacer()
            Text(controller.promptText)
                .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 9 * scale)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .accessibilityIdentifier("n027.story.journey.prompt")
                .padding(.bottom, 16 * scale)
        }
    }

    private func collisionOverlay(in size: CGSize) -> some View {
        ForEach(controller.scene?.localCollision ?? [], id: \.minX) { rect in
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(
                    width: (rect.maxX - rect.minX) * size.width,
                    height: (rect.maxY - rect.minY) * size.height
                )
                .position(
                    x: (rect.minX + rect.maxX) / 2 * size.width,
                    y: (rect.minY + rect.maxY) / 2 * size.height
                )
        }
    }

    private func anchorsOverlay(in size: CGSize) -> some View {
        ForEach(controller.sceneAnchors, id: \.id) { anchor in
            let isHighlighted = controller.highlightedAnchorID == anchor.id
            VStack(spacing: 2) {
                Circle()
                    .fill(controller.anchorColor(anchor))
                    .frame(width: (isHighlighted ? 22 : 14) * scale)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHighlighted ? 0.95 : 0.5), lineWidth: 1.5)
                    )
                if !controller.anchorLabel(anchor).isEmpty {
                    Text(controller.anchorLabel(anchor))
                        .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .position(
                x: anchor.point.x * size.width,
                y: anchor.point.y * size.height
            )
            .accessibilityLabel("\(controller.anchorLabel(anchor)) \(anchor.id)")
            .accessibilityIdentifier("n027.story.journey.anchor.\(anchor.id)")
        }
    }

    private func playerNode(in size: CGSize) -> some View {
        let visual = CharacterVisualCatalog.visual(for: CharacterVisualCatalog.playerID)
        return ZStack {
            Circle()
                .fill(Color(cgColor: visual.theme.cgColor))
                .frame(width: 26 * scale, height: 26 * scale)
            Circle()
                .stroke(Color(cgColor: visual.outline.cgColor), lineWidth: 2 * scale)
                .frame(width: 26 * scale, height: 26 * scale)
            Text("新")
                .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .position(
            x: controller.player.x * size.width,
            y: controller.player.y * size.height
        )
        .accessibilityLabel("玩家位置 \(controller.player.x), \(controller.player.y)")
        .accessibilityIdentifier("n027.story.journey.player")
    }
}
