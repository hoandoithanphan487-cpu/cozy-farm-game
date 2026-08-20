import Foundation

/// Data-driven character looks keyed by `NpcDefinition.id` (plus the player).
/// Presentation only: does not alter content IDs, dialogue, or schedules.
enum CharacterVisualCatalog {
    static let playerID = PlayerVisualID.sprout

    static let player = CharacterVisualDefinition(
        characterID: playerID,
        displayName: "新芽农人",
        theme: ThemeColor(red: 0.93, green: 0.78, blue: 0.42, label: "木蜜衣"),
        outline: ThemeColor(red: 0.22, green: 0.45, blue: 0.38, label: "苔边"),
        hair: ThemeColor(red: 0.42, green: 0.28, blue: 0.16, label: "湿土发"),
        silhouette: .mossTuft,
        expressions: Set(CharacterExpression.allCases)
    )

    static let allNPC: [CharacterVisualDefinition] = [
        CharacterVisualDefinition(
            characterID: ContentID.waterApprentice,
            displayName: "水工学徒",
            theme: ThemeColor(red: 0.28, green: 0.62, blue: 0.68, label: "雾蓝工衣"),
            outline: ThemeColor(red: 0.12, green: 0.32, blue: 0.38, label: "深渠边"),
            hair: ThemeColor(red: 0.22, green: 0.24, blue: 0.28, label: "短发"),
            silhouette: .copperClipCrop,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.seedSteward,
            displayName: "种源管理员",
            theme: ThemeColor(red: 0.34, green: 0.56, blue: 0.32, label: "苔绿罩衫"),
            outline: ThemeColor(red: 0.16, green: 0.30, blue: 0.14, label: "叶荫边"),
            hair: ThemeColor(red: 0.55, green: 0.38, blue: 0.18, label: "束髻"),
            silhouette: .seedBun,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.creekWarden,
            displayName: "溪岸巡护员",
            theme: ThemeColor(red: 0.48, green: 0.38, blue: 0.28, label: "湿石褐"),
            outline: ThemeColor(red: 0.28, green: 0.20, blue: 0.12, label: "铜闸边"),
            hair: ThemeColor(red: 0.30, green: 0.28, blue: 0.24, label: "巡护帽"),
            silhouette: .wardenCap,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.neighborHearsay,
            displayName: "涧麦婶",
            theme: ThemeColor(red: 0.78, green: 0.58, blue: 0.28, label: "麦蜜围裙"),
            outline: ThemeColor(red: 0.46, green: 0.30, blue: 0.10, label: "麦秆边"),
            hair: ThemeColor(red: 0.38, green: 0.22, blue: 0.12, label: "盘髻"),
            silhouette: .coiledKnot,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.neighborStoryteller,
            displayName: "石灯",
            theme: ThemeColor(red: 0.82, green: 0.42, blue: 0.22, label: "铜橙外袍"),
            outline: ThemeColor(red: 0.48, green: 0.18, blue: 0.08, label: "灯芯边"),
            hair: ThemeColor(red: 0.18, green: 0.14, blue: 0.12, label: "灯穗发"),
            silhouette: .lampSpike,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.neighborEvidence,
            displayName: "青砚",
            theme: ThemeColor(red: 0.32, green: 0.40, blue: 0.52, label: "砚青长衫"),
            outline: ThemeColor(red: 0.14, green: 0.18, blue: 0.28, label: "墨边"),
            hair: ThemeColor(red: 0.16, green: 0.16, blue: 0.18, label: "侧分"),
            silhouette: .inkPart,
            expressions: Set(CharacterExpression.allCases)
        ),
        CharacterVisualDefinition(
            characterID: ContentID.neighborConsensus,
            displayName: "絮宁",
            theme: ThemeColor(red: 0.62, green: 0.52, blue: 0.68, label: "柳絮衫"),
            outline: ThemeColor(red: 0.36, green: 0.28, blue: 0.44, label: "暮紫边"),
            hair: ThemeColor(red: 0.46, green: 0.36, blue: 0.28, label: "垂发"),
            silhouette: .willowFall,
            expressions: Set(CharacterExpression.allCases)
        ),
    ]

    static let npcByID: [String: CharacterVisualDefinition] = Dictionary(
        uniqueKeysWithValues: allNPC.map { ($0.characterID, $0) }
    )

    static func visual(for characterID: String) -> CharacterVisualDefinition {
        if characterID == playerID {
            return player
        }
        return npcByID[characterID] ?? player
    }

    static func npcVisual(forNpcID npcID: String) -> CharacterVisualDefinition? {
        npcByID[npcID]
    }
}
