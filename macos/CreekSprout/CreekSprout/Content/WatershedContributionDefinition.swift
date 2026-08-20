struct WatershedContributionDefinition: Equatable, Sendable {
    var id: String
    var sourceEventID: String
    var points: Int
    var prerequisiteIDs: [String]
    var oneTime: Bool
    var countsTowardMainline: Bool
}
