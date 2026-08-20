struct TutorialStepDefinition: Equatable, Sendable {
    var id: String
    var title: String
    var hint: String
    var completionFeedback: String
}

struct DialogueDefinition: Equatable, Sendable {
    var id: String
    var speakerName: String
    var lines: [String]
    var completedReply: String
}
