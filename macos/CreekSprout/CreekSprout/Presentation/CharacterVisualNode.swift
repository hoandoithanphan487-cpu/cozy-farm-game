import SpriteKit

/// Character presentation: pixel texture when `Assets/char_<id>.png` exists,
/// otherwise the N-001 SKShapeNode procedural look. Motion stays SKAction.
final class CharacterVisualNode: SKNode {
    let definition: CharacterVisualDefinition

    private let bodyRoot = SKNode()
    private let faceRoot = SKNode()
    private var talkBadge: SKShapeNode?
    private var talkBadgeLabel: SKLabelNode?
    private var currentExpression: CharacterExpression = .idle
    private var laidOutCellSize: CGFloat = 0
    private var motionAllowed = true
    private let assetStore: PixelAssetStore
    private var sheetAnimator: SpriteSheetAnimator?
    private var idleSprite: SKSpriteNode?
    private var facing: CharacterFrameDirection = .down

    private let showsName: Bool

    /// True when this node is drawing `SKSpriteNode` from the pixel pipeline.
    var usesPixelTexture: Bool {
        sheetAnimator != nil || bodyRoot.childNode(withName: "pixel-sprite") != nil
    }

    init(
        definition: CharacterVisualDefinition,
        cellSize: CGFloat,
        showsTalkBadge: Bool,
        showsName: Bool = true,
        assetStore: PixelAssetStore = .shared
    ) {
        self.definition = definition
        self.showsName = showsName
        self.assetStore = assetStore
        super.init()
        name = definition.characterID
        addChild(bodyRoot)
        addChild(faceRoot)
        if showsTalkBadge {
            let badge = SKShapeNode()
            badge.name = "talk-badge"
            addChild(badge)
            talkBadge = badge
            let label = SKLabelNode(text: "谈")
            label.name = "talk-badge-label"
            label.fontName = "PingFangSC-Semibold"
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
            talkBadgeLabel = label
        }
        layout(cellSize: cellSize)
        startIdleBob()
        startAmbientWalk()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CharacterVisualNode is code-created only")
    }

    func setMotionAllowed(_ allowed: Bool) {
        motionAllowed = allowed
        sheetAnimator?.setMotionAllowed(allowed)
        if allowed {
            startIdleBob()
            startBadgePulse()
            startAmbientWalk()
        } else {
            bodyRoot.removeAction(forKey: "idle-bob")
            talkBadge?.removeAction(forKey: "badge-pulse")
            removeAction(forKey: "ambient-walk")
            showIdlePose()
            bodyRoot.zRotation = 0
            bodyRoot.setScale(1)
            talkBadge?.setScale(1)
        }
    }

    func layout(cellSize: CGFloat) {
        guard abs(cellSize - laidOutCellSize) > 0.5 else { return }
        laidOutCellSize = cellSize
        rebuildShapes(cellSize: cellSize)
        applyExpression(currentExpression, cellSize: cellSize)
    }

    func setTalking(_ talking: Bool) {
        let next: CharacterExpression = talking ? .talking : .idle
        let changed = currentExpression != next
        applyExpression(next, cellSize: laidOutCellSize)
        if talking, changed {
            playBadgeEmphasis()
        }
    }

    /// Keeps identity and interaction markers local to the player's focus.
    /// The character sprite itself remains visible at every distance.
    func setContextVisibility(nameVisible: Bool, badgeVisible: Bool) {
        childNode(withName: "display-name")?.isHidden = !nameVisible
        childNode(withName: "display-name-plate")?.isHidden = !nameVisible
        talkBadge?.isHidden = !badgeVisible
        talkBadgeLabel?.isHidden = !badgeVisible
    }

    func setFacing(_ direction: Direction) {
        facing = CharacterFrameDirection(direction)
        sheetAnimator?.face(facing)
    }

