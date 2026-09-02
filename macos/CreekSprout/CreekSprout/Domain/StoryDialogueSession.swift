import Foundation

// MARK: - Story line condition evaluation

/// Evaluates `StoryLineCondition` against the live campaign state. Conditions
/// are pure functions of the persisted campaign; re-opening a saved session
/// therefore reproduces the exact same line sequence.
enum StoryLineConditionResolver {
    static func passes(
        _ condition: StoryLineCondition,
        state: GameState,
        arcID: StoryArcID
    ) -> Bool {
        switch condition {
        case .always:
            return true
        case let .selectedChoice(choice, conditionArcID):
            let stable = choice.stableID(in: conditionArcID)
            return state.storyCampaign.choices.contains {
                $0.arcID == conditionArcID && $0.choiceID == stable
            }
        case let .selectedAction(actionID):
            return state.storyCampaign.segment(arcID)?.completedActionIDs
                .contains(actionID) == true
        case let .romanceTender(expected):
            return state.storyCampaign.romanceTender == expected
        case let .q05Resolution(expected):
            return state.storyCampaign.choices.contains {
                $0.arcID == .q05
                    && $0.slotID == .primary
                    && $0.choiceID == expected.stableID(in: .q05)
            }
        }
    }

    /// Visible lines for a stage under the given state, in manuscript order.
    /// Inline choice responses become visible only after their intent was
    /// recorded in `state.storyCampaign.choices`.
    static func visibleLines(
        for stage: StoryStageDefinition,
        state: GameState,
        arcID: StoryArcID
    ) -> [StoryDialogueLineDefinition] {
        stage.lines.filter { passes($0.condition, state: state, arcID: arcID) }
    }

    /// Presented (visible) line IDs plus the boundary index where the stage's
    /// intents are offered. `boundary == nil` means intents appear at the end
    /// of the presented sequence.
    static func presentedSequence(
        for stage: StoryStageDefinition,
        state: GameState,
        arcID: StoryArcID
    ) -> (lineIDs: [String], boundary: Int?) {
        var presented: [String] = []
        var boundary: Int?
        for line in stage.lines {
            if passes(line.condition, state: state, arcID: arcID) {
                presented.append(line.id)
            } else if boundary == nil {
                boundary = presented.count
            }
        }
        return (presented, boundary)
    }
}

// MARK: - Persistent multi-speaker dialogue session

/// A resumable multi-speaker story dialogue. It is stored inside
/// `StoryCampaignState` so every save atomically captures the exact line
/// checkpoint, the offered intents and the cancellation state.
struct StoryDialogueSession: Equatable, Codable, Sendable {
    var sessionID: String
    var arcID: StoryArcID
    var stageKind: StoryStageID
    var sceneID: String?
    var cueID: String
    /// Number of presented lines already consumed; the next line to show.
    var lineIndex: Int
    /// Ordered, condition-resolved line IDs. Inline response lines are
    /// inserted when their intent is selected.
    var presentedLineIDs: [String]
    /// Where the stage's intents are offered (index into `presentedLineIDs`).
    /// `nil` means "after the last presented line".
    var choiceBoundaryLineIndex: Int?
    var pendingChoiceIDs: [StoryChoiceID]
    var selectedChoiceID: String?
    var createdAtDay: Int
    var isClosed: Bool
    var cancellationReason: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case arcID = "arc_id"
        case stageKind = "stage_kind"
        case sceneID = "scene_id"
        case cueID = "cue_id"
        case lineIndex = "line_index"
        case presentedLineIDs = "presented_line_ids"
        case choiceBoundaryLineIndex = "choice_boundary_line_index"
        case pendingChoiceIDs = "pending_choice_ids"
        case selectedChoiceID = "selected_choice_id"
        case createdAtDay = "created_at_day"
        case isClosed = "is_closed"
        case cancellationReason = "cancellation_reason"
    }

    var intentsPending: Bool {
        !pendingChoiceIDs.isEmpty && selectedChoiceID == nil
    }

    /// Whether the session is positioned at the intent offer point.
    var isAtBoundary: Bool {
        lineIndex == (choiceBoundaryLineIndex ?? presentedLineIDs.count)
    }

    var hasConsumedAllLines: Bool {
        lineIndex >= presentedLineIDs.count
    }

    /// Whether the whole stage content (lines + intents) is finished.
    var isComplete: Bool {
        hasConsumedAllLines && !intentsPending
    }

    func lineIDAtCurrentIndex(catalog: StoryContentCatalog = .shared) -> String? {
        guard presentedLineIDs.indices.contains(lineIndex) else { return nil }
        return presentedLineIDs[lineIndex]
    }
}

