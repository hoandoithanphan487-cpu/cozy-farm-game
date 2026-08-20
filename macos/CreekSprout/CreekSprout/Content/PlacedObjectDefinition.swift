struct PlacedObjectDefinition: Equatable, Codable, Sendable {
    var id: String
    var nameKey: String
    var itemID: String
    var category: String
    /// Footprint cells relative to the placement origin, facing `.up`.
    var footprint: [GridPosition]
}
