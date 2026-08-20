import CoreGraphics
import Foundation

enum TextSpeed: String, Codable, CaseIterable, Sendable {
    case slow
    case standard
    case fast
    case instant

    var displayName: String {
        switch self {
        case .slow: return "慢"
        case .standard: return "标准"
        case .fast: return "快"
        case .instant: return "立即"
        }
    }

    /// Multiplier applied to dialogue pacing hints and timed feedback.
    var pacingMultiplier: Double {
        switch self {
        case .slow: return 1.6
        case .standard: return 1.0
        case .fast: return 0.55
        case .instant: return 0.05
        }
    }
}

enum InputDeviceKind: String, Codable, Sendable {
    case keyboardMouse = "keyboard_mouse"
    case gamepad
}

struct VolumeSettings: Equatable, Codable, Sendable {
    var master: Double
    var music: Double
    var ambience: Double
    var sfx: Double
    var ui: Double

    static let defaults = VolumeSettings(
        master: 1.0,
        music: 1.0,
        ambience: 1.0,
        sfx: 1.0,
        ui: 1.0
    )

    enum CodingKeys: String, CodingKey {
        case master = "Master"
        case music = "Music"
        case ambience = "Ambience"
        case sfx = "SFX"
        case ui = "UI"
    }
}

struct DeviceBindings: Equatable, Codable, Sendable {
    var keyboardMouse: [String: [String]]
    var gamepad: [String: [String]]

    static var defaults: DeviceBindings {
        DeviceBindings(
            keyboardMouse: InputBindingDefinitions.defaultBindings(
                for: InputBindingDefinitions.keyboardMouseDevice
            ),
            gamepad: InputBindingDefinitions.defaultBindings(
                for: InputBindingDefinitions.gamepadDevice
            )
        )
    }

    func bindings(for device: InputDeviceKind) -> [String: [String]] {
        switch device {
        case .keyboardMouse: return keyboardMouse
        case .gamepad: return gamepad
        }
    }

    mutating func setBindings(_ table: [String: [String]], for device: InputDeviceKind) {
        switch device {
        case .keyboardMouse: keyboardMouse = table
        case .gamepad: gamepad = table
        }
    }
}

struct SettingsState: Equatable, Codable, Sendable {
    var uiScale: Int
    var vibrationEnabled: Bool
    var reduceFlashing: Bool
    var textSpeed: TextSpeed
    var volumes: VolumeSettings
    var lastUsedDevice: InputDeviceKind
    var bindings: DeviceBindings

    static let validUIScales = [100, 125, 150]

    static let defaults = SettingsState(
        uiScale: 100,
        vibrationEnabled: true,
        reduceFlashing: false,
        textSpeed: .standard,
        volumes: .defaults,
        lastUsedDevice: .keyboardMouse,
        bindings: .defaults
    )

    var uiScaleFactor: CGFloat {
        CGFloat(uiScale) / 100.0
    }

    enum CodingKeys: String, CodingKey {
        case uiScale = "ui_scale"
        case vibrationEnabled = "vibration_enabled"
        case reduceFlashing = "reduce_flashing"
        case textSpeed = "text_speed"
        case volumes
        case lastUsedDevice = "last_used_device"
        case bindings
    }

    func volumeSummaryLine() -> String {
        let pct = Int((volumes.master * 100).rounded())
        return "主音量 \(pct)%  音乐 \(Int(volumes.music * 100))%  环境 \(Int(volumes.ambience * 100))%  音效 \(Int(volumes.sfx * 100))%  界面 \(Int(volumes.ui * 100))%"
    }

    func accessibilitySummaryLine() -> String {
        "UI 缩放 \(uiScale)%  文字速度 \(textSpeed.displayName)  震动 \(vibrationEnabled ? "开" : "关")  闪烁减弱 \(reduceFlashing ? "开" : "关")"
    }
}
