struct CropDefinition: Equatable, Codable, Sendable {
    var id: String
    var seedItemID: String
    var harvestItemID: String
    var stageDays: [Int]
    var matureStageIndex: Int
    var yield: Int
}
