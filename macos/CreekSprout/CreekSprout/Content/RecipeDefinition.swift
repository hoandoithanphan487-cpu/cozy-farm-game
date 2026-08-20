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
}
