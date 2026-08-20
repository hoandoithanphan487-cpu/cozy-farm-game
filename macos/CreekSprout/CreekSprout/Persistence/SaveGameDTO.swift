import Foundation

enum SaveSchema {
    /// v7 adds `settings` (input bindings snapshot and accessibility choices).
    /// v8 adds `selected_recipe_id` (crafting selection survives map travel and reload).
    static let currentVersion = 8
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
    var scenarioID: String
    var economy: EconomyState
    var placedObjects: [PlacedObjectState]
    var tutorial: TutorialState
    var currentMapID: String
    var watershed: WatershedState
    var questLog: QuestLogState
    var harvestedGatherNodeIDs: [String]
    var community: CommunityState
    var relationships: RelationshipState
    var settings: SettingsState
    var selectedRecipeID: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case position
        case facing
        case clock
        case stamina
        case inventoryCapacity
        case inventory
        case farmCells
        case scenarioID = "scenario_id"
        case economy
        case placedObjects = "placed_objects"
        case tutorial
        case currentMapID = "current_map_id"
        case watershed
        case questLog = "quest_log"
        case harvestedGatherNodeIDs = "harvested_gather_node_ids"
        case community
        case relationships
        case settings
        case selectedRecipeID = "selected_recipe_id"
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
        scenarioID = state.scenarioID
        var economy = state.economy
        economy.shipping.pendingEntries.sort { $0.entryID < $1.entryID }
        economy.settlementHistory.sort { $0.settlementID < $1.settlementID }
        self.economy = economy
        placedObjects = state.placedObjects.sorted { $0.instanceID < $1.instanceID }
        tutorial = state.tutorial
        currentMapID = state.currentMapID
        var watershed = state.watershed
        watershed.appliedContributionIDs.sort()
        watershed.unlockedNodes.sort()
        watershed.completedProjects.sort()
        self.watershed = watershed
        var questLog = state.questLog
        questLog.entries.sort { $0.questID < $1.questID }
        self.questLog = questLog
        harvestedGatherNodeIDs = Array(Set(state.harvestedGatherNodeIDs)).sorted()
        var community = state.community
        community.neighborStates.sort { $0.npcID < $1.npcID }
        community.activeEvents.sort { $0.instanceID < $1.instanceID }
        community.eventHistory.sort { $0.instanceID < $1.instanceID }
        for index in community.activeEvents.indices {
            community.activeEvents[index].grantedEffectIDs.sort()
        }
        for index in community.eventHistory.indices {
            community.eventHistory[index].grantedEffectIDs.sort()
        }
        self.community = community
        var relationships = state.relationships
        relationships.sortAll()
        self.relationships = relationships
        settings = state.settings
        selectedRecipeID = state.selectedRecipeID
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
        let restored = GameState(
            position: position,
            facing: facing,
            clock: clock,
            stamina: stamina,
            inventoryCapacity: inventoryCapacity,
            inventory: inventory,
            farmCells: cells,
            scenarioID: scenarioID,
            economy: economy,
            placedObjects: placedObjects,
            tutorial: tutorial,
            currentMapID: currentMapID,
            watershed: watershed,
            questLog: questLog,
            harvestedGatherNodeIDs: harvestedGatherNodeIDs,
            community: community,
            relationships: relationships,
            settings: settings,
            selectedRecipeID: selectedRecipeID
        )
        return RelationshipService.reconcile(GossipService.reconcile(WatershedService.reconcile(restored)))
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
