struct TutorialState: Equatable, Codable, Sendable {
    var currentStepID: String
    var completedStepIDs: [String]
    var harvestCount: Int
    var talkedToWaterApprentice: Bool
    var didManualSave: Bool

    enum CodingKeys: String, CodingKey {
        case currentStepID = "current_step_id"
        case completedStepIDs = "completed_step_ids"
        case harvestCount = "harvest_count"
        case talkedToWaterApprentice = "talked_to_water_apprentice"
        case didManualSave = "did_manual_save"
    }

    static let newGame = TutorialState(
        currentStepID: ContentID.tutorialHarvest,
        completedStepIDs: [],
        harvestCount: 0,
        talkedToWaterApprentice: false,
        didManualSave: false
    )
}
