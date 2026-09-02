import Foundation

/// Data-driven input action table with stable IDs. Gameplay contexts are
/// separate from UI so conflicts are blocked only within the same context.
enum InputBindingDefinitions {
    static let keyboardMouseDevice = "keyboard_mouse"
    static let gamepadDevice = "gamepad"
    /// Presentation-only shortcut; it intentionally lives outside the rebinding table.
    static let characterInfoKeyboardBinding = "Key:Q"

    static let actionMoveUp = "brookseed.input.move_up"
    static let actionMoveDown = "brookseed.input.move_down"
    static let actionMoveLeft = "brookseed.input.move_left"
    static let actionMoveRight = "brookseed.input.move_right"
    static let actionInteract = "brookseed.input.interact"
    static let actionTalk = "brookseed.input.talk"
    static let actionTool1 = "brookseed.input.tool_1"
    static let actionTool2 = "brookseed.input.tool_2"
    static let actionTool3 = "brookseed.input.tool_3"
    static let actionTool4 = "brookseed.input.tool_4"
    static let actionDeposit = "brookseed.input.deposit"
    static let actionRetrieve = "brookseed.input.retrieve"
    static let actionCraft = "brookseed.input.craft"
    static let actionCycleRecipe = "brookseed.input.cycle_recipe"
    static let actionPreviewPlacement = "brookseed.input.preview_placement"
    static let actionConfirmPlacement = "brookseed.input.confirm_placement"
    static let actionSleep = "brookseed.input.sleep"
    static let actionSaveGame = "brookseed.input.save_game"
    static let actionLoadGame = "brookseed.input.load_game"
    static let actionCycleGossip = "brookseed.input.cycle_gossip"
    static let actionSubmitGossip = "brookseed.input.submit_gossip"
    static let actionCompleteEvidence = "brookseed.input.complete_evidence"
    static let actionOpenSettings = "brookseed.input.open_settings"
    static let actionToggleHud = "brookseed.input.toggle_hud"
    static let actionCycleSaveSlot = "brookseed.input.cycle_save_slot"
    static let actionUIUp = "brookseed.input.ui_up"
    static let actionUIDown = "brookseed.input.ui_down"
    static let actionUIAccept = "brookseed.input.ui_accept"
    static let actionUICancel = "brookseed.input.ui_cancel"

    static let requiredActionIDs: [String] = [
        actionMoveUp,
        actionMoveDown,
        actionMoveLeft,
        actionMoveRight,
        actionInteract,
        actionOpenSettings,
        actionUIAccept,
        actionUICancel,
    ]

    static let allActionIDs: [String] = [
        actionMoveUp,
        actionMoveDown,
        actionMoveLeft,
        actionMoveRight,
        actionInteract,
        actionTalk,
        actionTool1,
        actionTool2,
        actionTool3,
        actionTool4,
        actionDeposit,
        actionRetrieve,
        actionCraft,
        actionCycleRecipe,
        actionPreviewPlacement,
        actionConfirmPlacement,
        actionSleep,
        actionSaveGame,
        actionLoadGame,
        actionCycleGossip,
        actionSubmitGossip,
        actionCompleteEvidence,
        actionOpenSettings,
        actionToggleHud,
        actionUIUp,
        actionUIDown,
        actionUIAccept,
        actionUICancel,
    ]

    static let uiActionIDs: Set<String> = [
        actionUIUp,
        actionUIDown,
        actionUIAccept,
        actionUICancel,
    ]

    static func context(for actionID: String) -> String {
        uiActionIDs.contains(actionID) ? "ui" : "gameplay"
    }

    static func displayName(for actionID: String) -> String {
        switch actionID {
        case actionMoveUp: return "移动-上"
        case actionMoveDown: return "移动-下"
        case actionMoveLeft: return "移动-左"
        case actionMoveRight: return "移动-右"
        case actionInteract: return "动作/交互"
        case actionTalk: return "交谈"
        case actionTool1: return "工具 1（锄）"
        case actionTool2: return "工具 2（种）"
        case actionTool3: return "工具 3（水）"
        case actionTool4: return "工具 4（收）"
        case actionDeposit: return "投入出售箱"
        case actionRetrieve: return "取回待结算"
        case actionCraft: return "制作"
        case actionCycleRecipe: return "切换配方"
        case actionPreviewPlacement: return "放置预览"
        case actionConfirmPlacement: return "确认放置"
        case actionSleep: return "睡眠日结"
        case actionSaveGame: return "保存"
        case actionLoadGame: return "读取"
        case actionCycleGossip: return "切换社区行动"
        case actionSubmitGossip: return "提交社区行动"
        case actionCompleteEvidence: return "可选恢复"
        case actionOpenSettings: return "打开设置"
        case actionToggleHud: return "折叠/展开 HUD"
        case actionCycleSaveSlot: return "切换存档槽"
        case actionUIUp: return "界面-上"
        case actionUIDown: return "界面-下"
        case actionUIAccept: return "界面-确认"
        case actionUICancel: return "界面-取消"
        default: return actionID
        }
    }

    static func defaultBindings(for device: String) -> [String: [String]] {
        var table: [String: [String]] = [:]
        for actionID in allActionIDs {
            table[actionID] = defaultBinding(device: device, actionID: actionID)
        }
        return table
    }

