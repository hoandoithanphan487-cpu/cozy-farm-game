struct RecipeStack: Equatable, Codable, Sendable {
    var itemID: String
    var quantity: Int
}

struct RecipeDefinition: Equatable, Codable, Sendable {
    var id: String
    var nameKey: String
    var inputs: [RecipeStack]
    var outputs: [RecipeStack]
    var placedObjectID: String?
    var requiredUnlockID: String? = nil
    /// When set, the recipe is a processing recipe and may only run at that placed object.
    var requiredPlacedObjectID: String? = nil
    /// Stamina spent on a successful craft/process. Building recipes stay 0.
    var staminaCost: Int = 0

    var isProcessingRecipe: Bool { requiredPlacedObjectID != nil }
}
