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

    func testVs0DefinesFiveFarmableCropsWithDeterministicSeedOrder() {
        let catalog = ContentCatalog.vs0
        XCTAssertEqual(catalog.crops.count, 5)
        XCTAssertEqual(ContentID.farmSeedItemIDs.count, 5)
        XCTAssertEqual(
            ContentID.farmSeedItemIDs,
            [
                ContentID.mistRadishSeed,
                ContentID.streamLeafSeed,
                ContentID.amberBeanSeed,
                ContentID.bellBerrySeed,
                ContentID.honeyMelonSeed,
            ]
        )

        let expected: [(String, String, String, [Int], Int, Int)] = [
            (ContentID.mistRadishCrop, ContentID.mistRadishSeed, ContentID.mistRadishItem, [1, 1, 1], 2, 1),
            (ContentID.streamLeafCrop, ContentID.streamLeafSeed, ContentID.creekGreensItem, [1, 1, 2], 3, 1),
            (ContentID.amberBeanCrop, ContentID.amberBeanSeed, ContentID.amberBeanItem, [2, 2, 2], 3, 1),
            (ContentID.bellBerryCrop, ContentID.bellBerrySeed, ContentID.bellBerryItem, [2, 2, 3], 3, 2),
            (ContentID.honeyMelonCrop, ContentID.honeyMelonSeed, ContentID.honeyMelonItem, [2, 3, 3], 3, 1),
        ]
        for row in expected {
            let crop = catalog.crop(id: row.0)
            XCTAssertEqual(crop?.seedItemID, row.1)
            XCTAssertEqual(crop?.harvestItemID, row.2)
            XCTAssertEqual(crop?.stageDays, row.3)
            XCTAssertEqual(crop?.matureStageIndex, row.4)
            XCTAssertEqual(crop?.yield, row.5)
            XCTAssertEqual(catalog.item(id: row.1)?.category, "seed")
        }
    }
}
