import XCTest
@testable import CreekSprout

final class EconomyDebugReportTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testReportIncludesBalanceAndLedgerEntries() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let granted = DevelopmentCommands.grantCurrency(state: &state, amount: 10)
        XCTAssertTrue(granted.isSuccess)

        let report = EconomyDebugReport.make(from: state, catalog: catalog)
        XCTAssertEqual(report.balance, catalog.scenario.startingCurrency + 10)
        XCTAssertTrue(report.text.contains("balance=\(report.balance)"))
        XCTAssertTrue(report.text.contains("ledger 1 \(ContentID.debugGrantReason) 10 brookseed.debug.currency"))
        XCTAssertEqual(report.lines.first, "balance=\(report.balance)")
    }

    func testMaterialKitGrantIsIsolatedAndDeterministic() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let feedback = DevelopmentCommands.grantMaterialKit(state: &state, catalog: catalog)
        XCTAssertTrue(feedback.isSuccess)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.creekWood), 12)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mossStone), 4)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.reedFiber), 6)

        let crafted = CraftingService.craft(
            state: state,
            recipeID: ContentID.woodenCrateRecipe,
            catalog: catalog
        )
        guard case .success(let next) = crafted else {
            return XCTFail("debug kit should craft a crate")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.woodenCrateItem), 1)
    }

    func testCommandFeedbackHudSnapshot() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let commands = M2CommandService(catalog: catalog)
        addRadishes(&state, quantity: 1)
        let feedback = commands.depositShipping(
            state: &state,
            itemID: ContentID.mistRadishItem,
            quantity: 1
        )
        XCTAssertTrue(feedback.isSuccess)
        let hud = commands.hudSnapshot(state: state, lastFeedback: feedback)
        XCTAssertTrue(hud.contains("溪票 \(state.economy.balance)"))
        XCTAssertTrue(hud.contains("待结算 1"))
        XCTAssertTrue(hud.contains("✅"))
        XCTAssertTrue(hud.contains("已投入出售箱"))
    }

    private func addRadishes(_ state: inout GameState, quantity: Int) {
        let added = InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: ContentID.mistRadishItem,
            quantity: quantity,
            stackLimit: catalog.stackLimit(for: ContentID.mistRadishItem)
        )
        guard case .success(let inventory) = added else {
            return XCTFail("could not add radishes")
        }
        state.inventory = inventory
    }
}
