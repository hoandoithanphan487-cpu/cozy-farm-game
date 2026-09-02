import XCTest
@testable import CreekSprout

final class EconomyCatalogTests: XCTestCase {
    func testMistRadishUnitPriceAndTripleSettlementComeFromCatalog() {
        let catalog = ContentCatalog.vs0
        let item = catalog.item(id: ContentID.mistRadishItem)
        XCTAssertEqual(item?.baseSellPrice, 58)

        let prices = EconomyCatalog(content: catalog)
        let unit = prices.unitPrice(itemID: ContentID.mistRadishItem, quality: .normal)
        XCTAssertEqual(unit, item?.baseSellPrice)
        XCTAssertEqual(prices.lineTotal(unitPrice: unit ?? 0, quantity: 3), 174 as Int?)
        XCTAssertTrue(prices.isShippable(itemID: ContentID.mistRadishItem))
        XCTAssertNil(catalog.item(id: ContentID.mistRadishSeed)?.baseSellPrice)
        XCTAssertNil(catalog.item(id: ContentID.creekWood)?.baseSellPrice)
        XCTAssertNil(catalog.item(id: ContentID.woodenCrateItem)?.baseSellPrice)
        XCTAssertFalse(prices.isShippable(itemID: ContentID.mistRadishSeed))
        XCTAssertEqual(
            prices.settlementLine(itemID: ContentID.mistRadishItem, quantity: 3, amount: 174),
            "雾萝卜×3 = 174"
        )
        let rainBarrel = catalog.recipe(id: ContentID.rainBarrelRecipe)
        XCTAssertEqual(rainBarrel?.requiredUnlockID, ContentID.rainBarrelUnlock)
        XCTAssertFalse(catalog.isRecipeUnlocked(ContentID.rainBarrelRecipe, watershed: .empty))
    }

    func testQualityMultiplierUsesTruncatingBasisPoints() {
        XCTAssertEqual(ItemQuality.normal.multiplierBp, 100)
        XCTAssertEqual(ItemQuality.good.multiplierBp, 118)
        XCTAssertEqual(ItemQuality.excellent.multiplierBp, 142)
        XCTAssertEqual(EconomyCatalog.resolvedUnitPrice(baseSellPrice: 100, quality: .good), 118)
        XCTAssertEqual(EconomyCatalog.resolvedUnitPrice(baseSellPrice: 100, quality: .excellent), 142)
        XCTAssertEqual(EconomyCatalog.resolvedUnitPrice(baseSellPrice: 50, quality: .good), 59)
    }

    func testVs0ScenarioStartingResourcesAreDataDriven() {
        let scenario = ContentCatalog.vs0.scenario
        XCTAssertEqual(scenario.id, ContentID.vs0Scenario)
        XCTAssertEqual(scenario.startingCurrency, 720)
        XCTAssertEqual(scenario.startingItems.first?.itemID, ContentID.mistRadishSeed)
        XCTAssertEqual(scenario.startingItems.first?.quantity, 8)
        XCTAssertEqual(scenario.startingFarmCells.count, 3)
        XCTAssertTrue(scenario.startingFarmCells.allSatisfy { $0.cell.readyToHarvest })
        XCTAssertEqual(
            scenario.startingRecipeIDs,
            [
                ContentID.woodenCrateRecipe,
                ContentID.stonePathRecipe,
                ContentID.compostRackRecipe,
                ContentID.canalSegmentRecipe,
                ContentID.woodhoneyHearthRecipe,
        ]
        )
    }
}
