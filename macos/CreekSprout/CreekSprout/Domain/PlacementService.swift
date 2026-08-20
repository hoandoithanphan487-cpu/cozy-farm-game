enum PlacementFailure: Equatable, Error, Sendable {
    case unknownDefinition
    case missingItem
    case outOfBounds
    case occupancyConflict
    case notAdjacentToPlayer
    case exitUnreachable
}

struct PlacementPreview: Equatable, Sendable {
    var definitionID: String
    var origin: GridPosition
    var facing: Direction
    var footprint: [GridPosition]
    var isValid: Bool
    var failure: PlacementFailure?
}

struct PlacementService: Sendable {
    static func rotate(_ relative: GridPosition, facing: Direction) -> GridPosition {
        switch facing {
        case .up:
            return relative
        case .right:
            return GridPosition(x: relative.y, y: -relative.x)
        case .down:
            return GridPosition(x: -relative.x, y: -relative.y)
        case .left:
            return GridPosition(x: -relative.y, y: relative.x)
        }
    }

    static func absoluteFootprint(
        definitionID: String,
        origin: GridPosition,
        facing: Direction,
        catalog: ContentCatalog
    ) -> [GridPosition] {
        guard let definition = catalog.placedObject(id: definitionID) else {
            return []
        }
        return definition.footprint.map { relative in
            let rotated = rotate(relative, facing: facing)
            return GridPosition(x: origin.x + rotated.x, y: origin.y + rotated.y)
        }
    }

    static func preview(
        state: GameState,
        definitionID: String,
        origin: GridPosition,
        facing: Direction,
        catalog: ContentCatalog
    ) -> PlacementPreview {
        let footprint = absoluteFootprint(
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        )
        let prepared = prepare(
            state: state,
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        )
        return PlacementPreview(
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            footprint: footprint,
            isValid: prepared.failure == nil,
            failure: prepared.failure
        )
    }

    static func place(
        state: GameState,
        definitionID: String,
        origin: GridPosition,
        facing: Direction,
        catalog: ContentCatalog
    ) -> Result<GameState, PlacementFailure> {
        let prepared = prepare(
            state: state,
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        )
        guard let next = prepared.state else {
            return .failure(prepared.failure ?? .unknownDefinition)
        }
        return .success(next)
    }

    private struct Preparation {
        var state: GameState?
        var failure: PlacementFailure?
    }

    private static func prepare(
        state: GameState,
        definitionID: String,
        origin: GridPosition,
        facing: Direction,
        catalog: ContentCatalog
    ) -> Preparation {
        guard let definition = catalog.placedObject(id: definitionID) else {
            return Preparation(state: nil, failure: .unknownDefinition)
        }
        let footprint = absoluteFootprint(
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        )
        guard !footprint.isEmpty, footprint.allSatisfy(\.isInsideFarm) else {
            return Preparation(state: nil, failure: .outOfBounds)
        }
        let occupied = state.occupancy(catalog: catalog)
        let cropCells = Set(state.farmCells.compactMap { coordinate, cell in
            cell.hasCrop ? coordinate : nil
        })
        if footprint.contains(where: { occupied.contains($0) || cropCells.contains($0) || $0 == state.position }) {
            return Preparation(state: nil, failure: .occupancyConflict)
        }
        if !isAdjacent(origin, to: state.position) {
            return Preparation(state: nil, failure: .notAdjacentToPlayer)
        }

        var proposed = occupied
        footprint.forEach { proposed.insert($0) }
        if !canReach(catalog.scenario.exitCell, from: state.position, blocked: proposed) {
            return Preparation(state: nil, failure: .exitUnreachable)
        }

        switch InventoryService.tryRemove(state.inventory, itemID: definition.itemID, quantity: 1) {
        case .failure:
            return Preparation(state: nil, failure: .missingItem)
        case .success(let inventory):
            var next = state
            next.inventory = inventory
            next.placedObjects.append(
                PlacedObjectState(
                    instanceID: "\(definitionID)#\(origin.x),\(origin.y)#\(facing.rawValue)#\(next.placedObjects.count)",
                    definitionID: definitionID,
                    origin: origin,
                    facing: facing
                )
            )
            next.placedObjects.sort { $0.instanceID < $1.instanceID }
            return Preparation(state: next, failure: nil)
        }
    }

    private static func isAdjacent(_ origin: GridPosition, to player: GridPosition) -> Bool {
        abs(origin.x - player.x) + abs(origin.y - player.y) == 1
    }

    static func canReach(
        _ destination: GridPosition,
        from start: GridPosition,
        blocked: Set<GridPosition>
    ) -> Bool {
        guard start.isInsideFarm, destination.isInsideFarm else {
            return false
        }
        guard !blocked.contains(start), !blocked.contains(destination) else {
            return false
        }
        if start == destination {
            return true
        }
        var visited: Set<GridPosition> = [start]
        var queue: [GridPosition] = [start]
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        while let current = queue.first {
            queue.removeFirst()
            for delta in deltas {
                let next = GridPosition(x: current.x + delta.0, y: current.y + delta.1)
                guard next.isInsideFarm, !blocked.contains(next), !visited.contains(next) else {
                    continue
                }
                if next == destination {
                    return true
                }
                visited.insert(next)
                queue.append(next)
            }
        }
        return false
    }
}