    func playWalkSway(direction: Direction? = nil) {
        if let direction {
            facing = CharacterFrameDirection(direction)
        }
        if let sheetAnimator {
            applyExpression(.walking, cellSize: laidOutCellSize)
            showMotionSheet()
            sheetAnimator.playWalk(facing: facing)
            run(.sequence([
                .wait(forDuration: 0.34),
                .run { [weak self] in self?.showIdlePose() },
            ]), withKey: "restore-idle")
            return
        }
        applyExpression(.walking, cellSize: laidOutCellSize)
        let sway = laidOutCellSize * 0.04
        let tilt: CGFloat = 0.12
        let action = SKAction.sequence([
            SKAction.group([
                SKAction.rotate(toAngle: tilt, duration: 0.08),
                SKAction.moveBy(x: -sway, y: 0, duration: 0.08),
            ]),
            SKAction.group([
                SKAction.rotate(toAngle: -tilt, duration: 0.16),
                SKAction.moveBy(x: sway * 2, y: 0, duration: 0.16),
            ]),
            SKAction.group([
                SKAction.rotate(toAngle: 0, duration: 0.08),
                SKAction.moveBy(x: -sway, y: 0, duration: 0.08),
            ]),
            SKAction.run { [weak self] in
                self?.applyExpression(.idle, cellSize: self?.laidOutCellSize ?? 48)
            },
        ])
        bodyRoot.removeAction(forKey: "walk")
        bodyRoot.run(action, withKey: "walk")
    }

    @discardableResult
    func playPlayerAction(event: String?, direction: Direction) -> Bool {
        facing = CharacterFrameDirection(direction)
        guard let key = RuntimeArtCatalog.playerActionKey(for: event),
              let sheetAnimator else { return false }
        applyExpression(event == "harvested" ? .harvesting : .walking, cellSize: laidOutCellSize)
        showMotionSheet()
        let played = sheetAnimator.playAction(key: key, facing: facing)
        if played {
            run(.sequence([
                .wait(forDuration: 0.42),
                .run { [weak self] in self?.showIdlePose() },
            ]), withKey: "restore-idle")
        } else {
            showIdlePose()
        }
        return played
    }

