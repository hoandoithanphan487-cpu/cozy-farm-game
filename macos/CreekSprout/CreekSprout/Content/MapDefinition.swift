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

enum MapWaterSemantic: String, Equatable, Sendable {
    case base
    case edgeN = "edge_n"
    case edgeE = "edge_e"
    case edgeS = "edge_s"
    case edgeW = "edge_w"
    case cornerNE = "corner_ne"
    case cornerSE = "corner_se"
    case cornerSW = "corner_sw"
    case cornerNW = "corner_nw"
}

struct MapWaterCellDefinition: Equatable, Sendable {
    var cell: GridPosition
    var semantic: MapWaterSemantic
}

struct MapCanalCellDefinition: Equatable, Sendable {
    var cell: GridPosition
    var isNorthSouth: Bool
}

struct MapBuildingLayerDefinition: Equatable, Sendable {
    var filename: String
    var nativeWidth: Int
    var nativeHeight: Int
    var order: Int
    var semantic: String

    var assetID: String { String(filename.dropLast(4)) }
}

struct MapBuildingDefinition: Equatable, Sendable {
    var id: String
    var footprint: Set<GridPosition>
    var collisionCells: Set<GridPosition>
    var door: GridPosition
    var interactionCells: Set<GridPosition>
    var occlusionCells: Set<GridPosition>
    var renderAnchor: GridPosition
    var renderOffsetX: Int
    var renderOffsetY: Int
    var layers: [MapBuildingLayerDefinition]
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
    var environmentBoundaryCells: Set<GridPosition> = []
    var staticObstacleCells: Set<GridPosition> = []
    var waterCells: [MapWaterCellDefinition] = []
    var canalCells: [MapCanalCellDefinition] = []
    var pathCells: Set<GridPosition> = []
    var buildings: [MapBuildingDefinition] = []

    func contains(_ position: GridPosition) -> Bool {
        position.isInside(columns: columns, rows: rows)
    }

    func isBlocked(_ position: GridPosition) -> Bool {
        blockedCells.contains(position)
            || environmentBoundaryCells.contains(position)
            || staticObstacleCells.contains(position)
            || waterCells.contains(where: { $0.cell == position })
            || canalCells.contains(where: { $0.cell == position })
            || buildings.contains(where: { $0.collisionCells.contains(position) })
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

    func building(id: String) -> MapBuildingDefinition? {
        buildings.first { $0.id == id }
    }

    func building(near position: GridPosition) -> MapBuildingDefinition? {
        buildings.first { building in
            building.interactionCells.contains(position)
                || building.door == position
                || building.footprint.contains(position)
        }
    }
}
