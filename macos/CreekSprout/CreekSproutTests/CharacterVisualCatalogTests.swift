import XCTest
@testable import CreekSprout

final class CharacterVisualCatalogTests: XCTestCase {
    func testSevenNPCVisualsCoverStableIDs() throws {
        let expected = Set(WorldCatalog.npcList.map(\.id))
        XCTAssertEqual(expected.count, 7)
        XCTAssertEqual(Set(CharacterVisualCatalog.allNPC.map(\.characterID)), expected)
        for npc in WorldCatalog.npcList {
            let visual = try XCTUnwrap(CharacterVisualCatalog.npcVisual(forNpcID: npc.id))
            XCTAssertEqual(visual.displayName, npc.displayName)
            XCTAssertTrue(visual.isValid, npc.id)
        }
    }

    func testThemeHairAndExpressionsAreLegalAndDistinct() {
        let visuals = CharacterVisualCatalog.allNPC
        XCTAssertEqual(Set(visuals.map(\.silhouette)).count, 7)
        XCTAssertEqual(Set(visuals.map { colorKey($0.theme) }).count, 7)
        for visual in visuals {
            XCTAssertTrue(visual.theme.isValid)
            XCTAssertTrue(visual.outline.isValid)
            XCTAssertTrue(visual.hair.isValid)
            XCTAssertTrue(
                visual.expressions.isSuperset(of: CharacterVisualDefinition.requiredExpressions),
                visual.characterID
            )
        }
    }

    func testPlayerVisualIsSeparateFromNPCSet() {
        XCTAssertFalse(CharacterVisualCatalog.allNPC.contains { $0.characterID == PlayerVisualID.sprout })
        XCTAssertTrue(CharacterVisualCatalog.player.isValid)
        XCTAssertEqual(CharacterVisualCatalog.visual(for: PlayerVisualID.sprout).silhouette, .mossTuft)
    }

    private func colorKey(_ color: ThemeColor) -> String {
        String(format: "%.2f-%.2f-%.2f", color.red, color.green, color.blue)
    }
}
