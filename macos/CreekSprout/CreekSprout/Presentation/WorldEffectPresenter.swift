import SpriteKit

enum WorldEffectPresenter {
    static let animationActionKey = "runtime-art-animation"
    static let transientNodeName = "transient-world-fx"

    static func makeAnimatedSprite(
        keys: [RuntimeArtKey],
        cellSize: CGFloat,
        timePerFrame: TimeInterval,
        loops: Bool,
        motionAllowed: Bool,
        name: String,
        assetStore: PixelAssetStore = .shared
    ) -> SKSpriteNode? {
        let descriptors = keys.map { RuntimeArtCatalog.descriptor(for: $0) }
        let textures = descriptors.compactMap { assetStore.texture(descriptor: $0) }
        guard textures.count == descriptors.count,
              let first = textures.first,
              let descriptor = descriptors.first else { return nil }
        let scale = PixelMetrics.integerScale(cellSize: cellSize)
        let sprite = SKSpriteNode(
            texture: first,
            size: CGSize(
                width: descriptor.nativeSize.width * scale,
                height: descriptor.nativeSize.height * scale
            )
        )
        sprite.anchorPoint = CGPoint(x: descriptor.anchor.x, y: descriptor.anchor.y)
        sprite.name = name
        sprite.zPosition = descriptor.renderLayer.rawValue
        for texture in textures { texture.filteringMode = .nearest }
        guard motionAllowed, textures.count > 1 else { return sprite }
        let animation = SKAction.animate(
            with: textures,
            timePerFrame: timePerFrame,
            resize: false,
            restore: false
        )
        sprite.run(loops ? .repeatForever(animation) : animation, withKey: animationActionKey)
        return sprite
    }

    @discardableResult
    static func addTransient(
        keys: [RuntimeArtKey],
        at position: CGPoint,
        to parent: SKNode,
        cellSize: CGFloat,
        motionAllowed: Bool,
        assetStore: PixelAssetStore = .shared
    ) -> SKSpriteNode? {
        guard let sprite = makeAnimatedSprite(
            keys: keys,
            cellSize: cellSize,
            timePerFrame: 0.08,
            loops: false,
            motionAllowed: motionAllowed,
            name: transientNodeName,
            assetStore: assetStore
        ) else { return nil }
        sprite.position = position
        parent.addChild(sprite)
        let lifetime = motionAllowed ? 0.08 * Double(max(keys.count, 1)) : 0.12
        sprite.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]), withKey: "transient-cleanup")
        return sprite
    }
}
