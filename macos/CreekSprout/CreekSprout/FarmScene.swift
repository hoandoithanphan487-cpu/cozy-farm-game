//
//  FarmScene.swift
//  CreekSprout
//
//  Minimal SpriteKit spike: 10x6 placeholder farm grid and keyboard stepping.
//

import SpriteKit

final class FarmScene: SKScene {
    static let columns = GridPosition.columnCount
    static let rows = GridPosition.rowCount

    private(set) var gameState: GameState

    private let gridRoot = SKNode()
    private let playerNode = SKShapeNode()

    private var didSetup = false
    private var cellSize: CGFloat = 48
    private var gridOrigin = CGPoint.zero

    static func makeDefault() -> FarmScene {
        let scene = FarmScene(size: CGSize(width: 960, height: 640))
        scene.scaleMode = .resizeFill
        scene.anchorPoint = .zero
        return scene
    }

    override init(size: CGSize) {
        gameState = .spikeDefault
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        gameState = .spikeDefault
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        if !didSetup {
            backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
            addChild(gridRoot)
            configurePlayer()
            didSetup = true
        }
        rebuildLayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1, size.height > 1, size != oldSize else { return }
        rebuildLayout()
    }

    @discardableResult
    func tryMove(_ direction: Direction) -> Bool {
        let moved = gameState.move(direction)
        if moved {
            positionPlayer()
        }
        return moved
    }

    private func configurePlayer() {
        playerNode.fillColor = SKColor(red: 0.93, green: 0.78, blue: 0.42, alpha: 1)
        playerNode.strokeColor = SKColor(red: 0.22, green: 0.45, blue: 0.38, alpha: 1)
        playerNode.lineWidth = 3
        playerNode.zPosition = 10
        playerNode.name = "placeholder-dewdrop-walker"
        addChild(playerNode)
    }

    private func rebuildLayout() {
        gridRoot.removeAllChildren()

        let topReserve: CGFloat = 36
        let margin: CGFloat = 32
        let availableWidth = max(size.width - margin * 2, 1)
        let availableHeight = max(size.height - margin * 2 - topReserve, 1)
        cellSize = floor(
            min(
                availableWidth / CGFloat(Self.columns),
                availableHeight / CGFloat(Self.rows)
            )
        )

        let gridWidth = cellSize * CGFloat(Self.columns)
        let gridHeight = cellSize * CGFloat(Self.rows)
        gridOrigin = CGPoint(
            x: (size.width - gridWidth) / 2,
            y: (size.height - gridHeight - topReserve) / 2
        )

        drawGrid()
        refreshPlayerPath()
        positionPlayer()
    }

    private func drawGrid() {
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                let inset = max(cellSize * 0.06, 2)
                let cell = SKShapeNode(
                    rectOf: CGSize(width: cellSize - inset, height: cellSize - inset),
                    cornerRadius: 4
                )
                let isEven = (column + row).isMultiple(of: 2)
                cell.fillColor = isEven
                    ? SKColor(red: 0.45, green: 0.58, blue: 0.36, alpha: 1)
                    : SKColor(red: 0.38, green: 0.50, blue: 0.30, alpha: 1)
                cell.strokeColor = SKColor(red: 0.28, green: 0.36, blue: 0.24, alpha: 1)
                cell.lineWidth = 1
                cell.position = cellCenter(column: column, row: row)
                gridRoot.addChild(cell)
            }
        }
    }

    private func refreshPlayerPath() {
        let radius = max(cellSize * 0.32, 8)
        playerNode.path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
        playerNode.lineWidth = max(cellSize * 0.06, 2)
    }

    private func positionPlayer() {
        playerNode.position = cellCenter(column: gameState.position.x, row: gameState.position.y)
    }

    private func cellCenter(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: gridOrigin.x + (CGFloat(column) + 0.5) * cellSize,
            y: gridOrigin.y + (CGFloat(row) + 0.5) * cellSize
        )
    }
}