/// Persisted pair used to cross-check a dialogue session against its
/// frontstage cursor after a reload.
struct StoryDialogueSnapshot: Equatable, Codable, Sendable {
    var session: StoryDialogueSession
    var cursor: StoryRuntimeCursor

    enum CodingKeys: String, CodingKey {
        case session
        case cursor
    }
}

// MARK: - Read-only dialogue view

struct StoryDialogueView: Equatable, Sendable {
    struct Line: Equatable, Sendable {
        var id: String
        var speakerID: String
        var speakerName: String
        var speakerAnnotation: String?
        var portraitID: String?
        var text: String
        var sourceID: String?
    }

    struct Intent: Equatable, Sendable {
        var choiceID: StoryChoiceID
        var stableID: String
        var label: String
    }

    var sessionID: String
    var arcID: StoryArcID
    var stageKind: StoryStageID
    var sceneID: String?
    var cueID: String
    /// 1–3 consecutive lines sharing one speaker (page model).
    var pageLines: [Line]
    var pageNumber: Int
    var pageCount: Int
    var pendingIntents: [Intent]
    var hasSelectedIntent: Bool
    var selectedIntentID: String?
    var pacingMultiplier: Double
    var textSpeedDisplayName: String
    var isFinalPage: Bool
    var accessibilitySummary: String
}

enum StoryDialogueFailure: Equatable, Error, Sendable {
    case noActiveSession
    case stageUnavailable
    case cueUnavailable
    case invalidLineIndex
    case intentRequired
    case invalidIntent
    case intentAlreadySelected
    case sessionClosed
    case choiceRejected
    case interpolationFailed(String)
    case sessionAlreadyOpen
    case notResumable
}

// MARK: - Dialogue service (pure transactions)

