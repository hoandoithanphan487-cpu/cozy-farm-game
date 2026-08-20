struct MapLandmarkDefinition: Equatable, Sendable {
    var id: String
    var label: String
    var position: GridPosition
}

struct MapSpawnDefinition: Equatable, Sendable {
    var id: String
    var position: GridPosition
}

struct MapExitDefinition: Equatable, Sendable {
    var id: String
    var cell: GridPosition
    var destinationMapID: String
    var destinationSpawnID: String
}

struct MapDefinition: Equatable, Sendable {
    var id: String
    var nameKey: String
    var displayName: String
    var columns: Int
    var rows: Int
    var blockedCells: Set<GridPosition>
    var landmarks: [MapLandmarkDefinition]
    var spawns: [MapSpawnDefinition]
    var exits: [MapExitDefinition]

    func contains(_ position: GridPosition) -> Bool {
        position.isInside(columns: columns, rows: rows)
    }

    func isBlocked(_ position: GridPosition) -> Bool {
        blockedCells.contains(position)
    }

    func spawn(id: String) -> MapSpawnDefinition? {
        spawns.first { $0.id == id }
    }

    func exit(at position: GridPosition) -> MapExitDefinition? {
        exits.first { $0.cell == position }
    }

    func exit(id: String) -> MapExitDefinition? {
        exits.first { $0.id == id }
    }
}
