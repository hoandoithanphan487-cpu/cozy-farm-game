import Foundation

enum SaveSchema {
    static let currentVersion = 1
}

struct SaveGameDTO: Equatable, Codable, Sendable {
    var schemaVersion: Int
    var position: GridPosition
    var facing: Direction
    var clock: GameClock
    var stamina: Int
    var inventoryCapacity: Int
    var inventory: [InventoryQuantity]
    var farmCells: [FarmCellRecord]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case position
        case facing
        case clock
        case stamina
        case inventoryCapacity
        case inventory
        case farmCells
    }

    init(state: GameState, schemaVersion: Int = SaveSchema.currentVersion) {
        self.schemaVersion = schemaVersion
        position = state.position
        facing = state.facing
        clock = state.clock
        stamina = state.stamina
        inventoryCapacity = state.inventoryCapacity
        inventory = state.inventory
        farmCells = state.farmCells.keys.sorted { lhs, rhs in
            if lhs.y != rhs.y {
                return lhs.y < rhs.y
            }
            return lhs.x < rhs.x
        }.map { coordinate in
            FarmCellRecord(position: coordinate, cell: state.farmCells[coordinate] ?? FarmCell())
        }
    }

    func makeState() throws -> GameState {
        var cells: [GridPosition: FarmCell] = [:]
        cells.reserveCapacity(farmCells.count)
        for record in farmCells {
            let coordinate = GridPosition(x: record.x, y: record.y)
            if cells[coordinate] != nil {
                throw SaveStoreError.invalidContents
            }
            cells[coordinate] = record.cell
        }
        return GameState(
            position: position,
            facing: facing,
            clock: clock,
            stamina: stamina,
            inventoryCapacity: inventoryCapacity,
            inventory: inventory,
            farmCells: cells
        )
    }
}

struct FarmCellRecord: Equatable, Codable, Sendable {
    var x: Int
    var y: Int
    var prepared: Bool
    var wateredToday: Bool
    var fertility: Int
    var cropID: String
    var cropStage: Int
    var stageProgressDays: Int
    var plantedDay: Int
    var readyToHarvest: Bool

    init(position: GridPosition, cell: FarmCell) {
        x = position.x
        y = position.y
        prepared = cell.prepared
        wateredToday = cell.wateredToday
        fertility = cell.fertility
        cropID = cell.cropID
        cropStage = cell.cropStage
        stageProgressDays = cell.stageProgressDays
        plantedDay = cell.plantedDay
        readyToHarvest = cell.readyToHarvest
    }

    var cell: FarmCell {
        FarmCell(
            prepared: prepared,
            wateredToday: wateredToday,
            fertility: fertility,
            cropID: cropID,
            cropStage: cropStage,
            stageProgressDays: stageProgressDays,
            plantedDay: plantedDay,
            readyToHarvest: readyToHarvest
        )
    }
}
