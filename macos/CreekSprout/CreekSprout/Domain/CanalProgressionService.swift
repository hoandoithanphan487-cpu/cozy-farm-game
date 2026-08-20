enum CanalProgressionService {
    static func commitCanalPlacementIfNeeded(
        state: GameState,
        definitionID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, WatershedFailure> {
        guard definitionID == ContentID.canalSegmentObject else {
            return .success(state)
        }
        switch WatershedService.apply(
            state: state,
            contributionID: ContentID.placeCanalContribution,
            sourceEventID: ContentID.placedCanalEvent,
            catalog: catalog
        ) {
        case .failure(let error):
            return .failure(error)
        case .success(let applied):
            switch QuestService.markCanalPlaced(state: applied.state, catalog: catalog) {
            case .failure:
                return .success(applied.state)
            case .success(let quested):
                return .success(quested)
            }
        }
    }

    static func deliverCanalRepair(
        state: GameState,
        catalog: ContentCatalog
    ) -> Result<GameState, WatershedFailure> {
        if QuestService.status(of: ContentID.restoreOldCanalQuest, in: state) == .completed
            || state.watershed.hasApplied(ContentID.deliverCanalContribution) {
            return .success(WatershedService.reconcile(state))
        }
        var next = state
        if next.watershed.hasApplied(ContentID.placeCanalContribution) {
            if case .success(let marked) = QuestService.markCanalPlaced(state: next, catalog: catalog) {
                next = marked
            }
        }
        guard QuestService.status(of: ContentID.restoreOldCanalQuest, in: next) == .readyToTurnIn else {
            return .failure(.missingPrerequisite)
        }
        switch WatershedService.apply(
            state: next,
            contributionID: ContentID.deliverCanalContribution,
            sourceEventID: ContentID.deliverCanalEvent,
            catalog: catalog
        ) {
        case .failure(let error):
            return .failure(error)
        case .success(let applied):
            switch QuestService.complete(
                state: applied.state,
                questID: ContentID.restoreOldCanalQuest,
                catalog: catalog
            ) {
            case .failure:
                return .success(applied.state)
            case .success(let completed):
                return .success(completed)
            }
        }
    }

    static func dialogueID(for presence: NpcPresence, state: GameState) -> String {
        if presence.isTeachingSpawn, !state.tutorial.talkedToWaterApprentice {
            return presence.dialogueID
        }
        guard presence.npcID == ContentID.waterApprentice else {
            return presence.dialogueID
        }
        switch QuestService.status(of: ContentID.restoreOldCanalQuest, in: state) {
        case .notStarted:
            return ContentID.waterApprenticeQuestOffer
        case .active:
            return ContentID.waterApprenticeQuestProgress
        case .readyToTurnIn:
            return ContentID.waterApprenticeQuestTurnIn
        case .completed:
            return ContentID.waterApprenticeQuestDone
        }
    }

    static func handleTalkCompleted(
        dialogueID: String,
        state: inout GameState,
        catalog: ContentCatalog
    ) -> CommandFeedback? {
        switch dialogueID {
        case ContentID.waterApprenticeQuestOffer:
            if case .success(let next) = QuestService.accept(
                state: state,
                questID: ContentID.restoreOldCanalQuest,
                catalog: catalog
            ) {
                state = next
                return .success("已接取任务：让旧水渠再次流动。")
            }
            return nil
        case ContentID.waterApprenticeQuestTurnIn:
            switch deliverCanalRepair(state: state, catalog: catalog) {
            case .success(let next):
                let before = state.watershed.restorationPoints
                state = next
                let points = state.watershed.restorationPoints
                if points != before {
                    return .success("修复已回报。水脉 \(before)→\(points)。环境音切换为\(state.watershed.ambienceLabel)。")
                }
                return .success("修复已经回报过，水脉仍为 \(points)。")
            case .failure:
                return .failure("现在还不能回报修复。")
            }
        default:
            return nil
        }
    }

    static func questSummary(state: GameState, catalog: ContentCatalog) -> String {
        let title = catalog.quest(id: ContentID.restoreOldCanalQuest)?.title ?? "让旧水渠再次流动"
        switch QuestService.status(of: ContentID.restoreOldCanalQuest, in: state) {
        case .notStarted:
            return "任务 \(title)：未接取"
        case .active:
            return "任务 \(title)：进行中（制作并放置水渠接片）"
        case .readyToTurnIn:
            return "任务 \(title)：可回报（向水工学徒回报施工）"
        case .completed:
            return "任务 \(title)：完成"
        }
    }
}

enum WorldVariant {
    static func landmarkLabel(
        _ landmark: MapLandmarkDefinition,
        restored: Bool
    ) -> String {
        guard restored else {
            return landmark.label
        }
        switch landmark.id {
        case "brookseed.landmark.market_blocked_mouth":
            return "复流水口"
        case "brookseed.landmark.farm_sluice":
            return "通水铜闸"
        default:
            return landmark.label
        }
    }

    static func isRestoredWaterCell(_ position: GridPosition, mapID: String) -> Bool {
        if mapID == ContentID.creekMarket {
            return position == GridPosition(x: 8, y: 0) || position == GridPosition(x: 9, y: 0)
        }
        if mapID == ContentID.farmHomestead {
            return position == GridPosition(x: 8, y: 5) || position == GridPosition(x: 9, y: 5)
        }
        return false
    }
}
