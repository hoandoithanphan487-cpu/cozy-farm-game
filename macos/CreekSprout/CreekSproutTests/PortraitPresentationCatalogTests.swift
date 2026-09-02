import AppKit
import XCTest
@testable import CreekSprout

final class PortraitPresentationCatalogTests: XCTestCase {
    func testAllEightStableIDsMapToIndependentProcessedPortraits() {
        XCTAssertEqual(PortraitPresentationCatalog.entries.count, 8)
        XCTAssertEqual(Set(PortraitPresentationCatalog.entries.map(\.characterID)).count, 8)
        XCTAssertEqual(Set(PortraitPresentationCatalog.entries.map(\.assetName)).count, 8)
        XCTAssertTrue(PortraitPresentationCatalog.entries.allSatisfy { $0.assetName.hasPrefix("portrait_") })
        XCTAssertEqual(
            PortraitPresentationCatalog.assetName(for: ContentID.waterApprentice),
            "portrait_water_apprentice_clean_v01"
        )
        XCTAssertEqual(
            PortraitPresentationCatalog.assetName(for: PlayerVisualID.sprout),
            "portrait_player_clean_v01"
        )
    }

    func testUnknownIDIsSafeAndDoesNotResolveToAPlaceholderAsset() {
        XCTAssertNil(PortraitPresentationCatalog.entry(for: "brookseed.npc.unknown"))
        XCTAssertNil(PortraitPresentationCatalog.assetName(for: "brookseed.npc.unknown"))
    }

    func testPortraitLayoutPreservesAspectRatioAndFitsInsideContainer() {
        let fitted = PortraitPresentationCatalog.fittedSize(
            imageSize: CGSize(width: 2048, height: 2048),
            in: CGSize(width: 190, height: 220),
            inset: 10
        )
        XCTAssertEqual(fitted.width, fitted.height, accuracy: 0.001)
        XCTAssertLessThanOrEqual(fitted.width, 170.001)
        XCTAssertLessThanOrEqual(fitted.height, 200.001)
    }
}
