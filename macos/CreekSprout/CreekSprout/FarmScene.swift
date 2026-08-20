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
    private var selectedRecipeIndex = 0
    private var selectedGossipActionIndex = 0
    private var isPreviewingPlacement = false
    private var dialogueSession: DialogueSession?
    private var activeTeachingNPC = false
    private var talkingNpcID: String?
    private(set) var runtimeSettings: SettingsState = .defaults
    private var shakeRemaining: TimeInterval = 0
    private var flashPulseEnabled = true
    private var lastPublishedFeedback = ""
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

    var activeSaveSlotLabel: String {
        SaveSlotCatalog.displayLabel(for: SaveSlotCatalog.manualSlotName(index: activeManualSlotIndex))
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

    private let gridRoot = SKNode()
    private let previewRoot = SKNode()
    private let npcRoot = SKNode()
    private let playerNode = SKNode()
    private let facingIndicator = SKShapeNode()
    private let targetHighlight = SKShapeNode()
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
        let scene = FarmScene(size: CGSize(width: 960, height: 640))
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
            backgroundColor = SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
            addChild(gridRoot)
            previewRoot.zPosition = 6
            addChild(previewRoot)
            npcRoot.zPosition = 9
            addChild(npcRoot)
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

    func exportSettings() -> SettingsState {
        runtimeSettings
    }

    func syncSettingsIntoGameState() {
        gameState.settings = runtimeSettings
    }

    // MARK: - Player intent (keyboard)

    @discardableResult
    func tryMove(_ direction: Direction) -> Bool {
        if dialogueSession != nil {
            return false
        }
        let result = MapTravelService.tryMove(
            state: &gameState,
            direction: direction,
            catalog: catalog
        )
        if result.didMove {
            playerVisual?.playWalkSway()
        }
        if result.didTravel {
            lastFeedback = "已进入\(currentMap.displayName)。"
            lastFeedbackIsSuccess = true
            publishDerivedState(rebuildCells: true)
            return true
        }
        if MapTravelService.facingOrStandingExit(state: gameState, catalog: catalog) != nil {
            lastFeedback = "站在石阶上。面对石阶或按空格可进出地图。"
            lastFeedbackIsSuccess = true
            publishDerivedState(rebuildCells: false)
            return result.didMove
        }
        if isPreviewingPlacement, let definitionID = selectedPlacedObjectID {
            let preview = commands.previewPlacement(
                state: gameState,
                definitionID: definitionID,
                origin: gameState.targetCell,
                facing: gameState.facing
            )
            applyPreviewFeedback(preview)
        }
        publishDerivedState(rebuildCells: false)
        return result.didMove
    }

    func selectTool(_ tool: FarmTool) {
        guard selectedTool != tool else { return }
        selectedTool = tool
        lastFeedback = "已选择工具：\(tool.displayName)。"
        lastFeedbackIsSuccess = true
        publishDerivedState(rebuildCells: false)
    }

    func performAction() {
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
        guard gameState.currentMapID == ContentID.farmHomestead else {
            applyFeedback(.failure("这里不能耕作。走到石阶可返回农场。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let target = gameState.targetCell
        let outcome = actionService.apply(
            to: &gameState,
            target: target,
            tool: selectedTool,
            catalog: catalog
        )
        lastFeedback = outcome.reason
        lastFeedbackIsSuccess = outcome.isSuccess
        if outcome.isSuccess {
            var completed: [String] = []
            if outcome.event == "harvested" {
                playerVisual?.playHarvestPulse()
                audioService.play(.harvest)
                completed = tutorialService.recordHarvest(state: &gameState)
                if completed.isEmpty, gameState.tutorial.harvestCount < 3 {
                    lastFeedback = "已收获 \(gameState.tutorial.harvestCount)/3 株雾萝卜。"
                    lastFeedbackIsSuccess = true
                }
            } else {
                completed = tutorialService.advance(state: &gameState)
            }
            applyTutorialCompletionIfNeeded(completed)
        }
        publishDerivedState(rebuildCells: true, changedCell: target)
    }

    func depositShipping() {
        if rejectIfDialogueLocked("投入出售箱") {
            return
        }
        let quantity = InventoryService.count(gameState.inventory, itemID: ContentID.mistRadishItem)
        guard quantity > 0 else {
            applyFeedback(.failure("背包没有可投入的雾萝卜。"))
            publishDerivedState(rebuildCells: false)
            return
        }
        let feedback = commands.depositShipping(
            state: &gameState,
            itemID: ContentID.mistRadishItem,
            quantity: quantity
        )
        applyFeedback(feedback)
        if feedback.isSuccess {
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
                origin: gameState.targetCell,
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
            origin: gameState.targetCell,
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
            origin: gameState.targetCell,
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
        let feedback = commands.sleep(
            state: &gameState,
            clock: clockSystem,
            store: autoSaveStore()
        )
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
#endif

    func talkToNpc() {
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
        let store = manualSaveStore()
        do {
            try store.save(candidate)
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
        gameState.position = GridPosition(x: 5, y: 0)
        gameState.facing = gameState.currentMapID == ContentID.farmHomestead ? .up : .down
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
        let dialogueLine = dialogueSession.map { session in
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
                recipe: selectedRecipeName,
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
            recipe: selectedRecipeName,
            settlement: lastSettlementText,
            tool: selectedTool.displayName,
            playerCaption: "(\(gameState.position.x), \(gameState.position.y))",
            targetCaption: "(\(hudTarget.x), \(hudTarget.y))",
            dialogueLine: dialogueLine,
            feedback: feedback,
            isDialogueActive: dialogueSession != nil,
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

        let topReserve: CGFloat = 36
        let margin: CGFloat = 32
        let availableWidth = max(size.width - margin * 2, 1)
        let availableHeight = max(size.height - margin * 2 - topReserve, 1)
        let rawCell = min(
            availableWidth / CGFloat(mapColumns),
            availableHeight / CGFloat(mapRows)
        )
        cellSize = PixelMetrics.snappedCellSize(fitting: rawCell)

        let gridWidth = cellSize * CGFloat(mapColumns)
        let gridHeight = cellSize * CGFloat(mapRows)
        gridOrigin = PixelMetrics.snap(
            CGPoint(
                x: (size.width - gridWidth) / 2,
                y: (size.height - gridHeight - topReserve) / 2
            )
        )

        rebuildCells()
        refreshPlayerPath()
        positionPlayer()
        refreshNpcNodes()
        positionTargetHighlight()
        refreshPlacementPreviewNodes()
        refreshAmbienceBanner()
    }

    private func publishDerivedState(rebuildCells shouldRebuild: Bool, changedCell: GridPosition? = nil) {
        if lastFeedback != lastPublishedFeedback {
            if lastFeedbackIsSuccess, runtimeSettings.vibrationEnabled {
                shakeRemaining = 0.25
            }
            lastPublishedFeedback = lastFeedback
        }
        if shouldRebuild {
            if let changedCell {
                refreshCell(at: changedCell)
            } else {
                rebuildCells()
            }
        }
        positionPlayer()
        refreshNpcNodes()
        positionTargetHighlight()
        refreshPlacementPreviewNodes()
        refreshAmbienceBanner()
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
        let isWaterEdge = WorldVariant.isRestoredWaterCell(position, mapID: currentMap.id)
        let usedPixelTile = addPixelTileIfAvailable(
            to: node,
            onFarm: onFarm,
            prepared: cell.prepared,
            isWaterEdge: isWaterEdge
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

            if cell.readyToHarvest {
                let ring = SKShapeNode(
                    rectOf: CGSize(width: size * 0.94, height: size * 0.94),
                    cornerRadius: 4
                )
                ring.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1)
                ring.lineWidth = max(2.5, cellSize * 0.06)
                ring.fillColor = .clear
                node.addChild(ring)

                let label = SKLabelNode(text: "成熟")
                label.fontName = "PingFangSC-Semibold"
                label.fontSize = max(10, cellSize * 0.26)
                label.fontColor = SKColor(red: 1.0, green: 0.93, blue: 0.55, alpha: 1)
                label.position = CGPoint(x: 0, y: -cellSize * 0.32)
                label.zPosition = 3
                node.addChild(label)
            }
        }

        if onFarm, cell.wateredToday {
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
            node.addChild(makePlacedObjectGlyph(definitionID: placed.definitionID))
        }

        if currentMap.isBlocked(position) {
            let restoredWater = gameState.watershed.isRestored
                && WorldVariant.isRestoredWaterCell(position, mapID: currentMap.id)
            let hideBlockFill = usedPixelTile && isWaterEdge
            if !hideBlockFill {
                let block = SKShapeNode(
                    rectOf: CGSize(width: size * 0.78, height: size * 0.78),
                    cornerRadius: 3
                )
                if restoredWater {
                    block.fillColor = SKColor(red: 0.22, green: 0.48, blue: 0.72, alpha: 0.92)
                    block.strokeColor = SKColor(red: 0.10, green: 0.28, blue: 0.48, alpha: 1)
                } else {
                    block.fillColor = SKColor(red: 0.30, green: 0.28, blue: 0.26, alpha: 0.92)
                    block.strokeColor = SKColor(red: 0.16, green: 0.14, blue: 0.12, alpha: 1)
                }
                block.lineWidth = 2
                node.addChild(block)
            }

            let mark = SKLabelNode(text: restoredWater ? "流水" : "阻")
            mark.fontName = "PingFangSC-Semibold"
            mark.fontSize = max(10, cellSize * 0.22)
            mark.fontColor = SKColor(red: 0.96, green: 0.90, blue: 0.78, alpha: 1)
            mark.verticalAlignmentMode = .center
            mark.zPosition = 4
            node.addChild(mark)

            if restoredWater {
                let wave = SKLabelNode(text: "≈≈")
                wave.fontName = "PingFangSC-Semibold"
                wave.fontSize = max(8, cellSize * 0.18)
                wave.fontColor = SKColor.white
                wave.verticalAlignmentMode = .center
                wave.position = CGPoint(x: 0, y: cellSize * 0.22)
                wave.zPosition = 4
                node.addChild(wave)
            }
        }

        if currentMap.exit(at: position) != nil {
            let step = SKShapeNode(
                rectOf: CGSize(width: size * 0.70, height: size * 0.28),
                cornerRadius: 2
            )
            step.fillColor = SKColor(red: 0.72, green: 0.68, blue: 0.58, alpha: 1)
            step.strokeColor = SKColor(red: 0.40, green: 0.34, blue: 0.24, alpha: 1)
            step.position = CGPoint(x: 0, y: cellSize * 0.12)
            node.addChild(step)

            let exitLabel = SKLabelNode(text: "石阶")
            exitLabel.fontName = "PingFangSC-Semibold"
            exitLabel.fontSize = max(9, cellSize * 0.20)
            exitLabel.fontColor = SKColor.white
            exitLabel.verticalAlignmentMode = .center
            exitLabel.position = CGPoint(x: 0, y: -cellSize * 0.28)
            exitLabel.zPosition = 4
            node.addChild(exitLabel)
        }

        if let landmark = currentMap.landmarks.first(where: { $0.position == position }) {
            let landmarkLabel = SKLabelNode(
                text: WorldVariant.landmarkLabel(landmark, restored: gameState.watershed.isRestored)
            )
            landmarkLabel.fontName = "PingFangSC-Medium"
            landmarkLabel.fontSize = max(8, cellSize * 0.16)
            landmarkLabel.fontColor = SKColor(red: 1.0, green: 0.97, blue: 0.86, alpha: 1)
            landmarkLabel.verticalAlignmentMode = .center
            landmarkLabel.position = CGPoint(x: 0, y: cellSize * 0.32)
            landmarkLabel.zPosition = 4
            node.addChild(landmarkLabel)
        }

        if let gather = catalog.gatherNode(at: position, mapID: currentMap.id, state: gameState) {
            let harvested = gameState.harvestedGatherNodeIDs.contains(gather.id)
            let badge = SKShapeNode(
                rectOf: CGSize(width: size * 0.42, height: size * 0.28),
                cornerRadius: 2
            )
            badge.fillColor = harvested
                ? SKColor(red: 0.42, green: 0.42, blue: 0.40, alpha: 0.92)
                : SKColor(red: 0.28, green: 0.52, blue: 0.34, alpha: 0.95)
            badge.strokeColor = SKColor.white
            badge.lineWidth = 1
            badge.position = CGPoint(x: -cellSize * 0.22, y: cellSize * 0.22)
            node.addChild(badge)

            let badgeLabel = SKLabelNode(text: harvested ? "空" : "采")
            badgeLabel.fontName = "PingFangSC-Semibold"
            badgeLabel.fontSize = max(8, cellSize * 0.16)
            badgeLabel.fontColor = SKColor.white
            badgeLabel.verticalAlignmentMode = .center
            badgeLabel.position = badge.position
            badgeLabel.zPosition = 5
            node.addChild(badgeLabel)
            if flashPulseEnabled, !harvested {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.08, duration: 0.4),
                    SKAction.scale(to: 1.0, duration: 0.4),
                ])
                badge.run(.repeatForever(pulse))
            }

            let name = SKLabelNode(text: gather.label)
            name.fontName = "PingFangSC-Medium"
            name.fontSize = max(8, cellSize * 0.14)
            name.fontColor = SKColor(red: 0.92, green: 0.98, blue: 0.88, alpha: 1)
            name.verticalAlignmentMode = .center
            name.position = CGPoint(x: 0, y: -cellSize * 0.34)
            name.zPosition = 5
            node.addChild(name)
        }

        return node
    }

    /// Growth stages use distinct shapes plus a stage label ("芽"/"苗"/"熟").
    private func makeCropNode(cell: FarmCell) -> SKNode {
        let node = SKNode()
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

            let label = SKLabelNode(text: "芽")
            label.fontName = "PingFangSC-Semibold"
            label.fontSize = max(10, cellSize * 0.26)
            label.fontColor = SKColor(red: 0.85, green: 1.0, blue: 0.75, alpha: 1)
            label.position = CGPoint(x: 0, y: -cellSize * 0.32)
            label.zPosition = 3
            node.addChild(label)

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

            let label = SKLabelNode(text: "苗")
            label.fontName = "PingFangSC-Semibold"
            label.fontSize = max(10, cellSize * 0.26)
            label.fontColor = SKColor(red: 0.85, green: 1.0, blue: 0.75, alpha: 1)
            label.position = CGPoint(x: 0, y: -cellSize * 0.32)
            label.zPosition = 3
            node.addChild(label)

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

            let label = SKLabelNode(text: "熟")
            label.fontName = "PingFangSC-Semibold"
            label.fontSize = max(10, cellSize * 0.26)
            label.fontColor = SKColor(red: 1.0, green: 0.93, blue: 0.55, alpha: 1)
            label.position = CGPoint(x: 0, y: -cellSize * 0.32)
            label.zPosition = 3
            node.addChild(label)
        }

        return node
    }

    /// Farm grass / tilled / water-edge tiles. Market keeps the procedural fill.
    @discardableResult
    private func addPixelTileIfAvailable(
        to node: SKNode,
        onFarm: Bool,
        prepared: Bool,
        isWaterEdge: Bool
    ) -> Bool {
        guard onFarm else { return false }
        let kind = PixelAssetCatalog.tileKind(prepared: prepared, isWaterEdge: isWaterEdge)
        guard let sprite = PixelAssetStore.shared.makeSprite(kind: kind, cellSize: cellSize) else {
            return false
        }
        sprite.name = "pixel-tile"
        sprite.zPosition = 0
        node.addChild(sprite)
        return true
    }

    private func configurePlayer() {
        playerNode.removeAllChildren()
        playerNode.zPosition = 10
        playerNode.name = "player"

        let visual = CharacterVisualNode(
            definition: CharacterVisualCatalog.player,
            cellSize: max(cellSize, 48),
            showsTalkBadge: false,
            showsName: false
        )
        visual.setMotionAllowed(flashPulseEnabled)
        playerVisual = visual
        playerNode.addChild(visual)

        facingIndicator.fillColor = SKColor(red: 0.22, green: 0.45, blue: 0.38, alpha: 1)
        facingIndicator.strokeColor = SKColor.white
        facingIndicator.lineWidth = 1
        facingIndicator.zPosition = 12
        playerNode.addChild(facingIndicator)

        if playerNode.parent == nil {
            addChild(playerNode)
        }
        if targetHighlight.parent == nil {
            addChild(targetHighlight)
        }
        refreshPlayerPath()
    }

    private func configureAmbienceBanner() {
        ambienceBanner.fontName = "PingFangSC-Semibold"
        ambienceBanner.fontSize = 14
        ambienceBanner.fontColor = SKColor.white
        ambienceBanner.horizontalAlignmentMode = .right
        ambienceBanner.verticalAlignmentMode = .top
        ambienceBanner.zPosition = 20
        addChild(ambienceBanner)
    }

    private func refreshAmbienceBanner() {
        let restored = gameState.watershed.isRestored
        let weather = catalog.scenario.weather(on: gameState.clock.day)
        let weatherCaption = weather == .rain ? "天气 雨  " : "天气 晴  "
        let mapCaption = gameState.currentMapID == ContentID.creekMarket ? "溪岸流水/鸟鸣" : "农场微风/草"
        let rainCaption = weather == .rain ? " + 雨层" : ""
        ambienceBanner.text = weatherCaption + "♪ 环境音 \(mapCaption)\(rainCaption)"
        ambienceBanner.position = CGPoint(x: size.width - 16, y: size.height - 12)
        ambienceBanner.alpha = flashPulseEnabled ? 1.0 : 0.82
        if weather == .rain {
            backgroundColor = restored
                ? SKColor(red: 0.12, green: 0.20, blue: 0.28, alpha: 1)
                : SKColor(red: 0.13, green: 0.18, blue: 0.24, alpha: 1)
        } else {
            backgroundColor = restored
                ? SKColor(red: 0.14, green: 0.24, blue: 0.28, alpha: 1)
                : SKColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1)
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
            node.setTalking(talkingNpcID == presence.npcID)
        }
    }

    private func startPresentationAudioIfNeeded() {
        guard !isPerformanceMeasurementSession else { return }
        audioService.setLogURL(saveDirectory.appendingPathComponent("audio-latest.json"))
        audioService.start(volumes: runtimeSettings.volumes)
        syncAudioEnvironment()
    }

    private func syncAudioEnvironment() {
        guard !isPerformanceMeasurementSession else { return }
        let weather = catalog.scenario.weather(on: gameState.clock.day)
        if gameState.currentMapID == ContentID.creekMarket {
            audioService.setMapLayer(.creek)
        } else {
            audioService.setMapLayer(.farm)
        }
        audioService.setWeatherLayer(weather == .rain ? .rain : .none)
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
        let size = cellSize - max(cellSize * 0.06, 2) * 0.5
        targetHighlight.path = CGPath(
            roundedRect: CGRect(x: -size / 2, y: -size / 2, width: size, height: size),
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
        targetHighlight.strokeColor = SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
        targetHighlight.fillColor = .clear
        targetHighlight.lineWidth = max(2.5, cellSize * 0.06)
        targetHighlight.zPosition = 5
        targetHighlight.position = cellCenter(
            column: hudTarget.x,
            row: hudTarget.y
        )
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.30, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5),
        ])
        targetHighlight.run(SKAction.repeatForever(pulse))
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
            ContentID.mistRadishItem,
            ContentID.creekWood,
            ContentID.mossStone,
            ContentID.reedFiber,
            ContentID.woodenCrateItem,
            ContentID.stonePathItem,
            ContentID.compostRackItem,
            ContentID.canalSegmentItem,
            ContentID.rainBarrelItem,
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

    private func refreshPlacementPreviewNodes() {
        previewRoot.removeAllChildren()
        guard isPreviewingPlacement, let definitionID = selectedPlacedObjectID else { return }
        let preview = commands.previewPlacement(
            state: gameState,
            definitionID: definitionID,
            origin: gameState.targetCell,
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

    private func makePlacedObjectGlyph(definitionID: String) -> SKNode {
        let node = SKNode()
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
