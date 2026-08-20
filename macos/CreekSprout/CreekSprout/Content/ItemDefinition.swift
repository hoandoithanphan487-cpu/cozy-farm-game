struct ItemDefinition: Equatable, Codable, Sendable {
    var id: String
    var nameKey: String
    var category: String
    var stackLimit: Int
    /// `nil` means the item cannot be sold. `0` is a defined zero price and still not shippable.
    var baseSellPrice: Int? = nil
}
