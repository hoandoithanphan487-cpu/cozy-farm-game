import Foundation

struct TutorialService: Sendable {
    var catalog: ContentCatalog

    func goalLine(for state: GameState) -> String {
        if state.tutorial.currentStepID == ContentID.tutorialNextDay, state.clock.day >= 3 {
            return postTutorialGoalLine(for: state)
        }
        guard let step = step(id: state.tutorial.currentStepID) else {
            return "当前目标：继续照料农场"
        }
        if step.hint.isEmpty {
            return "当前目标：\(step.title)"
        }
        return "当前目标：\(step.title)  \(step.hint)"
    }

    private func postTutorialGoalLine(for state: GameState) -> String {
        if let event = GossipService.latestEvent(state: state) {
            switch event.status {
            case .resolvedCorrected, .resolvedRelay, .deferred, .expired:
                return "当前目标：\(CanalProgressionService.questSummary(state: state, catalog: catalog).replacingOccurrences(of: "任务 ", with: ""))"
            case .verified:
                return "当前目标：走到絮宁旁，用 Y/B 选择「纠正絮宁」"
            case .investigating:
                return "当前目标：走到青砚旁，用 Y/B 选择「\(HudCopy.firstVerifyChoice)」"
            case .offered:
                return "当前目标：到涧麦婶处，用 Y/B 选择「\(HudCopy.startVerifyChoice)」"
            }
        }
        return "当前目标：\(CanalProgressionService.questSummary(state: state, catalog: catalog).replacingOccurrences(of: "任务 ", with: ""))"
    }

    func step(id: String) -> TutorialStepDefinition? {
        catalog.tutorialStep(id: id)
    }

    func completionMessage(for stepID: String) -> String? {
        step(id: stepID)?.completionFeedback
    }

    @discardableResult
    func recordHarvest(state: inout GameState) -> [String] {
        if state.tutorial.harvestCount < 99 {
            state.tutorial.harvestCount += 1
        }
        return advance(state: &state)
    }

    @discardableResult
    func recordTalk(state: inout GameState) -> [String] {
        guard !state.tutorial.talkedToWaterApprentice else {
            return []
        }
        state.tutorial.talkedToWaterApprentice = true
        return advance(state: &state)
    }

    @discardableResult
    func recordManualSave(state: inout GameState) -> [String] {
        state.tutorial.didManualSave = true
        return advance(state: &state)
    }

    @discardableResult
    func advance(state: inout GameState) -> [String] {
        var completedNow: [String] = []
        while let currentID = nextCompletableStepID(state: state) {
            if !state.tutorial.completedStepIDs.contains(currentID) {
                state.tutorial.completedStepIDs.append(currentID)
                completedNow.append(currentID)
            }
            guard let nextID = Self.nextStepID(after: currentID) else {
                break
            }
            state.tutorial.currentStepID = nextID
        }
        return completedNow
    }

    func canTalk(to spawn: InitialNpcSpawn, from state: GameState) -> Bool {
        let faced = GridPosition(
            x: state.position.x + state.facing.deltaX,
            y: state.position.y + state.facing.deltaY
        )
        return faced == spawn.position || state.position == spawn.position
    }

    private func nextCompletableStepID(state: GameState) -> String? {
        let currentID = state.tutorial.currentStepID
        guard currentID != ContentID.tutorialNextDay else {
            return nil
        }
        guard ContentID.tutorialStepIDs.contains(currentID) else {
            return nil
        }
        guard isSatisfied(currentID, state: state) else {
            return nil
        }
        return currentID
    }

