struct GameState: Equatable, Sendable {
    var position: GridPosition
    var facing: Direction
    var clock: GameClock
    var stamina: Int
    var inventoryCapacity: Int
    var inventory: [InventoryQuantity]
    var farmCells: [GridPosition: FarmCell]

    static let spikeDefault = GameState(
        position: GridPosition(x: 4, y: 2),
        facing: .down,
        clock: .spikeDefault,
        stamina: 100,
        inventoryCapacity: 16,
        inventory: [
            InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 1),
        ],
        farmCells: [:]
    )

    static func m1NewGame(seedQuantity: Int = 8) -> GameState {
        GameState(
            position: GridPosition(x: 5, y: 4),
            facing: .down,
            clock: GameClock(day: 1, minute: GameClock.dayStartMinute),
            stamina: 100,
            inventoryCapacity: 16,
            inventory: seedQuantity > 0
                ? [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: seedQuantity)]
                : [],
            farmCells: [:]
        )
    }

    var coordinateCaption: String {
        "逻辑坐标 (\(position.x), \(position.y))"
    }

    var targetCell: GridPosition {
        position.moved(in: facing) ?? position
    }

    @discardableResult
    mutating func move(_ direction: Direction) -> Bool {
        facing = direction
        guard let next = position.moved(in: direction) else {
            return false
        }
        position = next
        return true
    }

    func cell(at position: GridPosition) -> FarmCell {
        farmCells[position] ?? FarmCell()
    }
}
