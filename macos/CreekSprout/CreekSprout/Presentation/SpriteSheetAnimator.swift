import SpriteKit

enum CharacterFrameDirection: Int, CaseIterable, Sendable {
    case down = 0
    case left = 1
    case right = 2
    case up = 3

    init(_ direction: Direction) {
        switch direction {
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .up: self = .up
        }
    }
}

/// Presentation-only 4×4 character sheet player. Every completed action
/// returns to frame zero of the character's current facing direction.
final class SpriteSheetAnimator {
    private(set) var facing: CharacterFrameDirection = .down
    private(set) var activeKey: RuntimeArtKey
    let sprite: SKSpriteNode

    private let walkDescriptor: RuntimeArtDescriptor
    private let cellSize: CGFloat
    private let assetStore: PixelAssetStore
    private var motionAllowed: Bool

    init?(
        walkKey: RuntimeArtKey,
        cellSize: CGFloat,
        motionAllowed: Bool,
        assetStore: PixelAssetStore = .shared
    ) {
        let descriptor = RuntimeArtCatalog.descriptor(for: walkKey)
        guard Self.isValidCharacterSheet(descriptor),
              let frames = Self.frameTextures(descriptor: descriptor, assetStore: assetStore),
              let first = frames.first else { return nil }
        self.walkDescriptor = descriptor
        self.activeKey = walkKey
        self.cellSize = cellSize
        self.motionAllowed = motionAllowed
        self.assetStore = assetStore
        sprite = SKSpriteNode(
            texture: first,
            size: PixelMetrics.snap(CGSize(width: cellSize, height: cellSize * 1.5))
        )
        sprite.anchorPoint = CGPoint(x: descriptor.anchor.x, y: descriptor.anchor.y)
        sprite.name = "character-spritesheet"
        sprite.zPosition = RuntimeRenderLayer.actor.rawValue
        sprite.texture?.filteringMode = .nearest
        idle(facing: .down)
    }

    func setMotionAllowed(_ allowed: Bool) {
        motionAllowed = allowed
        if !allowed {
            idle(facing: facing)
        }
    }

    func face(_ nextFacing: CharacterFrameDirection) {
        facing = nextFacing
        if sprite.action(forKey: "character-sheet-animation") == nil {
            idle(facing: nextFacing)
        }
    }

    func idle(facing nextFacing: CharacterFrameDirection) {
        facing = nextFacing
        activeKey = walkDescriptor.key
        sprite.removeAction(forKey: "character-sheet-animation")
        if let texture = Self.frameTextures(
            descriptor: walkDescriptor,
            direction: nextFacing,
            assetStore: assetStore
        )?.first {
            texture.filteringMode = .nearest
            sprite.texture = texture
        }
    }

    func playWalk(facing nextFacing: CharacterFrameDirection) {
        facing = nextFacing
        activeKey = walkDescriptor.key
        guard motionAllowed,
              let frames = Self.frameTextures(
                descriptor: walkDescriptor,
                direction: nextFacing,
                assetStore: assetStore
              ), frames.count == 4 else {
            idle(facing: nextFacing)
            return
        }
        let animate = SKAction.animate(with: frames, timePerFrame: 0.075, resize: false, restore: false)
        sprite.run(.sequence([
            animate,
            .run { [weak self] in
                guard let self else { return }
                self.idle(facing: self.facing)
            },
        ]), withKey: "character-sheet-animation")
    }

    /// Returns false when the requested action sheet is unavailable or
    /// malformed. Callers can then retain the established procedural pulse.
    @discardableResult
    func playAction(key: RuntimeArtKey, facing nextFacing: CharacterFrameDirection) -> Bool {
        let descriptor = RuntimeArtCatalog.descriptor(for: key)
        guard Self.isValidCharacterSheet(descriptor),
              let frames = Self.frameTextures(
                descriptor: descriptor,
                direction: nextFacing,
                assetStore: assetStore
              ), frames.count == 4 else {
            idle(facing: nextFacing)
            return false
        }
        facing = nextFacing
        activeKey = key
        guard motionAllowed else {
            sprite.texture = frames[0]
            return true
        }
        let animate = SKAction.animate(with: frames, timePerFrame: 0.09, resize: false, restore: false)
        sprite.run(.sequence([
            animate,
            .run { [weak self] in
                guard let self else { return }
                self.idle(facing: self.facing)
            },
        ]), withKey: "character-sheet-animation")
        return true
    }

    static func isValidCharacterSheet(_ descriptor: RuntimeArtDescriptor) -> Bool {
        descriptor.frameGrid == .fourDirectionsFourFrames
            && descriptor.nativeSize.width > 0
            && descriptor.nativeSize.height > 0
            && Int(descriptor.nativeSize.width) % descriptor.frameGrid.columns == 0
            && Int(descriptor.nativeSize.height) % descriptor.frameGrid.rows == 0
            && descriptor.frameSize == PixelMetrics.characterNative
            && descriptor.anchor == .bottomCenter
    }

    /// SpriteKit texture rectangles use a bottom-left origin while the source
    /// art direction rows are authored top-to-bottom.
    static func normalizedFrameRect(
        column: Int,
        direction: CharacterFrameDirection,
        grid: RuntimeFrameGrid = .fourDirectionsFourFrames
    ) -> CGRect? {
        guard column >= 0, column < grid.columns,
              direction.rawValue >= 0, direction.rawValue < grid.rows else { return nil }
        let width = 1 / CGFloat(grid.columns)
        let height = 1 / CGFloat(grid.rows)
        return CGRect(
            x: CGFloat(column) * width,
            y: 1 - CGFloat(direction.rawValue + 1) * height,
            width: width,
            height: height
        )
    }

    static func frameTextures(
        descriptor: RuntimeArtDescriptor,
        direction: CharacterFrameDirection? = nil,
        assetStore: PixelAssetStore = .shared
    ) -> [SKTexture]? {
        guard isValidCharacterSheet(descriptor),
              let sheet = assetStore.texture(descriptor: descriptor) else { return nil }
        let directions = direction.map { [$0] } ?? CharacterFrameDirection.allCases
        return directions.flatMap { row in
            (0..<descriptor.frameGrid.columns).compactMap { column in
                guard let rect = normalizedFrameRect(
                    column: column,
                    direction: row,
                    grid: descriptor.frameGrid
                ) else { return nil }
                let frame = SKTexture(rect: rect, in: sheet)
                frame.filteringMode = .nearest
                return frame
            }
        }
    }
}