    private static func defaultBinding(device: String, actionID: String) -> [String] {
        if device == gamepadDevice {
            return [defaultGamepadBinding(actionID: actionID)]
        }
        return [defaultKeyboardBinding(actionID: actionID)]
    }

    private static func defaultKeyboardBinding(actionID: String) -> String {
        switch actionID {
        case actionMoveUp: return "Key:W"
        case actionMoveDown: return "Key:S"
        case actionMoveLeft: return "Key:A"
        case actionMoveRight: return "Key:D"
        case actionInteract: return "Key:Space"
        case actionTalk: return "Key:T"
        case actionTool1: return "Key:1"
        case actionTool2: return "Key:2"
        case actionTool3: return "Key:3"
        case actionTool4: return "Key:4"
        case actionDeposit: return "Key:I"
        case actionRetrieve: return "Key:U"
        case actionCraft: return "Key:C"
        case actionCycleRecipe: return "Key:R"
        case actionPreviewPlacement: return "Key:P"
        case actionConfirmPlacement: return "Key:F"
        case actionSleep: return "Key:N"
        case actionSaveGame: return "Key:K"
        case actionLoadGame: return "Key:L"
        case actionCycleGossip: return "Key:Y"
        case actionSubmitGossip: return "Key:B"
        case actionCompleteEvidence: return "Key:V"
        case actionOpenSettings: return "Key:Escape"
        case actionToggleHud: return "Key:H"
        case actionCycleSaveSlot: return "Key:O"
        case actionUIUp: return "Key:Up"
        case actionUIDown: return "Key:Down"
        case actionUIAccept: return "Key:Return"
        case actionUICancel: return "Key:Escape"
        default: return "Key:\(actionID)"
        }
    }

    private static func defaultGamepadBinding(actionID: String) -> String {
        switch actionID {
        case actionMoveUp: return "Joypad:DpadUp"
        case actionMoveDown: return "Joypad:DpadDown"
        case actionMoveLeft: return "Joypad:DpadLeft"
        case actionMoveRight: return "Joypad:DpadRight"
        case actionInteract: return "Joypad:A"
        case actionTalk: return "Joypad:Y"
        case actionTool1: return "Joypad:LB"
        case actionTool2: return "Joypad:RB"
        case actionTool3: return "Joypad:X"
        case actionTool4: return "Joypad:B"
        case actionDeposit: return "Joypad:LeftTrigger"
        case actionRetrieve: return "Joypad:RightTrigger"
        case actionCraft: return "Joypad:LeftShoulder"
        case actionCycleRecipe: return "Joypad:RightShoulder"
        case actionPreviewPlacement: return "Joypad:LeftStick"
        case actionConfirmPlacement: return "Joypad:RightStickPress"
        case actionSleep: return "Joypad:Start"
        case actionSaveGame: return "Joypad:Back"
        case actionLoadGame: return "Joypad:Menu"
        case actionCycleGossip: return "Joypad:LeftStickPress"
        case actionSubmitGossip: return "Joypad:RightStick"
        case actionCompleteEvidence: return "Joypad:Guide"
        case actionOpenSettings: return "Joypad:Options"
        case actionToggleHud: return "Joypad:Touchpad"
        case actionUIUp: return "Joypad:DpadUp"
        case actionUIDown: return "Joypad:DpadDown"
        case actionUIAccept: return "Joypad:A"
        case actionUICancel: return "Joypad:B"
        default: return "Joypad:\(actionID)"
        }
    }

    static func bindingLabel(_ binding: String) -> String {
        let parts = binding.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return binding }
        switch parts[0] {
        case "Key":
            return keyLabel(parts[1])
        case "Mouse":
            return parts[1] == "Left" ? "鼠标左键" : parts[1] == "Right" ? "鼠标右键" : parts[1]
        case "Joypad":
            return gamepadLabel(parts[1])
        default:
            return binding
        }
    }

    static var characterInfoKeyboardLabel: String {
        bindingLabel(characterInfoKeyboardBinding)
    }

    private static func keyLabel(_ key: String) -> String {
        switch key {
        case "Space": return "空格"
        case "Return": return "回车"
        case "Escape": return "Esc"
        case "Up": return "↑"
        case "Down": return "↓"
        case "Left": return "←"
        case "Right": return "→"
        default: return key
        }
    }

    private static func gamepadLabel(_ button: String) -> String {
        switch button {
        case "A": return "手柄 A"
        case "B": return "手柄 B"
        case "X": return "手柄 X"
        case "Y": return "手柄 Y"
        case "Start": return "手柄 Start"
        case "Back": return "手柄 Back"
        case "Menu": return "手柄 Menu"
        case "Options": return "手柄 Options"
        case "Guide": return "手柄 Guide"
        case "LeftTrigger": return "手柄 LT"
        case "RightTrigger": return "手柄 RT"
        case "LeftShoulder": return "手柄 LB"
        case "RightShoulder": return "手柄 RB"
        case "LeftStick": return "手柄 左摇杆"
        case "RightStick": return "手柄 右摇杆"
        case "LeftStickPress": return "手柄 左摇杆按下"
        case "RightStickPress": return "手柄 右摇杆按下"
        case "DpadUp": return "手柄 上"
        case "DpadDown": return "手柄 下"
        case "DpadLeft": return "手柄 左"
        case "DpadRight": return "手柄 右"
        default: return "手柄 \(button)"
        }
    }
}
