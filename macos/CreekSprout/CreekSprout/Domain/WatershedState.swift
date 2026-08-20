struct WatershedState: Equatable, Codable, Sendable {
    var restorationPoints: Int
    var unlockedNodes: [String]
    var completedProjects: [String]
    var appliedContributionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case restorationPoints = "restoration_points"
        case unlockedNodes = "unlocked_nodes"
        case completedProjects = "completed_projects"
        case appliedContributionIDs = "applied_contribution_ids"
    }

    static let empty = WatershedState(
        restorationPoints: 0,
        unlockedNodes: [],
        completedProjects: [],
        appliedContributionIDs: []
    )

    var isRestored: Bool {
        restorationPoints >= ContentID.watershedThreshold
    }

    var ambienceLayerID: String {
        isRestored ? ContentID.flowingWaterAmbience : ContentID.dryChannelAmbience
    }

    var ambienceLabel: String {
        isRestored ? "流水层" : "干涸层"
    }

    var channelLabel: String {
        isRestored ? "已恢复" : "干涸"
    }

    func hasApplied(_ contributionID: String) -> Bool {
        appliedContributionIDs.contains(contributionID)
    }
}

struct QuestEntryState: Equatable, Codable, Sendable {
    var questID: String
    var status: QuestStatus

    enum CodingKeys: String, CodingKey {
        case questID = "quest_id"
        case status
    }
}

struct QuestLogState: Equatable, Codable, Sendable {
    var entries: [QuestEntryState]

    enum CodingKeys: String, CodingKey {
        case entries
    }

    static let empty = QuestLogState(entries: [])

    func status(of questID: String) -> QuestStatus {
        entries.first { $0.questID == questID }?.status ?? .notStarted
    }

    mutating func setStatus(_ status: QuestStatus, for questID: String) {
        if status == .notStarted {
            entries.removeAll { $0.questID == questID }
            return
        }
        if let index = entries.firstIndex(where: { $0.questID == questID }) {
            entries[index].status = status
        } else {
            entries.append(QuestEntryState(questID: questID, status: status))
        }
        entries.sort { $0.questID < $1.questID }
    }
}
