//
//  ContentView.swift
//  CreekSprout
//
//  SwiftUI shell: hosts the SpriteKit scene, forwards keyboard input, and
//  renders a HUD from FarmScene's derived state only. GameState remains the
//  sole authority inside FarmScene. DEBUG-only development commands are
//  compiled out of release builds.
//

import Combine
import GameController
import AppKit
import SpriteKit
import SwiftUI

private enum BuildingCardMode {
    case expanded
    case dismissed
}

private enum GamePresentationMode: Equatable {
    case roaming
    case dialogue
    case storyDialogue
    case storyJourney
    case storyGallery
    case characterInfo
    case buildingInspect
    case catTour
    case catShopSupply
    case livestockRoster
}

struct ContentView: View {
    @FocusState private var isSceneFocused: Bool
    @State private var farmScene: FarmScene?
    @State private var shell = DemoShellState()
    @State private var hudText = ""
    @State private var isHudCompact = true
    @State private var settings = SettingsState.defaults
    @State private var showCharacterInfo = false
    @State private var buildingCardMode: BuildingCardMode = .dismissed
    @State private var nearbyBuildingID: String?
    @State private var activeDialoguePortraitAssetName: String?
    @State private var activeDialogueSpeakerName = ""
    @State private var activeDialogueCharacterID: String?
    @State private var isNearCatBbqShop = false
    @State private var showCatBbqArtTour = false
    @State private var showCatShopSupply = false
    @State private var showLivestockRoster = false
    @State private var settingsTab = 0
    @State private var settingsRow = 0
    @State private var rebindingActionID: String?
    @State private var settingsStatusMessage: String?
    @State private var hudNow = Date()
    @State private var formalSlots: [FormalManualSlotSummary] = []
    @State private var selectedFormalSlotIndex = 0
    @State private var showFormalSlotPicker = false
    @State private var pendingFormalNewGame: FormalNewGameRequest?
    @State private var formalSessionError: String?
    @State private var activeFormalSlotIndex = 0
    @State private var morningReportSession = MorningCropReportSessionState()
    @State private var morningReportSnapshot: MorningCropReportSnapshot?
    @State private var cropSleepRiskCoordinator = CropSleepRiskConfirmationCoordinator()
    @State private var pendingCropSleepRisk: CropSleepRiskRequest?
    @State private var showStoryJourney = false
    @State private var storyJourneyController: StoryJourneySceneController?
    @State private var showStoryGallery = false

    private let settingsStore = SettingsStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let farmScene, shell.route == .playing {
                gameLayer(farmScene, refreshToken: hudNow)
            }

            if shell.route == .welcome {
                DemoWelcomeView(
                    continueAvailable: shell.continueAvailable,
                    selectedIndex: shell.selectedWelcomeIndex,
                    scale: settings.uiScaleFactor,
                    items: FormalGameCopy.welcomeItems,
                    continueUnavailableText: FormalGameCopy.continueUnavailable,
                    accessibilityPrefix: "n027.formal.welcome",
                    onSelect: { shell.selectedWelcomeIndex = $0 },
                    onActivate: { index in
                        shell.selectedWelcomeIndex = index
                        performShellCommand(shell.activateWelcomeSelection())
                    }
                )
            }

            if showFormalSlotPicker {
                FormalNewGameSlotPickerView(
                    slots: formalSlots,
                    selectedIndex: selectedFormalSlotIndex,
                    scale: settings.uiScaleFactor,
                    onSelect: prepareFormalNewGame,
                    onCancel: closeFormalNewGameFlow
                )
                .zIndex(300)
            }

            if let request = pendingFormalNewGame {
                FormalOverwriteConfirmView(
                    request: request,
                    scale: settings.uiScaleFactor,
                    onConfirm: { confirmFormalNewGame(request) },
                    onCancel: closeFormalNewGameFlow
                )
                .zIndex(310)
            }

            if let formalSessionError {
                FormalSessionAlertView(
                    message: formalSessionError,
                    scale: settings.uiScaleFactor,
                    onClose: { self.formalSessionError = nil }
                )
                .zIndex(320)
            }

            if shell.overlay == .pause {
                DemoPauseView(
                    selectedIndex: shell.selectedPauseIndex,
                    scale: settings.uiScaleFactor,
                    items: FormalGameCopy.pauseItems,
                    onSelect: { shell.selectedPauseIndex = $0 },
                    onActivate: { index in
                        shell.selectedPauseIndex = index
                        performShellCommand(shell.activatePauseSelection())
                    }
                )
            }

            if shell.overlay == .controls {
                DemoTextPanelView(
                    title: DemoCopy.controls,
                    bodyText: DemoCopy.controlsBody,
                    scale: settings.uiScaleFactor,
                    onClose: { performShellCommand(.closeOverlay) }
                )
            }

            if shell.overlay == .restartConfirm {
                DemoConfirmView(
                    scale: settings.uiScaleFactor,
                    title: FormalGameCopy.restartTitle,
                    bodyText: FormalGameCopy.restartBody,
                    confirmTitle: FormalGameCopy.restartAction,
                    cancelTitle: "取消",
                    onConfirm: { performShellCommand(.confirmRestartDemo) },
                    onCancel: { performShellCommand(.cancelRestart) }
                )
            }

