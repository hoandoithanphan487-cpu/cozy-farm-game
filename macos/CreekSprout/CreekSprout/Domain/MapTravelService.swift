struct MapMoveResult: Equatable, Sendable {
    var didMove: Bool
    var didTravel: Bool
    var destinationMapID: String?
}

enum MapTravelService {
    static func map(for state: GameState, catalog: ContentCatalog) -> MapDefinition? {
        catalog.map(id: state.currentMapID)
    }

    static func visibleNpcs(state: GameState, catalog: ContentCatalog) -> [NpcPresence] {
        if state.currentMapID == ContentID.farmHomestead {
            return catalog.scenario.startingNpcSpawns.map { spawn in
                NpcPresence(
                    npcID: spawn.npcID,
                    displayName: spawn.displayName,
                    position: spawn.position,
                    dialogueID: spawn.dialogueID,
                    role: .questGiver,
                    isTeachingSpawn: spawn.npcID == ContentID.waterApprentice
                )
            }
        }
        return catalog.npcs.values
            .filter { $0.mapID == state.currentMapID }
            .sorted { $0.id < $1.id }
            .map { npc in
                NpcPresence(
                    npcID: npc.id,
                    displayName: npc.displayName,
                    position: npc.position,
                    dialogueID: npc.dialoguePoolID,
                    role: npc.role,
                    isTeachingSpawn: false
                )
            }
    }

    static func npc(
        atOrFacing state: GameState,
        catalog: ContentCatalog
    ) -> NpcPresence? {
        guard let map = map(for: state, catalog: catalog) else {
            return nil
        }
        let target = state.targetCell(in: map)
        return visibleNpcs(state: state, catalog: catalog).first { npc in
            npc.position == target || npc.position == state.position
        }
    }

    static func facingOrStandingExit(state: GameState, catalog: ContentCatalog) -> MapExitDefinition? {
        guard let map = map(for: state, catalog: catalog) else {
            return nil
        }
        if let onCell = map.exit(at: state.position) {
            return onCell
        }
        return map.exit(at: state.targetCell(in: map))
    }

    @discardableResult
    static func tryMove(
        state: inout GameState,
        direction: Direction,
        catalog: ContentCatalog
    ) -> MapMoveResult {
        state.facing = direction
        guard let map = map(for: state, catalog: catalog) else {
            return MapMoveResult(didMove: false, didTravel: false, destinationMapID: nil)
        }
        let next = GridPosition(
            x: state.position.x + direction.deltaX,
            y: state.position.y + direction.deltaY
        )
        guard map.contains(next), !map.isBlocked(next) else {
            return MapMoveResult(didMove: false, didTravel: false, destinationMapID: nil)
        }
        state.position = next
        return MapMoveResult(didMove: true, didTravel: false, destinationMapID: nil)
    }

    static func interactWithExit(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> MapMoveResult? {
        guard let exit = facingOrStandingExit(state: state, catalog: catalog) else {
            return nil
        }
        return travel(state: &state, through: exit, catalog: catalog)
    }

    static func travelIfOnExit(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> MapMoveResult? {
        guard let map = map(for: state, catalog: catalog),
              let exit = map.exit(at: state.position) else {
            return nil
        }
        return travel(state: &state, through: exit, catalog: catalog)
    }

    static func travel(
        state: inout GameState,
        through exit: MapExitDefinition,
        catalog: ContentCatalog
    ) -> MapMoveResult {
        guard let destination = catalog.map(id: exit.destinationMapID),
              let spawn = destination.spawn(id: exit.destinationSpawnID),
              destination.contains(spawn.position),
              !destination.isBlocked(spawn.position) else {
            return MapMoveResult(didMove: false, didTravel: false, destinationMapID: nil)
        }
        state.currentMapID = destination.id
        state.position = spawn.position
        return MapMoveResult(didMove: true, didTravel: true, destinationMapID: destination.id)
    }
}
