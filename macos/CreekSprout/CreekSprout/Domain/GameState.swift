struct GameState: Equatable, Sendable {
    var position: GridPosition
    var facing: Direction
    var clock: GameClock
    var stamina: Int
    var inventoryCapacity: Int
    var inventory: [InventoryQuantity]
    var farmCells: [GridPosition: FarmCell]
    var scenarioID: String = ContentID.vs0Scenario
    var economy: EconomyState = .empty
    var placedObjects: [PlacedObjectState] = []
    var tutorial: TutorialState = .newGame
    var currentMapID: String = ContentID.farmHomestead
    var watershed: WatershedState = .empty
    var questLog: QuestLogState = .empty
    var harvestedGatherNodeIDs: [String] = []
    var community: CommunityState = .empty
    var relationships: RelationshipState = .empty
    var settings: SettingsState = .defaults
    var selectedRecipeID: String?

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

    static func vs0NewGame(catalog: ContentCatalog = .vs0) -> GameState {
        let scenario = catalog.scenario
        var cells: [GridPosition: FarmCell] = [:]
        for record in scenario.startingFarmCells {
            cells[record.position] = record.cell
        }
        return GameState(
            position: scenario.playerStart,
            facing: scenario.playerFacing,
            clock: GameClock(day: scenario.startDay, minute: scenario.startMinute),
            stamina: 100,
            inventoryCapacity: scenario.startingInventoryCapacity,
            inventory: scenario.startingItems,
            farmCells: cells,
            scenarioID: scenario.id,
            economy: EconomyState(balance: scenario.startingCurrency),
            placedObjects: [],
            currentMapID: ContentID.farmHomestead,
            community: .newGame(balance: catalog.communityBalance)
        )
    }

    var coordinateCaption: String {
        "逻辑坐标 (\(position.x), \(position.y))"
    }

    var targetCell: GridPosition {
        position.moved(in: facing) ?? position
    }

    func targetCell(in map: MapDefinition) -> GridPosition {
        let next = GridPosition(x: position.x + facing.deltaX, y: position.y + facing.deltaY)
        return map.contains(next) ? next : position
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

    func occupancy(catalog: ContentCatalog) -> Set<GridPosition> {
        var occupied = Set<GridPosition>()
        for object in placedObjects {
            for cell in PlacementService.absoluteFootprint(
                definitionID: object.definitionID,
                origin: object.origin,
                facing: object.facing,
                catalog: catalog
            ) {
                occupied.insert(cell)
            }
        }
        return occupied
    }
}