            if shell.overlay == .settings {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                SettingsPanelView(
                    settings: $settings,
                    selectedTab: $settingsTab,
                    selectedRow: $settingsRow,
                    rebindingActionID: $rebindingActionID,
                    statusMessage: $settingsStatusMessage,
                    onPersist: persistSettings,
                    onRestoreDefaults: restoreDefaults,
                    onClose: { closeSettings() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showCatBbqArtTour {
                CatBbqArtTourView(
                    scale: settings.uiScaleFactor,
                    onClose: closeCatBbqArtTour
                )
                .transition(.opacity)
                .zIndex(200)
            }

            if showCatShopSupply, let farmScene {
                CatShopSupplyView(
                    board: farmScene.catShopBoardSnapshot,
                    scale: settings.uiScaleFactor,
                    onSupplyCrop: { offerID, itemID, quantity in
                        farmScene.supplyCatShopCrop(
                            offerID: offerID,
                            itemID: itemID,
                            quantity: quantity
                        )
                        refreshHudText()
                    },
                    onSupplyAnimal: { offerID, animalID in
                        farmScene.supplyCatShopAnimal(offerID: offerID, animalID: animalID)
                        refreshHudText()
                    },
                    onShowArtTour: openCatBbqArtTourFromSupply,
                    onClose: closeCatShopSupply
                )
                .transition(.opacity)
                .zIndex(210)
            }

            if showLivestockRoster, let farmScene {
                LivestockRosterView(
                    animals: farmScene.livestockRosterSnapshot,
                    stamina: farmScene.hudPresentationState.resources.staminaCurrent,
                    scale: settings.uiScaleFactor,
                    onCare: { animalID in
                        farmScene.careForAnimal(animalID)
                        refreshHudText()
                    },
                    onClose: closeLivestockRoster
                )
                .transition(.opacity)
                .zIndex(210)
            }

            if shell.route == .playing,
               let farmScene,
               farmScene.isOnFarmMap,
               morningReportSnapshot == nil,
               pendingCropSleepRisk == nil,
               shell.overlay == .none,
               !showCatBbqArtTour,
               !showCatShopSupply,
               !showLivestockRoster {
                MorningCropReportReopenButton(
                    scale: settings.uiScaleFactor,
                    controlHints: MorningCropReportControlHints.resolve(settings: settings),
                    onAction: handleMorningCropReportAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18 * settings.uiScaleFactor)
                .zIndex(220)
            }

            if let morningReportSnapshot {
                MorningCropReportView(
                    snapshot: morningReportSnapshot,
                    scale: settings.uiScaleFactor,
                    controlHints: MorningCropReportControlHints.resolve(settings: settings),
                    onAction: handleMorningCropReportAction
                )
                .transition(.opacity)
                .zIndex(230)
            }

            if let pendingCropSleepRisk {
                CropSleepRiskConfirmationView(
                    request: pendingCropSleepRisk,
                    scale: settings.uiScaleFactor,
                    controlHints: MorningCropReportControlHints.resolve(settings: settings),
                    onAction: handleMorningCropReportAction
                )
                .transition(.opacity)
                .zIndex(240)
            }

            if shell.route == .playing, let farmScene {
                if let storyView = farmScene.storyDialogueView {
                    StoryDialoguePresentationLayer(
                        view: storyView,
                        scale: settings.uiScaleFactor,
                        focusedIntentIndex: farmScene.storyDialogueFocusedIntentIndex,
                        advanceBindingLabel: farmScene.storyDialogueBindingLabel(
                            for: InputBindingDefinitions.actionInteract
                        ),
                        cancelBindingLabel: farmScene.storyDialogueBindingLabel(
                            for: InputBindingDefinitions.actionUICancel
                        ),
                        onAdvance: {
                            farmScene.advanceStoryDialogue()
                            refreshHudText()
                        },
                        onSelectIntent: { index in
                            farmScene.selectStoryIntent(at: index)
                            refreshHudText()
                        },
                        onCancel: {
                            farmScene.cancelStoryDialogue()
                            refreshHudText()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(400)
                }
            }

            if showStoryJourney, let controller = storyJourneyController {
                StoryJourneySceneView(
                    controller: controller,
                    scale: settings.uiScaleFactor,
                    onClose: closeStoryJourney
                )
                .transition(.opacity)
                .zIndex(410)
            }

            if showStoryGallery, let farmScene {
                StoryGalleryView(
                    snapshot: farmScene.storyGallerySnapshot,
                    scale: settings.uiScaleFactor,
                    onRecallPreReveal: {
                        farmScene.recallPreRevealForGallery()
                        refreshHudText()
                    },
                    onClose: closeStoryGallery
                )
                .transition(.opacity)
                .zIndex(420)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .focusable()
        .focused($isSceneFocused)
        .focusEffectDisabled()
        .onAppear {
            showCharacterInfo = false
            bootstrapSettings()
            refreshFormalSessionAvailability()
            claimKeyboardFocus()
        }
        .onChange(of: shell.route) { _, _ in
            claimKeyboardFocus()
        }
        .onChange(of: shell.overlay) { _, _ in
            claimKeyboardFocus()
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            pollGamepadIfNeeded()
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { now in
            hudNow = now
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            farmScene?.isPaused = false
            syncMenuPause()
            claimKeyboardFocus()
        }
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
    }

    @ViewBuilder
    private func gameLayer(_ farmScene: FarmScene, refreshToken: Date) -> some View {
        let mode = presentationMode(for: farmScene)
        ZStack(alignment: .topLeading) {
            SpriteView(scene: farmScene)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            if isHudCompact {
                CompactFarmHudView(
                    state: farmScene.hudPresentationState,
                    scale: settings.uiScaleFactor,
                    showsBottomDock: mode == .roaming,
                    supplementalPrompt: supplementalPrompt
                )
                .allowsHitTesting(false)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(hudLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(
                                size: hudFontSize(for: line) * settings.uiScaleFactor,
                                weight: hudWeight(for: line),
                                design: .monospaced
                            ))
                            .foregroundStyle(Color.white)
                            .opacity(lineOpacity(for: line))
                    }
                }
                .padding(10 * settings.uiScaleFactor)
                .background(Color(red: 0.05, green: 0.07, blue: 0.06).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if mode == .buildingInspect,
               let landmarkID = nearbyBuildingID {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                GeometryReader { geometry in
                    let zones = HudSafeZoneLayout.resolve(viewport: geometry.size)
                    let rect = zones.buildingCardExpanded
                    BuildingPresentationCard(
                        expanded: true,
                        landmarkID: landmarkID
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if mode == .dialogue,
               let dialogue = farmScene.hudPresentationState.dialogue {
                DialoguePresentationLayer(
                    dialogue: dialogue,
                    characterID: activeDialogueCharacterID,
                    portraitAssetName: activeDialoguePortraitAssetName,
                    speakerName: activeDialogueSpeakerName,
                    scale: settings.uiScaleFactor
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if mode == .characterInfo {
                CharacterInfoCard(characterID: farmScene.characterInfoCharacterID)
                    .frame(maxWidth: 430, maxHeight: 540)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.25))
                    .transition(.opacity)
            }


        }
    }

    private func presentationMode(for farmScene: FarmScene) -> GamePresentationMode {
        if showStoryGallery { return .storyGallery }
        if showStoryJourney { return .storyJourney }
        if showCatShopSupply { return .catShopSupply }
        if showLivestockRoster { return .livestockRoster }
        if showCatBbqArtTour { return .catTour }
        if showCharacterInfo { return .characterInfo }
        if farmScene.storyDialogueView != nil { return .storyDialogue }
        if farmScene.hudPresentationState.dialogue != nil { return .dialogue }
        if buildingCardMode == .expanded, nearbyBuildingID != nil { return .buildingInspect }
        return .roaming
    }

    private var supplementalPrompt: String? {
        if let nearbyBuildingID,
           let entry = BuildingPresentationCatalog.entry(for: nearbyBuildingID) {
            return "[\(BuildingPresentationCatalog.inspectKeyboardLabel)] 查看\(entry.displayName)"
        }
        if isNearCatBbqShop {
            return "[J] 猫猫烧烤店供货"
        }
        if farmScene?.isOnFarmMap == true {
            return "[M] 农场动物名册"
        }
        return nil
    }

    private var hudLines: [String] {
        hudText.components(separatedBy: "\n")
    }

    private func hudFontSize(for line: String) -> CGFloat {
        if line.hasPrefix("【") {
            return 12
        }
        if line.hasPrefix("[+]") || line.hasPrefix("[!]")
            || line.hasPrefix("成功：") || line.hasPrefix("失败：") {
            return 13
        }
        return 12
    }

    private func lineOpacity(for line: String) -> Double {
        if line.hasPrefix("[+]") || line.hasPrefix("[!]") {
            return 1
        }
        if line.hasPrefix("【") {
            return 0.92
        }
        return 1
    }

    private func toggleHudCompact() {
        isHudCompact.toggle()
        refreshHudText()
    }

    private func hudWeight(for line: String) -> Font.Weight {
        if line.hasPrefix("【") || line.hasPrefix("[+]") || line.hasPrefix("[!]")
            || line.hasPrefix("成功：") || line.hasPrefix("失败：") {
            return .semibold
        }
        return .medium
    }

    private func refreshHudText() {
        hudText = farmScene?.hudText(compact: isHudCompact) ?? ""
    }

    private func bootstrapSettings() {
        let loaded = activeSettingsStore.load()
        settings = loaded.state
        #if DEBUG
        if let scale = N027SmokeLaunchOptions.uiScale,
           SettingsState.validUIScales.contains(scale) {
            settings.uiScale = scale
        }
        if let speed = N027SmokeLaunchOptions.textSpeed {
            settings.textSpeed = speed
        }
        #endif
        farmScene?.applySettings(settings)
        farmScene?.syncSettingsIntoGameState()
    }

    private func persistSettings() {
        farmScene?.applySettings(settings)
        farmScene?.syncSettingsIntoGameState()
        try? activeSettingsStore.save(settings)
        refreshHudText()
    }

    private func restoreDefaults() {
        var next = settings
        InputBindingsService.restoreDefaults(settings: &next)
        settings = next
        rebindingActionID = nil
        settingsStatusMessage = "已恢复全部默认设置。"
        persistSettings()
    }

    private func openSettings() {
        performShellCommand(.openSettings)
    }

    private func closeSettings() {
        rebindingActionID = nil
        persistSettings()
        performShellCommand(.closeOverlay)
    }

    private func syncMenuPause() {
        let customOverlayOpen = showCatBbqArtTour
            || showCatShopSupply
            || showLivestockRoster
            || showFormalSlotPicker
            || pendingFormalNewGame != nil
            || formalSessionError != nil
            || morningReportSnapshot != nil
            || pendingCropSleepRisk != nil
            || showStoryJourney
            || showStoryGallery
        farmScene?.setMenuPaused(
            shell.route == .playing && (shell.isClockPaused || customOverlayOpen)
        )
        // The game shell routes every key through `handle(_:)`, including the
        // welcome/picker/report overlays. Keep the focusable view focused
        // whenever the shell is up; overlay controls are `.focusable(false)`
        // so they never steal keys from the deterministic key path.
        isSceneFocused = shell.route == .playing || shell.route == .welcome
    }

    private func bindScene(_ scene: FarmScene) {
        scene.applySettings(settings)
        scene.syncSettingsIntoGameState()
        scene.onStateChanged = {
            refreshHudText()
            let nextBuildingID = scene.buildingPresentationLandmarkID
            if nextBuildingID != nearbyBuildingID {
                nearbyBuildingID = nextBuildingID
                buildingCardMode = .dismissed
            }
            activeDialoguePortraitAssetName = scene.dialoguePortraitAssetName
            activeDialogueSpeakerName = scene.dialogueSpeakerName ?? ""
            activeDialogueCharacterID = scene.characterInfoCharacterID
            if scene.hudPresentationState.dialogue != nil {
                showCharacterInfo = false
                buildingCardMode = .dismissed
            }
            isNearCatBbqShop = scene.isNearCatBbqShop
            synchronizeMorningCropReport(for: scene)
            hudNow = Date()
        }
        scene.onJourneyStart = {
            openStoryJourneyResuming()
        }
        scene.onStoryGraduation = {
            openStoryGalleryAfterGraduation()
        }
        nearbyBuildingID = scene.buildingPresentationLandmarkID
        activeDialoguePortraitAssetName = scene.dialoguePortraitAssetName
        activeDialogueSpeakerName = scene.dialogueSpeakerName ?? ""
        activeDialogueCharacterID = scene.characterInfoCharacterID
        isNearCatBbqShop = scene.isNearCatBbqShop
        showCharacterInfo = false
        showCatBbqArtTour = false
        showCatShopSupply = false
        showLivestockRoster = false
        showStoryGallery = false
        showStoryJourney = false
        storyJourneyController = nil
        buildingCardMode = .dismissed
        farmScene = scene
        synchronizeMorningCropReport(for: scene)
        refreshHudText()
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func claimKeyboardFocus() {
        DispatchQueue.main.async {
            isSceneFocused = true
        }
    }

    private func plannedCropCoverage(for scene: FarmScene) -> [CropCoverageSummary] {
        [
            IrrigationService().previewOvernightCoverage(
                state: scene.gameState,
                catalog: .vs0
            ),
            CropCareService.previewCommunityCoverage(
                in: scene.gameState,
                catalog: .vs0
            ),
        ]
    }

    private func currentMorningCropReport(for scene: FarmScene) -> MorningCropReportSnapshot {
        MorningCropReportService.snapshot(
            state: scene.gameState,
            catalog: .vs0,
            plannedCoverage: plannedCropCoverage(for: scene)
        )
    }

    private func synchronizeMorningCropReport(for scene: FarmScene) {
        guard scene.isOnFarmMap else { return }
        let day = scene.gameState.clock.day
        let transition = morningReportSession.enterFarm(day: day)
        if transition != .unchanged || morningReportSession.isPresented {
            morningReportSnapshot = currentMorningCropReport(for: scene)
        }
        syncMenuPause()
    }

    private func handleMorningCropReportAction(_ action: MorningCropReportUIAction) {
        guard let scene = farmScene else { return }
        switch action {
        case .reopenReport:
            guard scene.isOnFarmMap else { return }
            _ = morningReportSession.reopen(day: scene.gameState.clock.day)
            morningReportSnapshot = currentMorningCropReport(for: scene)
        case .closeReport:
            _ = morningReportSession.close(day: scene.gameState.clock.day)
            morningReportSnapshot = nil
        case .cancelSleep(let token):
            _ = cropSleepRiskCoordinator.cancel(token: token)
            pendingCropSleepRisk = nil
        case .confirmSleep(let token):
            let result = cropSleepRiskCoordinator.confirm(
                token: token,
                state: scene.gameState,
                catalog: .vs0,
                plannedCoverage: plannedCropCoverage(for: scene)
            )
            pendingCropSleepRisk = nil
            if case .authorized = result {
                scene.sleepAndSettle()
            } else if case .stale = result {
                pendingCropSleepRisk = cropSleepRiskCoordinator.issue(
                    state: scene.gameState,
                    catalog: .vs0,
                    plannedCoverage: plannedCropCoverage(for: scene)
                )
            }
        }
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func requestSleepAfterCropRiskCheck() {
        guard let scene = farmScene else { return }
        let request = cropSleepRiskCoordinator.issue(
            state: scene.gameState,
            catalog: .vs0,
            plannedCoverage: plannedCropCoverage(for: scene)
        )
        if let request {
            pendingCropSleepRisk = request
            syncMenuPause()
        } else {
            scene.sleepAndSettle()
        }
    }

    private func performShellCommand(_ command: DemoShellCommand) {
        switch command {
        case .startDemo:
            openFormalNewGameFlow()
            return
        case .confirmRestartDemo:
            restartFormalCampaign()
            return
        case .continueGame:
            beginContinueSession()
            return
        case .returnToTitle:
            farmScene?.setMenuPaused(false)
            farmScene = nil
            nearbyBuildingID = nil
            activeDialoguePortraitAssetName = nil
            isNearCatBbqShop = false
            showCatBbqArtTour = false
            showCatShopSupply = false
            showLivestockRoster = false
            showCharacterInfo = false
            morningReportSnapshot = nil
            pendingCropSleepRisk = nil
            morningReportSession = MorningCropReportSessionState()
            cropSleepRiskCoordinator = CropSleepRiskConfirmationCoordinator()
            refreshFormalSessionAvailability()
        case .openSettings:
            settingsTab = 0
            settingsRow = 0
            rebindingActionID = nil
            settingsStatusMessage = nil
            settings.lastUsedDevice = .keyboardMouse
        default:
            break
        }
        if command != .none {
            shell.apply(command)
        }
        syncMenuPause()
    }

    private func beginContinueSession() {
        do {
            let launch = try formalSessionService.continueGame()
            launchFormalSession(launch, restoresSavedSettings: true, isContinue: true)
        } catch {
            formalSessionError = formalErrorMessage(error)
            refreshFormalSessionAvailability()
            syncMenuPause()
        }
    }

    private var formalSessionService: FormalGameSessionService {
        FormalGameSessionService(productionRoot: sessionSaveDirectory)
    }

    /// Save root for the formal session. The DEBUG-only smoke driver redirects
    /// it with `--n027-evidence-root`; Release always uses production.
    private var sessionSaveDirectory: URL {
        #if DEBUG
        if let root = N027SmokeLaunchOptions.evidenceRoot {
            return root
        }
        #endif
        return FarmScene.productionSaveDirectory
    }

    private var activeSettingsStore: SettingsStore {
        SettingsStore(directory: sessionSaveDirectory)
    }

    private func refreshFormalSessionAvailability() {
        formalSlots = formalSessionService.manualSlots()
        shell.continueAvailable = formalSlots.contains { slot in
            if case .occupied = slot.state { return true }
            return false
        }
    }

    private func openFormalNewGameFlow() {
        refreshFormalSessionAvailability()
        selectedFormalSlotIndex = formalSlots.first(where: { slot in
            if case .unreadable = slot.state { return false }
            return true
        })?.slotIndex ?? 0
        showFormalSlotPicker = true
        pendingFormalNewGame = nil
        formalSessionError = nil
        syncMenuPause()
    }

    private func prepareFormalNewGame(_ slotIndex: Int) {
        selectedFormalSlotIndex = slotIndex
        do {
            let request = try formalSessionService.prepareNewGame(inManualSlot: slotIndex)
            showFormalSlotPicker = false
            if request.requiresOverwriteConfirmation {
                pendingFormalNewGame = request
            } else {
                confirmFormalNewGame(request)
            }
        } catch {
            formalSessionError = formalErrorMessage(error)
        }
        syncMenuPause()
    }

    private func moveFormalSlotSelection(_ delta: Int) {
        let ordered = formalSlots.sorted { $0.slotIndex < $1.slotIndex }
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.slotIndex == selectedFormalSlotIndex } ?? 0
        for step in 1...ordered.count {
            let offset = (current + (delta >= 0 ? step : -step) + ordered.count) % ordered.count
            let candidate = ordered[offset]
            if case .unreadable = candidate.state { continue }
            selectedFormalSlotIndex = candidate.slotIndex
            return
        }
    }

    private func confirmFormalNewGame(_ request: FormalNewGameRequest) {
        do {
            let launch = try formalSessionService.confirmNewGame(
                using: request.confirmationToken
            )
            launchFormalSession(launch, restoresSavedSettings: false, isContinue: false)
        } catch {
            pendingFormalNewGame = nil
            formalSessionError = formalErrorMessage(error)
            refreshFormalSessionAvailability()
            syncMenuPause()
        }
    }

    private func closeFormalNewGameFlow() {
        showFormalSlotPicker = false
        pendingFormalNewGame = nil
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func restartFormalCampaign() {
        do {
            let request = try formalSessionService.prepareNewGame(
                inManualSlot: activeFormalSlotIndex
            )
            let launch = try formalSessionService.confirmNewGame(
                using: request.confirmationToken
            )
            launchFormalSession(launch, restoresSavedSettings: false, isContinue: false)
        } catch {
            formalSessionError = formalErrorMessage(error)
            shell.overlay = .none
            syncMenuPause()
        }
    }

    private func launchFormalSession(
        _ launch: FormalSessionLaunch,
        restoresSavedSettings: Bool,
        isContinue: Bool
    ) {
        let scene = FarmScene.makeSession(saveDirectory: sessionSaveDirectory)
        scene.replaceSessionState(
            launch.state,
            activeManualSlotIndex: launch.manualSlotIndex,
            usesCampaignGenerationPersistence: true
        )
        if restoresSavedSettings {
            settings = scene.exportSettings()
        }
        activeFormalSlotIndex = launch.manualSlotIndex
        showFormalSlotPicker = false
        pendingFormalNewGame = nil
        formalSessionError = nil
        morningReportSnapshot = nil
        pendingCropSleepRisk = nil
        morningReportSession = MorningCropReportSessionState()
        cropSleepRiskCoordinator = CropSleepRiskConfirmationCoordinator()
        shell.route = .playing
        shell.overlay = .none
        shell.sessionKind = isContinue ? .continuePlay : .formalCampaign
        shell.selectedPauseIndex = 0
        bindScene(scene)
        refreshFormalSessionAvailability()
        #if DEBUG
        applyN027SmokeOptionsIfNeeded()
        #endif
    }

#if DEBUG
    /// Applies the smoke driver's accelerated fixtures after a formal session
    /// is launched. Compile-time DEBUG only; Release has no such entry.
    private func applyN027SmokeOptionsIfNeeded() {
        guard let fixture = N027SmokeLaunchOptions.smokeFixture else { return }
        switch fixture {
        case .q01WarningOne:
            farmScene?.installN027StorySmokeFixture(.q01WarningOne)
        case .journey:
            openStoryJourney(sceneID: StorySceneID.oldWaterway)
        case .gallery:
            farmScene?.installN027StorySmokeFixture(.galleryUnlocked)
            showStoryGallery = true
            syncMenuPause()
            claimKeyboardFocus()
        }
    }
#endif

    private func formalErrorMessage(_ error: Error) -> String {
        switch error as? FormalGameSessionError {
        case .invalidManualSlot:
            return "所选手动槽无效，请重新选择。"
        case .staleConfirmationToken:
            return "存档在确认前发生了变化。为避免覆盖错误的 campaign，请重新选择存档槽。"
        case .ambiguousCampaignOwnership:
            return "这个存档槽无法安全确认所属 campaign，因此没有执行覆盖。"
        case .noContinuableCampaign:
            return FormalGameCopy.continueUnavailable
        case .invalidContinueBinding:
            return "继续游戏候选的 campaign、存档槽或代际绑定不一致，已拒绝载入。"
        case .persistenceFailure:
            return "存档写入或复读验证失败，原有 campaign 保持不变。"
        case .debugFixtureRequired:
            return "测试夹具不能用于正式存档根。"
        case nil:
            return "正式存档操作失败：\(error.localizedDescription)"
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        settings.lastUsedDevice = .keyboardMouse
        farmScene?.updateInputDevice(.keyboardMouse)
        let representation = KeyPressRepresentation(press)

        if formalSessionError != nil {
            if representation.keyName == "escape"
                || representation.keyName == "return"
                || representation.keyName == "space" {
                formalSessionError = nil
                syncMenuPause()
                claimKeyboardFocus()
            }
            return .handled
        }

        if let request = pendingFormalNewGame {
            if representation.keyName == "return" || representation.keyName == "space" {
                confirmFormalNewGame(request)
            } else if representation.keyName == "escape" {
                closeFormalNewGameFlow()
            }
            return .handled
        }

        if showFormalSlotPicker {
            if representation.keyName == "escape" {
                closeFormalNewGameFlow()
                return .handled
            }
            if representation.keyName == "upArrow" || representation.keyName == "leftArrow" {
                moveFormalSlotSelection(-1)
                return .handled
            }
            if representation.keyName == "downArrow" || representation.keyName == "rightArrow" {
                moveFormalSlotSelection(1)
                return .handled
            }
            if representation.keyName == "return" || representation.keyName == "space" {
                prepareFormalNewGame(selectedFormalSlotIndex)
                return .handled
            }
            if let character = representation.character,
               let number = Int(character), (1...formalSlots.count).contains(number) {
                prepareFormalNewGame(number - 1)
                return .handled
            }
            return .handled
        }

        if showStoryJourney, let controller = storyJourneyController {
            switch representation.keyName {
            case "upArrow":
                controller.move(dx: 0, dy: -1)
            case "downArrow":
                controller.move(dx: 0, dy: 1)
            case "leftArrow":
                controller.move(dx: -1, dy: 0)
            case "rightArrow":
                controller.move(dx: 1, dy: 0)
            case "space", "return":
                _ = controller.interact()
            case "escape":
                closeStoryJourney()
            default:
                break
            }
            return .handled
        }

        if showStoryGallery {
            if representation.keyName == "escape" {
                closeStoryGallery()
            }
            return .handled
        }

        if farmScene?.storyDialogueRoutingContext != nil {
            if representation.keyName == "escape" {
                farmScene?.cancelStoryDialogue()
                refreshHudText()
                return .handled
            }
            if let binding = InputBindingCodec.bindingString(forKeyPress: representation) {
                let uiAction = InputBindingsService.action(
                    forBinding: binding,
                    device: .keyboardMouse,
                    settings: settings,
                    context: "ui"
                )
                let gameAction = InputBindingsService.action(
                    forBinding: binding,
                    device: .keyboardMouse,
                    settings: settings
                )
                if let actionID = uiAction ?? gameAction,
                   farmScene?.routeStoryDialogueAction(actionID) == true {
                    refreshHudText()
                    return .handled
                }
            }
            return .handled
        }

        if pendingCropSleepRisk != nil || morningReportSnapshot != nil {
            if let binding = InputBindingCodec.bindingString(forKeyPress: representation),
               let actionID = InputBindingsService.action(
                    forBinding: binding,
                    device: .keyboardMouse,
                    settings: settings,
                    context: "ui"
               ) {
                let context: MorningCropReportUIContext = pendingCropSleepRisk.map {
                    .sleepRiskPresented(token: $0.token)
                } ?? .reportPresented
                if let action = MorningCropReportActionRouter.route(
                    actionID: actionID,
                    context: context
                ) {
                    handleMorningCropReportAction(action)
                }
            }
            return .handled
        }

        if showCatShopSupply {
            if representation.keyName == "escape"
                || representation.character?.lowercased() == "j" {
                closeCatShopSupply()
            }
            return .handled
        }

        if showLivestockRoster {
            if representation.keyName == "escape"
                || representation.character?.lowercased() == "m" {
                closeLivestockRoster()
            }
            return .handled
        }

        if showCatBbqArtTour {
            if representation.keyName == "escape"
                || representation.character?.lowercased() == "j" {
                closeCatBbqArtTour()
            }
            return .handled
        }

        if shell.overlay == .settings {
            return handleSettingsInput(representation)
        }

        if shell.overlay == .restartConfirm {
            if representation.keyName == "return" || representation.keyName == "space" {
                performShellCommand(.confirmRestartDemo)
                return .handled
            }
            _ = shell.handleEscape()
            syncMenuPause()
            return .handled
        }

        if representation.keyName == "escape" {
            if showCharacterInfo {
                showCharacterInfo = false
                return .handled
            }
            if buildingCardMode == .expanded {
                buildingCardMode = .dismissed
                return .handled
            }
            if shell.route == .welcome && shell.overlay == .none {
                return .ignored
            }
            _ = shell.handleEscape()
            syncMenuPause()
            return .handled
        }

        if shell.route == .welcome {
            return handleWelcomeInput(representation)
        }

        if shell.overlay == .pause {
            return handlePauseInput(representation)
        }

        if shell.overlay == .controls {
            return .handled
        }

        guard let farmScene else { return .ignored }

        if representation.character?.lowercased() == "j", isNearCatBbqShop {
            openCatShopSupply()
            return .handled
        }

        if representation.character?.lowercased() == "m", farmScene.isOnFarmMap {
            openLivestockRoster()
            return .handled
        }

        if press.characters.lowercased() == "o" {
            farmScene.cycleSaveSlot()
            refreshHudText()
            return .handled
        }

        guard let binding = InputBindingCodec.bindingString(forKeyPress: representation) else {
            return .ignored
        }

        guard let route = InputBindingsService.route(
            for: binding,
            device: .keyboardMouse,
            settings: settings
        ) else {
            if binding == BuildingPresentationCatalog.inspectKeyboardBinding {
                guard nearbyBuildingID != nil else { return .ignored }
                switch buildingCardMode {
                case .expanded: buildingCardMode = .dismissed
                case .dismissed:
                    showCharacterInfo = false
                    buildingCardMode = .expanded
                }
                return .handled
            }
            return .ignored
        }

        switch route {
        case .action(let actionID):
            if showCharacterInfo || buildingCardMode == .expanded {
                return .handled
            }
            return performGameplayAction(actionID)
        case .showCharacterInfo:
            guard farmScene.hudPresentationState.dialogue == nil else { return .handled }
            showCharacterInfo.toggle()
            if showCharacterInfo {
                buildingCardMode = .dismissed
            }
            return .handled
        }
    }

    private func openCatBbqArtTour() {
        guard isNearCatBbqShop else { return }
        showCharacterInfo = false
        buildingCardMode = .dismissed
        showCatShopSupply = false
        showCatBbqArtTour = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func openCatBbqArtTourFromSupply() {
        guard isNearCatBbqShop else { return }
        showCatShopSupply = false
        showCatBbqArtTour = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func closeCatBbqArtTour() {
        showCatBbqArtTour = false
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func openCatShopSupply() {
        guard isNearCatBbqShop else { return }
        showCharacterInfo = false
        buildingCardMode = .dismissed
        showCatBbqArtTour = false
        showLivestockRoster = false
        showCatShopSupply = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func closeCatShopSupply() {
        showCatShopSupply = false
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func openLivestockRoster() {
        guard farmScene?.isOnFarmMap == true else { return }
        showCharacterInfo = false
        buildingCardMode = .dismissed
        showCatBbqArtTour = false
        showCatShopSupply = false
        showLivestockRoster = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func closeLivestockRoster() {
        showLivestockRoster = false
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func openStoryJourney(sceneID: String) {
        showCharacterInfo = false
        buildingCardMode = .dismissed
        showCatBbqArtTour = false
        showCatShopSupply = false
        showLivestockRoster = false
        showStoryGallery = false
        let controller = StoryJourneySceneController(sceneID: sceneID)
        wireStoryJourney(controller)
        storyJourneyController = controller
        showStoryJourney = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    /// Opens the journey at the scene derived from the persisted mission
    /// checkpoint, wiring checkpoint/exit/back/abandon into the domain layer.
    private func openStoryJourneyResuming() {
        guard let farmScene else { return }
        let checkpoint = farmScene.activeJourneyCheckpoint ?? .departure
        let (sceneID, resolved) = Self.journeySceneID(for: checkpoint)
        let controller = StoryJourneySceneController(sceneID: sceneID)
        if resolved {
            controller.markCheckpointResolved()
        }
        wireStoryJourney(controller)
        storyJourneyController = controller
        showStoryJourney = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    /// Maps a persisted journey checkpoint to the scene to present and whether
    /// that scene's checkpoint is already resolved.
    private static func journeySceneID(
        for checkpoint: StoryJourneyCheckpoint
    ) -> (sceneID: String, resolved: Bool) {
        switch checkpoint {
        case .departure:
            return (StorySceneID.oldWaterway, false)
        case .oldWaterway:
            return (StorySceneID.mistRidgeFork, false)
        case .mistRidgeFork:
            return (StorySceneID.greygateFarm, false)
        case .greyFenceFarm:
            return (StorySceneID.greygateFarm, true)
        case .homecoming:
            return (StorySceneID.oldWaterway, false)
        }
    }

    /// Wires the journey controller callbacks into the domain layer through
    /// the bound farm scene.
    private func wireStoryJourney(_ controller: StoryJourneySceneController) {
        guard let farmScene else { return }
        controller.onInspect = { [weak controller] _ in
            guard let controller else { return }
            let checkpoint: StoryJourneyCheckpoint
            switch controller.sceneID {
            case StorySceneID.oldWaterway: checkpoint = .oldWaterway
            case StorySceneID.mistRidgeFork: checkpoint = .mistRidgeFork
            default: checkpoint = .greyFenceFarm
            }
            if farmScene.advanceJourneyCheckpoint(to: checkpoint) {
                controller.markCheckpointResolved()
                refreshHudText()
            }
        }
        controller.onExit = { [weak controller] in
            guard let controller else { return }
            if controller.isFinalScene {
                if farmScene.completeHomecoming() {
                    closeStoryJourney()
                }
                refreshHudText()
            } else {
                controller.advanceToNextScene()
            }
        }
        controller.onBack = { [weak controller] in
            controller?.goBackScene()
        }
        controller.onAbandon = {
            if farmScene.abandonJourney() {
                closeStoryJourney()
            }
            refreshHudText()
        }
    }

    /// Opens the gallery after a graduation; the gallery is the final screen
    /// of the all-evil ending.
    private func openStoryGalleryAfterGraduation() {
        showStoryGallery = true
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func closeStoryJourney() {
        showStoryJourney = false
        storyJourneyController = nil
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func closeStoryGallery() {
        showStoryGallery = false
        syncMenuPause()
        claimKeyboardFocus()
    }

    private func handleWelcomeInput(_ representation: KeyPressRepresentation) -> KeyPress.Result {
        if representation.keyName == "upArrow" || representation.character?.lowercased() == "w" {
            shell.moveWelcomeSelection(-1)
            return .handled
        }
        if representation.keyName == "downArrow" || representation.character?.lowercased() == "s" {
            shell.moveWelcomeSelection(1)
            return .handled
        }
        if representation.keyName == "return" || representation.keyName == "space" {
            performShellCommand(shell.activateWelcomeSelection())
            return .handled
        }
        if let text = representation.character, let number = Int(text), (1...4).contains(number) {
            shell.selectedWelcomeIndex = number - 1
            performShellCommand(shell.activateWelcomeSelection())
            return .handled
        }
        return .ignored
    }

    private func handlePauseInput(_ representation: KeyPressRepresentation) -> KeyPress.Result {
        if representation.keyName == "upArrow" || representation.character?.lowercased() == "w" {
            shell.movePauseSelection(-1)
            return .handled
        }
        if representation.keyName == "downArrow" || representation.character?.lowercased() == "s" {
            shell.movePauseSelection(1)
            return .handled
        }
        if representation.keyName == "return" || representation.keyName == "space" {
            performShellCommand(shell.activatePauseSelection())
            return .handled
        }
        if let text = representation.character, let number = Int(text), (1...5).contains(number) {
            shell.selectedPauseIndex = number - 1
            performShellCommand(shell.activatePauseSelection())
            return .handled
        }
        return .handled
    }

    private func handleSettingsInput(_ press: KeyPressRepresentation) -> KeyPress.Result {
        if let rebindingActionID {
            if let binding = InputBindingCodec.bindingString(forKeyPress: press) {
                var next = settings
                let result = InputBindingsService.rebind(
                    settings: &next,
                    device: settings.lastUsedDevice,
                    actionID: rebindingActionID,
                    binding: binding
                )
                if result.ok {
                    settings = next
                    self.rebindingActionID = nil
                    settingsStatusMessage = nil
                    persistSettings()
                } else {
                    settingsStatusMessage = result.message
                }
                return .handled
            }
            return .handled
        }

        if matchesSettingsAction(press, actionID: InputBindingDefinitions.actionUICancel)
            || matchesSettingsAction(press, actionID: InputBindingDefinitions.actionOpenSettings) {
            closeSettings()
            return .handled
        }

        if matchesSettingsAction(press, actionID: InputBindingDefinitions.actionUIUp) {
            let count = max(settingsRowCount, 1)
            settingsRow = (settingsRow - 1 + count) % count
            settingsStatusMessage = nil
            return .handled
        }

        if matchesSettingsAction(press, actionID: InputBindingDefinitions.actionUIDown) {
            settingsRow = (settingsRow + 1) % max(settingsRowCount, 1)
            settingsStatusMessage = nil
            return .handled
        }

        if matchesSettingsAction(press, actionID: InputBindingDefinitions.actionUIAccept) {
            activateSettingsRow()
            return .handled
        }

        // Tab-switch: key-based (keyCharacter comes from KeyEquivalent, which is
        // derived from the virtual keycode, so it stays "," under CJK IME where
        // KeyPress.characters can be empty or full-width), plus character fallbacks.
        if press.keyCharacter == "," || press.character == "," || press.character == "，" {
            settingsTab = (settingsTab + 1) % 3
            settingsRow = 0
            settingsStatusMessage = nil
            return .handled
        }

        return .ignored
    }

    private var settingsRowCount: Int {
        switch settingsTab {
        case 0: return 4
        case 1: return InputBindingDefinitions.allActionIDs.count
        default: return 5
        }
    }

    private func activateSettingsRow() {
        switch settingsTab {
        case 0:
            cycleAccessibilityRow(settingsRow)
        case 1:
            rebindingActionID = InputBindingDefinitions.allActionIDs[settingsRow]
            settingsStatusMessage = nil
        default:
            cycleVolumeRow(settingsRow)
        }
        persistSettings()
    }

    private func cycleAccessibilityRow(_ row: Int) {
        switch row {
        case 0:
            guard let index = SettingsState.validUIScales.firstIndex(of: settings.uiScale) else { return }
            settings.uiScale = SettingsState.validUIScales[(index + 1) % SettingsState.validUIScales.count]
        case 1:
            guard let index = TextSpeed.allCases.firstIndex(of: settings.textSpeed) else { return }
            settings.textSpeed = TextSpeed.allCases[(index + 1) % TextSpeed.allCases.count]
        case 2:
            settings.vibrationEnabled.toggle()
        case 3:
            settings.reduceFlashing.toggle()
        default:
            break
        }
    }

    private func cycleVolumeRow(_ row: Int) {
        let step = 0.1
        func next(_ value: Double) -> Double {
            min(1.0, (value + step).rounded(toPlaces: 2))
        }
        switch row {
        case 0: settings.volumes.master = next(settings.volumes.master)
        case 1: settings.volumes.music = next(settings.volumes.music)
        case 2: settings.volumes.ambience = next(settings.volumes.ambience)
        case 3: settings.volumes.sfx = next(settings.volumes.sfx)
        default: settings.volumes.ui = next(settings.volumes.ui)
        }
    }

    private func matchesSettingsAction(_ press: KeyPressRepresentation, actionID: String) -> Bool {
        guard let binding = settings.bindings.bindings(for: .keyboardMouse)[actionID]?.first else {
            return false
        }
        return InputBindingCodec.matches(binding: binding, press: press)
    }

    private func performGameplayAction(_ actionID: String) -> KeyPress.Result {
        if shell.overlay != .none && actionID != InputBindingDefinitions.actionOpenSettings {
            return .handled
        }
        guard let farmScene else { return .ignored }
        switch actionID {
        case InputBindingDefinitions.actionMoveUp:
            farmScene.tryMove(.up)
        case InputBindingDefinitions.actionMoveDown:
            farmScene.tryMove(.down)
        case InputBindingDefinitions.actionMoveLeft:
            farmScene.tryMove(.left)
        case InputBindingDefinitions.actionMoveRight:
            farmScene.tryMove(.right)
        case InputBindingDefinitions.actionInteract:
            farmScene.performAction()
        case InputBindingDefinitions.actionTalk:
            farmScene.talkToNpc()
        case InputBindingDefinitions.actionTool1:
            farmScene.selectTool(.hoe)
        case InputBindingDefinitions.actionTool2:
            farmScene.selectTool(.seed)
        case InputBindingDefinitions.actionTool3:
            farmScene.selectTool(.water)
        case InputBindingDefinitions.actionTool4:
            farmScene.selectTool(.harvest)
        case InputBindingDefinitions.actionDeposit:
            farmScene.depositShipping()
        case InputBindingDefinitions.actionRetrieve:
            farmScene.retrieveShipping()
        case InputBindingDefinitions.actionCraft:
            farmScene.craftSelectedRecipe()
        case InputBindingDefinitions.actionCycleRecipe:
            farmScene.cycleRecipe()
        case InputBindingDefinitions.actionPreviewPlacement:
            farmScene.previewPlacement()
        case InputBindingDefinitions.actionConfirmPlacement:
            farmScene.confirmPlacement()
        case InputBindingDefinitions.actionSleep:
            requestSleepAfterCropRiskCheck()
        case InputBindingDefinitions.actionSaveGame:
            persistSettings()
            farmScene.saveGame()
        case InputBindingDefinitions.actionLoadGame:
            farmScene.loadGame()
            settings = farmScene.exportSettings()
            try? settingsStore.save(settings)
        case InputBindingDefinitions.actionCycleGossip:
            farmScene.cycleGossipAction()
        case InputBindingDefinitions.actionSubmitGossip:
            farmScene.submitGossipAction()
        case InputBindingDefinitions.actionCompleteEvidence:
            farmScene.completeEvidenceObjective()
        case InputBindingDefinitions.actionOpenSettings:
            _ = shell.handleEscape()
            syncMenuPause()
            return .handled
        case InputBindingDefinitions.actionToggleHud:
            toggleHudCompact()
        default:
            return .ignored
        }
        refreshHudText()
        return .handled
    }

    private func pollGamepadIfNeeded() {
        guard let controller = GCController.controllers().first else { return }
        guard let extended = controller.extendedGamepad else { return }

        settings.lastUsedDevice = .gamepad
        farmScene?.updateInputDevice(.gamepad)
        let buttons: [(String, Bool)] = [
            ("A", extended.buttonA.isPressed),
            ("B", extended.buttonB.isPressed),
            ("X", extended.buttonX.isPressed),
            ("Y", extended.buttonY.isPressed),
            ("Start", extended.buttonMenu.isPressed),
            ("Back", extended.buttonOptions?.isPressed ?? false),
            ("DpadUp", extended.dpad.up.isPressed),
            ("DpadDown", extended.dpad.down.isPressed),
            ("DpadLeft", extended.dpad.left.isPressed),
            ("DpadRight", extended.dpad.right.isPressed),
        ]

        for (name, pressed) in buttons where pressed {
            let binding = "Joypad:\(name)"
            if showStoryJourney, let controller = storyJourneyController {
                switch name {
                case "DpadUp": controller.move(dx: 0, dy: -1)
                case "DpadDown": controller.move(dx: 0, dy: 1)
                case "DpadLeft": controller.move(dx: -1, dy: 0)
                case "DpadRight": controller.move(dx: 1, dy: 0)
                case "A": _ = controller.interact()
                case "B": closeStoryJourney()
                default: break
                }
                return
            }
            if showStoryGallery {
                if name == "B" {
                    closeStoryGallery()
                }
                return
            }
            if farmScene?.storyDialogueRoutingContext != nil {
                if let actionID = InputBindingsService.action(
                    forBinding: binding,
                    device: .gamepad,
                    settings: settings,
                    context: "ui"
                ) ?? InputBindingsService.action(
                    forBinding: binding,
                    device: .gamepad,
                    settings: settings
                ),
                   farmScene?.routeStoryDialogueAction(actionID) == true {
                    refreshHudText()
                }
                return
            }
            if pendingCropSleepRisk != nil || morningReportSnapshot != nil {
                if let actionID = InputBindingsService.action(
                    forBinding: binding,
                    device: .gamepad,
                    settings: settings,
                    context: "ui"
                ) {
                    let context: MorningCropReportUIContext = pendingCropSleepRisk.map {
                        .sleepRiskPresented(token: $0.token)
                    } ?? .reportPresented
                    if let action = MorningCropReportActionRouter.route(
                        actionID: actionID,
                        context: context
                    ) {
                        handleMorningCropReportAction(action)
                    }
                }
                return
            }
            if showFormalSlotPicker || pendingFormalNewGame != nil || formalSessionError != nil {
                if let actionID = InputBindingsService.action(
                    forBinding: binding,
                    device: .gamepad,
                    settings: settings,
                    context: "ui"
                ) {
                    handleFormalGamepadAction(actionID)
                }
                return
            }
            if shell.overlay == .settings {
                if rebindingActionID != nil {
                    var next = settings
                    let result = InputBindingsService.rebind(
                        settings: &next,
                        device: .gamepad,
                        actionID: rebindingActionID!,
                        binding: binding
                    )
                    if result.ok {
                        settings = next
                        rebindingActionID = nil
                        settingsStatusMessage = nil
                        persistSettings()
                    } else {
                        settingsStatusMessage = result.message
                    }
                    return
                }
                if let actionID = InputBindingsService.action(
                    forBinding: binding,
                    device: .gamepad,
                    settings: settings,
                    context: "ui"
                ) {
                    if actionID == InputBindingDefinitions.actionUIAccept {
                        activateSettingsRow()
                    } else if actionID == InputBindingDefinitions.actionUICancel
                                || actionID == InputBindingDefinitions.actionOpenSettings {
                        closeSettings()
                    } else if actionID == InputBindingDefinitions.actionUIUp {
                        settingsRow = max(settingsRow - 1, 0)
                    } else if actionID == InputBindingDefinitions.actionUIDown {
                        settingsRow = min(settingsRow + 1, settingsRowCount - 1)
                    }
                }
                return
            }

            if let actionID = InputBindingsService.action(
                forBinding: binding,
                device: .gamepad,
                settings: settings
            ) {
                _ = performGameplayAction(actionID)
            }
        }
    }

    private func handleFormalGamepadAction(_ actionID: String) {
        if formalSessionError != nil {
            if actionID == InputBindingDefinitions.actionUIAccept
                || actionID == InputBindingDefinitions.actionUICancel {
                formalSessionError = nil
                syncMenuPause()
                claimKeyboardFocus()
            }
            return
        }
        if let request = pendingFormalNewGame {
            if actionID == InputBindingDefinitions.actionUIAccept {
                confirmFormalNewGame(request)
            } else if actionID == InputBindingDefinitions.actionUICancel {
                closeFormalNewGameFlow()
            }
            return
        }
        guard showFormalSlotPicker else { return }
        switch actionID {
        case InputBindingDefinitions.actionUIUp:
            moveFormalSlotSelection(-1)
        case InputBindingDefinitions.actionUIDown:
            moveFormalSlotSelection(1)
        case InputBindingDefinitions.actionUIAccept:
            prepareFormalNewGame(selectedFormalSlotIndex)
        case InputBindingDefinitions.actionUICancel:
            closeFormalNewGameFlow()
        default:
            break
        }
    }
}

struct CompactFarmHudView: View {
    let state: HudPresentationState
    let scale: CGFloat
    var showsBottomDock = true
    var supplementalPrompt: String? = nil

    private let ink = Color(red: 0.98, green: 0.99, blue: 0.96)
    private let glass = Color(red: 0.045, green: 0.065, blue: 0.055).opacity(0.92)
    private let copper = Color(red: 0xE2 / 255, green: 0x9A / 255, blue: 0x4A / 255)
    private let moss = Color(red: 0xA8 / 255, green: 0xC4 / 255, blue: 0x7A / 255)
    private let line = Color.white.opacity(0.28)

    var body: some View {
        GeometryReader { geometry in
            let zones = HudSafeZoneLayout.resolve(viewport: geometry.size)
            ZStack(alignment: .topLeading) {
                hudCard {
                    HStack(spacing: 8 * scale) {
                        RuntimePixelIcon(assetID: "ui_time", size: 24 * scale)
                        VStack(alignment: .leading, spacing: 1) {
                            ViewThatFits(in: .horizontal) {
                                calendarRow(showWeatherName: true)
                                calendarRow(showWeatherName: false)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 5 * scale) {
                                Text("目标")
                                    .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                                    .foregroundStyle(copper)
                                Text(HudCopy.compactGoal(state.questLine))
                                    .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                                    .lineLimit(2)
                                    .opacity(0.9)
                            }
                        }
                    }
                }
                .frame(width: zones.statusLeft.width, height: zones.statusLeft.height, alignment: .leading)
                .position(x: zones.statusLeft.midX, y: zones.statusLeft.midY)

                HStack(spacing: 8 * scale) {
                    statusChip(icon: "ui_stamina", text: "\(state.resources.staminaCurrent)/\(state.resources.staminaMaximum)")
                    statusChip(icon: "ui_currency", text: "\(state.resources.currency)")
                }
                .frame(width: zones.statusRight.width, height: zones.statusRight.height, alignment: .trailing)
                .position(x: zones.statusRight.midX, y: zones.statusRight.midY)

                if showsBottomDock {
                    HStack(spacing: 6 * scale) {
                        ForEach(state.toolbelt) { slot in
                            ZStack {
                                RuntimePixelIcon(
                                    assetID: slot.isSelected ? RuntimeArtKey.uiSlotSelected.rawValue : RuntimeArtKey.uiSlot.rawValue,
                                    size: 48 * scale
                                )
                                RuntimePixelIcon(
                                    assetID: slot.assetID,
                                    size: (slot.assetID.hasPrefix("crop_") ? 32 : 24) * scale
                                )
                                Text(slot.bindingLabel)
                                    .font(.system(size: 9 * scale, weight: .bold, design: .rounded))
                                    .foregroundStyle(ink)
                                    .offset(y: 17 * scale)
                            }
                            .accessibilityLabel("\(slot.bindingLabel) \(slot.displayName)\(slot.isSelected ? " 已选择" : "")")
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(width: zones.toolbelt.width, height: zones.toolbelt.height)
                    .background(glass)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(line, lineWidth: 1))
                    .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
                    .position(x: zones.toolbelt.midX, y: zones.toolbelt.midY)

                    Group {
                        if let toast = state.toast {
                            Text(HudCopy.playerToast(message: toast.message, isSuccess: toast.isSuccess))
                                .foregroundStyle(toast.isSuccess ? moss : copper)
                        } else {
                            HStack(spacing: 7 * scale) {
                                RuntimePixelIcon(assetID: RuntimeArtKey.uiInteractBadge.rawValue, size: 22 * scale)
                                Text("[\(state.prompt.bindingLabel)] \(state.prompt.text)")
                                if let supplementalPrompt {
                                    Rectangle()
                                        .fill(line)
                                        .frame(width: 1, height: 16 * scale)
                                    Text(supplementalPrompt)
                                        .foregroundStyle(copper)
                                }
                            }
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12 * scale)
                    .frame(width: zones.contextPrompt.width, height: zones.contextPrompt.height)
                    .background(glass)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(line, lineWidth: 1))
                    .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
                    .position(x: zones.contextPrompt.midX, y: zones.contextPrompt.midY)
                }
            }
        }
    }

    private func calendarRow(showWeatherName: Bool) -> some View {
        HStack(spacing: 6 * scale) {
            Text(state.calendar.mapName)
                .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                .fixedSize(horizontal: true, vertical: false)
            Text("第\(state.calendar.day)天 \(state.calendar.time)")
                .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                .opacity(0.94)
                .fixedSize(horizontal: true, vertical: false)
            RuntimePixelIcon(assetID: state.calendar.weatherAssetID, size: 24 * scale)
            if showWeatherName {
                Text(state.calendar.weatherName)
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func statusChip(icon: String, text: String) -> some View {
        HStack(spacing: 5 * scale) {
            iconWell(icon, size: 18 * scale)
            Text(text)
                .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .monospacedDigit()
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10 * scale)
        .padding(.vertical, 6 * scale)
        .background(glass)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(line, lineWidth: 1))
        .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
    }

    private func iconWell(_ assetID: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.45))
            RuntimePixelIcon(assetID: assetID, size: size)
        }
        .frame(width: size + 4, height: size + 4)
    }

    private func hudCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(ink)
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 6 * scale)
            .background(glass)
            .clipShape(RoundedRectangle(cornerRadius: 10 * scale))
            .overlay(
                RoundedRectangle(cornerRadius: 10 * scale)
                    .stroke(line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
    }
}

private struct DialoguePresentationLayer: View {
    let dialogue: HudPresentationState.DialogueBanner
    let characterID: String?
    let portraitAssetName: String?
    let speakerName: String
    let scale: CGFloat

    private let glass = Color(red: 0.045, green: 0.065, blue: 0.055).opacity(0.96)
    private let copper = Color(red: 0xE2 / 255, green: 0x9A / 255, blue: 0x4A / 255)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 12 * scale) {
                        if let portraitAssetName {
                            ConceptPortraitCard(
                                characterID: characterID,
                                assetName: portraitAssetName,
                                speakerName: speakerName
                            )
                        }

                        VStack(alignment: .leading, spacing: 8 * scale) {
                            Text(dialogue.speakerName)
                                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                                .foregroundStyle(copper)
                            Text(dialogue.line)
                                .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                Spacer()
                                Text("[空格 / T] 继续")
                                    .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .padding(16 * scale)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: min(170 * scale, geometry.size.height * 0.28),
                            alignment: .topLeading
                        )
                        .background(glass)
                        .clipShape(RoundedRectangle(cornerRadius: 14 * scale))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14 * scale)
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 18 * scale)
                    .padding(.bottom, 18 * scale)
                }
            }
        }
    }
}

private struct RuntimePixelIcon: View {
    let assetID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let texture = PixelAssetStore.shared.texture(named: assetID) {
                Image(nsImage: textureToImage(texture))
                    .resizable()
                    .interpolation(.none)
            } else if let directory = PixelAssetStore.shared.assetsDirectory(),
                      let image = NSImage(contentsOf: directory.appendingPathComponent("\(assetID).png")) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.4, green: 0.33, blue: 0.28))
            }
        }
        .frame(width: size, height: size)
    }

    private func textureToImage(_ texture: SKTexture) -> NSImage {
        let cgImage = texture.cgImage()
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

private struct ConceptPortraitCard: View {
    let characterID: String?
    let assetName: String
    let speakerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = portraitImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 190, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            } else {
                PortraitFallbackView(label: "立绘暂不可用")
                    .frame(width: 190, height: 220)
            }
            Text(speakerName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(10)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }

    private var portraitImage: NSImage? {
        guard let characterID else { return nil }
        return PortraitPresentationCatalog.image(for: characterID)
    }
}

private struct CharacterInfoCard: View {
    let characterID: String?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("角色信息")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text("[\(InputBindingDefinitions.characterInfoKeyboardLabel)]关闭")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)

            if let characterID,
               let image = PortraitPresentationCatalog.image(for: characterID) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 330, maxHeight: 430)
                Text(CharacterVisualCatalog.visual(for: characterID).displayName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                PortraitFallbackView(label: "暂无可用立绘")
                    .frame(maxWidth: 330, maxHeight: 430)
                Text("角色资料暂不可用")
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .background(Color.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 5)
    }
}

private struct PortraitFallbackView: View {
    let label: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2)))
            VStack(spacing: 8) {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 28))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.82))
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
