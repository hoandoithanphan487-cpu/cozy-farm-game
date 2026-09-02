import CoreGraphics
import Foundation

struct HudPresentationState: Equatable, Sendable {
    struct Calendar: Equatable, Sendable {
        var mapName: String
        var day: Int
        var time: String
        var weatherName: String
        var weatherAssetID: String
    }

    struct Resources: Equatable, Sendable {
        var staminaCurrent: Int
        var staminaMaximum: Int
        var currency: Int
    }

    struct ToolSlot: Equatable, Identifiable, Sendable {
        var id: String
        var bindingLabel: String
        var displayName: String
        var assetID: String
        var isSelected: Bool
    }

    struct Toast: Equatable, Sendable {
        var message: String
        var isSuccess: Bool
    }

    struct Prompt: Equatable, Sendable {
        var bindingLabel: String
        var text: String
        var usesGamepad: Bool
    }

    struct DialogueBanner: Equatable, Sendable {
        var speakerName: String
        var line: String
    }

    var calendar: Calendar
    var resources: Resources
    var toolbelt: [ToolSlot]
    var questLine: String
    var toast: Toast?
    var prompt: Prompt
    var dialogue: DialogueBanner?
    var debugBindingLabel: String
}

struct HudSafeZoneLayout: Equatable, Sendable {
    let statusLeft: CGRect
    let statusRight: CGRect
    let toolbelt: CGRect
    let toast: CGRect
    let contextPrompt: CGRect
    let buildingCardNear: CGRect
    let buildingCardExpanded: CGRect
    let worldSafeRectDefault: CGRect
    let worldSafeRectNearBuilding: CGRect

    static func resolve(viewport: CGSize) -> HudSafeZoneLayout {
        if viewport.width >= 1_200 || viewport.height >= 760 {
            return HudSafeZoneLayout(
                statusLeft: CGRect(x: 16, y: 16, width: 380, height: 64),
                statusRight: CGRect(x: viewport.width - 320, y: 16, width: 304, height: 44),
                toolbelt: CGRect(x: (viewport.width - 368) / 2, y: viewport.height - 72, width: 368, height: 56),
                toast: CGRect(x: (viewport.width - 560) / 2, y: viewport.height - 124, width: 560, height: 40),
                contextPrompt: CGRect(x: (viewport.width - 560) / 2, y: viewport.height - 124, width: 560, height: 40),
                buildingCardNear: CGRect(x: viewport.width - 280, y: 92, width: 264, height: 96),
                buildingCardExpanded: CGRect(x: viewport.width - 408, y: 92, width: 392, height: 480),
                worldSafeRectDefault: CGRect(x: 16, y: 92, width: viewport.width - 32, height: viewport.height - 244),
                worldSafeRectNearBuilding: CGRect(x: 16, y: 92, width: viewport.width - 440, height: viewport.height - 244)
            )
        }
        return HudSafeZoneLayout(
            statusLeft: CGRect(x: 16, y: 16, width: 352, height: 64),
            statusRight: CGRect(x: viewport.width - 272, y: 16, width: 256, height: 44),
            toolbelt: CGRect(x: (viewport.width - 360) / 2, y: viewport.height - 72, width: 360, height: 56),
            toast: CGRect(x: (viewport.width - 520) / 2, y: viewport.height - 124, width: 520, height: 40),
            contextPrompt: CGRect(x: (viewport.width - 520) / 2, y: viewport.height - 124, width: 520, height: 40),
            buildingCardNear: CGRect(x: viewport.width - 248, y: 92, width: 232, height: 88),
            buildingCardExpanded: CGRect(x: viewport.width - 392, y: 92, width: 376, height: 400),
            worldSafeRectDefault: CGRect(x: 16, y: 92, width: viewport.width - 32, height: viewport.height - 244),
            worldSafeRectNearBuilding: CGRect(x: 16, y: 92, width: viewport.width - 408, height: viewport.height - 244)
        )
    }
}
