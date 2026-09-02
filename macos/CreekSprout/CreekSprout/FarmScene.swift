//
//  FarmScene.swift
//  CreekSprout
//
//  SpriteKit presentation layer for the VS-0 farming loop.
//  Owns the authoritative GameState; renders only derived state and forwards
//  player intent to domain services (FarmActionService, M2CommandService,
//  ClockSystem, SaveStore). No economy, crafting, or placement rules are
//  reimplemented here. Placement preview is a temporary overlay and is never
//  written to the save.
//

import Foundation
import SpriteKit

final class FarmScene: SKScene {
    // MARK: - Authority state (owned by the scene, never by SwiftUI)

    private(set) var gameState: GameState
    private(set) var selectedTool: FarmTool = .hoe
    private(set) var selectedSeedItemID = ContentID.mistRadishSeed
    private(set) var lastFeedback = "欢迎来到新芽农场。看当前目标开始吧。"
    private(set) var lastFeedbackIsSuccess = true

    private let catalog = ContentCatalog.vs0
    private let commands = M2CommandService(catalog: .vs0)
    private let community = CommunityCommandService(catalog: .vs0)
    private let tutorialService = TutorialService(catalog: .vs0)
    private var clockSystem = ClockSystem()
    private let actionService = FarmActionService()
    private let saveDirectory: URL
    private var activeManualSlotIndex = 0
    private var usesCampaignGenerationPersistence = false
    private var selectedRecipeIndex = 0
    private var selectedProcessingRecipeIndex = 0
    private var selectedGossipActionIndex = 0
    private var isPreviewingPlacement = false
    private(set) var isProcessingPanelOpen = false
    private var dialogueSession: DialogueSession?
    private var activeTeachingNPC = false
    private var talkingNpcID: String?
    private var lastPresentedCharacterID: String?
    private(set) var runtimeSettings: SettingsState = .defaults
    private var shakeRemaining: TimeInterval = 0
    private var flashPulseEnabled = true
    private var lastPublishedFeedback = ""
    private var feedbackExpiresAt = Date.distantFuture
    private var cachedHudText: String?
    private var cachedHudCompact: Bool?
    private var hudDirty = true
    private var isPerformanceMeasurementSession = false
    private var frameSampler = FrameTimeSampler(warmupSeconds: 60)
    private var mapLoadTimer = MapLoadTimer()
    private var memorySamplesMB: [Double] = []
    private var lastMemorySampleTime: TimeInterval = 0

    var frameTimeSampler: FrameTimeSampler { frameSampler }
    var mapTransitionTimer: MapLoadTimer { mapLoadTimer }
    var perfMemorySamplesMB: [Double] { memorySamplesMB }
    var presentationCellSize: CGFloat { cellSize }