enum StoryDialogueService {
    /// Opens a fresh session from the current frontstage cursor. The returned
    /// candidate must be validated and saved before replacing memory.
    static func openSession(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, StoryDialogueFailure> {
        guard state.storyCampaign.dialogueSession == nil else {
            return .failure(.sessionAlreadyOpen)
        }
        let campaign = state.storyCampaign
        guard let lease = campaign.frontstageLease else {
            return .failure(.noActiveSession)
        }
        let arcID: StoryArcID
        switch lease.owner {
        case .story, .finale:
            guard let resolved = StoryArcID(rawValue: lease.resourceID) else {
                return .failure(.noActiveSession)
            }
            arcID = resolved
        case .journey:
            arcID = .q08
        case .communityEvent, .forcedTutorial, .resumedSession, .hint:
            return .failure(.noActiveSession)
        }
        guard let beatID = campaign.cursor.beatID,
              let stageKind = StoryStageID(rawValue: beatID),
              let stage = catalog.stage(arcID: arcID, kind: stageKind) else {
            return .failure(.stageUnavailable)
        }
        guard let cueID = campaign.cursor.cueID,
              catalog.visibleBlockingCue(
                  id: cueID,
                  finaleUnlocked: campaign.finaleBeat.order >= FinaleBeat.discovery.order
              ) != nil else {
            return .failure(.cueUnavailable)
        }
        let sequence = StoryLineConditionResolver.presentedSequence(
            for: stage,
            state: state,
            arcID: arcID
        )
        guard !sequence.lineIDs.isEmpty else {
            return .failure(.stageUnavailable)
        }
        var next = state
        next.storyCampaign.dialogueSession = StoryDialogueSession(
            sessionID: "brookseed.story.session.\(arcID.shortCode).\(stageKind.rawValue).day_\(state.clock.day)",
            arcID: arcID,
            stageKind: stageKind,
            sceneID: campaign.cursor.sceneID,
            cueID: cueID,
            lineIndex: 0,
            presentedLineIDs: sequence.lineIDs,
            choiceBoundaryLineIndex: sequence.boundary,
            pendingChoiceIDs: stage.choices,
            selectedChoiceID: nil,
            createdAtDay: state.clock.day,
            isClosed: false,
            cancellationReason: nil
        )
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Advances one presented line. Returns a candidate whose session line
    /// checkpoint and story cursor both moved; `true` means the last line of
    /// the stage was consumed.
    static func advance(
        state: GameState,
        catalog: StoryContentCatalog = .shared
    ) -> Result<(state: GameState, reachedEnd: Bool), StoryDialogueFailure> {
        guard let session = state.storyCampaign.dialogueSession, !session.isClosed else {
            return .failure(.noActiveSession)
        }
        if session.intentsPending, session.isAtBoundary {
            return .failure(.intentRequired)
        }
        guard session.presentedLineIDs.indices.contains(session.lineIndex) else {
            return .failure(.invalidLineIndex)
        }
        let lineID = session.presentedLineIDs[session.lineIndex]
        guard catalog.visibleLine(
            id: lineID,
            finaleUnlocked: state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order
        ) != nil, let stage = catalog.stage(arcID: session.arcID, kind: session.stageKind),
              let fullIndex = stage.lines.firstIndex(where: { $0.id == lineID }) else {
            return .failure(.invalidLineIndex)
        }
        let persisted: GameState
        switch state.storyCampaign.frontstageLease?.owner {
        case .story, .finale:
            switch StoryCommandService.persistLine(
                state: state,
                lineID: lineID,
                lineIndex: fullIndex,
                catalog: catalog
            ) {
            case .success(let candidate):
                persisted = candidate
            case .failure:
                return .failure(.stageUnavailable)
            }
        default:
            // Journey sessions keep the journey cursor untouched; their lines
            // live only in the dialogue session.
            persisted = state
        }
        guard var nextSession = persisted.storyCampaign.dialogueSession,
              nextSession.sessionID == session.sessionID else {
            return .failure(.notResumable)
        }
        nextSession.lineIndex = session.lineIndex + 1
        nextSession.isClosed = nextSession.isComplete
        if nextSession.isClosed {
            nextSession.cancellationReason = nil
        }
        var next = persisted
        next.storyCampaign.dialogueSession = nextSession
        next.storyCampaign.canonicalize()
        return .success((next, nextSession.isClosed))
    }

    /// Records the player intent through `StoryCommandService.selectChoice`
    /// and re-sequences the session so the matching inline response plays.
    static func selectIntent(
        state: GameState,
        choice: StoryChoiceID,
        catalog: StoryContentCatalog = .shared
    ) -> Result<GameState, StoryDialogueFailure> {
        guard let session = state.storyCampaign.dialogueSession, !session.isClosed else {
            return .failure(.noActiveSession)
        }
        guard session.selectedChoiceID == nil else {
            return .failure(.intentAlreadySelected)
        }
        guard session.intentsPending else {
            return .failure(.invalidIntent)
        }
        guard session.pendingChoiceIDs.contains(choice) else {
            return .failure(.invalidIntent)
        }
        let chosen: GameState
        switch StoryCommandService.selectChoice(
            state: state,
            arcID: session.arcID,
            choice: choice
        ) {
        case .success(let candidate):
            chosen = candidate
        case .failure:
            return .failure(.choiceRejected)
        }
        guard var updated = chosen.storyCampaign.dialogueSession,
              updated.sessionID == session.sessionID else {
            return .failure(.notResumable)
        }
        guard let stage = catalog.stage(arcID: session.arcID, kind: session.stageKind) else {
            return .failure(.stageUnavailable)
        }
        let sequence = StoryLineConditionResolver.presentedSequence(
            for: stage,
            state: chosen,
            arcID: session.arcID
        )
        updated.presentedLineIDs = sequence.lineIDs
        updated.choiceBoundaryLineIndex = sequence.boundary
        updated.selectedChoiceID = choice.stableID(in: session.arcID)
        updated.pendingChoiceIDs = []
        var next = chosen
        next.storyCampaign.dialogueSession = updated
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Cancels the session and deterministically releases the frontstage
    /// lease, returning control without advancing the story phase. Re-entering
    /// the event anchor re-opens the beat.
    static func cancelSession(
        state: GameState
    ) -> Result<GameState, StoryDialogueFailure> {
        guard let session = state.storyCampaign.dialogueSession, !session.isClosed else {
            return .failure(.noActiveSession)
        }
        var next = state
        next.storyCampaign.dialogueSession = nil
        next.storyCampaign.frontstageLease = nil
        next.storyCampaign.cursor = .empty
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    /// Persisted snapshot (session + cursor) for save-time cross-checking.
    static func snapshot(state: GameState) -> StoryDialogueSnapshot? {
        guard let session = state.storyCampaign.dialogueSession else { return nil }
        return StoryDialogueSnapshot(session: session, cursor: state.storyCampaign.cursor)
    }

    /// Builds the read-only display model. Interpolation uses the allowed
    /// whitelist tokens only.
    static func view(
        state: GameState,
        settings: SettingsState,
        catalog: StoryContentCatalog = .shared
    ) throws -> StoryDialogueView {
        guard let session = state.storyCampaign.dialogueSession else {
            throw StoryDialogueFailure.noActiveSession
        }
        let campaign = state.storyCampaign
        let finaleUnlocked = campaign.finaleBeat.order >= FinaleBeat.discovery.order
        let lines = session.presentedLineIDs.compactMap { id in
            catalog.visibleLine(id: id, finaleUnlocked: finaleUnlocked)
        }
        let q05 = campaign.choices.first {
            $0.arcID == .q05 && $0.slotID == .primary
        }.map { record in
            StoryChoiceID(rawValue: record.choiceID.replacingOccurrences(
                of: "\(StoryArcID.q05.rawValue).choice.",
                with: ""
            )) ?? .publicOrder
        }
        let remaining = lines.dropFirst(session.lineIndex)
        let page = pageChunk(Array(remaining))
        let pageLines: [StoryDialogueView.Line] = try page.map { line in
            let actor = catalog.actorsByID[line.speakerID]
            let interpolated: String
            do {
                interpolated = try StoryDialogueInterpolator.interpolate(
                    line.text,
                    standing: state.community.standing,
                    q05Resolution: q05
                )
            } catch {
                throw StoryDialogueFailure.interpolationFailed(
                    String(describing: error)
                )
            }
            return StoryDialogueView.Line(
                id: line.id,
                speakerID: line.speakerID,
                speakerName: actor?.displayName ?? line.speakerID,
                speakerAnnotation: line.speakerAnnotation,
                portraitID: line.portraitID,
                text: interpolated,
                sourceID: line.sourceID
            )
        }
        let intents: [StoryDialogueView.Intent] = session.pendingChoiceIDs.map {
            StoryDialogueView.Intent(
                choiceID: $0,
                stableID: $0.stableID(in: session.arcID),
                label: $0.dialogueIntentLabel
            )
        }
        let pageCount = countPages(Array(remaining), chunk: pageChunk)
        let pagesBefore = countPages(Array(remaining.prefix(session.lineIndex)), chunk: pageChunk)
        let pageNumber = session.lineIndex == 0 ? 1 : pagesBefore + 1
        let isFinal = session.isComplete
        let speakerSummary = pageLines.map(\.speakerName).first ?? ""
        let intentSummary = intents.map(\.label).joined(separator: "、")
        let accessibilitySummary = [
            "剧情 \(session.arcID.shortCode) \(session.stageKind.rawValue)",
            speakerSummary.isEmpty ? nil : "\(speakerSummary)：",
            pageLines.map(\.text).joined(separator: " "),
            intents.isEmpty ? nil : "选项：\(intentSummary)",
        ].compactMap { $0 }.joined(separator: " ")
        return StoryDialogueView(
            sessionID: session.sessionID,
            arcID: session.arcID,
            stageKind: session.stageKind,
            sceneID: session.sceneID,
            cueID: session.cueID,
            pageLines: pageLines,
            pageNumber: pageNumber,
            pageCount: pageCount,
            pendingIntents: intents,
            hasSelectedIntent: session.selectedChoiceID != nil,
            selectedIntentID: session.selectedChoiceID,
            pacingMultiplier: settings.textSpeed.pacingMultiplier,
            textSpeedDisplayName: settings.textSpeed.displayName,
            isFinalPage: isFinal,
            accessibilitySummary: accessibilitySummary
        )
    }

    /// 1–3 consecutive lines; a speaker change always starts a new page.
    nonisolated private static func pageChunk(_ lines: [StoryDialogueLineDefinition]) -> [StoryDialogueLineDefinition] {
        guard let first = lines.first else { return [] }
        var chunk: [StoryDialogueLineDefinition] = [first]
        for line in lines.dropFirst() where chunk.count < 3 {
            if line.speakerID == chunk[0].speakerID {
                chunk.append(line)
            } else {
                break
            }
        }
        return chunk
    }

    nonisolated private static func countPages(
        _ lines: [StoryDialogueLineDefinition],
        chunk: ([StoryDialogueLineDefinition]) -> [StoryDialogueLineDefinition]
    ) -> Int {
        var remaining = lines
        var count = 0
        while !remaining.isEmpty {
            remaining = Array(remaining.dropFirst(chunk(remaining).count))
            count += 1
        }
        return max(1, count)
    }
}

// MARK: - Dialogue input routing (keyboard / mouse / gamepad / rebound)

enum StoryDialogueRoutingIntent: Equatable, Sendable {
    case advance
    case cancel
    case selectIntent(index: Int)
    case focusIntent(delta: Int)
    case none
}

/// Routes existing rebindable actions into the dialogue context. Action IDs
/// come from `InputBindingDefinitions`, so custom bindings automatically
/// reach the dialogue.
enum StoryDialogueInputRouter {
    static func route(
        actionID: String,
        intentsPending: Bool,
        atBoundary: Bool,
        hasSelectedIntent: Bool,
        focusedIntentIndex: Int?,
        intentCount: Int
    ) -> StoryDialogueRoutingIntent {
        if intentsPending, atBoundary {
            switch actionID {
            case InputBindingDefinitions.actionUIUp:
                return .focusIntent(delta: -1)
            case InputBindingDefinitions.actionUIDown:
                return .focusIntent(delta: 1)
            case InputBindingDefinitions.actionUIAccept,
                 InputBindingDefinitions.actionInteract,
                 InputBindingDefinitions.actionTalk:
                guard intentCount > 0, !hasSelectedIntent else { return .none }
                return .selectIntent(index: max(0, focusedIntentIndex ?? 0) % intentCount)
            case InputBindingDefinitions.actionUICancel:
                return .cancel
            default:
                return .none
            }
        }
        switch actionID {
        case InputBindingDefinitions.actionInteract,
             InputBindingDefinitions.actionTalk:
            return .advance
        case InputBindingDefinitions.actionUICancel:
            return .cancel
        default:
            return .none
        }
    }
}

// MARK: - Intent button labels (button meaning, never player personality)

extension StoryChoiceID {
    var dialogueIntentLabel: String {
        switch self {
        case .fieldFirst: return "先救田头"
        case .reedFirst: return "先取水点"
        case .inspectFirst: return "先检查闸具"
        case .harvest: return "先抢收"
        case .sandbag: return "先堆沙袋"
        case .patrol: return "先巡查渠线"
        case .livestock: return "先安顿牲畜"
        case .cutTest: return "先取苗样"
        case .traceRumor: return "先查流言出处"
        case .protectInventory: return "先护库存"
        case .regroup: return "先聚齐人手"
        case .parallelCrop: return "先并行补种"
        case .publishMissingPage: return "先补印缺页"
        case .publicOrder: return "公开限量单"
        case .coop: return "联合供货"
        case .delay: return "暂缓签约"
        case .talk: return "当面谈"
        case .noSide: return "不站边"
        case .pause: return "先缓一缓"
        case .love: return "留住亲近"
        case .tender: return "以温柔回应"
        case .friend: return "保持朋友"
        case .menu: return "先定菜单"
        case .inventory: return "先清点库存"
        case .evidence: return "先查证物"
        case .tradeUnion: return "先找行会"
        case .oldWaterway: return "先走旧水路"
        case .takeLedger: return "拿起账簿"
        case .keepReading: return "继续读下去"
        case .closeLedger: return "合上账簿"
        case .returnTitles: return "归还名号"
        case .whyMe: return "问为什么是我"
        case .anyTruth: return "问有没有真话"
        case .silence: return "沉默"
        case .breakTitles: return "砸毁名号"
        case .water: return "最后浇一次水"
        case .leave: return "从码头离开"
        }
    }
}