    private func isSatisfied(_ stepID: String, state: GameState) -> Bool {
        switch stepID {
        case ContentID.tutorialHarvest:
            return state.tutorial.harvestCount >= 3
        case ContentID.tutorialDeposit:
            return pendingMistRadishCount(state) == 3
        case ContentID.tutorialTill:
            return hasFreshlyTilledPlot(state)
        case ContentID.tutorialPlant:
            return hasYoungCrop(state)
        case ContentID.tutorialWater:
            return hasWateredYoungCrop(state)
        case ContentID.tutorialTalk:
            return state.tutorial.talkedToWaterApprentice
        case ContentID.tutorialSave:
            return state.tutorial.didManualSave
        case ContentID.tutorialSleep:
            return hasDayOneSettlement(state) && state.economy.balance == 894
        default:
            return false
        }
    }

    private func pendingMistRadishCount(_ state: GameState) -> Int {
        state.economy.shipping.pendingEntries
            .filter { $0.itemID == ContentID.mistRadishItem }
            .reduce(0) { $0 + $1.quantity }
    }

    private func hasFreshlyTilledPlot(_ state: GameState) -> Bool {
        let teachingPlots = Set(catalog.scenario.startingFarmCells.map(\.position))
        return state.farmCells.contains { position, cell in
            cell.prepared && !teachingPlots.contains(position)
        }
    }

    private func hasYoungCrop(_ state: GameState) -> Bool {
        state.farmCells.values.contains { cell in
            guard cell.hasCrop, let crop = catalog.crop(id: cell.cropID) else {
                return false
            }
            return cell.cropStage < crop.matureStageIndex
        }
    }

    private func hasWateredYoungCrop(_ state: GameState) -> Bool {
        state.farmCells.values.contains { cell in
            guard cell.hasCrop, cell.wateredToday, let crop = catalog.crop(id: cell.cropID) else {
                return false
            }
            return cell.cropStage < crop.matureStageIndex
        }
    }

    private func hasDayOneSettlement(_ state: GameState) -> Bool {
        state.economy.settlementHistory.contains { $0.gameDay == 1 }
    }

    private static func nextStepID(after stepID: String) -> String? {
        guard let index = ContentID.tutorialStepIDs.firstIndex(of: stepID) else {
            return nil
        }
        let next = index + 1
        guard next < ContentID.tutorialStepIDs.count else {
            return nil
        }
        return ContentID.tutorialStepIDs[next]
    }
}

struct DialogueSession: Equatable, Sendable {
    var dialogueID: String
    var speakerName: String
    var lines: [String]
    var lineIndex: Int
    var isReplay: Bool

    var currentLine: String {
        guard lines.indices.contains(lineIndex) else {
            return ""
        }
        return lines[lineIndex]
    }

    var isOnLastLine: Bool {
        lineIndex >= lines.count - 1
    }

    mutating func advance() -> Bool {
        guard lineIndex + 1 < lines.count else {
            return true
        }
        lineIndex += 1
        return false
    }
}

enum DialogueService {
    static func startTeaching(
        spawn: InitialNpcSpawn,
        catalog: ContentCatalog,
        alreadyCompleted: Bool,
        clock: ClockSystem
    ) -> DialogueSession? {
        start(
            dialogueID: spawn.dialogueID,
            catalog: catalog,
            alreadyCompleted: alreadyCompleted,
            clock: clock
        )
    }

    static func start(
        dialogueID: String,
        catalog: ContentCatalog,
        alreadyCompleted: Bool,
        clock: ClockSystem
    ) -> DialogueSession? {
        guard let definition = catalog.dialogue(id: dialogueID) else {
            return nil
        }
        clock.addPauseReason(.dialogue)
        if alreadyCompleted {
            return DialogueSession(
                dialogueID: definition.id,
                speakerName: definition.speakerName,
                lines: [definition.completedReply],
                lineIndex: 0,
                isReplay: true
            )
        }
        return DialogueSession(
            dialogueID: definition.id,
            speakerName: definition.speakerName,
            lines: definition.lines,
            lineIndex: 0,
            isReplay: false
        )
    }

    static func end(clock: ClockSystem) {
        clock.removePauseReason(.dialogue)
    }
}