    var activeSaveSlotLabel: String {
        SaveSlotCatalog.displayLabel(for: SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex))
    }

    var dialogueSpeakerName: String? {
        dialogueSession?.speakerName
    }

    var dialoguePortraitAssetName: String? {
        guard let talkingNpcID else { return nil }
        return ConceptArtCatalog.characterAssetName(for: talkingNpcID)
    }

    var hudPresentationState: HudPresentationState {
        let hour = gameState.clock.minute / 60
        let minute = gameState.clock.minute % 60
        let weather = catalog.scenario.weather(on: gameState.clock.day).displayName
        let device = runtimeSettings.lastUsedDevice
        func binding(_ actionID: String) -> String {
            InputBindingsService.primaryBindingLabel(
                actionID: actionID,
                device: device,
                settings: runtimeSettings
            )
        }
        let cropID = catalog.crop(seedItemID: selectedSeedItemID)?.id ?? ContentID.mistRadishCrop
        let seedAssetID = PixelAssetCatalog.cropKind(for: cropID)?.rawValue ?? "crop_mist_radish"
        let slots = [
            HudPresentationState.ToolSlot(
                id: "hoe", bindingLabel: binding(InputBindingDefinitions.actionTool1),
                displayName: "锄头", assetID: "tool_hoe", isSelected: selectedTool == .hoe
            ),
            HudPresentationState.ToolSlot(
                id: "seed", bindingLabel: binding(InputBindingDefinitions.actionTool2),
                displayName: catalog.displayName(forItemID: selectedSeedItemID), assetID: seedAssetID,
                isSelected: selectedTool == .seed
            ),
            HudPresentationState.ToolSlot(
                id: "water", bindingLabel: binding(InputBindingDefinitions.actionTool3),
                displayName: "浇水壶", assetID: "tool_watering_can", isSelected: selectedTool == .water
            ),
            HudPresentationState.ToolSlot(
                id: "harvest", bindingLabel: binding(InputBindingDefinitions.actionTool4),
                displayName: "收获", assetID: "tool_harvest_glove", isSelected: selectedTool == .harvest
            ),
        ]
        return HudPresentationState(
            calendar: .init(
                mapName: currentMap.displayName,
                day: gameState.clock.day,
                time: String(format: "%02d:%02d", hour, minute),
                weatherName: weather,
                weatherAssetID: "ui_weather"
            ),
            resources: .init(
                staminaCurrent: gameState.stamina,
                staminaMaximum: 100,
                currency: gameState.economy.balance
            ),
            toolbelt: slots,
            questLine: tutorialService.goalLine(for: gameState),
            toast: dialogueSession == nil && Date() <= feedbackExpiresAt
                ? .init(message: lastFeedback, isSuccess: lastFeedbackIsSuccess)
                : nil,
            prompt: .init(
                bindingLabel: binding(InputBindingDefinitions.actionInteract),
                text: interactionPromptText,
                usesGamepad: device == .gamepad
            ),
            dialogue: dialogueSession.map {
                .init(speakerName: $0.speakerName, line: $0.currentLine)
            },
            debugBindingLabel: binding(InputBindingDefinitions.actionToggleHud)
        )
    }

    private var interactionPromptText: String {
        if dialogueSession != nil { return "继续对话" }
        if currentMap.exit(at: hudTarget) != nil || currentMap.exit(at: gameState.position) != nil {
            return "前往\(currentMap.id == ContentID.farmHomestead ? "溪岸集市" : "农场")"
        }
        if catalog.gatherNode(at: hudTarget, mapID: currentMap.id, state: gameState) != nil {
            return "采集"
        }
        if currentMap.landmarks.contains(where: { $0.position == hudTarget }) {
            return "查看地点"
        }
        return currentMap.id == ContentID.farmHomestead ? "使用\(selectedTool.displayName)" : "交互"
    }

    var buildingPresentationLandmarkID: String? {
        currentMap.buildings.first { building in
            BuildingPresentationCatalog.contains(building.id)
                && (building.interactionCells.contains(hudTarget)
                    || building.interactionCells.contains(gameState.position)
                    || building.door == hudTarget)
        }?.id
    }

    /// Ephemeral proximity used only to reveal the cat-shop art tour.
    var isNearCatBbqShop: Bool {
        WorldLifeCatalog.isNearCatBbqShop(
            mapID: gameState.currentMapID,
            position: gameState.position
        )
    }

    var isOnFarmMap: Bool {
        gameState.currentMapID == ContentID.farmHomestead
    }

    var livestockRosterSnapshot: [FarmAnimalCardSnapshot] {
        gameState.livestock.animals.map { animal in
            let definition = LivestockCatalog.definition(id: animal.definitionID)
            let adult = LivestockService.isAdult(animal)
            return FarmAnimalCardSnapshot(
                id: animal.instanceID,
                definitionID: animal.definitionID,
                name: animal.displayName,
                speciesName: definition?.displayName ?? "未知动物",
                ageDays: animal.ageDays,
                stageLabel: adult ? "成年" : "幼年",
                caredToday: animal.lastCaredDay == gameState.clock.day,
                isProtected: animal.isProtected,
                canSupply: LivestockService.canSupply(animal, on: gameState.clock.day),
                supplyPrice: definition?.supplyPrice ?? 0
            )
        }
    }

    var catShopBoardSnapshot: CatShopBoardSnapshot {
        let offers = CatShopCatalog.offers(day: gameState.clock.day, content: catalog).map { offer in
            let used = gameState.catShop.suppliedQuantity(offerID: offer.id, day: gameState.clock.day)
            let owned: Int
            let kind: CatShopOfferCardSnapshot.Kind
            switch offer.kind {
            case .crop(let itemID):
                kind = .crop(itemID: itemID)
                owned = InventoryService.count(gameState.inventory, itemID: itemID)
            case .animal(let definitionID):
                kind = .animal(definitionID: definitionID)
                owned = gameState.livestock.animals.filter { $0.definitionID == definitionID }.count
            }
            return CatShopOfferCardSnapshot(
                id: offer.id,
                kind: kind,
                name: offer.displayName,
                unitPrice: offer.unitPrice,
                dailyLimit: offer.dailyLimit,
                remaining: max(0, offer.dailyLimit - used),
                ownedQuantity: owned
            )
        }
        let receiptText = gameState.catShop.receipts.last.map {
            "最近收据：\($0.displayName)×\($0.quantity) = \($0.total) 溪票"
        }
        return CatShopBoardSnapshot(
            day: gameState.clock.day,
            balance: gameState.economy.balance,
            offers: offers,
            animals: livestockRosterSnapshot,
            latestReceiptText: receiptText
        )
    }

    func careForAnimal(_ animalID: String) {
        guard isOnFarmMap else {
            applyFeedback(.failure("只能在农场照料动物。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        switch LivestockService.care(state: gameState, animalID: animalID) {
        case .failure(.animalNotFound):
            applyFeedback(.failure("没有找到这只动物。"))
        case .failure(.alreadyCaredToday):
            applyFeedback(.failure("这只动物今天已经照料过了。"))
        case .failure(.insufficientStamina):
            applyFeedback(.failure("体力不足，今天先休息一下吧。"))
        case .success(let next):
            gameState = next
            let name = gameState.livestock.animal(id: animalID)?.displayName ?? "动物"
            applyFeedback(.success("已照料\(name)，体力 −\(LivestockCatalog.careStaminaCost)。"))
        }
        publishDerivedState(rebuildCells: false)
    }

    func supplyCatShopCrop(offerID: String, itemID: String, quantity: Int) {
        guard isNearCatBbqShop else {
            applyFeedback(.failure("请先走到溪火猫食铺旁边。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let requestID = nextCatShopRequestID()
        switch CatShopSupplyService.supplyCrop(
            state: gameState,
            offerID: offerID,
            itemID: itemID,
            quantity: quantity,
            requestID: requestID,
            catalog: catalog
        ) {
        case .failure:
            applyFeedback(.failure("供货失败，物品和溪票均未改变。"))
        case .success(let result):
            gameState = result.state
            applyFeedback(.success("供货完成：\(result.receipt.displayName)×\(quantity)，立即到账 \(result.receipt.total) 溪票。"))
            audioService.play(.settle)
        }
        publishDerivedState(rebuildCells: true)
    }

    func supplyCatShopAnimal(offerID: String, animalID: String) {
        guard isNearCatBbqShop else {
            applyFeedback(.failure("请先走到溪火猫食铺旁边。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let requestID = nextCatShopRequestID()
        switch CatShopSupplyService.supplyAnimal(
            state: gameState,
            offerID: offerID,
            animalID: animalID,
            requestID: requestID,
            catalog: catalog
        ) {
        case .failure(.animalNotEligible):
            applyFeedback(.failure("只有成年、今日已照料且未受保护的动物可以供货。"))
        case .failure:
            applyFeedback(.failure("动物供货失败，圈舍和溪票均未改变。"))
        case .success(let result):
            gameState = result.state
            applyFeedback(.success("供货完成：\(result.receipt.displayName)已由猫店员接手，立即到账 \(result.receipt.total) 溪票。"))
            audioService.play(.settle)
        }
        publishDerivedState(rebuildCells: true)
    }

    private func nextCatShopRequestID() -> String {
        "brookseed.catshop.request.day\(gameState.clock.day).receipt\(gameState.catShop.receipts.count + 1)"
    }

    /// Last NPC presented in dialogue. This is ephemeral presentation state;
    /// it is intentionally not part of GameState or the save codec.
    var characterInfoCharacterID: String? {
        talkingNpcID ?? lastPresentedCharacterID ?? CharacterVisualCatalog.playerID
    }

    // MARK: - N-027 story dialogue (presentation wiring only)

    /// Focused intent button index, shared by keyboard, mouse and gamepad.
    private(set) var storyDialogueFocusedIntentIndex = 0

    /// Read-only multi-speaker dialogue view produced by the story runtime.
    var storyDialogueView: StoryDialogueView? {
        guard let session = gameState.storyCampaign.dialogueSession,
              !session.isClosed else { return nil }
        return try? StoryDialogueService.view(state: gameState, settings: runtimeSettings)
    }

    /// True when a story/finale beat is armed (lease + cursor) with no open
    /// dialogue session yet.
    var hasArmedStoryBeat: Bool {
        guard let lease = gameState.storyCampaign.frontstageLease else { return false }
        guard lease.owner == .story || lease.owner == .finale else { return false }
        let cursor = gameState.storyCampaign.cursor
        return gameState.storyCampaign.dialogueSession == nil
            && cursor.beatID != nil
            && cursor.cueID != nil
    }

    /// Routing context consumed by `StoryDialogueInputRouter`.
    var storyDialogueRoutingContext: StoryDialogueRoutingContext? {
        guard let session = gameState.storyCampaign.dialogueSession,
              !session.isClosed else { return nil }
        return StoryDialogueRoutingContext(
            intentsPending: session.intentsPending,
            atBoundary: session.isAtBoundary,
            hasSelectedIntent: session.selectedChoiceID != nil,
            focusedIntentIndex: storyDialogueFocusedIntentIndex,
            intentCount: session.pendingChoiceIDs.count
        )
    }

    /// Primary binding label for the dialogue footer hints.
    func storyDialogueBindingLabel(for actionID: String) -> String {
        InputBindingsService.primaryBindingLabel(
            actionID: actionID,
            device: runtimeSettings.lastUsedDevice,
            settings: runtimeSettings
        )
    }

    /// Routes one rebindable action into the dialogue context. Returns true
    /// when the story dialogue consumed the action.
    @discardableResult
    func routeStoryDialogueAction(_ actionID: String) -> Bool {
        guard let context = storyDialogueRoutingContext else { return false }
        let intent = StoryDialogueInputRouter.route(
            actionID: actionID,
            intentsPending: context.intentsPending,
            atBoundary: context.atBoundary,
            hasSelectedIntent: context.hasSelectedIntent,
            focusedIntentIndex: context.focusedIntentIndex,
            intentCount: context.intentCount
        )
        switch intent {
        case .advance:
            advanceStoryDialogue()
        case .cancel:
            cancelStoryDialogue()
        case .selectIntent(let index):
            selectStoryIntent(at: index)
        case .focusIntent(let delta):
            moveStoryDialogueIntentFocus(delta)
        case .none:
            return false
        }
        return true
    }

    /// Opens the armed story session; after a cancel, re-arms the same beat
    /// through the domain blocking-session entry point.
    func openStoryDialogueIfPending() {
        if hasArmedStoryBeat {
            guard case .success(let candidate) = StoryDialogueService.openSession(
                state: gameState
            ) else {
                return
            }
            storyDialogueFocusedIntentIndex = 0
            commitStoryCandidate(candidate)
            audioService.play(.talk)
            applyFeedback(.success("剧情对话开始。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        if !canRearmStoryStage {
            return
        }
        for arcID in StoryArcID.allCases where arcID.sequence <= StoryArcID.q08.sequence {
            guard let segment = gameState.storyCampaign.segment(arcID),
                  let stageKind = StoryStageID(rawValue: segment.phase.rawValue),
                  [StoryStageID.warningOne, .warningTwo, .eruption].contains(stageKind),
                  let stage = StoryContentCatalog.shared.stage(arcID: arcID, kind: stageKind),
                  let cueID = stage.lines.compactMap(\.blockingCueID).first,
                  case .success(let armed) = StoryCommandService.beginBlockingSession(
                      state: gameState,
                      arcID: arcID,
                      phase: segment.phase,
                      cueID: cueID
                  ),
                  case .success(let candidate) = StoryDialogueService.openSession(
                      state: armed
                  ) else {
                continue
            }
            storyDialogueFocusedIntentIndex = 0
            commitStoryCandidate(candidate)
            audioService.play(.talk)
            applyFeedback(.success("剧情对话重新开始。"))
            publishDerivedState(rebuildCells: false)
            return
        }
    }

    /// A cancelled story beat (same-stage lease) can be re-armed by
    /// re-entering its anchor; used to gate interact/talk.
    private var canRearmStoryStage: Bool {
        guard gameState.storyCampaign.dialogueSession == nil,
              gameState.storyCampaign.frontstageLease == nil else { return false }
        return gameState.storyCampaign.segments.contains { segment in
            guard let kind = StoryStageID(rawValue: segment.phase.rawValue) else {
                return false
            }
            return [StoryStageID.warningOne, .warningTwo, .eruption].contains(kind)
        }
    }

    func advanceStoryDialogue() {
        guard storyDialogueView != nil else { return }
        switch StoryDialogueService.advance(state: gameState) {
        case .failure(let failure):
            applyFeedback(.failure(storyDialogueFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
        case .success(let outcome):
            var candidate = outcome.state
            if outcome.reachedEnd, let closed = closeCompletedStoryStage(candidate) {
                candidate = closed
            }
            commitStoryCandidate(candidate)
            publishDerivedState(rebuildCells: false)
        }
    }

    /// Completes the beat after the last line: story stages release the
    /// frontstage lease via `closeDialogue`; finale stages advance the beat
    /// chain via `FinaleService`. Closed sessions are never persisted.
    private func closeCompletedStoryStage(_ state: GameState) -> GameState? {
        guard let session = state.storyCampaign.dialogueSession,
              session.isClosed else { return state }
        switch state.storyCampaign.frontstageLease?.owner {
        case .story:
            guard let phase = StoryPhase(rawValue: session.stageKind.rawValue) else {
                return try? StoryDialogueService.cancelSession(state: state).get()
            }
            switch StoryDirector.closeDialogue(
                state: state,
                arcID: session.arcID,
                completedPhase: phase
            ) {
            case .success(let next):
                return next
            case .failure:
                return try? StoryDialogueService.cancelSession(state: state).get()
            }
        case .finale:
            var next = state
            switch session.arcID {
            case .q09:
                if case .success(let advanced) = FinaleService.advanceAfterLedgerIntent(
                    state: next
                ) {
                    next = advanced
                }
            case .q10:
                if case .success(let advanced) = FinaleService.advanceAfterConfrontationIntent(
                    state: next
                ) {
                    next = advanced
                }
            default:
                break
            }
            if next.storyCampaign.dialogueSession?.isClosed == true {
                next.storyCampaign.dialogueSession = nil
            }
            return next
        default:
            // Journey sessions own their lifecycle (checkpoint-driven).
            return state
        }
    }

    func selectStoryIntent(at index: Int) {
        guard let view = storyDialogueView,
              view.pendingIntents.indices.contains(index) else { return }
        let choice = view.pendingIntents[index].choiceID
        switch StoryDialogueService.selectIntent(state: gameState, choice: choice) {
        case .failure(let failure):
            applyFeedback(.failure(storyDialogueFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
        case .success(let candidate):
            commitStoryCandidate(candidate)
            publishDerivedState(rebuildCells: false)
        }
    }

    func cancelStoryDialogue() {
        guard gameState.storyCampaign.dialogueSession != nil else { return }
        switch StoryDialogueService.cancelSession(state: gameState) {
        case .failure(let failure):
            applyFeedback(.failure(storyDialogueFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
        case .success(let candidate):
            storyDialogueFocusedIntentIndex = 0
            commitStoryCandidate(candidate)
            applyFeedback(.success("已取消剧情对话，控制已归还。"))
            publishDerivedState(rebuildCells: false)
        }
    }

    func moveStoryDialogueIntentFocus(_ delta: Int) {
        guard let context = storyDialogueRoutingContext,
              context.intentCount > 0 else { return }
        storyDialogueFocusedIntentIndex =
            (storyDialogueFocusedIntentIndex + delta + context.intentCount) % context.intentCount
        publishDerivedState(rebuildCells: false)
    }

    /// Persists a story candidate before committing memory (same two-phase
    /// discipline as sleep/save). Non-campaign sessions commit in memory only.
    private func commitStoryCandidate(_ candidate: GameState) {
        guard usesCampaignGenerationPersistence else {
            gameState = candidate
            return
        }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            _ = try coordinator.save(
                candidate,
                kind: .campaignAuto,
                ownerManualSlot: owner
            )
            gameState = candidate
        } catch {
            applyFeedback(.failure("剧情进度保存失败，本次对话未生效。"))
        }
    }

    private func storyDialogueFailureCopy(_ failure: StoryDialogueFailure) -> String {
        switch failure {
        case .intentRequired:
            return "请先选择一个行动。"
        case .invalidIntent:
            return "这个行动现在不可用。"
        case .sessionClosed:
            return "对话已结束。"
        case .interpolationFailed:
            return "对话文本暂时无法显示。"
        default:
            return "剧情对话暂时不可用。"
        }
    }

    // MARK: - N-027 Q08 journey (presentation wiring)

    /// Opens when the Q08 journey starts (departure confirmed).
    var onJourneyStart: (() -> Void)?

    /// Opens when graduation unlocks the gallery.
    var onStoryGraduation: (() -> Void)?

    /// Q08 departure readiness: eruption stage, standing ≥ 90, no mission,
    /// no frontstage lease and no active community events (mirrors
    /// `JourneyService.buildMissionSnapshot` guards).
    var canPrepareJourney: Bool {
        guard usesCampaignGenerationPersistence else { return false }
        guard gameState.storyCampaign.segment(.q08)?.phase == .eruption,
              gameState.storyCampaign.frontstageLease == nil,
              gameState.storyCampaign.mission == nil,
              gameState.community.activeEvents.isEmpty,
              gameState.community.standing >= 90 else { return false }
        return true
    }

    /// The in-progress journey checkpoint, nil when no active mission.
    var activeJourneyCheckpoint: StoryJourneyCheckpoint? {
        guard let mission = gameState.storyCampaign.mission,
              mission.status != .completed else { return nil }
        return mission.checkpoint
    }

    /// Starts the Q08 journey: two-phase `prepareJourney`; memory is only
    /// committed after the mission generation landed. Returns true on success.
    @discardableResult
    func prepareJourneyIfReady() -> Bool {
        guard canPrepareJourney else { return false }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            let generation = try JourneyService.prepareJourney(
                state: gameState,
                coordinator: coordinator,
                ownerManualSlot: owner
            )
            gameState = generation.state
            applyFeedback(.success("出发远行。猫猫公主在雾岭等你。"))
            publishDerivedState(rebuildCells: false)
            return true
        } catch {
            applyFeedback(.failure("出发失败，远行没有开始。"))
            publishDerivedState(rebuildCells: false)
            return false
        }
    }

    /// Persists the next journey checkpoint as `mission_current` and commits
    /// memory only after the write landed. Returns true on success.
    @discardableResult
    func advanceJourneyCheckpoint(to checkpoint: StoryJourneyCheckpoint) -> Bool {
        guard let mission = gameState.storyCampaign.mission,
              mission.status == .travelling else { return false }
        switch JourneyService.advanceCheckpoint(state: gameState, to: checkpoint) {
        case .failure(let failure):
            applyFeedback(.failure(journeyFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
            return false
        case .success(let candidate):
            let coordinator = CampaignSaveCoordinator(
                rootDirectory: saveDirectory,
                catalog: catalog
            )
            let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
            do {
                _ = try coordinator.save(
                    candidate,
                    kind: .missionCurrent,
                    ownerManualSlot: owner
                )
                gameState = candidate
                applyFeedback(.success("检查点已记录。"))
                publishDerivedState(rebuildCells: false)
                return true
            } catch {
                applyFeedback(.failure("检查点保存失败，进度未推进。"))
                publishDerivedState(rebuildCells: false)
                return false
            }
        }
    }

    /// Completes the homecoming (two-phase, exactly-once settlement) and
    /// enters Q08 aftermath. Returns true on success.
    @discardableResult
    func completeHomecoming() -> Bool {
        guard let mission = gameState.storyCampaign.mission,
              mission.status == .travelling,
              mission.checkpoint == .greyFenceFarm else { return false }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            let generation = try JourneyService.completeHomecoming(
                state: gameState,
                coordinator: coordinator,
                ownerManualSlot: owner
            )
            gameState = generation.state
            applyFeedback(.success("返乡结算完成。猫猫公主回家了。"))
            publishDerivedState(rebuildCells: false)
            return true
        } catch let failure as JourneyFailure {
            applyFeedback(.failure(journeyFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
            return false
        } catch {
            applyFeedback(.failure("返乡结算失败。"))
            publishDerivedState(rebuildCells: false)
            return false
        }
    }

    /// Abandons the journey and rolls back to the `pre_mist_ridge` protection
    /// generation. Returns true when the rollback landed.
    @discardableResult
    func abandonJourney() -> Bool {
        guard let mission = gameState.storyCampaign.mission,
              mission.status != .completed else { return false }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            let rolledBack = try JourneyService.abandon(
                state: gameState,
                coordinator: coordinator,
                ownerManualSlot: owner
            )
            gameState = rolledBack
            applyFeedback(.success("已放弃远行，回到出发前的溪谷。"))
            publishDerivedState(rebuildCells: false)
            return true
        } catch let failure as JourneyFailure {
            applyFeedback(.failure(journeyFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
            return false
        } catch {
            applyFeedback(.failure("放弃远行失败。"))
            publishDerivedState(rebuildCells: false)
            return false
        }
    }

    /// Departure interaction: only from the farm stone steps while the Q08
    /// eruption stage is ready. Returns true when a journey started.
    @discardableResult
    private func tryPrepareJourneyDeparture() -> Bool {
        guard canPrepareJourney,
              playerAtStoryAnchor("brookseed.story.anchor.farm.stone_steps") else {
            return false
        }
        guard prepareJourneyIfReady() else { return false }
        onJourneyStart?()
        return true
    }

    // MARK: - N-027 Q09/Q10 finale (presentation wiring)

    /// Q09 discovery readiness: Q08 aftermath complete, finale locked.
    var canBeginFinaleDiscovery: Bool {
        guard usesCampaignGenerationPersistence else { return false }
        guard gameState.storyCampaign.finaleBeat == .locked,
              gameState.storyCampaign.segment(.q08)?.phase == .aftermath,
              gameState.storyCampaign.mission?.status == .completed else {
            return false
        }
        return true
    }

    /// Writes the `pre_reveal` protection BEFORE any ledger text, enters the
    /// Q09 discovery stage and opens the finale dialogue session. Returns
    /// true when the discovery started.
    @discardableResult
    func beginFinaleDiscovery() -> Bool {
        guard canBeginFinaleDiscovery else { return false }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            let generation = try FinaleService.beginDiscovery(
                state: gameState,
                coordinator: coordinator,
                ownerManualSlot: owner
            )
            gameState = generation.state
            guard case .success(let entered) = FinaleService.enterDiscovery(
                state: gameState
            ) else {
                applyFeedback(.failure("账簿发现无法开始。"))
                publishDerivedState(rebuildCells: false)
                return false
            }
            gameState = entered
            if case .success(let opened) = FinaleService.openStageSession(
                state: entered
            ) {
                gameState = opened
                storyDialogueFocusedIntentIndex = 0
                audioService.play(.talk)
            }
            applyFeedback(.success("猫铺帘幕后藏着账簿。"))
            publishDerivedState(rebuildCells: false)
            return true
        } catch {
            applyFeedback(.failure("发现账簿失败，进度未改变。"))
            publishDerivedState(rebuildCells: false)
            return false
        }
    }

    /// Q09 discovery interaction: only from the cat shop curtain anchors while
    /// the finale is locked. Returns true when discovery started.
    @discardableResult
    private func tryBeginFinaleDiscovery() -> Bool {
        guard canBeginFinaleDiscovery else { return false }
        let curtainAnchors = [
            "brookseed.story.anchor.market.cat_shop_curtain",
            "brookseed.story.anchor.market.cat_shop_side",
            "brookseed.story.anchor.market.cat_shop_front",
        ]
        guard curtainAnchors.contains(where: playerAtStoryAnchor) else {
            return false
        }
        return beginFinaleDiscovery()
    }

    /// Q10 `leave` graduation: from the market wharf while the final action
    /// is pending. Returns true when the player graduated.
    @discardableResult
    private func tryGraduateByLeave() -> Bool {
        guard gameState.storyCampaign.finaleBeat == .finalActionPending,
              playerAtStoryAnchor(StoryAnchorCatalog.endingDepartureAnchorID) else {
            return false
        }
        switch FinaleService.graduateAfterLeave(state: gameState) {
        case .failure(let failure):
            applyFeedback(.failure(finaleFailureCopy(failure)))
            publishDerivedState(rebuildCells: false)
            return false
        case .success(let candidate):
            commitStoryCandidate(candidate)
            applyFeedback(.success("你从码头离开了溪谷。"))
            publishDerivedState(rebuildCells: false)
            onStoryGraduation?()
            return true
        }
    }

    /// Q10 `water` graduation: after a real successful watering while the
    /// final action is pending. Returns true when the player graduated.
    @discardableResult
    private func tryGraduateByWater() -> Bool {
        guard gameState.storyCampaign.finaleBeat == .finalActionPending else {
            return false
        }
        switch FinaleService.graduateAfterWater(state: gameState) {
        case .failure:
            return false
        case .success(let candidate):
            commitStoryCandidate(candidate)
            applyFeedback(.success("你为溪谷浇下了最后一桶水。"))
            publishDerivedState(rebuildCells: false)
            onStoryGraduation?()
            return true
        }
    }

    private func playerAtStoryAnchor(_ anchorID: String) -> Bool {
        guard let anchor = StoryAnchorCatalog.anchor(id: anchorID),
              case let .worldGrid(world) = anchor else { return false }
        return gameState.position == world.cell
            || gameState.targetCell == world.cell
    }

    private func journeyFailureCopy(_ failure: JourneyFailure) -> String {
        switch failure {
        case .notEligible:
            return "现在还不能出发。"
        case .missionAlreadyActive:
            return "已经有一场远行在进行。"
        case .notInJourney:
            return "当前没有远行。"
        case .unknownCheckpoint:
            return "未知的远行检查点。"
        case .invalidTransition:
            return "远行状态不允许这个操作。"
        case .settlementAlreadyReceived:
            return "返乡结算已完成。"
        case .cannotAbandon:
            return "没有可回退的保护档，不能放弃。"
        case .protectionMissing:
            return "保护档缺失，无法放弃远行。"
        case .saveFailed:
            return "远行保存失败。"
        case .overflow:
            return "结算金额溢出，已取消。"
        case .settlementRejected:
            return "远行结算与快照不一致，已取消。"
        }
    }

    private func finaleFailureCopy(_ failure: FinaleFailure) -> String {
        switch failure {
        case .notEligible:
            return "终局尚未解锁。"
        case .invalidTransition:
            return "终局状态不允许这个操作。"
        case .preRevealWriteFailed:
            return "保护档写入失败，揭露未开始。"
        case .stageUnavailable:
            return "这个终局阶段暂时不可用。"
        case .noLease:
            return "当前没有终局阶段。"
        case .alreadyGraduated:
            return "你已经完成了毕业。"
        case .waterActionMissing:
            return "需要先在田里真实浇下一次水。"
        case .leaveAnchorUnavailable:
            return "需要站到集市码头才能离开。"
        case .saveFailed:
            return "终局保存失败。"
        }
    }

    // MARK: - N-027 finale gallery (presentation wiring only)

    private(set) var storyGalleryPreRevealRecall: StoryPreRevealRecallSnapshot?

    var storyGallerySnapshot: StoryGallerySnapshot {
        let gallery = gameState.storyCampaign.gallery
        return StoryGallerySnapshot(
            isUnlocked: gallery.isUnlocked,
            discoveredLedgerPageIDs: gallery.discoveredLedgerPageIDs,
            discoveredAnnotationIDs: gallery.discoveredAnnotationIDs,
            keepsakeIDs: gallery.keepsakeIDs,
            endingID: gallery.endingID,
            preRevealRecall: storyGalleryPreRevealRecall
        )
    }

    /// Reads the campaign-scoped `pre_reveal` protection generation for the
    /// gallery. Only available after graduation and never touches production
    /// files when the scene runs on an evidence root.
    func recallPreRevealForGallery() {
        guard gameState.storyCampaign.gallery.isUnlocked else { return }
        guard usesCampaignGenerationPersistence else {
            storyGalleryPreRevealRecall = nil
            applyFeedback(.failure("当前会话没有 campaign 保护档。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let coordinator = CampaignSaveCoordinator(
            rootDirectory: saveDirectory,
            catalog: catalog
        )
        let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
        do {
            let recalled = try FinaleService.recallPreReveal(
                state: gameState,
                coordinator: coordinator,
                ownerManualSlot: owner
            )
            let mapName = catalog.map(id: recalled.currentMapID)?.displayName
                ?? recalled.currentMapID
            storyGalleryPreRevealRecall = StoryPreRevealRecallSnapshot(
                day: recalled.clock.day,
                mapDisplayName: mapName,
                standing: recalled.community.standing,
                balance: recalled.economy.balance,
                positionCaption: "(\(recalled.position.x), \(recalled.position.y))",
                growingCropCount: recalled.farmCells.values.filter(\.isGrowingCrop).count
            )
            applyFeedback(.success("已读取揭露前保护档。"))
        } catch {
            storyGalleryPreRevealRecall = nil
            applyFeedback(.failure("读取揭露前保护档失败。"))
        }
        publishDerivedState(rebuildCells: false)
    }

    private var currentMap: MapDefinition {
        catalog.map(id: gameState.currentMapID) ?? WorldCatalog.farmHomestead
    }

    private var mapColumns: Int { currentMap.columns }
    private var mapRows: Int { currentMap.rows }

    private var hudTarget: GridPosition {
        gameState.targetCell(in: currentMap)
    }

    /// Fired whenever any derived state changes (movement, tool, action,
    /// day-end, save/load, clock tick) so ContentView can refresh its HUD.
    var onStateChanged: (() -> Void)?

    // MARK: - Nodes

    private let worldRoot = SKNode()
    private let bleedRoot = SKNode()
    private let weatherRoot = SKNode()
    private let gridRoot = SKNode()
    private let buildingRoot = SKNode()
    private let lifeRoot = SKNode()
    private let previewRoot = SKNode()
    private let npcRoot = SKNode()
    private let playerNode = SKNode()
    private let facingIndicator = SKShapeNode()
    private let targetHighlight = SKNode()
    private let ambienceBanner = SKLabelNode()
    let audioService = SynthesizedAudioService()
    private var playerVisual: CharacterVisualNode?
    private var npcVisuals: [String: CharacterVisualNode] = [:]

    private var didSetup = false
    private var cellSize: CGFloat = 48
    private var gridOrigin = CGPoint.zero
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Factories

    static func makeDefault() -> FarmScene {
        makeSession(size: CGSize(width: 960, height: 640), saveDirectory: productionSaveDirectory)
    }

    /// Save directory: ~/Library/Application Support/CreekSprout (current user).
    static var productionSaveDirectory: URL { makeSaveDirectory() }

    static func makeSession(
        size: CGSize = CGSize(width: 1_280, height: 800),
        saveDirectory: URL? = nil
    ) -> FarmScene {
        let scene = FarmScene(size: size, saveDirectory: saveDirectory ?? productionSaveDirectory)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = .zero
        return scene
    }

    /// Save directory: ~/Library/Application Support/CreekSprout (current user).
    private static func makeSaveDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("CreekSprout", isDirectory: true)
    }

    override init(size: CGSize) {
        gameState = .vs0NewGame()
        saveDirectory = Self.makeSaveDirectory()
        super.init(size: size)
    }

    init(size: CGSize, saveDirectory: URL) {
        gameState = .vs0NewGame()
        self.saveDirectory = saveDirectory
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        gameState = .vs0NewGame()
        saveDirectory = Self.makeSaveDirectory()
        super.init(coder: aDecoder)
    }

    private func autoSaveStore() -> SaveStore {
        SaveStore(directory: saveDirectory, slotName: SaveSlotCatalog.autoSlotName, catalog: catalog)
    }

    private func manualSaveStore(for index: Int? = nil) -> SaveStore {
        let slotIndex = index ?? activeManualSlotIndex
        return SaveStore(
            directory: saveDirectory,
            slotName: SaveSlotCatalog.manualSlotName(index: slotIndex),
            catalog: catalog
        )
    }

    private func legacySaveStore() -> SaveStore {
        SaveStore(directory: saveDirectory, slotName: SaveSlotCatalog.legacyDefaultSlot, catalog: catalog)
    }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        if !didSetup {
            backgroundColor = WorldCamera.atmosphereColor(
                mapID: ContentID.farmHomestead,
                isRain: false,
                restored: false
            )
            worldRoot.name = "world-root"
            bleedRoot.name = "bleed-root"
            bleedRoot.zPosition = -2
            weatherRoot.name = "weather-overlay"
            weatherRoot.zPosition = 40
            addChild(worldRoot)
            addChild(weatherRoot)
            worldRoot.addChild(bleedRoot)
            worldRoot.addChild(gridRoot)
            worldRoot.addChild(buildingRoot)
            lifeRoot.zPosition = 4.6
            worldRoot.addChild(lifeRoot)
            previewRoot.zPosition = 6
            worldRoot.addChild(previewRoot)
            npcRoot.zPosition = 9
            worldRoot.addChild(npcRoot)
            configurePlayer()
            configureAmbienceBanner()
            didSetup = true
        }
        rebuildLayout()
        startPresentationAudioIfNeeded()
        onStateChanged?()
        writeHudDumpIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1, size.height > 1, size != oldSize else { return }
        rebuildLayout()
    }

    /// Game time advances through ClockSystem with real wall-clock delta,
    /// independent of frame rate.
    override func update(_ currentTime: TimeInterval) {
        guard didSetup else { return }
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }
        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard delta > 0, delta < 1.0 else { return }

        if shakeRemaining > 0 {
            shakeRemaining = max(0, shakeRemaining - delta)
            let offset = CGFloat(sin(currentTime * 40)) * 4 * CGFloat(shakeRemaining / 0.25)
            gridRoot.position = CGPoint(x: offset, y: 0)
        } else if gridRoot.position != .zero {
            gridRoot.position = .zero
        }

        let before = gameState.clock
        clockSystem.advance(state: &gameState, deltaSeconds: delta)
        if gameState.clock != before {
            invalidateHudCache()
            onStateChanged?()
            if !isPerformanceMeasurementSession {
                writeHudDumpIfNeeded()
            }
        }
        sampleMemoryIfNeeded()
    }

    func recordPerformanceFrameDuration(_ seconds: TimeInterval) {
        frameSampler.recordFrameDuration(seconds: seconds)
    }

    // MARK: - Settings

    func applySettings(_ settings: SettingsState) {
        runtimeSettings = settings
        flashPulseEnabled = !settings.reduceFlashing
        audioService.applyVolumes(settings.volumes)
        playerVisual?.setMotionAllowed(flashPulseEnabled)
        for node in npcVisuals.values {
            node.setMotionAllowed(flashPulseEnabled)
        }
        publishDerivedState(rebuildCells: false)
    }

    func updateInputDevice(_ device: InputDeviceKind) {
        guard runtimeSettings.lastUsedDevice != device else { return }
        runtimeSettings.lastUsedDevice = device
        invalidateHudCache()
        onStateChanged?()
    }

    func exportSettings() -> SettingsState {
        runtimeSettings
    }

    func syncSettingsIntoGameState() {
        gameState.settings = runtimeSettings
    }

    func replaceSessionState(
        _ state: GameState,
        activeManualSlotIndex: Int = 0,
        usesCampaignGenerationPersistence: Bool = false
    ) {
        self.activeManualSlotIndex = ((activeManualSlotIndex % SaveSlotCatalog.manualSlotNames.count)
            + SaveSlotCatalog.manualSlotNames.count) % SaveSlotCatalog.manualSlotNames.count
        self.usesCampaignGenerationPersistence = usesCampaignGenerationPersistence
        applyLoadedState(state)
        publishDerivedState(rebuildCells: true)
    }

    func setMenuPaused(_ paused: Bool) {
        if paused {
            clockSystem.addPauseReason(.menu)
        } else {
            clockSystem.removePauseReason(.menu)
        }
    }

    var isMenuPaused: Bool {
        clockSystem.containsPauseReason(.menu)
    }

    // MARK: - Player intent (keyboard)

    @discardableResult
    func tryMove(_ direction: Direction) -> Bool {
        if dialogueSession != nil || storyDialogueView != nil {
            return false
        }
        let result = MapTravelService.tryMove(
            state: &gameState,
            direction: direction,
            catalog: catalog
        )
        playerVisual?.setFacing(direction)
        if result.didMove {
            playerVisual?.playWalkSway(direction: direction)
        }
        if result.didTravel {
            lastFeedback = "已进入\(currentMap.displayName)。"
            lastFeedbackIsSuccess = true
            closeProcessingPanelIfNeeded()
            publishDerivedState(rebuildCells: true)
            return true
        }
        if MapTravelService.facingOrStandingExit(state: gameState, catalog: catalog) != nil {
            lastFeedback = "这里是地图出口。面向出口或按空格可以前往另一边。"
            lastFeedbackIsSuccess = true
            publishDerivedState(rebuildCells: false)
            return result.didMove
        }
        if isPreviewingPlacement, let definitionID = selectedPlacedObjectID {
            let preview = commands.previewPlacement(
                state: gameState,
                definitionID: definitionID,
                origin: hudTarget,
                facing: gameState.facing
            )
            applyPreviewFeedback(preview)
        }
        closeProcessingPanelIfNeeded()
        publishDerivedState(rebuildCells: false)
        return result.didMove
    }

    func selectTool(_ tool: FarmTool) {
        if tool == .seed, selectedTool == .seed {
            cycleSeedSelection()
            return
        }
        guard selectedTool != tool else { return }
        selectedTool = tool
        if tool == .seed {
            selectAvailableSeedIfNeeded()
            lastFeedback = "已选择种子：\(catalog.displayName(forItemID: selectedSeedItemID))。再按 2 切换。"
        } else {
            lastFeedback = "已选择工具：\(tool.displayName)。"
        }
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    private func selectAvailableSeedIfNeeded() {
        guard InventoryService.count(gameState.inventory, itemID: selectedSeedItemID) == 0,
              let first = availableSeedItemIDs.first else { return }
        selectedSeedItemID = first
    }

    private var availableSeedItemIDs: [String] {
        ContentID.farmSeedItemIDs.filter {
            InventoryService.count(gameState.inventory, itemID: $0) > 0
        }
    }

    private func cycleSeedSelection() {
        let available = availableSeedItemIDs
        guard !available.isEmpty else {
            lastFeedback = "背包里没有可用种子。"
            lastFeedbackIsSuccess = false
            publishDerivedState(rebuildCells: false)
            return
        }
        let current = available.firstIndex(of: selectedSeedItemID) ?? -1
        selectedSeedItemID = available[(current + 1) % available.count]
        lastFeedback = "已选择种子：\(catalog.displayName(forItemID: selectedSeedItemID))。"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    func performAction() {
        if storyDialogueView != nil {
            advanceStoryDialogue()
            return
        }
        if hasArmedStoryBeat || canRearmStoryStage {
            openStoryDialogueIfPending()
            if storyDialogueView != nil {
                return
            }
        }
        if tryGraduateByLeave() {
            return
        }
        if tryBeginFinaleDiscovery() {
            return
        }
        if tryPrepareJourneyDeparture() {
            return
        }
        if dialogueSession != nil {
            advanceDialogue()
            return
        }
        if travelThroughExitIfRequested() {
            return
        }
        if gatherIfPossible() {
            return
        }
        if openOrFocusProcessingStation() {
            return
        }
        guard gameState.currentMapID == ContentID.farmHomestead else {
            applyFeedback(.failure("这里不能耕作。走到石阶可返回农场。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let target = hudTarget
        let outcome = actionService.apply(
            to: &gameState,
            target: target,
            tool: selectedTool,
            catalog: catalog,
            seedItemID: selectedSeedItemID
        )
        lastFeedback = outcome.reason
        lastFeedbackIsSuccess = outcome.isSuccess
        if outcome.isSuccess {
            let playedFormalAction = playerVisual?.playPlayerAction(
                event: outcome.event,
                direction: gameState.facing
            ) ?? false
            var completed: [String] = []
            if outcome.event == "harvested" {
                if !playedFormalAction {
                    playerVisual?.playHarvestPulse()
                }
                audioService.play(.harvest)
                completed = tutorialService.recordHarvest(state: &gameState)
                if completed.isEmpty, gameState.tutorial.harvestCount < 3 {
                    lastFeedback = "已收获 \(gameState.tutorial.harvestCount)/3 株雾萝卜。"
                    lastFeedbackIsSuccess = true
                }
            } else {
                completed = tutorialService.advance(state: &gameState)
            }
            if outcome.event == "watered" {
                playWorldEffect(RuntimeArtCatalog.waterSplashFrames, at: target)
                if tryGraduateByWater() {
                    return
                }
            } else if outcome.event == "harvested" {
                playWorldEffect(RuntimeArtCatalog.harvestFrames, at: target)
            }
            applyTutorialCompletionIfNeeded(completed)
        }
        publishDerivedState(rebuildCells: true, changedCell: target)
    }

    func depositShipping() {
        if rejectIfDialogueLocked("投入出售箱") {
            return
        }
        let prices = EconomyCatalog(content: catalog)
        let uniqueIDs = Array(
            Set(gameState.inventory.map(\.itemID).filter { prices.isShippable(itemID: $0) })
        ).sorted()
        guard !uniqueIDs.isEmpty else {
            applyFeedback(.failure("背包没有可投入的物品。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        var deposited = 0
        var last = CommandFeedback.failure("投入失败，背包与出售箱均未改变。")
        for itemID in uniqueIDs {
            let quantity = InventoryService.count(gameState.inventory, itemID: itemID)
            guard quantity > 0 else { continue }
            last = commands.depositShipping(
                state: &gameState,
                itemID: itemID,
                quantity: quantity
            )
            if last.isSuccess {
                deposited += quantity
            } else {
                applyFeedback(last)
                publishDerivedState(rebuildCells: true)
                return
            }
        }
        if uniqueIDs.count == 1 {
            applyFeedback(last)
        } else {
            applyFeedback(.success("已投入出售箱，共 \(deposited) 件。"))
        }
        if last.isSuccess {
            audioService.play(.deposit)
            applyTutorialCompletionIfNeeded(tutorialService.advance(state: &gameState))
        }
        publishDerivedState(rebuildCells: true)
    }

    func retrieveShipping() {
        if rejectIfDialogueLocked("取回出售箱物品") {
            return
        }
        guard gameState.economy.shipping.pendingQuantity > 0 else {
            applyFeedback(.failure("出售箱是空的，没有可取回的物品。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let feedback = commands.retrieveAllShipping(state: &gameState)
        applyFeedback(feedback)
        publishDerivedState(rebuildCells: true)
    }

    func craftSelectedRecipe() {
        if rejectIfDialogueLocked("制作") {
            return
        }
        if isProcessingPanelOpen {
            guard let recipeID = selectedProcessingRecipeID else {
                applyFeedback(.failure("没有可加工的配方。"))
                publishDerivedState(rebuildCells: false)
                return
            }
            let feedback = commands.process(state: &gameState, recipeID: recipeID)
            applyFeedback(feedback)
            if feedback.isSuccess {
                audioService.play(.craft)
            }
            publishDerivedState(rebuildCells: true)
            return
        }
        guard let recipeID = selectedRecipeID else {
            applyFeedback(.failure("没有可制作的配方。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let feedback = commands.craft(state: &gameState, recipeID: recipeID)
        applyFeedback(feedback)
        if feedback.isSuccess {
            audioService.play(.craft)
        }
        publishDerivedState(rebuildCells: true)
    }

    func cycleRecipe() {
        if rejectIfDialogueLocked("切换配方") {
            return
        }
        if isProcessingPanelOpen {
            let recipeIDs = catalog.availableProcessingRecipeIDs(for: gameState)
            guard !recipeIDs.isEmpty else {
                applyFeedback(.failure("没有可切换的加工配方。"))
                publishDerivedState(rebuildCells: false)
                return
            }
            selectedProcessingRecipeIndex = (selectedProcessingRecipeIndex + 1) % recipeIDs.count
            applyFeedback(.success("已选择加工配方：\(selectedProcessingRecipeName)。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let recipeIDs = catalog.availableRecipeIDs(for: gameState)
        guard !recipeIDs.isEmpty else {
            applyFeedback(.failure("没有可切换的配方。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        selectedRecipeIndex = (selectedRecipeIndex + 1) % recipeIDs.count
        syncSelectedRecipeIntoGameState()
        if isPreviewingPlacement, let definitionID = selectedPlacedObjectID {
            let preview = commands.previewPlacement(
                state: gameState,
                definitionID: definitionID,
                origin: hudTarget,
                facing: gameState.facing
            )
            applyPreviewFeedback(preview)
        } else {
            applyFeedback(.success("已选择配方：\(selectedRecipeName)。"))
        }
        publishDerivedState(rebuildCells: false)
    }

    func previewPlacement() {
        if rejectIfDialogueLocked("放置预览") {
            return
        }
        guard gameState.currentMapID == ContentID.farmHomestead else {
            applyFeedback(.failure("只能在农场放置。"))
            isPreviewingPlacement = false
            publishDerivedState(rebuildCells: false)
            return
        }
        guard let definitionID = selectedPlacedObjectID else {
            applyFeedback(.failure("当前配方没有可放置的物体。"))
            isPreviewingPlacement = false
            publishDerivedState(rebuildCells: false)
            return
        }
        isPreviewingPlacement = true
        let preview = commands.previewPlacement(
            state: gameState,
            definitionID: definitionID,
            origin: hudTarget,
            facing: gameState.facing
        )
        applyPreviewFeedback(preview)
        publishDerivedState(rebuildCells: false)
    }

    func confirmPlacement() {
        if rejectIfDialogueLocked("确认放置") {
            return
        }
        guard gameState.currentMapID == ContentID.farmHomestead else {
            applyFeedback(.failure("只能在农场放置。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        guard let definitionID = selectedPlacedObjectID else {
            applyFeedback(.failure("当前配方没有可放置的物体。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let feedback = commands.place(
            state: &gameState,
            definitionID: definitionID,
            origin: hudTarget,
            facing: gameState.facing
        )
        applyFeedback(feedback)
        if feedback.isSuccess {
            isPreviewingPlacement = false
        }
        publishDerivedState(rebuildCells: true)
    }

    func sleepAndSettle() {
        if rejectIfDialogueLocked("睡眠日结") {
            return
        }
        isPreviewingPlacement = false
        let feedback: CommandFeedback
        if usesCampaignGenerationPersistence {
            let coordinator = CampaignSaveCoordinator(
                rootDirectory: saveDirectory,
                catalog: catalog
            )
            let owner = SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex)
            feedback = commands.sleep(
                state: &gameState,
                clock: clockSystem,
                persist: { candidate in
                    _ = try coordinator.save(
                        candidate,
                        kind: .campaignAuto,
                        ownerManualSlot: owner
                    )
                }
            )
        } else {
            feedback = commands.sleep(
                state: &gameState,
                clock: clockSystem,
                store: autoSaveStore()
            )
        }
        applyFeedback(feedback)
        if feedback.isSuccess {
            audioService.play(.settle)
            applyTutorialCompletionIfNeeded(tutorialService.advance(state: &gameState))
        }
        publishDerivedState(rebuildCells: true)
    }

#if DEBUG
    func grantDebugMaterials() {
        let feedback = DevelopmentCommands.grantMaterialKit(
            state: &gameState,
            catalog: catalog
        )
        applyFeedback(feedback)
        publishDerivedState(rebuildCells: true)
    }

    func showDebugReport() {
        let report = commands.debugReport(state: gameState)
        applyFeedback(.success(report))
        publishDerivedState(rebuildCells: false)
    }

    /// Test/evidence-only state injection. Release builds expose no mutation
    /// path and gameplay still reaches these states through domain services.
    func installN015PresentationEvidenceState(_ state: GameState) {
        gameState = state
        if didSetup {
            publishDerivedState(rebuildCells: true)
        } else {
            invalidateHudCache()
        }
    }

    enum N027FarmSceneSmokeFixture {
        case q01WarningOne
        case galleryUnlocked
    }

    /// DEBUG-only accelerated fixture install for the isolated smoke driver.
    /// The Q01 fixture is SaveValidation-legal; the gallery fixture is a
    /// presentation preview that is never saved.
    func installN027StorySmokeFixture(_ fixture: N027FarmSceneSmokeFixture) {
        switch fixture {
        case .q01WarningOne:
            // Reuse the live campaign ID so campaignAuto saves (dialogue
            // checkpoints) pass the coordinator's campaign guard.
            gameState = N027StoryPresentationFixture.q01WarningOneArmed(
                campaignID: gameState.campaignID
            )
        case .galleryUnlocked:
            gameState = N027StoryPresentationFixture.galleryUnlockedPresentation()
        }
        storyDialogueFocusedIntentIndex = 0
        storyGalleryPreRevealRecall = nil
        if didSetup {
            publishDerivedState(rebuildCells: true)
        } else {
            invalidateHudCache()
        }
    }
#endif

    func talkToNpc() {
        if storyDialogueView != nil {
            advanceStoryDialogue()
            return
        }
        if hasArmedStoryBeat || canRearmStoryStage {
            openStoryDialogueIfPending()
            if storyDialogueView != nil {
                return
            }
        }
        if dialogueSession != nil {
            advanceDialogue()
            return
        }
        guard let presence = MapTravelService.npc(atOrFacing: gameState, catalog: catalog) else {
            applyFeedback(.failure(HudCopy.noNpcToTalk()))
            publishDerivedState(rebuildCells: false)
            return
        }
        let dialogueID = CanalProgressionService.dialogueID(for: presence, state: gameState)
        let alreadyCompleted =
            (presence.isTeachingSpawn
                && gameState.tutorial.talkedToWaterApprentice
                && dialogueID == ContentID.waterApprenticeVs0Dialogue)
            || dialogueID == ContentID.waterApprenticeQuestDone
        guard let session = DialogueService.start(
            dialogueID: dialogueID,
            catalog: catalog,
            alreadyCompleted: alreadyCompleted,
            clock: clockSystem
        ) else {
            applyFeedback(.failure("现在无法交谈。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        dialogueSession = session
        activeTeachingNPC = presence.isTeachingSpawn
        talkingNpcID = presence.npcID
        lastPresentedCharacterID = presence.npcID
        audioService.play(.talk)
        npcVisuals[presence.npcID]?.setTalking(true)
        lastFeedback = "\(session.speakerName)：\(session.currentLine)"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    // MARK: - Community event (M3-003)

    /// NPC the player is standing on or facing; community actions are submitted
    /// to this NPC only.
    private var adjacentNpcID: String? {
        MapTravelService.npc(atOrFacing: gameState, catalog: catalog)?.npcID
    }

    private var adjacentGossipActions: [GossipActionDefinition] {
        guard let npcID = adjacentNpcID else { return [] }
        return community.availableActions(state: gameState, npcID: npcID)
    }

    func cycleGossipAction() {
        if rejectIfDialogueLocked("切换社区行动") {
            return
        }
        let actions = adjacentGossipActions
        guard !actions.isEmpty else {
            applyFeedback(.failure("附近没有可提交的社区行动。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        selectedGossipActionIndex = (selectedGossipActionIndex + 1) % actions.count
        let choice = actions[selectedGossipActionIndex].choiceText
        applyFeedback(.success("已选择社区行动：\(choice)。按 B 提交。"))
        publishDerivedState(rebuildCells: false)
    }

    func submitGossipAction() {
        if rejectIfDialogueLocked("提交社区行动") {
            return
        }
        guard let npcID = adjacentNpcID else {
            applyFeedback(.failure("先走到涧麦婶、青砚或絮宁旁边再提交。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let actions = adjacentGossipActions
        guard !actions.isEmpty else {
            applyFeedback(.failure("这位邻居现在没有可提交的社区行动。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let action = actions[selectedGossipActionIndex % actions.count]
        let feedback = community.submit(state: &gameState, actionID: action.id, npcID: npcID)
        applyFeedback(feedback)
        selectedGossipActionIndex = 0
        publishDerivedState(rebuildCells: true)
    }

    /// Neighbour C's ungated one-step objective: the recovery path that lifts a
    /// paused optional node back to available without any standing gate.
    func completeEvidenceObjective() {
        if rejectIfDialogueLocked("可选恢复") {
            return
        }
        guard adjacentNpcID == ContentID.neighborEvidence else {
            applyFeedback(.failure(HudCopy.evidenceAwayFromQingyan()))
            publishDerivedState(rebuildCells: false)
            return
        }
        switch ResolveGossipActionUseCase.completeEvidenceObjective(
            state: &gameState,
            catalog: catalog
        ) {
        case .failure:
            applyFeedback(.failure(HudCopy.evidenceCannotComplete()))
        case .success(let standing):
            applyFeedback(
                .success(
                    HudCopy.evidenceCompleted(
                        standing: standing,
                        optionalSummary: community.optionalNodeSummary(state: gameState)
                    )
                )
            )
        }
        publishDerivedState(rebuildCells: true)
    }

    func cycleSaveSlot() {
        activeManualSlotIndex = (activeManualSlotIndex + 1) % SaveSlotCatalog.manualSlotNames.count
        lastFeedback = "当前手动存档槽：\(activeSaveSlotLabel)。"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    func saveGame(toSlot index: Int? = nil) {
        if rejectIfDialogueLocked("保存") {
            return
        }
        if let index {
            activeManualSlotIndex = ((index % SaveSlotCatalog.manualSlotNames.count)
                + SaveSlotCatalog.manualSlotNames.count) % SaveSlotCatalog.manualSlotNames.count
        }
        syncSettingsIntoGameState()
        syncSelectedRecipeIntoGameState()
        var candidate = gameState
        let completed = tutorialService.recordManualSave(state: &candidate)
        do {
            if usesCampaignGenerationPersistence {
                let coordinator = CampaignSaveCoordinator(
                    rootDirectory: saveDirectory,
                    catalog: catalog
                )
                _ = try coordinator.save(
                    candidate,
                    kind: .manual,
                    ownerManualSlot: SaveSlotCatalog.manualSlotName(
                        index: activeManualSlotIndex
                    )
                )
            } else {
                try manualSaveStore().save(candidate)
            }
            gameState = candidate
            lastFeedback = "保存成功（\(activeSaveSlotLabel)）。"
            lastFeedbackIsSuccess = true
            applyTutorialCompletionIfNeeded(completed)
        } catch SaveStoreError.cannotCreateDirectory {
            lastFeedback = "保存失败：无法创建存档目录。"
            lastFeedbackIsSuccess = false
        } catch SaveStoreError.temporaryVerificationFailed {
            lastFeedback = "保存失败：写入校验未通过。"
            lastFeedbackIsSuccess = false
        } catch SaveStoreError.cannotPreserveBackup {
            lastFeedback = "保存失败：无法保留备份。"
            lastFeedbackIsSuccess = false
        } catch SaveStoreError.replacementFailed {
            lastFeedback = "保存失败：替换存档失败。"
            lastFeedbackIsSuccess = false
        } catch {
            lastFeedback = "保存失败：\(error.localizedDescription)"
            lastFeedbackIsSuccess = false
        }
        publishDerivedState(rebuildCells: true)
    }

    func loadGame(fromSlot index: Int? = nil) {
        if let index {
            activeManualSlotIndex = ((index % SaveSlotCatalog.manualSlotNames.count)
                + SaveSlotCatalog.manualSlotNames.count) % SaveSlotCatalog.manualSlotNames.count
        }
        let store = manualSaveStore()
        do {
            let loaded = try loadFromManualOrLegacy(store: store)
            applyLoadedState(loaded)
            lastFeedback = "读取成功（\(activeSaveSlotLabel)），状态已恢复。"
            lastFeedbackIsSuccess = true
        } catch SaveStoreError.missingSave {
            lastFeedback = "读取失败：\(activeSaveSlotLabel) 没有存档。"
            lastFeedbackIsSuccess = false
        } catch SaveStoreError.noValidSaveGeneration {
            lastFeedback = "读取失败：存档损坏且无有效备份。"
            lastFeedbackIsSuccess = false
        } catch SaveStoreError.unsupportedSchema {
            lastFeedback = "读取失败：存档版本不受支持。"
            lastFeedbackIsSuccess = false
        } catch {
            lastFeedback = "读取失败：\(error.localizedDescription)"
            lastFeedbackIsSuccess = false
        }
        publishDerivedState(rebuildCells: true)
    }

    @discardableResult
    func exportPerformanceEvidence(to directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("[PerfExport] mkdir failed: \(error)")
            return false
        }
        var payload: [String: Any] = [
            "sampling_method": [
                "frame_times": "mach_absolute_time duration of FarmScene.update() plus perf stress intents per paced frame; excludes idle sleep",
                "map_loads": "mach_absolute_time from beginLoad() before travel through finishLoad() after rebuildLayout",
                "memory_mb": "mach_task_basic_info resident_size sampled every 5s during update()",
            ],
            "generated_at_utc": ISO8601DateFormatter().string(from: Date()),
            "frame_times": frameSampler.summaryJSON(includeSamples: false),
            "map_loads": mapLoadTimer.summaryJSON(includeSamples: false),
            "resolution": ["width": Double(size.width), "height": Double(size.height)],
        ]
        if !memorySamplesMB.isEmpty, let start = memorySamplesMB.first, let peak = memorySamplesMB.max(), let end = memorySamplesMB.last {
            payload["memory_mb"] = [
                "start": start,
                "peak": peak,
                "end": end,
                "sample_count": memorySamplesMB.count,
            ]
        }
        guard PerformanceEvidenceWriter.writeJSON(payload, fileName: "perf-summary.json", directory: directory) else {
            print("[PerfExport] perf-summary.json failed")
            return false
        }
        let frameSamples: [Double] = frameSampler.samplesMs
        if !frameSamples.isEmpty {
            struct FrameSamplesFile: Encodable {
                let clockSource = "mach_absolute_time"
                let samplesMs: [Double]

                enum CodingKeys: String, CodingKey {
                    case clockSource = "clock_source"
                    case samplesMs = "samples_ms"
                }
            }
            guard PerformanceEvidenceWriter.writeEncodable(
                FrameSamplesFile(samplesMs: frameSamples),
                fileName: "frame-samples.json",
                directory: directory
            ) else {
                print("[PerfExport] frame-samples.json failed")
                return false
            }
        }
        let mapSamples: [Double] = mapLoadTimer.samplesMs
        if !mapSamples.isEmpty {
            struct MapSamplesFile: Encodable {
                let clockSource = "mach_absolute_time"
                let samplesMs: [Double]

                enum CodingKeys: String, CodingKey {
                    case clockSource = "clock_source"
                    case samplesMs = "samples_ms"
                }
            }
            guard PerformanceEvidenceWriter.writeEncodable(
                MapSamplesFile(samplesMs: mapSamples),
                fileName: "map-load-samples.json",
                directory: directory
            ) else {
                print("[PerfExport] map-load-samples.json failed")
                return false
            }
        }
        return true
    }

    /// Initializes nodes/layout for headless perf sampling (no SKView required).
    func prepareForPerformanceMeasurement(warmupSeconds: TimeInterval = 60) {
        if !didSetup {
            backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
            addChild(gridRoot)
            addChild(buildingRoot)
            previewRoot.zPosition = 6
            addChild(previewRoot)
            npcRoot.zPosition = 9
            addChild(npcRoot)
            configurePlayer()
            configureAmbienceBanner()
            didSetup = true
        }
        lastUpdateTime = 0
        isPerformanceMeasurementSession = true
        frameSampler = FrameTimeSampler(warmupSeconds: warmupSeconds)
        mapLoadTimer.reset()
        memorySamplesMB.removeAll()
        lastMemorySampleTime = 0
        rebuildLayout()
    }

    /// Farm ↔ market round trips using real travel + layout rebuild timing.
    func runMapTransitionBenchmark(roundTrips: Int, preserveExistingSamples: Bool = false) {
        if preserveExistingSamples {
            mapLoadTimer.reset()
            gameState = .vs0NewGame()
            restoreRecipeSelection(from: gameState)
            rebuildLayout()
        } else {
            prepareForPerformanceMeasurement(warmupSeconds: 0)
        }
        let trips = max(roundTrips, 1)
        for _ in 0..<trips {
            for _ in 0..<2 {
                positionAtMapExitForTravel()
                _ = travelThroughExitIfRequested()
            }
        }
    }

    private func positionAtMapExitForTravel() {
        guard let exit = currentMap.exits.first else { return }
        gameState.position = exit.cell
        gameState.facing = gameState.currentMapID == ContentID.farmHomestead ? .down : .up
    }

    func stepPerformanceMapTravel() {
        positionAtMapExitForTravel()
        _ = travelThroughExitIfRequested()
    }

    private func loadFromManualOrLegacy(store: SaveStore) throws -> GameState {
        if FileManager.default.fileExists(atPath: store.primaryURL.path) {
            return try store.load()
        }
        return try legacySaveStore().load()
    }

    private func applyLoadedState(_ loaded: GameState) {
        DialogueService.end(clock: clockSystem)
        dialogueSession = nil
        activeTeachingNPC = false
        talkingNpcID = nil
        selectedGossipActionIndex = 0
        gameState = loaded
        runtimeSettings = loaded.settings
        flashPulseEnabled = !runtimeSettings.reduceFlashing
        clockSystem = ClockSystem()
        isPreviewingPlacement = false
        isProcessingPanelOpen = false
        restoreRecipeSelection(from: loaded)
        _ = tutorialService.advance(state: &gameState)
    }

    // MARK: - Derived HUD state

    var hudText: String {
        hudText(compact: false)
    }

    func hudText(compact: Bool) -> String {
        if !hudDirty, cachedHudCompact == compact, let cachedHudText {
            return cachedHudText
        }
        let built = buildHudText(compact: compact)
        cachedHudText = built
        cachedHudCompact = compact
        hudDirty = false
        return built
    }

    private func buildHudText(compact: Bool) -> String {
        let hour = gameState.clock.minute / 60
        let minute = gameState.clock.minute % 60
        let time = String(format: "%02d:%02d", hour, minute)
        let pending = gameState.economy.shipping.pendingQuantity
        let storyDialogueLine = storyDialogueView.map { view in
            let speaker = view.pageLines.map(\.speakerName).joined(separator: "、")
            let text = view.pageLines.map(\.text).joined(separator: " ")
            return "【剧情】\(view.arcID.shortCode) \(view.stageKind.rawValue) \(view.pageNumber)/\(view.pageCount) \(speaker)：\(text)"
        }
        let dialogueLine = storyDialogueLine ?? dialogueSession.map { session in
            "\(session.speakerName)：\(session.currentLine)"
        }
        let weather = catalog.scenario.weather(on: gameState.clock.day).displayName
        let goalLine = tutorialService.goalLine(for: gameState)
        let feedback = HudCopy.feedbackLine(message: lastFeedback, isSuccess: lastFeedbackIsSuccess)
        let saveSlotLine = "存档槽 \(activeSaveSlotLabel)  ·  自动槽 \(SaveSlotCatalog.displayLabel(for: SaveSlotCatalog.autoSlotName))"
        if compact {
            return HudCopy.compactAssemble(
                mapName: currentMap.displayName,
                day: gameState.clock.day,
                time: time,
                weather: weather,
                goalLine: goalLine,
                recipe: hudRecipeName,
                saveSlotLine: saveSlotLine,
                feedback: feedback,
                collapsedHint: "【折叠】HUD 已折叠  [H]展开  地图可见"
            )
        }
        return HudCopy.assemble(
            mapName: currentMap.displayName,
            day: gameState.clock.day,
            time: time,
            weather: weather,
            goalLine: goalLine,
            questSummary: CanalProgressionService.questSummary(state: gameState, catalog: catalog),
            watershedLine: HudCopy.watershedLine(state: gameState, catalog: catalog),
            standingLine: community.standingLine(state: gameState),
            eventLine: community.eventLine(state: gameState),
            verificationHint: community.verificationPathLine(state: gameState),
            trustLine: community.trustLine(state: gameState),
            optionalNodeLine: community.optionalNodeSummary(state: gameState),
            actionLine: community.actionLine(
                state: gameState,
                npcID: adjacentNpcID,
                selectedIndex: selectedGossipActionIndex
            ),
            stamina: gameState.stamina,
            balance: gameState.economy.balance,
            pending: pending,
            inventory: inventorySummary,
            recipe: hudRecipeName,
            settlement: lastSettlementText,
            tool: selectedTool == .seed
                ? "种子·\(catalog.displayName(forItemID: selectedSeedItemID))"
                : selectedTool.displayName,
            playerCaption: "(\(gameState.position.x), \(gameState.position.y))",
            targetCaption: "(\(hudTarget.x), \(hudTarget.y))",
            dialogueLine: dialogueLine,
            feedback: feedback,
            isDialogueActive: dialogueSession != nil || storyDialogueView != nil,
            accessibilityLine: runtimeSettings.accessibilitySummaryLine(),
            volumeLine: runtimeSettings.volumeSummaryLine(),
            inputHintBlock: InputBindingsService.keyHintLines(settings: runtimeSettings)
                + "\n"
                + HudCopy.keyHints(isDialogueActive: dialogueSession != nil)
                + "\n[H]折叠 HUD  [O]切换存档槽"
        )
    }

    private func invalidateHudCache() {
        hudDirty = true
    }

    private func syncSelectedRecipeIntoGameState() {
        gameState.selectedRecipeID = selectedRecipeID
    }

    private func restoreRecipeSelection(from state: GameState) {
        let recipeIDs = catalog.availableRecipeIDs(for: state)
        guard !recipeIDs.isEmpty else {
            selectedRecipeIndex = 0
            gameState.selectedRecipeID = nil
            return
        }
        if let saved = state.selectedRecipeID, let index = recipeIDs.firstIndex(of: saved) {
            selectedRecipeIndex = index
        } else {
            selectedRecipeIndex = 0
        }
        gameState.selectedRecipeID = selectedRecipeID
    }

    private func sampleMemoryIfNeeded() {
        let now = PerformanceClock.monotonicSeconds()
        guard now - lastMemorySampleTime >= 5 else { return }
        lastMemorySampleTime = now
        if let mb = MemorySampler.residentSizeMB() {
            memorySamplesMB.append(mb)
        }
    }

    // MARK: - Layout

    private func rebuildLayout() {
        gridRoot.removeAllChildren()
        buildingRoot.removeAllChildren()

        cellSize = WorldCamera.cellSize(for: size)
        gridOrigin = .zero

        rebuildBleed()
        rebuildCells()
        rebuildBuildings()
        rebuildWorldLife()
        refreshPlayerPath()
        positionPlayer()
        refreshNpcNodes()
        positionTargetHighlight()
        refreshPlacementPreviewNodes()
        refreshAmbienceBanner()
        applyCamera()
    }

    /// N-019 decorative world-life layer: shrubs, flowers, ambient animals,
    /// the cat-bbq landmark and its three cat staff, plus the edge landscape
    /// band. Presentation-only; never saved, never collides.
    private func rebuildWorldLife() {
        lifeRoot.removeAllChildren()
        let npcPositions = Set(
            WorldCatalog.npcs.values
                .filter { $0.mapID == currentMap.id }
                .map(\.position)
        )
        let gatherPositions = Set(
            ProgressionCatalog.gatherNodeList
                .filter { $0.mapID == currentMap.id }
                .map(\.position)
        )
        let placements = WorldLifeCatalog.placements(mapID: currentMap.id)
            + WorldLifeCatalog.edgeBand(mapID: currentMap.id)
        for placement in placements {
            if !WorldLifeCatalog.shouldRender(placement.kind, livestock: gameState.livestock) {
                continue
            }
            if placement.kind == .catBbqShop {
                // 溪火猫食铺 R3 画布 72×72（3×3 格），底边中点锚定在 anchor 格。
                // 画布是展示专用视觉层：允许覆盖环境边界与建筑遮挡，只要求
                // 画布完全落在当前地图画布内；不参与碰撞、不写存档。
                let canvasX = placement.cell.x - 1...placement.cell.x + 1
                let canvasY = placement.cell.y...placement.cell.y + 2
                guard canvasX.lowerBound >= 0,
                      canvasX.upperBound < currentMap.columns,
                      canvasY.upperBound < currentMap.rows else { continue }
            } else if !placement.kind.isBackdrop {
                if !currentMap.contains(placement.cell) { continue }
                let isIntentionalLandscapeBoundary = currentMap.environmentBoundaryCells.contains(placement.cell)
                    && (placement.kind.isTree || placement.kind.isShrub
                        || placement.kind.isFlower || placement.kind.isFence
                        || placement.kind.isFieldPatch || placement.kind.isScenicTilled)
                let isIntentionalWaterDetail = (placement.kind.isRiverStone || placement.kind.isShoreInset)
                    && currentMap.waterCells.contains(where: { $0.cell == placement.cell })
                if currentMap.isBlocked(placement.cell)
                    && !isIntentionalLandscapeBoundary
                    && !isIntentionalWaterDetail { continue }
                if WorldVisualCatalog.isStonePath(placement.cell, mapID: currentMap.id)
                    && !placement.kind.isPastureGround { continue }
                if npcPositions.contains(placement.cell) { continue }
                if gatherPositions.contains(placement.cell) { continue }
                if currentMap.exits.contains(where: { $0.cell == placement.cell }) { continue }
                if currentMap.spawns.contains(where: { $0.position == placement.cell }) { continue }
            }
            guard let image = WorldLifeCatalog.image(for: placement.kind) else { continue }
            let texture = SKTexture(image: image)
            // World-life assets, including the R17 horizon, are authored at
            // native pixel resolution. Nearest-only
            // sampling preserves the established game pixel density and hard
            // edge language instead of blending in painterly HD cutouts.
            texture.filteringMode = .nearest
            let scale = PixelMetrics.integerScale(cellSize: cellSize)
            let native = image.size
            // 32 px crop art uses the next lower integer zoom so each mature
            // plant fits inside its 24 px wet-soil bed instead of merging into
            // neighbouring plants. Tiles, cats, animals and buildings retain
            // the shared scene zoom.
            let presentationScale: CGFloat
            if placement.kind.isCropDisplay {
                presentationScale = max(1, scale - 1)
            } else if placement.kind.isFarShoreInset {
                // Smaller, cooler far-bank pieces establish the distant plane.
                presentationScale = max(1, scale - 1)
            } else if placement.kind.isNearShoreInset {
                // Larger camera-facing pieces overlap the near edge as foreground.
                presentationScale = scale + 1
            } else {
                presentationScale = scale
            }
            let sprite = SKSpriteNode(
                texture: texture,
                size: CGSize(
                    width: native.width * presentationScale,
                    height: native.height * presentationScale
                )
            )
            sprite.texture?.filteringMode = .nearest
            sprite.name = "world-life-\(placement.kind.rawValue)"
            let position = cellCenter(column: placement.cell.x, row: placement.cell.y)
            if placement.kind.isBackdrop {
                // Native panorama widths are exactly mapColumns × 24. Center
                // them on the full map instead of on an integer anchor cell.
                // The anchor row supplies only the lower edge, allowing the
                // ridge to sit behind buildings, paths and the market exit.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(
                    x: CGFloat(currentMap.columns) * cellSize / 2,
                    y: CGFloat(placement.cell.y) * cellSize
                )
                sprite.zPosition = placement.kind.backdropLayerZ
            } else if placement.kind == .catBbqShop {
                // 72×72 canvas, bottom-center anchor on the anchor cell; the
                // compact landmark sits beside, rather than over, the entrance.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = 0
            } else if placement.kind.isScenicLake {
                // Final world z=1.1: below buildings, actors and every normal
                // prop. Four native 144×96 frames share one hard shoreline;
                // only the internal water glints move.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.1
                    - lifeRoot.zPosition
                let textures = WorldLifeCatalog.marketScenicLakeFrames().map { frame -> SKTexture in
                    let frameTexture = SKTexture(image: frame)
                    frameTexture.filteringMode = .nearest
                    return frameTexture
                }
                if let first = textures.first {
                    sprite.texture = first
                }
                if flashPulseEnabled, textures.count == 4 {
                    sprite.run(SKAction.repeatForever(SKAction.animate(
                        with: textures,
                        timePerFrame: 0.14,
                        resize: false,
                        restore: false
                    )), withKey: "market-scenic-lake-flow")
                }
            } else if placement.kind.isGreenhouse {
                // Keep the catalog anchor and all gameplay geometry stable;
                // move only the rendered canvas half a tile toward the horizon.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(
                    x: position.x,
                    y: position.y - cellSize / 2
                        + cellSize * WorldLifeCatalog.marketGreenhouseRetreatInTiles
                )
                sprite.zPosition = RuntimeRenderLayer.buildingBase.rawValue - 0.2
                    - lifeRoot.zPosition
            } else if placement.kind.isDiningSet {
                // Top-centre anchoring keeps the composite in the lower-left
                // clearing and lets its three stools extend into the south bleed.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 1)
                sprite.position = CGPoint(x: position.x, y: position.y + cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.cropOrPropBase.rawValue + 0.1
                    - lifeRoot.zPosition
            } else if placement.kind.isCatStaff {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.actor.rawValue - 0.2
                attachGentleSway(to: sprite)
            } else if placement.kind.isAnimal {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.actor.rawValue - 0.5
                attachGentleSway(to: sprite)
            } else if placement.kind.isTree {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.actor.rawValue - 1.0
            } else if placement.kind.isGardenBed {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = position
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.2
            } else if placement.kind.isScenicTilled {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = position
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.18
            } else if placement.kind.isPastureGround {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = position
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.15
            } else if placement.kind.isRiverStone {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.85
            } else if placement.kind.isShoreInset {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = position
                if placement.kind.isFarShoreInset {
                    sprite.color = NSColor(
                        calibratedRed: 120 / 255,
                        green: 151 / 255,
                        blue: 160 / 255,
                        alpha: 1
                    )
                    sprite.colorBlendFactor = 0.16
                    sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.62
                } else {
                    sprite.color = NSColor(
                        calibratedRed: 38 / 255,
                        green: 54 / 255,
                        blue: 56 / 255,
                        alpha: 1
                    )
                    sprite.colorBlendFactor = 0.14
                    sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 1.08
                }
            } else if placement.kind.isFence {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = position
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.9
            } else if placement.kind.isCropDisplay {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.7
            } else if placement.kind.isFieldPatch || placement.kind.isHaystack {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.55
            } else {
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: position.x, y: position.y - cellSize / 2)
                sprite.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.4
                attachGentleSway(to: sprite)
            }
            lifeRoot.addChild(sprite)
        }
        rebuildMarketSluiceApronIfNeeded()
    }

    /// Extends the wharf outlet across its lower footprint cell so the
    /// presentation reads as one continuous gate -> stone chute -> creek path.
    /// The water cell below owns the second half; neither node affects collision.
    private func rebuildMarketSluiceApronIfNeeded() {
        guard currentMap.id == ContentID.creekMarket else { return }
        let position = cellCenter(
            column: WorldVisualCatalog.marketSluiceApron.x,
            row: WorldVisualCatalog.marketSluiceApron.y
        )
        let descriptor = RuntimeArtCatalog.descriptor(for: .tileCanalNS)
        if let apron = PixelAssetStore.shared.makeSprite(
            descriptor: descriptor,
            cellSize: cellSize
        ) {
            apron.name = "formal-sluice-apron"
            apron.position = position
            apron.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.3
            lifeRoot.addChild(apron)
        }
        if let runoff = WorldEffectPresenter.makeAnimatedSprite(
            keys: WorldVisualCatalog.canalAnimationKeys(
                at: WorldVisualCatalog.marketSluiceApron
            ),
            cellSize: cellSize,
            timePerFrame: 0.14,
            loops: true,
            motionAllowed: flashPulseEnabled,
            name: "formal-sluice-apron-runoff"
        ) {
            runoff.position = position
            runoff.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.5
            lifeRoot.addChild(runoff)
        }
    }

    /// Pixel-stepped idle motion keeps world-life texels on whole scene points.
    /// Continuous interpolation made nearest-neighbour sprites shimmer between
    /// fractional positions, especially on Retina captures.
    private func attachGentleSway(to node: SKNode) {
        guard flashPulseEnabled else { return }
        let phase = Double(Int(abs(node.position.x)) % 4) * 0.08
        node.run(SKAction.repeatForever(SKAction.sequence([
            .wait(forDuration: 0.72 + phase),
            .moveBy(x: 0, y: 1, duration: 0),
            .wait(forDuration: 0.36),
            .moveBy(x: 0, y: -1, duration: 0),
            .wait(forDuration: 0.72),
        ])))
    }

    private func applyCamera() {
        let hudSafeRect = HudSafeZoneLayout.resolve(viewport: size).worldSafeRectDefault
        worldRoot.position = WorldCamera.worldOrigin(
            viewport: size,
            mapColumns: mapColumns,
            mapRows: mapRows,
            cellSize: cellSize,
            player: gameState.position,
            safeRect: WorldCamera.sceneSafeRect(fromHudSafeRect: hudSafeRect, viewport: size)
        )
    }

    private func publishDerivedState(rebuildCells shouldRebuild: Bool, changedCell: GridPosition? = nil) {
        if lastFeedback != lastPublishedFeedback {
            if lastFeedbackIsSuccess, runtimeSettings.vibrationEnabled {
                shakeRemaining = 0.25
            }
            lastPublishedFeedback = lastFeedback
            feedbackExpiresAt = Date().addingTimeInterval(
                3.5 * runtimeSettings.textSpeed.pacingMultiplier
            )
        }
        if shouldRebuild {
            if let changedCell {
                refreshCell(at: changedCell)
            } else {
                rebuildBleed()
                rebuildCells()
            }
        }
        rebuildBuildings()
        rebuildWorldLife()
        positionPlayer()
        refreshNpcNodes()
        positionTargetHighlight()
        refreshPlacementPreviewNodes()
        refreshAmbienceBanner()
        applyCamera()
        syncAudioEnvironment()
        invalidateHudCache()
        onStateChanged?()
        writeHudDumpIfNeeded()
    }

    /// Debug-only HUD snapshot for D0/M4 evidence capture when AX is unavailable.
    private func writeHudDumpIfNeeded() {
        guard !isPerformanceMeasurementSession else { return }
        let url = saveDirectory.appendingPathComponent("hud-latest.txt")
        try? hudText.write(to: url, atomically: true, encoding: .utf8)
        let compactURL = saveDirectory.appendingPathComponent("hud-compact-latest.txt")
        try? hudText(compact: true).write(to: compactURL, atomically: true, encoding: .utf8)
        let consumed = PixelAssetStore.shared.loadedAssetIDs.joined(separator: "\n") + "\n"
        try? consumed.write(
            to: saveDirectory.appendingPathComponent("consumed-runtime-pngs.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func cellNodeName(at position: GridPosition) -> String {
        "cell-\(position.x)-\(position.y)"
    }

    private func refreshCell(at position: GridPosition) {
        gridRoot.childNode(withName: cellNodeName(at: position))?.removeFromParent()
        let node = makeCellNode(at: position)
        node.name = cellNodeName(at: position)
        node.position = cellCenter(column: position.x, row: position.y)
        gridRoot.addChild(node)
    }

    private func rebuildCells() {
        gridRoot.removeAllChildren()
        for row in 0..<mapRows {
            for column in 0..<mapColumns {
                let position = GridPosition(x: column, y: row)
                let node = makeCellNode(at: position)
                node.name = cellNodeName(at: position)
                node.position = cellCenter(column: column, row: row)
                gridRoot.addChild(node)
            }
        }
    }

    private func rebuildBuildings() {
        buildingRoot.removeAllChildren()
        for building in currentMap.buildings {
            let node = BuildingVisualPresenter.makeNode(
                building: building,
                cellSize: cellSize,
                playerPosition: gameState.position,
                watershedRestored: gameState.watershed.isRestored
            )
            let anchor = cellCenter(column: building.renderAnchor.x, row: building.renderAnchor.y)
            node.position.x += anchor.x
            node.position.y += anchor.y - cellSize / 2
            buildingRoot.addChild(node)
        }
    }

    /// Renders a farm plot with pixel tiles when present, else shape + label
    /// signals (never color alone): empty grass, tilled furrows, sprout/seedling/
    /// mature crop, water drop, and a "成熟" tag with an outline ring.
    private func makeCellNode(at position: GridPosition) -> SKNode {
        let node = SKNode()
        let cell = gameState.cell(at: position)
        let inset = max(cellSize * 0.06, 2)
        let size = cellSize - inset

        let isEven = (position.x + position.y).isMultiple(of: 2)
        let onFarm = gameState.currentMapID == ContentID.farmHomestead
        let waterCells = WorldVisualCatalog.restoredWaterCells(
            mapID: currentMap.id,
            restored: gameState.watershed.isRestored
        )
        let usedPixelTile = addPixelTileIfAvailable(
            to: node,
            onFarm: onFarm,
            prepared: cell.prepared,
            watered: cell.wateredToday,
            position: position,
            waterCells: waterCells
        )
        if !usedPixelTile {
            let ground = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
            if onFarm {
                ground.fillColor = isEven
                    ? SKColor(red: 0.45, green: 0.58, blue: 0.36, alpha: 1)
                    : SKColor(red: 0.38, green: 0.50, blue: 0.30, alpha: 1)
                ground.strokeColor = SKColor(red: 0.28, green: 0.36, blue: 0.24, alpha: 1)
            } else {
                ground.fillColor = isEven
                    ? SKColor(red: 0.42, green: 0.52, blue: 0.58, alpha: 1)
                    : SKColor(red: 0.36, green: 0.46, blue: 0.54, alpha: 1)
                ground.strokeColor = SKColor(red: 0.22, green: 0.32, blue: 0.40, alpha: 1)
            }
            ground.lineWidth = 1
            node.addChild(ground)
        }

        if onFarm, cell.prepared, !usedPixelTile {
            let soil = SKShapeNode(
                rectOf: CGSize(width: size * 0.96, height: size * 0.96),
                cornerRadius: 3
            )
            soil.fillColor = SKColor(red: 0.52, green: 0.38, blue: 0.24, alpha: 1)
            soil.strokeColor = SKColor(red: 0.34, green: 0.24, blue: 0.15, alpha: 1)
            soil.lineWidth = 1
            node.addChild(soil)

            let furrowSpacing = size * 0.28
            var furrowY = -furrowSpacing
            while furrowY <= furrowSpacing {
                let furrow = SKShapeNode(
                    rectOf: CGSize(width: size * 0.82, height: max(1.5, cellSize * 0.035))
                )
                furrow.fillColor = SKColor(red: 0.28, green: 0.19, blue: 0.11, alpha: 0.95)
                furrow.position = CGPoint(x: 0, y: furrowY)
                node.addChild(furrow)
                furrowY += furrowSpacing
            }
        }

        if onFarm, cell.hasCrop {
            node.addChild(makeCropNode(cell: cell))

            // Keep the field calm: readiness is emphasized only for the cell
            // the player is actively facing. A yellow frame around every
            // mature plant turned a crop row into a wall of UI boxes.
            if cell.readyToHarvest, position == hudTarget {
                let ring = SKShapeNode(
                    rectOf: CGSize(width: size * 0.94, height: size * 0.94),
                    cornerRadius: 4
                )
                ring.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1)
                ring.lineWidth = max(2.5, cellSize * 0.06)
                ring.fillColor = .clear
                node.addChild(ring)

            }
        }

        if onFarm, cell.wateredToday, !usedPixelTile {
            let drop = SKShapeNode(
                ellipseIn: CGRect(x: -cellSize * 0.10, y: -cellSize * 0.08,
                                  width: cellSize * 0.20, height: cellSize * 0.26)
            )
            drop.fillColor = SKColor(red: 0.35, green: 0.62, blue: 0.95, alpha: 0.9)
            drop.strokeColor = SKColor(red: 0.20, green: 0.42, blue: 0.72, alpha: 1)
            drop.lineWidth = 1
            drop.position = CGPoint(x: cellSize * 0.28, y: cellSize * 0.26)
            node.addChild(drop)
        }

        if onFarm, let placed = placedObject(at: position) {
            let glyph = makePlacedObjectGlyph(placed: placed)
            let displayCell = WorldVisualCatalog.placedObjectDisplayCell(
                for: placed,
                mapID: currentMap.id
            )
            glyph.name = "placed-object-\(placed.instanceID)"
            glyph.position = CGPoint(
                x: CGFloat(displayCell.x - placed.origin.x) * cellSize,
                y: CGFloat(displayCell.y - placed.origin.y) * cellSize
            )
            node.addChild(glyph)
        }

        if currentMap.exit(at: position) != nil,
           !WorldVisualCatalog.isStonePath(position, mapID: currentMap.id),
           !usedPixelTile {
            let step = SKShapeNode(
                rectOf: CGSize(width: size * 0.70, height: size * 0.28),
                cornerRadius: 2
            )
            step.fillColor = SKColor(red: 0.72, green: 0.68, blue: 0.58, alpha: 1)
            step.strokeColor = SKColor(red: 0.40, green: 0.34, blue: 0.24, alpha: 1)
            step.position = CGPoint(x: 0, y: cellSize * 0.12)
            node.addChild(step)

        }

        if let gather = catalog.gatherNode(at: position, mapID: currentMap.id, state: gameState) {
            let harvested = gameState.harvestedGatherNodeIDs.contains(gather.id)
            if !harvested {
                let gatherKey = RuntimeArtCatalog.gatherKey(for: gather)
                let descriptor = RuntimeArtCatalog.descriptor(for: gatherKey)
                if let sprite = PixelAssetStore.shared.makeSprite(descriptor: descriptor, cellSize: cellSize) {
                    if gatherKey == .gatherCreekWood {
                        // One diagonal piece looked like a dropped tool. Two
                        // mirrored, integer-scaled pieces read as a small wood
                        // cache and sit naturally on the new service landing.
                        let scale = max(PixelMetrics.integerScale(cellSize: cellSize) - 1, 1)
                        sprite.size = CGSize(
                            width: descriptor.nativeSize.width * CGFloat(scale),
                            height: descriptor.nativeSize.height * CGFloat(scale)
                        )
                        sprite.position = CGPoint(x: -cellSize * 0.10, y: -cellSize / 2)
                        let second = SKSpriteNode(texture: sprite.texture, size: sprite.size)
                        second.texture?.filteringMode = .nearest
                        second.anchorPoint = sprite.anchorPoint
                        second.xScale = -1
                        second.position = CGPoint(x: cellSize * 0.14, y: -cellSize / 2 + CGFloat(scale * 2))
                        second.name = "formal-gatherable-wood-stack"
                        second.zPosition = RuntimeRenderLayer.cropOrPropBase.rawValue - 0.1
                        node.addChild(second)
                    } else {
                        sprite.position = CGPoint(x: 0, y: -cellSize / 2)
                    }
                    sprite.name = "formal-gatherable"
                    sprite.zPosition = RuntimeRenderLayer.cropOrPropBase.rawValue
                    node.addChild(sprite)
                } else {
                    let badge = SKShapeNode(rectOf: CGSize(width: size * 0.42, height: size * 0.28), cornerRadius: 2)
                    badge.fillColor = SKColor(red: 0.28, green: 0.52, blue: 0.34, alpha: 0.95)
                    badge.strokeColor = SKColor.white
                    badge.position = CGPoint(x: 0, y: cellSize * 0.12)
                    node.addChild(badge)
                }
            }
        }

        return node
    }

    /// Growth stages use distinct shapes plus a stage label ("芽"/"苗"/"熟").
    private func makeCropNode(cell: FarmCell) -> SKNode {
        let node = SKNode()
        if let assetID = PixelAssetCatalog.cropStageAssetID(
            cropID: cell.cropID,
            stage: cell.cropStage,
            readyToHarvest: cell.readyToHarvest
        ), let texture = PixelAssetStore.shared.texture(named: assetID) {
            let scale = PixelMetrics.integerScale(cellSize: cellSize)
            let spriteSize = CGSize(
                width: PixelMetrics.cropNative.width * scale,
                height: PixelMetrics.cropNative.height * scale
            )
            let sprite = SKSpriteNode(texture: texture, size: spriteSize)
            sprite.texture?.filteringMode = .nearest
            sprite.name = "pixel-crop-stage"
            // Bottom-center anchor: the plant grows upward without sliding its roots.
            sprite.position = CGPoint(x: 0, y: (spriteSize.height - cellSize) / 2)
            sprite.zPosition = 2
            node.addChild(sprite)
            return node
        }
        let green = SKColor(red: 0.35, green: 0.75, blue: 0.32, alpha: 1)
        let leafGreen = SKColor(red: 0.28, green: 0.62, blue: 0.24, alpha: 1)

        switch cell.cropStage {
        case 0:
            let stem = SKShapeNode(
                rectOf: CGSize(width: max(2, cellSize * 0.05), height: cellSize * 0.18)
            )
            stem.fillColor = leafGreen
            stem.position = CGPoint(x: 0, y: cellSize * 0.06)
            node.addChild(stem)

            let sprout = SKShapeNode(circleOfRadius: max(3, cellSize * 0.10))
            sprout.fillColor = green
            sprout.position = CGPoint(x: 0, y: cellSize * 0.16)
            node.addChild(sprout)


        case 1:
            let stem = SKShapeNode(
                rectOf: CGSize(width: max(2.5, cellSize * 0.06), height: cellSize * 0.30)
            )
            stem.fillColor = leafGreen
            stem.position = CGPoint(x: 0, y: cellSize * 0.08)
            node.addChild(stem)

            let leafLeft = SKShapeNode(
                ellipseIn: CGRect(x: -cellSize * 0.24, y: cellSize * 0.04,
                                  width: cellSize * 0.22, height: cellSize * 0.14)
            )
            leafLeft.fillColor = green
            leafLeft.zRotation = -0.6
            node.addChild(leafLeft)

            let leafRight = SKShapeNode(
                ellipseIn: CGRect(x: cellSize * 0.02, y: cellSize * 0.04,
                                  width: cellSize * 0.22, height: cellSize * 0.14)
            )
            leafRight.fillColor = leafGreen
            leafRight.zRotation = 0.6
            node.addChild(leafRight)


        default:
            if let kind = PixelAssetCatalog.cropKind(for: cell.cropID),
               let sprite = PixelAssetStore.shared.makeSprite(kind: kind, cellSize: cellSize) {
                sprite.name = "pixel-crop"
                sprite.zPosition = 2
                node.addChild(sprite)
            } else {
                // Mature mist radish (procedural fallback): white bulb + green tops.
                let bulb = SKShapeNode(
                    ellipseIn: CGRect(x: -cellSize * 0.20, y: -cellSize * 0.16,
                                      width: cellSize * 0.40, height: cellSize * 0.40)
                )
                bulb.fillColor = SKColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
                bulb.strokeColor = SKColor(red: 0.72, green: 0.66, blue: 0.60, alpha: 1)
                bulb.lineWidth = 1
                node.addChild(bulb)

                let rootTip = SKShapeNode(
                    ellipseIn: CGRect(x: -cellSize * 0.05, y: -cellSize * 0.28,
                                      width: cellSize * 0.10, height: cellSize * 0.16)
                )
                rootTip.fillColor = SKColor(red: 0.92, green: 0.88, blue: 0.82, alpha: 1)
                node.addChild(rootTip)

                let topLeaf = SKShapeNode(
                    ellipseIn: CGRect(x: -cellSize * 0.16, y: cellSize * 0.14,
                                      width: cellSize * 0.34, height: cellSize * 0.14)
                )
                topLeaf.fillColor = leafGreen
                topLeaf.zRotation = -0.25
                node.addChild(topLeaf)
            }

        }

        return node
    }

    /// Formal terrain is presentation-only. Domain map topology remains owned
    /// by WorldCatalog and MapTravelService.
    @discardableResult
    private func addPixelTileIfAvailable(
        to node: SKNode,
        onFarm: Bool,
        prepared: Bool,
        watered: Bool,
        position: GridPosition,
        waterCells: Set<GridPosition>
    ) -> Bool {
        if waterCells.contains(position) {
            if let shore = PixelAssetStore.shared.makeSprite(kind: .tileWaterEdge, cellSize: cellSize) {
                shore.name = "formal-water-edge"
                shore.zPosition = RuntimeRenderLayer.ground.rawValue - 0.1
                node.addChild(shore)
            }
            guard let water = WorldEffectPresenter.makeAnimatedSprite(
                keys: WorldVisualCatalog.waterAnimationKeys(at: position),
                cellSize: cellSize,
                timePerFrame: 0.14,
                loops: true,
                motionAllowed: flashPulseEnabled,
                name: "formal-water"
            ) else { return false }
            water.zPosition = RuntimeRenderLayer.ground.rawValue
            if currentMap.id == ContentID.creekMarket {
                // Three hard-edged colour planes make the horizontal creek
                // read as distance: cool/light far row, neutral middle row,
                // and darker camera-facing row. Texture pixels and nearest
                // sampling stay intact; no blur or gradient is introduced.
                switch position.y {
                case 2:
                    water.color = NSColor(
                        calibratedRed: 120 / 255,
                        green: 151 / 255,
                        blue: 160 / 255,
                        alpha: 1
                    )
                    water.colorBlendFactor = 0.14
                case 0:
                    water.color = NSColor(
                        calibratedRed: 38 / 255,
                        green: 54 / 255,
                        blue: 56 / 255,
                        alpha: 1
                    )
                    water.colorBlendFactor = 0.12
                default:
                    water.colorBlendFactor = 0
                }
            }
            node.addChild(water)
            let border = WorldVisualCatalog.waterBorder(at: position, mapID: currentMap.id)
            for key in border.edgeKeys + border.cornerKeys {
                let descriptor = RuntimeArtCatalog.descriptor(for: key)
                if let overlay = PixelAssetStore.shared.makeSprite(descriptor: descriptor, cellSize: cellSize) {
                    overlay.zPosition = RuntimeRenderLayer.groundDetail.rawValue
                    node.addChild(overlay)
                }
            }
            let sluiceKeys = WorldVisualCatalog.sluiceConnectionKeys(
                at: position,
                mapID: currentMap.id
            )
            for key in sluiceKeys {
                let descriptor = RuntimeArtCatalog.descriptor(for: key)
                if let connector = PixelAssetStore.shared.makeSprite(
                    descriptor: descriptor,
                    cellSize: cellSize
                ) {
                    connector.name = "formal-sluice-river-connector"
                    connector.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.3
                    node.addChild(connector)
                }
            }
            if !sluiceKeys.isEmpty,
               let runoff = WorldEffectPresenter.makeAnimatedSprite(
                    keys: WorldVisualCatalog.canalAnimationKeys(at: position),
                    cellSize: cellSize,
                    timePerFrame: 0.14,
                    loops: true,
                    motionAllowed: flashPulseEnabled,
                    name: "formal-sluice-runoff"
               ) {
                runoff.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.5
                node.addChild(runoff)
            }
            return true
        }
        let farmApronKeys = WorldVisualCatalog.farmSluiceConnectionKeys(
            at: position,
            mapID: currentMap.id
        )
        let isFarmSluiceApron = !farmApronKeys.isEmpty
        let canalKeys = isFarmSluiceApron
            ? farmApronKeys
            : WorldVisualCatalog.canalKeys(
                at: position,
                mapID: currentMap.id,
                restored: gameState.watershed.isRestored
            )
        if !canalKeys.isEmpty {
            for canalKey in canalKeys {
                let descriptor = RuntimeArtCatalog.descriptor(for: canalKey)
                if let canal = PixelAssetStore.shared.makeSprite(descriptor: descriptor, cellSize: cellSize) {
                    canal.name = isFarmSluiceApron
                        ? "formal-farm-sluice-apron"
                        : "formal-canal-base"
                    canal.zPosition = RuntimeRenderLayer.groundDetail.rawValue
                    node.addChild(canal)
                }
            }
            if currentMap.id == ContentID.farmHomestead {
                let depth = makeNorthSouthCanalDepthOverlay(includesMouthShadow: isFarmSluiceApron)
                depth.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.18
                node.addChild(depth)
            }
            let raining = catalog.scenario.weather(on: gameState.clock.day) == .rain
            let showsFlow = currentMap.id == ContentID.farmHomestead
                || gameState.watershed.isRestored
                || raining
            if showsFlow,
               let flow = WorldEffectPresenter.makeAnimatedSprite(
                    keys: WorldVisualCatalog.canalAnimationKeys(at: position),
                    cellSize: cellSize,
                    timePerFrame: 0.14,
                    loops: true,
                    motionAllowed: flashPulseEnabled,
                    name: isFarmSluiceApron
                        ? "formal-farm-sluice-apron-flow"
                        : "formal-canal-flow"
               ) {
                flow.zPosition = RuntimeRenderLayer.groundDetail.rawValue + 0.3
                node.addChild(flow)
            }
            return true
        }
        if WorldVisualCatalog.isStonePath(position, mapID: currentMap.id) {
            let descriptor = RuntimeArtCatalog.descriptor(for: .tileStonePath)
            if let sprite = PixelAssetStore.shared.makeSprite(descriptor: descriptor, cellSize: cellSize) {
                sprite.name = "formal-stone-path"
                sprite.zPosition = RuntimeRenderLayer.ground.rawValue
                node.addChild(sprite)
                return true
            }
        }
        let kind = PixelAssetCatalog.tileKind(
            prepared: onFarm && prepared,
            watered: onFarm && watered,
            isWaterEdge: false,
            position: position
        )
        guard let sprite = PixelAssetStore.shared.makeSprite(kind: kind, cellSize: cellSize) else {
            return false
        }
        sprite.name = onFarm && prepared
            ? (watered ? "farm-soil-watered-r2" : "farm-soil-dry-r2")
            : "pixel-tile"
        sprite.zPosition = 0
        node.addChild(sprite)
        return true
    }

    /// Hard-edged one-pixel light and two-pixel shadow strips reinforce the
    /// channel walls without soft gradients or higher-resolution cutouts.
    /// The apron receives one extra mouth shadow that remains below the B4
    /// building layers, so the water appears to emerge from inside the wheel.
    private func makeNorthSouthCanalDepthOverlay(includesMouthShadow: Bool) -> SKNode {
        let root = SKNode()
        root.name = "formal-canal-depth"
        let scale = CGFloat(PixelMetrics.integerScale(cellSize: cellSize))

        let castShadow = SKSpriteNode(
            color: SKColor(red: 0.055, green: 0.13, blue: 0.16, alpha: 0.34),
            size: CGSize(width: scale * 2, height: cellSize)
        )
        castShadow.name = "formal-canal-cast-shadow"
        castShadow.position = CGPoint(x: scale * 5, y: 0)
        root.addChild(castShadow)

        let sunlitRim = SKSpriteNode(
            color: SKColor(red: 0.68, green: 0.88, blue: 0.84, alpha: 0.28),
            size: CGSize(width: scale, height: cellSize)
        )
        sunlitRim.name = "formal-canal-sunlit-rim"
        sunlitRim.position = CGPoint(x: -scale * 5, y: 0)
        sunlitRim.zPosition = 0.1
        root.addChild(sunlitRim)

        if includesMouthShadow {
            let mouthShadow = SKSpriteNode(
                color: SKColor(red: 0.055, green: 0.13, blue: 0.16, alpha: 0.48),
                size: CGSize(width: scale * 10, height: scale * 2)
            )
            mouthShadow.name = "formal-farm-sluice-mouth-shadow"
            mouthShadow.position = CGPoint(x: 0, y: cellSize * 0.36)
            mouthShadow.zPosition = 0.2
            root.addChild(mouthShadow)
        }
        return root
    }

    private func configurePlayer() {
        playerNode.removeAllChildren()
        playerNode.zPosition = 10
        playerNode.name = "player"

        let visual = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: cellSize,
            showsTalkBadge: false,
            showsName: false
        )
        visual.setMotionAllowed(flashPulseEnabled)
        playerVisual = visual
        playerNode.addChild(visual)

        facingIndicator.isHidden = true
        facingIndicator.fillColor = SKColor(red: 0.22, green: 0.45, blue: 0.38, alpha: 0.35)
        facingIndicator.strokeColor = SKColor.white.withAlphaComponent(0.4)
        facingIndicator.lineWidth = 1
        facingIndicator.zPosition = 12
        playerNode.addChild(facingIndicator)

        if playerNode.parent == nil {
            worldRoot.addChild(playerNode)
        }
        if targetHighlight.parent == nil {
            worldRoot.addChild(targetHighlight)
        }
        refreshPlayerPath()
    }

    private func configureAmbienceBanner() {
        ambienceBanner.isHidden = true
        addChild(ambienceBanner)
    }

    private func rebuildBleed() {
        bleedRoot.removeAllChildren()
        let bleed = WorldCamera.bleedCells
        for row in -bleed..<(mapRows + bleed) {
            for column in -bleed..<(mapColumns + bleed) {
                if (0..<mapColumns).contains(column), (0..<mapRows).contains(row) { continue }
                let kind = PixelAssetCatalog.tileKind(
                    prepared: false,
                    watered: false,
                    isWaterEdge: false,
                    position: GridPosition(x: column, y: row)
                )
                guard let sprite = PixelAssetStore.shared.makeSprite(kind: kind, cellSize: cellSize) else {
                    continue
                }
                sprite.position = cellCenter(column: column, row: row)
                sprite.alpha = 0.88
                sprite.zPosition = -1
                bleedRoot.addChild(sprite)
            }
        }
    }

    private func refreshAmbienceBanner() {
        let restored = gameState.watershed.isRestored
        let weather = catalog.scenario.weather(on: gameState.clock.day)
        let isRain = weather == .rain
        let isMarket = gameState.currentMapID == ContentID.creekMarket
        backgroundColor = WorldCamera.atmosphereColor(
            mapID: gameState.currentMapID,
            isRain: isRain,
            restored: restored
        )
        weatherRoot.removeAllChildren()
        let wash = SKSpriteNode(
            color: WorldCamera.weatherWash(isRain: isRain, isMarket: isMarket),
            size: size
        )
        wash.anchorPoint = .zero
        wash.zPosition = 0
        wash.name = "weather-wash"
        weatherRoot.addChild(wash)
        guard isRain else { return }
        for index in 0..<8 {
            guard let splash = WorldEffectPresenter.makeAnimatedSprite(
                keys: RuntimeArtCatalog.waterSplashFrames,
                cellSize: 24,
                timePerFrame: 0.16,
                loops: true,
                motionAllowed: flashPulseEnabled,
                name: "formal-rain-splash"
            ) else { continue }
            let x = CGFloat((index * 167 + 41) % max(Int(size.width), 1))
            let y = size.height - CGFloat(36 + (index * 53) % 160)
            splash.position = CGPoint(x: x, y: y)
            splash.alpha = 0.5
            splash.zPosition = 1
            weatherRoot.addChild(splash)
        }
    }

    private func refreshNpcNodes() {
        npcRoot.isHidden = false
        let visible = MapTravelService.visibleNpcs(state: gameState, catalog: catalog)
        let visibleIDs = Set(visible.map(\.npcID))
        for (id, node) in npcVisuals where !visibleIDs.contains(id) {
            node.removeFromParent()
            npcVisuals.removeValue(forKey: id)
        }
        for presence in visible {
            let node: CharacterVisualNode
            if let existing = npcVisuals[presence.npcID] {
                node = existing
                node.layout(cellSize: cellSize)
            } else {
                node = CharacterVisualNode(
                    definition: CharacterVisualCatalog.visual(for: presence.npcID),
                    cellSize: cellSize,
                    showsTalkBadge: true
                )
                node.setMotionAllowed(flashPulseEnabled)
                npcRoot.addChild(node)
                npcVisuals[presence.npcID] = node
            }
            node.position = cellCenter(column: presence.position.x, row: presence.position.y)
            let isTalking = talkingNpcID == presence.npcID
            let columnDistance = abs(presence.position.x - gameState.position.x)
            let rowDistance = abs(presence.position.y - gameState.position.y)
            let proximity = max(columnDistance, rowDistance)
            node.setContextVisibility(
                nameVisible: proximity <= 3 || isTalking,
                badgeVisible: proximity <= 1 && !isTalking
            )
            node.setTalking(isTalking)
        }
    }

    private func startPresentationAudioIfNeeded() {
        // The macOS XCTest host boots the SwiftUI app before the test bundle is
        // connected. Starting AVAudioPlayerNode in that bootstrap window can
        // raise an Objective-C AVFAudio exception after device sleep/wake and
        // prevent every test from launching. Audio has dedicated service tests;
        // presentation autoplay is therefore disabled only in the XCTest host.
        let isXCTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isPerformanceMeasurementSession else { return }
        if isXCTestHost {
            syncAudioEnvironment()
            return
        }
        audioService.setLogURL(saveDirectory.appendingPathComponent("audio-latest.json"))
        audioService.start(volumes: runtimeSettings.volumes)
        syncAudioEnvironment()
    }

    private func syncAudioEnvironment() {
        let isXCTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isPerformanceMeasurementSession else { return }
        let weather = catalog.scenario.weather(on: gameState.clock.day)
        let mapLayer: AmbientMapLayer = gameState.currentMapID == ContentID.creekMarket ? .creek : .farm
        let weatherLayer: AmbientWeatherLayer = weather == .rain ? .rain : .none
        if isXCTestHost {
            audioService.setEnvironmentWithoutPlayback(mapLayer: mapLayer, weatherLayer: weatherLayer)
        } else {
            audioService.setMapLayer(mapLayer)
            audioService.setWeatherLayer(weatherLayer)
        }
    }

    private func refreshPlayerPath() {
        playerVisual?.layout(cellSize: cellSize)
        let arrowSize = max(cellSize * 0.14, 6)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: cellSize * 0.42 + arrowSize))
        path.addLine(to: CGPoint(x: -arrowSize * 0.7, y: cellSize * 0.42 - arrowSize * 0.2))
        path.addLine(to: CGPoint(x: arrowSize * 0.7, y: cellSize * 0.42 - arrowSize * 0.2))
        path.closeSubpath()
        facingIndicator.path = path
        facingIndicator.lineWidth = max(cellSize * 0.03, 1)
    }

    private func positionPlayer() {
        playerNode.position = cellCenter(column: gameState.position.x, row: gameState.position.y)
        playerVisual?.layout(cellSize: cellSize)
        playerVisual?.setFacing(gameState.facing)
        switch gameState.facing {
        case .up:
            facingIndicator.zRotation = 0
        case .right:
            facingIndicator.zRotation = -.pi / 2
        case .down:
            facingIndicator.zRotation = .pi
        case .left:
            facingIndicator.zRotation = .pi / 2
        }
    }

    private func positionTargetHighlight() {
        guard didSetup else { return }
        targetHighlight.removeAllActions()
        targetHighlight.removeAllChildren()
        let targetIsValid = currentMap.contains(hudTarget) && !currentMap.isBlocked(hudTarget)
        let keys = targetIsValid
            ? RuntimeArtCatalog.targetValidFrames
            : RuntimeArtCatalog.targetInvalidFrames
        if let sprite = WorldEffectPresenter.makeAnimatedSprite(
            keys: keys,
            cellSize: cellSize,
            timePerFrame: 0.32,
            loops: true,
            motionAllowed: flashPulseEnabled,
            name: targetIsValid ? "formal-target-valid" : "formal-target-invalid"
        ) {
            targetHighlight.addChild(sprite)
        } else {
            let highlightSize = cellSize - max(cellSize * 0.06, 2) * 0.5
            let fallback = SKShapeNode(
                rectOf: CGSize(width: highlightSize, height: highlightSize),
                cornerRadius: 4
            )
            fallback.strokeColor = targetIsValid
                ? SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
                : SKColor(red: 0.90, green: 0.20, blue: 0.18, alpha: 1)
            fallback.fillColor = .clear
            fallback.lineWidth = max(2.5, cellSize * 0.06)
            targetHighlight.addChild(fallback)
        }
        targetHighlight.zPosition = RuntimeRenderLayer.interactionFx.rawValue
        targetHighlight.position = cellCenter(
            column: hudTarget.x,
            row: hudTarget.y
        )
    }

    private func playWorldEffect(_ keys: [RuntimeArtKey], at position: GridPosition) {
        WorldEffectPresenter.addTransient(
            keys: keys,
            at: cellCenter(column: position.x, row: position.y),
            to: self,
            cellSize: cellSize,
            motionAllowed: flashPulseEnabled
        )
    }

    private func cellCenter(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: gridOrigin.x + (CGFloat(column) + 0.5) * cellSize,
            y: gridOrigin.y + (CGFloat(row) + 0.5) * cellSize
        )
    }

    // MARK: - M2 derived presentation

    private var selectedRecipeID: String? {
        let recipeIDs = catalog.availableRecipeIDs(for: gameState)
        guard !recipeIDs.isEmpty else { return nil }
        return recipeIDs[selectedRecipeIndex % recipeIDs.count]
    }

    private var selectedRecipeName: String {
        guard let recipeID = selectedRecipeID else { return "无" }
        let nameKey = catalog.recipe(id: recipeID)?.nameKey ?? recipeID
        return catalog.displayName(forNameKey: nameKey)
    }

    private var selectedProcessingRecipeID: String? {
        let recipeIDs = catalog.availableProcessingRecipeIDs(for: gameState)
        guard !recipeIDs.isEmpty else { return nil }
        return recipeIDs[selectedProcessingRecipeIndex % recipeIDs.count]
    }

    private var selectedProcessingRecipeName: String {
        guard let recipeID = selectedProcessingRecipeID else { return "无" }
        let nameKey = catalog.recipe(id: recipeID)?.nameKey ?? recipeID
        return catalog.displayName(forNameKey: nameKey)
    }

    private var hudRecipeName: String {
        if isProcessingPanelOpen {
            return "加工 \(selectedProcessingRecipeName)"
        }
        return selectedRecipeName
    }

    private var selectedPlacedObjectID: String? {
        guard let recipeID = selectedRecipeID else { return nil }
        return catalog.recipe(id: recipeID)?.placedObjectID
    }

    private var lastSettlementText: String {
        guard let record = gameState.economy.settlementHistory.last else {
            return "最近日结：尚未结算"
        }
        if record.lines.isEmpty {
            return "最近日结：无出售，总额 0"
        }
        let lines = record.lines.map(\.displayText).joined(separator: "；")
        return "最近日结：\(lines)（总额 \(record.total)）"
    }

    private var inventorySummary: String {
        let usedSlots = gameState.inventory.count
        let trackedIDs = [
            ContentID.mistRadishSeed,
            ContentID.streamLeafSeed,
            ContentID.amberBeanSeed,
            ContentID.bellBerrySeed,
            ContentID.honeyMelonSeed,
            ContentID.mistRadishItem,
            ContentID.creekWood,
            ContentID.mossStone,
            ContentID.reedFiber,
            ContentID.woodenCrateItem,
            ContentID.stonePathItem,
            ContentID.compostRackItem,
            ContentID.canalSegmentItem,
            ContentID.rainBarrelItem,
            ContentID.woodhoneyHearthItem,
            ContentID.creekGreensItem,
            ContentID.honeySearedCreekGreensItem,
            ContentID.amberBeanItem,
            ContentID.honeySearedAmberBeanItem,
            ContentID.bellBerryItem,
            ContentID.honeyPreservedBellBerryItem,
            ContentID.honeyMelonItem,
            ContentID.honeySearedHoneyMelonItem,
        ]
        var parts: [String] = []
        for itemID in trackedIDs {
            let count = InventoryService.count(gameState.inventory, itemID: itemID)
            let alwaysShow = itemID == ContentID.mistRadishSeed || itemID == ContentID.mistRadishItem
            if alwaysShow || count > 0 {
                parts.append("\(catalog.displayName(forItemID: itemID))×\(count)")
            }
        }
        return "背包 \(usedSlots)/\(gameState.inventoryCapacity)  \(parts.joined(separator: "  "))"
    }

    @discardableResult
    private func rejectIfDialogueLocked(_ intent: String) -> Bool {
        guard dialogueSession != nil else {
            return false
        }
        applyFeedback(.failure(HudCopy.dialogueLocked(intent: intent)))
        publishDerivedState(rebuildCells: false)
        return true
    }

    private func applyFeedback(_ feedback: CommandFeedback) {
        lastFeedback = feedback.message
        lastFeedbackIsSuccess = feedback.isSuccess
    }

    private func applyTutorialCompletionIfNeeded(_ completed: [String]) {
        guard let stepID = completed.last,
              let message = tutorialService.completionMessage(for: stepID) else {
            return
        }
        applyFeedback(.success(message))
    }

    private func travelThroughExitIfRequested() -> Bool {
        mapLoadTimer.beginLoad()
        guard let result = MapTravelService.interactWithExit(state: &gameState, catalog: catalog),
              result.didTravel else {
            mapLoadTimer.cancelLoad()
            if MapTravelService.facingOrStandingExit(state: gameState, catalog: catalog) != nil {
                lastFeedback = "面对石阶并按空格可进出地图。"
                lastFeedbackIsSuccess = true
                publishDerivedState(rebuildCells: false)
            }
            return false
        }
        lastFeedback = "已进入\(currentMap.displayName)。"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: true)
        mapLoadTimer.finishLoad()
        return true
    }

    private func gatherIfPossible() -> Bool {
        guard GatherService.node(facingOrStanding: gameState, catalog: catalog) != nil else {
            return false
        }
        let feedback = commands.gatherFacingNode(state: &gameState)
        applyFeedback(feedback)
        publishDerivedState(rebuildCells: true)
        return true
    }

    private func advanceDialogue() {
        guard var session = dialogueSession else { return }
        if session.advance() {
            DialogueService.end(clock: clockSystem)
            dialogueSession = nil
            let trustFeedback = talkingNpcID.flatMap { npcID in
                community.talk(state: &gameState, npcID: npcID)
            }
            if session.isReplay {
                applyFeedback(.success("\(session.speakerName)：\(session.lines[0])"))
            } else if activeTeachingNPC, session.dialogueID == ContentID.waterApprenticeVs0Dialogue {
                let completed = tutorialService.recordTalk(state: &gameState)
                if let stepID = completed.last, let message = tutorialService.completionMessage(for: stepID) {
                    applyFeedback(.success(message))
                } else {
                    applyFeedback(.success("交谈结束。"))
                }
            } else if let questFeedback = CanalProgressionService.handleTalkCompleted(
                dialogueID: session.dialogueID,
                state: &gameState,
                catalog: catalog
            ) {
                applyFeedback(questFeedback)
            } else {
                applyFeedback(.success("交谈结束。"))
            }
            if let trustFeedback {
                applyFeedback(.success("\(lastFeedback) \(trustFeedback.message)"))
            }
            activeTeachingNPC = false
            talkingNpcID = nil
            publishDerivedState(rebuildCells: false)
            return
        }
        dialogueSession = session
        lastFeedback = "\(session.speakerName)：\(session.currentLine)"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    private func applyPreviewFeedback(_ preview: PlacementPreview) {
        let name = catalog.displayName(
            forNameKey: catalog.placedObject(id: preview.definitionID)?.nameKey ?? preview.definitionID
        )
        if preview.isValid {
            applyFeedback(.success("放置预览：\(name) 可放置（未写入存档）。"))
            return
        }
        let message: String
        switch preview.failure {
        case .outOfBounds:
            message = "无法放置：超出农场边界。"
        case .occupancyConflict:
            message = "无法放置：目标被占用。"
        case .notAdjacentToPlayer:
            message = "无法放置：玩家或出口不可达。"
        case .exitUnreachable:
            message = "无法放置：玩家或出口不可达。"
        case .missingItem:
            message = "无法放置：背包没有\(name)。"
        case .unknownDefinition, .none:
            message = "无法放置：预览失败。"
        }
        applyFeedback(.failure(message))
    }

    private func placedObject(at position: GridPosition) -> PlacedObjectState? {
        gameState.placedObjects.first { object in
            PlacementService.absoluteFootprint(
                definitionID: object.definitionID,
                origin: object.origin,
                facing: object.facing,
                catalog: catalog
            ).contains(position)
        }
    }

    @discardableResult
    private func openOrFocusProcessingStation() -> Bool {
        guard facingProcessingStation() else { return false }
        isProcessingPanelOpen = true
        let ids = catalog.availableProcessingRecipeIDs(for: gameState)
        if !ids.isEmpty {
            selectedProcessingRecipeIndex %= ids.count
        }
        let stationName = catalog.displayName(forNameKey: "item.woodhoney_hearth")
        applyFeedback(
            .success("已打开\(stationName)。当前配方：\(selectedProcessingRecipeName)。按切换配方选择，再按制作确认。")
        )
        publishDerivedState(rebuildCells: false)
        return true
    }

    private func closeProcessingPanelIfNeeded() {
        guard isProcessingPanelOpen else { return }
        if facingProcessingStation() { return }
        isProcessingPanelOpen = false
    }

    private func facingProcessingStation() -> Bool {
        guard gameState.currentMapID == ContentID.farmHomestead else { return false }
        let candidates = [hudTarget, gameState.position]
        return candidates.contains { position in
            guard let placed = placedObject(at: position) else { return false }
            return catalog.placedObject(id: placed.definitionID)?.category == "processing"
        }
    }

    private func refreshPlacementPreviewNodes() {
        previewRoot.removeAllChildren()
        guard isPreviewingPlacement, let definitionID = selectedPlacedObjectID else { return }
        let preview = commands.previewPlacement(
            state: gameState,
            definitionID: definitionID,
            origin: hudTarget,
            facing: gameState.facing
        )
        for cell in preview.footprint {
            let node = makePreviewCellNode(isValid: preview.isValid)
            node.position = cellCenter(column: cell.x, row: cell.y)
            previewRoot.addChild(node)
        }
    }

    private func makePreviewCellNode(isValid: Bool) -> SKNode {
        let node = SKNode()
        let size = cellSize - max(cellSize * 0.06, 2)
        let outline = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
        outline.fillColor = isValid
            ? SKColor(red: 0.20, green: 0.70, blue: 0.35, alpha: 0.28)
            : SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 0.28)
        outline.strokeColor = isValid
            ? SKColor(red: 0.15, green: 0.55, blue: 0.28, alpha: 1)
            : SKColor(red: 0.75, green: 0.12, blue: 0.12, alpha: 1)
        outline.lineWidth = max(2, cellSize * 0.05)
        node.addChild(outline)

        if isValid {
            let check = SKShapeNode(circleOfRadius: max(4, cellSize * 0.10))
            check.fillColor = SKColor(red: 0.20, green: 0.62, blue: 0.32, alpha: 1)
            check.strokeColor = SKColor.white
            check.lineWidth = 1
            check.position = CGPoint(x: 0, y: cellSize * 0.10)
            node.addChild(check)
        } else {
            let bar = SKShapeNode(rectOf: CGSize(width: cellSize * 0.36, height: max(2, cellSize * 0.06)))
            bar.fillColor = SKColor(red: 0.82, green: 0.16, blue: 0.16, alpha: 1)
            bar.zRotation = .pi / 4
            bar.position = CGPoint(x: 0, y: cellSize * 0.10)
            node.addChild(bar)
            let bar2 = SKShapeNode(rectOf: CGSize(width: cellSize * 0.36, height: max(2, cellSize * 0.06)))
            bar2.fillColor = SKColor(red: 0.82, green: 0.16, blue: 0.16, alpha: 1)
            bar2.zRotation = -.pi / 4
            bar2.position = CGPoint(x: 0, y: cellSize * 0.10)
            node.addChild(bar2)
        }

        let label = SKLabelNode(text: isValid ? "可" : "否")
        label.fontName = "PingFangSC-Semibold"
        label.fontSize = max(10, cellSize * 0.24)
        label.fontColor = SKColor.white
        label.position = CGPoint(x: 0, y: -cellSize * 0.30)
        label.zPosition = 1
        node.addChild(label)
        return node
    }

    private func makePlacedObjectGlyph(placed: PlacedObjectState) -> SKNode {
        let node = SKNode()
        let definitionID = placed.definitionID
        let formalCanalKey = definitionID == ContentID.canalSegmentObject
            ? RuntimeArtCatalog.placedCanalKey(facing: placed.facing)
            : nil
        let assetID = formalCanalKey?.rawValue
            ?? PixelAssetCatalog.placedObjectAssetID(for: definitionID)
        if let assetID,
           let texture = PixelAssetStore.shared.texture(named: assetID) {
            let sharedScale = PixelMetrics.integerScale(cellSize: cellSize)
            let nativeSize: CGSize
            switch definitionID {
            case ContentID.rainBarrelObject:
                nativeSize = CGSize(width: 24, height: 32)
            case ContentID.woodenCrateObject, ContentID.stonePathObject,
                 ContentID.canalSegmentObject:
                nativeSize = CGSize(width: 24, height: 24)
            default:
                nativeSize = CGSize(width: 48, height: 48)
            }
            // The two 48 px work-yard props were being magnified at the same
            // factor as 24 px ground tiles, so they overlapped neighbouring
            // cells and the hearth read as a building-sized machine. Dropping
            // exactly one integer zoom step preserves crisp pixels and the
            // logical one-cell footprint.
            let scale = definitionID == ContentID.woodhoneyHearthObject
                    || definitionID == ContentID.compostRackObject
                ? max(sharedScale - 1, 1)
                : sharedScale
            let spriteSize = CGSize(width: nativeSize.width * scale, height: nativeSize.height * scale)
            let sprite = SKSpriteNode(texture: texture, size: spriteSize)
            sprite.texture?.filteringMode = .nearest
            sprite.name = "pixel-placed-object"
            // Visual footprint may overhang collision, but its base stays on the authoritative cell.
            sprite.position = CGPoint(x: 0, y: (spriteSize.height - cellSize) / 2)
            sprite.zPosition = 3
            node.addChild(sprite)
            if definitionID == ContentID.canalSegmentObject,
               (gameState.watershed.isRestored || catalog.scenario.weather(on: gameState.clock.day) == .rain),
               let flow = WorldEffectPresenter.makeAnimatedSprite(
                    keys: WorldVisualCatalog.canalAnimationKeys(at: placed.origin),
                    cellSize: cellSize,
                    timePerFrame: 0.14,
                    loops: true,
                    motionAllowed: flashPulseEnabled,
                    name: "placed-canal-flow"
               ) {
                flow.zPosition = RuntimeRenderLayer.interactionFx.rawValue
                node.addChild(flow)
            }
            return node
        }
        let size = cellSize * 0.62
        let plate = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        plate.fillColor = SKColor(red: 0.55, green: 0.40, blue: 0.28, alpha: 1)
        plate.strokeColor = SKColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1)
        plate.lineWidth = 2
        node.addChild(plate)

        let mark: String
        switch definitionID {
        case ContentID.woodenCrateObject:
            mark = "箱"
        case ContentID.stonePathObject:
            mark = "径"
        case ContentID.compostRackObject:
            mark = "肥"
        case ContentID.canalSegmentObject:
            mark = "渠"
        case ContentID.rainBarrelObject:
            mark = "桶"
        case ContentID.woodhoneyHearthObject:
            mark = "灶"
            plate.fillColor = SKColor(red: 0.72, green: 0.42, blue: 0.22, alpha: 1)
            plate.strokeColor = SKColor(red: 0.42, green: 0.22, blue: 0.10, alpha: 1)
        default:
            mark = "物"
        }
        let label = SKLabelNode(text: mark)
        label.fontName = "PingFangSC-Semibold"
        label.fontSize = max(10, cellSize * 0.26)
        label.fontColor = SKColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1)
        label.position = CGPoint(x: 0, y: -cellSize * 0.10)
        label.zPosition = 1
        node.addChild(label)
        if definitionID == ContentID.woodhoneyHearthObject {
            let caption = SKLabelNode(text: "木蜜灶台")
            caption.fontName = "PingFangSC-Semibold"
            caption.fontSize = max(7, cellSize * 0.16)
            caption.fontColor = SKColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1)
            caption.position = CGPoint(x: 0, y: -cellSize * 0.36)
            caption.zPosition = 2
            node.addChild(caption)
        }
        return node
    }
}

private extension FarmTool {
    var displayName: String {
        switch self {
        case .hoe: return "锄头"
        case .seed: return "种子"
        case .water: return "水壶"
        case .harvest: return "收获"
        }
    }
}
