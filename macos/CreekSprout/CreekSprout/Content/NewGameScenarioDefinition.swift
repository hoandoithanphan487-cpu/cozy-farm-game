struct InitialFarmCell: Equatable, Codable, Sendable {
    var position: GridPosition
    var cell: FarmCell
}

struct InitialNpcSpawn: Equatable, Codable, Sendable {
    var npcID: String
    var displayName: String
    var position: GridPosition
    var dialogueID: String
}

enum WeatherKind: String, Equatable, Codable, Sendable {
    case clear
    case rain

    var displayName: String {
        switch self {
        case .clear: return "晴"
        case .rain: return "雨"
        }
    }
}

struct NewGameScenarioDefinition: Equatable, Codable, Sendable {
    var id: String
    var startDay: Int
    var startMinute: Int
    var startingCurrency: Int
    var startingInventoryCapacity: Int
    var playerStart: GridPosition
    var playerFacing: Direction
    var exitCell: GridPosition
    var startingItems: [InventoryQuantity]
    var startingFarmCells: [InitialFarmCell]
    var startingRecipeIDs: [String]
    var startingNpcSpawns: [InitialNpcSpawn] = []
    var guaranteedGatherNodeIDs: [String] = []
    /// Scripted VS-1 weather. Missing days default to clear; not persisted.
    var scriptedWeatherByDay: [Int: WeatherKind] = [:]

    func weather(on day: Int) -> WeatherKind {
        scriptedWeatherByDay[day] ?? .clear
    }
}
