enum GatherFailure: Equatable, Error, Sendable {
    case unknownNode
    case locked
    case alreadyHarvested
    case notAdjacent
    case insufficientStamina
    case capacityExceeded
}

enum GatherService {
    static func node(
        facingOrStanding state: GameState,
        catalog: ContentCatalog
    ) -> GatherNodeDefinition? {
        guard let map = catalog.map(id: state.currentMapID) else {
            return nil
        }
        let target = state.targetCell(in: map)
        if let atTarget = catalog.gatherNode(at: target, mapID: map.id, state: state) {
            return atTarget
        }
        return catalog.gatherNode(at: state.position, mapID: map.id, state: state)
    }

    static func harvest(
        state: GameState,
        nodeID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, GatherFailure> {
        guard let node = catalog.gatherNode(id: nodeID) else {
            return .failure(.unknownNode)
        }
        guard catalog.isGatherNodeUnlocked(node, watershed: state.watershed) else {
            return .failure(.locked)
        }
        if node.oneTime, state.harvestedGatherNodeIDs.contains(node.id) {
            return .failure(.alreadyHarvested)
        }
        guard node.mapID == state.currentMapID else {
            return .failure(.notAdjacent)
        }
        let standing = state.position == node.position
        let adjacent = abs(state.position.x - node.position.x) + abs(state.position.y - node.position.y) == 1
        guard standing || adjacent else {
            return .failure(.notAdjacent)
        }
        guard state.stamina >= node.staminaCost else {
            return .failure(.insufficientStamina)
        }

        var inventory = state.inventory
        for yield in node.yields {
            switch InventoryService.tryAdd(
                inventory,
                capacity: state.inventoryCapacity,
                itemID: yield.itemID,
                quantity: yield.quantity,
                stackLimit: catalog.stackLimit(for: yield.itemID)
            ) {
            case .failure:
                return .failure(.capacityExceeded)
            case .success(let nextInventory):
                inventory = nextInventory
            }
        }

        var next = state
        next.inventory = inventory
        next.stamina -= node.staminaCost
        if node.oneTime {
            next.harvestedGatherNodeIDs.append(node.id)
            next.harvestedGatherNodeIDs = Array(Set(next.harvestedGatherNodeIDs)).sorted()
        }
        return .success(next)
    }
}
