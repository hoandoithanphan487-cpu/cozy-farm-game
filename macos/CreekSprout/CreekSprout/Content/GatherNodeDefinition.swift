struct GatherNodeDefinition: Equatable, Sendable {
    var id: String
    var mapID: String
    var position: GridPosition
    var label: String
    var yields: [RecipeStack]
    var oneTime: Bool
    var staminaCost: Int
    var requiredUnlockID: String?
}