    func playHarvestPulse() {
        applyExpression(.harvesting, cellSize: laidOutCellSize)
        let lift = laidOutCellSize * 0.18
        let action = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.12, duration: 0.08),
                SKAction.moveBy(x: 0, y: lift, duration: 0.08),
            ]),
            SKAction.wait(forDuration: 0.06),
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.12),
                SKAction.moveBy(x: 0, y: -lift, duration: 0.12),
            ]),
            SKAction.run { [weak self] in
                self?.applyExpression(.idle, cellSize: self?.laidOutCellSize ?? 48)
            },
        ])
        bodyRoot.removeAction(forKey: "harvest")
        bodyRoot.run(action, withKey: "harvest")
    }

    private func showIdlePose() {
        idleSprite?.isHidden = false
        if idleSprite != nil {
            sheetAnimator?.sprite.isHidden = true
        }
        sheetAnimator?.idle(facing: facing)
        applyExpression(.idle, cellSize: laidOutCellSize)
    }

    private func showMotionSheet() {
        guard sheetAnimator != nil else { return }
        idleSprite?.isHidden = true
        sheetAnimator?.sprite.isHidden = false
    }

    private func startAmbientWalk() {
        guard showsName, motionAllowed else { return }
        removeAction(forKey: "ambient-walk")
        let delay = 3.6 + Double((UInt(bitPattern: definition.characterID.hashValue) % 17)) * 0.12
        run(.repeatForever(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentExpression != .talking else { return }
                let facings: [Direction] = [.down, .left, .right, .up]
                let next = facings[Int(UInt(bitPattern: self.definition.characterID.hashValue) % 4)]
                self.playWalkSway(direction: next)
            },
        ])), withKey: "ambient-walk")
    }

    /// Snapshot pose without running SKAction (for evidence frames).
    func applySnapshotPose(_ expression: CharacterExpression, walkTilt: CGFloat = 0, harvestLift: CGFloat = 0) {
        bodyRoot.removeAllActions()
        bodyRoot.zRotation = walkTilt
        bodyRoot.position = CGPoint(x: 0, y: harvestLift)
        bodyRoot.setScale(harvestLift > 0 ? 1.12 : 1)
        applyExpression(expression, cellSize: laidOutCellSize)
    }

    // MARK: - Build

    private func rebuildShapes(cellSize: CGFloat) {
        bodyRoot.removeAllChildren()
        sheetAnimator = nil
        idleSprite = nil
        if let kind = PixelAssetCatalog.characterKind(for: definition.characterID),
           let sprite = assetStore.makeSprite(kind: kind, cellSize: cellSize) {
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.size = PixelMetrics.snap(CGSize(width: cellSize, height: cellSize * 1.5))
            sprite.position = CGPoint(x: 0, y: -cellSize / 2)
            sprite.zPosition = 1
            sprite.name = "pixel-sprite"
            idleSprite = sprite
            bodyRoot.addChild(sprite)
        }
        if let walkKey = RuntimeArtCatalog.walkKey(for: definition.characterID),
           let animator = SpriteSheetAnimator(
                walkKey: walkKey,
                cellSize: cellSize,
                motionAllowed: motionAllowed,
                assetStore: assetStore
           ) {
            animator.sprite.position = CGPoint(x: 0, y: -cellSize / 2)
            animator.sprite.isHidden = idleSprite != nil
            sheetAnimator = animator
            bodyRoot.addChild(animator.sprite)
            animator.idle(facing: facing)
        }
        if idleSprite == nil && sheetAnimator == nil {
            rebuildProceduralBody(cellSize: cellSize)
        }

        if let badge = talkBadge, let label = talkBadgeLabel {
            let badgeSize = CGSize(width: max(14, cellSize * 0.32), height: max(11, cellSize * 0.22))
            badge.path = CGPath(
                roundedRect: CGRect(
                    x: -badgeSize.width / 2,
                    y: -badgeSize.height / 2,
                    width: badgeSize.width,
                    height: badgeSize.height
                ),
                cornerWidth: 2,
                cornerHeight: 2,
                transform: nil
            )
            badge.fillColor = SKColor(red: 0.95, green: 0.82, blue: 0.28, alpha: 1)
            badge.strokeColor = SKColor(red: 0.42, green: 0.32, blue: 0.05, alpha: 1)
            badge.lineWidth = 1
            badge.position = CGPoint(x: cellSize * 0.30, y: cellSize * 0.34)
            badge.zPosition = 4
            label.fontSize = max(9, cellSize * 0.18)
            label.fontColor = SKColor(red: 0.22, green: 0.16, blue: 0.05, alpha: 1)
            label.position = badge.position
            label.zPosition = 5
            startBadgePulse()
        }

        if showsName {
            let name = childNode(withName: "display-name") as? SKLabelNode ?? {
                let node = SKLabelNode()
                node.name = "display-name"
                node.fontName = "PingFangSC-Semibold"
                node.fontColor = SKColor.white
                node.verticalAlignmentMode = .center
                addChild(node)
                return node
            }()
            name.text = definition.displayName
            name.fontSize = max(8, min(11, cellSize * 0.16))
            name.fontColor = SKColor(red: 0.98, green: 0.96, blue: 0.88, alpha: 1)
            name.horizontalAlignmentMode = .center
            name.position = CGPoint(x: 0, y: cellSize * 0.58)
            name.zPosition = 6
            let plate = childNode(withName: "display-name-plate") as? SKShapeNode ?? {
                let node = SKShapeNode()
                node.name = "display-name-plate"
                addChild(node)
                return node
            }()
            let plateSize = CGSize(width: max(36, name.frame.width + 10), height: max(12, name.fontSize + 6))
            plate.path = CGPath(
                roundedRect: CGRect(x: -plateSize.width / 2, y: -plateSize.height / 2, width: plateSize.width, height: plateSize.height),
                cornerWidth: 4,
                cornerHeight: 4,
                transform: nil
            )
            plate.fillColor = SKColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 0.72)
            plate.strokeColor = SKColor(white: 1, alpha: 0.12)
            plate.lineWidth = 1
            plate.position = name.position
            plate.zPosition = 5
        }
    }

    private func rebuildProceduralBody(cellSize: CGFloat) {
        let bodyWidth = max(14, cellSize * 0.38)
        let bodyHeight = max(18, cellSize * 0.46)
        let tunic = SKShapeNode(rectOf: CGSize(width: bodyWidth, height: bodyHeight), cornerRadius: 4)
        tunic.fillColor = definition.theme.skColor
        tunic.strokeColor = definition.outline.skColor
        tunic.lineWidth = 2
        tunic.position = CGPoint(x: 0, y: -2)
        tunic.name = "tunic"
        bodyRoot.addChild(tunic)

        let headRadius = max(6, cellSize * 0.15)
        let head = SKShapeNode(circleOfRadius: headRadius)
        head.fillColor = SKColor(red: 0.96, green: 0.86, blue: 0.70, alpha: 1)
        head.strokeColor = definition.outline.skColor
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: cellSize * 0.30)
        head.name = "head"
        bodyRoot.addChild(head)

        let hair = makeHairNode(cellSize: cellSize, headRadius: headRadius)
        hair.position = CGPoint(x: 0, y: cellSize * 0.30)
        hair.name = "hair"
        bodyRoot.addChild(hair)
    }

    private func makeHairNode(cellSize: CGFloat, headRadius: CGFloat) -> SKShapeNode {
        let path = HairPathBuilder.path(for: definition.silhouette, radius: headRadius)
        let node = SKShapeNode(path: path)
        node.fillColor = definition.hair.skColor
        node.strokeColor = definition.outline.skColor
        node.lineWidth = 1.2
        if definition.silhouette == .wardenCap || definition.silhouette == .copperClipCrop {
            let accent = SKShapeNode(circleOfRadius: max(2, cellSize * 0.05))
            accent.fillColor = SKColor(red: 0.78, green: 0.48, blue: 0.22, alpha: 1)
            accent.strokeColor = SKColor(red: 0.42, green: 0.24, blue: 0.08, alpha: 1)
            accent.position = HairPathBuilder.accentOffset(for: definition.silhouette, radius: headRadius)
            node.addChild(accent)
        }
        return node
    }

    private func applyExpression(_ expression: CharacterExpression, cellSize: CGFloat) {
        currentExpression = expression
        faceRoot.removeAllChildren()
        if usesPixelTexture {
            if let sprite = bodyRoot.childNode(withName: "pixel-sprite") {
                // Pixel sheets must stay at an integer scale. The former 1.06
                // talking pulse forced texels onto fractional screen pixels
                // and made otherwise-nearest sprites look soft.
                sprite.setScale(1)
            }
            return
        }
        guard cellSize > 1 else { return }
        let y = cellSize * 0.30
        let eyeY = y + cellSize * 0.02
        let eyeSpread = cellSize * 0.07
        let eyeRadius: CGFloat
        switch expression {
        case .harvesting: eyeRadius = max(1.2, cellSize * 0.022)
        case .talking, .listening: eyeRadius = max(1.6, cellSize * 0.032)
        case .idle, .walking: eyeRadius = max(1.4, cellSize * 0.028)
        }
        let left = SKShapeNode(circleOfRadius: eyeRadius)
        left.fillColor = SKColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1)
        left.strokeColor = .clear
        left.position = CGPoint(x: -eyeSpread, y: eyeY)
        let right = SKShapeNode(circleOfRadius: eyeRadius)
        right.fillColor = left.fillColor
        right.strokeColor = .clear
        right.position = CGPoint(x: eyeSpread, y: eyeY)
        faceRoot.addChild(left)
        faceRoot.addChild(right)

        let mouth: SKShapeNode
        switch expression {
        case .talking:
            mouth = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.10, height: cellSize * 0.08))
        case .harvesting:
            mouth = SKShapeNode(rectOf: CGSize(width: cellSize * 0.10, height: max(1.5, cellSize * 0.02)), cornerRadius: 1)
        case .listening:
            mouth = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.09, height: cellSize * 0.04))
        case .idle, .walking:
            mouth = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.09, height: cellSize * 0.03))
        }
        mouth.fillColor = SKColor(red: 0.55, green: 0.28, blue: 0.28, alpha: 1)
        mouth.strokeColor = .clear
        mouth.position = CGPoint(x: 0, y: y - cellSize * 0.06)
        faceRoot.addChild(mouth)
        faceRoot.zPosition = 3
    }

    private func startIdleBob() {
        guard motionAllowed, !usesPixelTexture else { return }
        bodyRoot.removeAction(forKey: "idle-bob")
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 1.5, duration: 0.7),
            SKAction.moveBy(x: 0, y: -1.5, duration: 0.7),
        ])
        bodyRoot.run(.repeatForever(bob), withKey: "idle-bob")
    }

    private func startBadgePulse() {
        guard motionAllowed, let badge = talkBadge else { return }
        badge.removeAction(forKey: "badge-pulse")
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.45),
        ])
        badge.run(.repeatForever(pulse), withKey: "badge-pulse")
    }

    private func playBadgeEmphasis() {
        guard let badge = talkBadge else { return }
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.22, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.12),
        ])
        badge.run(pop, withKey: "badge-pop")
    }
}

