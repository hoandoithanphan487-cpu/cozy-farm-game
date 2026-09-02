enum CropCondition: String, Equatable, Codable, Sendable {
    case healthy
    case thirsty
    case wilted
    case withered
}

struct FarmCell: Equatable, Codable, Sendable {
    var prepared: Bool = false
    var wateredToday: Bool = false
    var fertility: Int = 0
    var cropID: String = ""
    var cropStage: Int = 0
    var stageProgressDays: Int = 0
    var plantedDay: Int = 0
    var readyToHarvest: Bool = false
    var dryStreak: Int = 0
    var cropCondition: CropCondition = .healthy

    var hasCrop: Bool {
        !cropID.isEmpty
    }

    var isGrowingCrop: Bool {
        hasCrop && !readyToHarvest && cropCondition != .withered
    }
}
