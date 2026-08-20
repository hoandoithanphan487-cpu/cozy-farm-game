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
import SpriteKit
import SwiftUI

struct ContentView: View {
    @FocusState private var isSceneFocused: Bool
    @State private var farmScene = FarmScene.makeDefault()
    @State private var hudText = ""
    @State private var isHudCompact = false
    @State private var settings = SettingsState.defaults
    @State private var showSettings = false
    @State private var settingsTab = 0
    @State private var settingsRow = 0
    @State private var rebindingActionID: String?
    @State private var settingsStatusMessage: String?

    private let settingsStore = SettingsStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: farmScene)
                .ignoresSafeArea()
                .focusable()
                .focused($isSceneFocused)
                .focusEffectDisabled()

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
            .background(Color(red: 0.05, green: 0.07, blue: 0.06).opacity(isHudCompact ? 0.55 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
            .allowsHitTesting(false)
            .frame(maxWidth: isHudCompact ? 520 : .infinity, alignment: .topLeading)

            if showSettings {
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
        }
        .onAppear {
            isSceneFocused = true
            bootstrapSettings()
            farmScene.onStateChanged = {
                refreshHudText()
            }
            refreshHudText()
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            pollGamepadIfNeeded()
        }
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
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

    private func refreshHudText() {
        hudText = farmScene.hudText(compact: isHudCompact)
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

    private func bootstrapSettings() {
        let loaded = settingsStore.load()
        settings = loaded.state
        farmScene.applySettings(settings)
        farmScene.syncSettingsIntoGameState()
    }

    private func persistSettings() {
        farmScene.applySettings(settings)
        farmScene.syncSettingsIntoGameState()
        try? settingsStore.save(settings)
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
        showSettings = true
        settingsTab = 0
        settingsRow = 0
        rebindingActionID = nil
        settingsStatusMessage = nil
        settings.lastUsedDevice = .keyboardMouse
    }

    private func closeSettings() {
        showSettings = false
        rebindingActionID = nil
        persistSettings()
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        settings.lastUsedDevice = .keyboardMouse
        let representation = KeyPressRepresentation(press)

        if showSettings {
            return handleSettingsInput(representation)
        }

        if press.characters.lowercased() == "o" {
            farmScene.cycleSaveSlot()
            refreshHudText()
            return .handled
        }

        guard let binding = InputBindingCodec.bindingString(forKeyPress: representation) else {
            return .ignored
        }

        guard let actionID = InputBindingsService.action(
            forBinding: binding,
            device: .keyboardMouse,
            settings: settings
        ) else {
            return .ignored
        }

        return performGameplayAction(actionID)
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
            farmScene.sleepAndSettle()
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
            openSettings()
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
            if showSettings {
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
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

#Preview {
    ContentView()
}
