struct FarmCell: Equatable, Codable, Sendable {
    var prepared: Bool = false
    var wateredToday: Bool = false
    var fertility: Int = 0
    var cropID: String = ""
    var cropStage: Int = 0
    var stageProgressDays: Int = 0
    var plantedDay: Int = 0
    var readyToHarvest: Bool = false

    var hasCrop: Bool {
        !cropID.isEmpty
    }
}
