enum QuestFailure: Equatable, Error, Sendable {
    case unknownQuest
    case illegalStatus
}

/// Availability of an optional node that declares `min_standing`. A gated node
/// pauses instead of failing, and always keeps at least one ungated recovery
/// path, so low standing can never soft-lock progression.
enum OptionalNodeStatus: String, Equatable, Sendable {
    case available
    case paused
    case ungated

    var displayName: String {
        switch self {
        case .available: return "可用"
        case .paused: return "暂停"
        case .ungated: return "无门槛"
        }
    }
}

enum QuestService {
    static func status(of questID: String, in state: GameState) -> QuestStatus {
        state.questLog.status(of: questID)
    }

    /// Mainline quests never declare `min_standing`, so this always returns
    /// `.ungated` for them and the canal line stays reachable at any standing.
    static func optionalNodeStatus(
        of questID: String,
        state: GameState,
        catalog: ContentCatalog
    ) -> OptionalNodeStatus {
        guard let quest = catalog.quest(id: questID), let minStanding = quest.minStanding else {
            return .ungated
        }
        return state.community.standing >= minStanding ? .available : .paused
    }

    static func recoveryPathIDs(for questID: String, catalog: ContentCatalog) -> [String] {
        catalog.quest(id: questID)?.recoveryPathIDs ?? []
    }

    static func accept(
        state: GameState,
        questID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, QuestFailure> {
        guard catalog.quest(id: questID) != nil else {
            return .failure(.unknownQuest)
        }
        var next = state
        switch next.questLog.status(of: questID) {
        case .notStarted:
            next.questLog.setStatus(.active, for: questID)
            return .success(next)
        case .active, .readyToTurnIn, .completed:
            return .success(next)
        }
    }

    static func markCanalPlaced(state: GameState, catalog: ContentCatalog) -> Result<GameState, QuestFailure> {
        guard catalog.quest(id: ContentID.restoreOldCanalQuest) != nil else {
            return .failure(.unknownQuest)
        }
        var next = state
        switch next.questLog.status(of: ContentID.restoreOldCanalQuest) {
        case .notStarted, .active:
            next.questLog.setStatus(.readyToTurnIn, for: ContentID.restoreOldCanalQuest)
            return .success(next)
        case .readyToTurnIn, .completed:
            return .success(next)
        }
    }

    static func complete(state: GameState, questID: String, catalog: ContentCatalog) -> Result<GameState, QuestFailure> {
        guard catalog.quest(id: questID) != nil else {
            return .failure(.unknownQuest)
        }
        var next = state
        switch next.questLog.status(of: questID) {
        case .readyToTurnIn, .completed:
            next.questLog.setStatus(.completed, for: questID)
            return .success(next)
        case .notStarted, .active:
            return .failure(.illegalStatus)
        }
    }
}
