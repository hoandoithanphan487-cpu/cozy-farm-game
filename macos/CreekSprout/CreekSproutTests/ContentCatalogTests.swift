import XCTest
@testable import CreekSprout

final class ContentCatalogTests: XCTestCase {
    func testMistRadishPlaceholderMatchesFrozenBaseline() {
        let catalog = ContentCatalog.m1Placeholder
        let crop = catalog.crop(id: ContentID.mistRadishCrop)
        XCTAssertEqual(crop?.id, "brookseed.crop.mist_radish")
        XCTAssertEqual(crop?.seedItemID, "brookseed.item.mist_radish_seed")
        XCTAssertEqual(crop?.harvestItemID, "brookseed.item.mist_radish")
        XCTAssertEqual(crop?.stageDays, [1, 1, 1])
        XCTAssertEqual(crop?.matureStageIndex, 2)
        XCTAssertEqual(crop?.yield, 1)
        XCTAssertEqual(catalog.item(id: ContentID.mistRadishSeed)?.stackLimit, 99)
        XCTAssertEqual(catalog.item(id: ContentID.mistRadishItem)?.stackLimit, 99)
    }
}
