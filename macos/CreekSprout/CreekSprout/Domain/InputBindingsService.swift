import Foundation

enum InputBindingError: Equatable, Error {
    case invalidRequest
    case bindingConflict(conflictActionID: String)
    case requiredBinding
    case bindingNotFound
}

struct InputBindingResult: Equatable {
    var ok: Bool
    var error: InputBindingError?
    var message: String?

    static func success() -> InputBindingResult {
        InputBindingResult(ok: true, error: nil, message: nil)
    }

    static func failure(_ error: InputBindingError, message: String) -> InputBindingResult {
        InputBindingResult(ok: false, error: error, message: message)
    }
}

enum GameplayInputRoute: Equatable {
    case action(String)
    case showCharacterInfo
}

enum InputBindingsService {
    static func route(
        for binding: String,
        device: InputDeviceKind,
        settings: SettingsState
    ) -> GameplayInputRoute? {
        // Configured gameplay actions win first. This preserves I → deposit and
        // also keeps a user rebind from being silently intercepted by the UI.
        if let actionID = action(forBinding: binding, device: device, settings: settings) {
            return .action(actionID)
        }
        if device == .keyboardMouse,
           binding == InputBindingDefinitions.characterInfoKeyboardBinding {
            return .showCharacterInfo
        }
        return nil
    }

    static func rebind(
        settings: inout SettingsState,
        device: InputDeviceKind,
        actionID: String,
        binding: String
    ) -> InputBindingResult {
        guard InputBindingDefinitions.allActionIDs.contains(actionID),
              !binding.isEmpty else {
            return .failure(.invalidRequest, message: "无效的绑定请求。")
        }

        var table = settings.bindings.bindings(for: device)
        guard table[actionID] != nil else {
            return .failure(.invalidRequest, message: "无效的绑定请求。")
        }

        let context = InputBindingDefinitions.context(for: actionID)
        for (candidateID, bindings) in table where candidateID != actionID {
            guard InputBindingDefinitions.context(for: candidateID) == context,
                  bindings.contains(binding) else {
                continue
            }
            let conflictName = InputBindingDefinitions.displayName(for: candidateID)
            return .failure(
                .bindingConflict(conflictActionID: candidateID),
                message: "绑定冲突：\(InputBindingDefinitions.bindingLabel(binding)) 已被「\(conflictName)」占用。"
            )
        }

        table[actionID] = [binding]
        settings.bindings.setBindings(table, for: device)
        return .success()
    }

    static func removeBinding(
        settings: inout SettingsState,
        device: InputDeviceKind,
        actionID: String,
        binding: String
    ) -> InputBindingResult {
        guard InputBindingDefinitions.allActionIDs.contains(actionID) else {
            return .failure(.invalidRequest, message: "无效的绑定请求。")
        }

        var table = settings.bindings.bindings(for: device)
        guard var bindings = table[actionID], bindings.contains(binding) else {
            return .failure(.bindingNotFound, message: "未找到该绑定。")
        }

        if InputBindingDefinitions.requiredActionIDs.contains(actionID), bindings.count == 1 {
            return .failure(.requiredBinding, message: "必要动作必须保留至少一个绑定。")
        }

        bindings.removeAll { $0 == binding }
        table[actionID] = bindings
        settings.bindings.setBindings(table, for: device)
        return .success()
    }

    static func restoreDefaults(settings: inout SettingsState) {
        settings = .defaults
    }

    static func action(
        forBinding binding: String,
        device: InputDeviceKind,
        settings: SettingsState,
        context: String? = nil
    ) -> String? {
        let table = settings.bindings.bindings(for: device)
        for actionID in InputBindingDefinitions.allActionIDs {
            guard table[actionID]?.contains(binding) == true else { continue }
            if let context, InputBindingDefinitions.context(for: actionID) != context {
                continue
            }
            return actionID
        }
        return nil
    }

    static func primaryBindingLabel(
        actionID: String,
        device: InputDeviceKind,
        settings: SettingsState
    ) -> String {
        let table = settings.bindings.bindings(for: device)
        guard let binding = table[actionID]?.first else { return "未绑定" }
        return InputBindingDefinitions.bindingLabel(binding)
    }

    static func keyHintLines(settings: SettingsState) -> String {
        let device = settings.lastUsedDevice
        let prefix = device == .gamepad ? "【手柄提示】" : "【按键提示】"
        let move = [
            primaryBindingLabel(actionID: InputBindingDefinitions.actionMoveUp, device: device, settings: settings),
            primaryBindingLabel(actionID: InputBindingDefinitions.actionMoveDown, device: device, settings: settings),
            primaryBindingLabel(actionID: InputBindingDefinitions.actionMoveLeft, device: device, settings: settings),
            primaryBindingLabel(actionID: InputBindingDefinitions.actionMoveRight, device: device, settings: settings),
        ].joined(separator: "/")
        let settingsKey = primaryBindingLabel(
            actionID: InputBindingDefinitions.actionOpenSettings,
            device: device,
            settings: settings
        )
        return [
            prefix,
            "移动 \(move)  设置 \(settingsKey)",
            "动作 \(primaryBindingLabel(actionID: InputBindingDefinitions.actionInteract, device: device, settings: settings))  保存 \(primaryBindingLabel(actionID: InputBindingDefinitions.actionSaveGame, device: device, settings: settings))",
        ].joined(separator: "\n")
    }
}

enum InputBindingCodec {
    static func bindingString(forKeyPress press: KeyPressRepresentation) -> String? {
        if let special = specialKeyBinding(for: press.keyName) {
            return special
        }
        if press.keyName == "return" {
            return "Key:Return"
        }
        if let character = press.character, character.count == 1 {
            let upper = character.uppercased()
            if upper.first?.isLetter == true || upper.first?.isNumber == true {
                return "Key:\(upper)"
            }
        }
        return nil
    }

    static func matches(binding: String, press: KeyPressRepresentation) -> Bool {
        bindingString(forKeyPress: press) == binding
    }

    static func matches(binding: String, gamepadButton: String) -> Bool {
        binding == "Joypad:\(gamepadButton)"
    }

    private static func specialKeyBinding(for keyName: String) -> String? {
        switch keyName {
        case "escape": return "Key:Escape"
        case "space": return "Key:Space"
        case "return", "enter": return "Key:Return"
        case "upArrow": return "Key:Up"
        case "downArrow": return "Key:Down"
        case "leftArrow": return "Key:Left"
        case "rightArrow": return "Key:Right"
        default: return nil
        }
    }
}

/// Testable key-press representation decoupled from SwiftUI.
struct KeyPressRepresentation: Equatable {
    var keyName: String
    var character: String?
    /// Key-level character from KeyEquivalent (derived from the virtual keycode),
    /// stable across IMEs where `character` can be empty or full-width.
    var keyCharacter: Character? = nil
}

#if canImport(SwiftUI)
import SwiftUI

extension KeyPressRepresentation {
    init(_ press: KeyPress) {
        if press.key == .escape {
            keyName = "escape"
        } else if press.key == .space {
            keyName = "space"
        } else if press.key == .return {
            keyName = "return"
        } else if press.key == .leftArrow {
            keyName = "leftArrow"
        } else if press.key == .rightArrow {
            keyName = "rightArrow"
        } else if press.key == .upArrow {
            keyName = "upArrow"
        } else if press.key == .downArrow {
            keyName = "downArrow"
        } else {
            keyName = String(describing: press.key)
        }
        keyCharacter = press.key.character
        character = press.characters.isEmpty ? nil : press.characters.lowercased()
    }
}
#endif