enum HairPathBuilder {
    static func path(for silhouette: HairSilhouette, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        switch silhouette {
        case .copperClipCrop:
            path.addEllipse(in: CGRect(x: -radius * 1.05, y: -radius * 0.15, width: radius * 2.1, height: radius * 1.45))
        case .seedBun:
            path.addEllipse(in: CGRect(x: -radius * 1.05, y: -radius * 0.2, width: radius * 2.1, height: radius * 1.35))
            path.addEllipse(in: CGRect(x: -radius * 0.45, y: radius * 0.7, width: radius * 0.9, height: radius * 0.75))
        case .wardenCap:
            path.addRoundedRect(
                in: CGRect(x: -radius * 1.35, y: radius * 0.05, width: radius * 2.7, height: radius * 0.55),
                cornerWidth: 3,
                cornerHeight: 3
            )
            path.addRoundedRect(
                in: CGRect(x: -radius * 0.95, y: radius * 0.35, width: radius * 1.9, height: radius * 0.85),
                cornerWidth: 4,
                cornerHeight: 4
            )
        case .coiledKnot:
            path.addEllipse(in: CGRect(x: -radius * 1.1, y: -radius * 0.25, width: radius * 2.2, height: radius * 1.4))
            path.addEllipse(in: CGRect(x: radius * 0.35, y: radius * 0.35, width: radius * 0.85, height: radius * 0.85))
        case .lampSpike:
            path.move(to: CGPoint(x: -radius * 1.05, y: -radius * 0.1))
            path.addLine(to: CGPoint(x: -radius * 0.7, y: radius * 1.35))
            path.addLine(to: CGPoint(x: -radius * 0.15, y: radius * 0.55))
            path.addLine(to: CGPoint(x: 0, y: radius * 1.55))
            path.addLine(to: CGPoint(x: radius * 0.2, y: radius * 0.55))
            path.addLine(to: CGPoint(x: radius * 0.75, y: radius * 1.25))
            path.addLine(to: CGPoint(x: radius * 1.05, y: -radius * 0.1))
            path.closeSubpath()
        case .inkPart:
            path.move(to: CGPoint(x: -radius * 1.15, y: radius * 0.15))
            path.addLine(to: CGPoint(x: -radius * 0.15, y: radius * 1.15))
            path.addLine(to: CGPoint(x: 0, y: radius * 0.55))
            path.addLine(to: CGPoint(x: radius * 1.1, y: radius * 1.05))
            path.addLine(to: CGPoint(x: radius * 1.15, y: -radius * 0.05))
            path.addLine(to: CGPoint(x: -radius * 1.15, y: -radius * 0.15))
            path.closeSubpath()
        case .willowFall:
            path.addEllipse(in: CGRect(x: -radius * 1.15, y: -radius * 0.35, width: radius * 2.3, height: radius * 1.55))
            path.addRoundedRect(
                in: CGRect(x: radius * 0.35, y: -radius * 1.35, width: radius * 0.55, height: radius * 1.2),
                cornerWidth: 4,
                cornerHeight: 4
            )
            path.addRoundedRect(
                in: CGRect(x: -radius * 0.95, y: -radius * 1.15, width: radius * 0.4, height: radius * 0.9),
                cornerWidth: 3,
                cornerHeight: 3
            )
        case .mossTuft:
            path.addEllipse(in: CGRect(x: -radius * 1.0, y: 0, width: radius * 2.0, height: radius * 1.15))
            path.addEllipse(in: CGRect(x: -radius * 0.35, y: radius * 0.7, width: radius * 0.7, height: radius * 0.5))
        }
        return path
    }

    static func accentOffset(for silhouette: HairSilhouette, radius: CGFloat) -> CGPoint {
        switch silhouette {
        case .copperClipCrop: return CGPoint(x: radius * 0.7, y: radius * 0.15)
        case .wardenCap: return CGPoint(x: 0, y: radius * 0.7)
        default: return .zero
        }
    }
}
