enum QuestObjectiveKind: String, Equatable, Sendable {
    case collect
    case deliver
    case talk
    case build
    case reachWatershed = "reach_watershed"
}

struct QuestObjectiveDefinition: Equatable, Sendable {
    var id: String
    var kind: QuestObjectiveKind
    var targetID: String
    var quantity: Int
    var consumesItems: Bool
}

enum QuestStatus: String, Equatable, Codable, Sendable {
    case notStarted = "not_started"
    case active
    case readyToTurnIn = "ready_to_turn_in"
    case completed
}

struct QuestDefinition: Equatable, Sendable {
    var id: String
    var titleKey: String
    var title: String
    var isMainline: Bool
    var oneTime: Bool
    var minStanding: Int?
    /// Gossip action or quest IDs that raise standing without being gated by the
    /// same `min_standing`. Content validation requires at least one whenever
    /// `minStanding` is set, so a gated optional node can never soft-lock.
    var recoveryPathIDs: [String] = []
    /// One-off community standing granted on completion; 0 for most quests.
    var standingReward: Int = 0
    var objectives: [QuestObjectiveDefinition]
    var completionEventID: String
}
