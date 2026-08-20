import CoreGraphics
import Foundation
import SpriteKit

/// Stable presentation identity for the player avatar. Not a content ID;
/// never written to saves or validated by ContentValidator.
enum PlayerVisualID {
    static let sprout = "brookseed.player.sprout"
}

enum HairSilhouette: String, Equatable, CaseIterable, Sendable {
    case copperClipCrop
    case seedBun
    case wardenCap
    case coiledKnot
    case lampSpike
    case inkPart
    case willowFall
    case mossTuft
}

enum CharacterExpression: String, Equatable, CaseIterable, Sendable {
    case idle
    case walking
    case harvesting
    case talking
    case listening
}

struct ThemeColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    /// Accessible name so color is never the only identifier.
    var label: String

    var isValid: Bool {
        (0.0...1.0).contains(red)
            && (0.0...1.0).contains(green)
            && (0.0...1.0).contains(blue)
            && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var skColor: SKColor {
        SKColor(red: red, green: green, blue: blue, alpha: 1)
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct CharacterVisualDefinition: Equatable, Sendable {
    var characterID: String
    var displayName: String
    var theme: ThemeColor
    var outline: ThemeColor
    var hair: ThemeColor
    var silhouette: HairSilhouette
    var expressions: Set<CharacterExpression>

    var isValid: Bool {
        !characterID.isEmpty
            && !displayName.isEmpty
            && theme.isValid
            && outline.isValid
            && hair.isValid
            && expressions.isSuperset(of: CharacterVisualDefinition.requiredExpressions)
    }

    static let requiredExpressions: Set<CharacterExpression> = [
        .idle, .walking, .harvesting, .talking,
    ]
}
