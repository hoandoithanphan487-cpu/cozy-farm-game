import XCTest
@testable import CreekSprout

final class ShippingServiceTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private var prices: EconomyCatalog { EconomyCatalog(content: catalog) }

    func testDepositRemovesInventoryAndCreatesMergedPendingEntry() {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 3)
        let unitPrice = prices.unitPrice(itemID: ContentID.mistRadishItem, quality: .normal)!

        let result = ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        )
        guard case .success(let next) = result else {
            return XCTFail("expected deposit success")
        }
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.mistRadishItem), 0)
        XCTAssertEqual(next.economy.shipping.pendingEntries.count, 1)
        let entry = next.economy.shipping.pendingEntries[0]
        XCTAssertEqual(entry.quantity, 3)
        XCTAssertEqual(entry.itemID, ContentID.mistRadishItem)
        XCTAssertEqual(entry.quality, .normal)
        XCTAssertEqual(entry.depositedDay, 1)
        XCTAssertEqual(entry.unitPriceSnapshot, unitPrice)
        XCTAssertEqual(Set(next.economy.shipping.pendingEntries.map(\.entryID)).count, 1)
    }

    func testDepositFailureRollsBackInventoryAndShipping() {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 2)
        let before = state
        let result = ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        )
        XCTAssertEqual(result, .failure(.insufficientQuantity))
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishItem), 2)
        XCTAssertTrue(state.economy.shipping.pendingEntries.isEmpty)
    }

    func testRetrieveRestoresItemsAndClearsEntry() {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 3)
        state = try! ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        let entryID = state.economy.shipping.pendingEntries[0].entryID

        let result = ShippingService.retrieve(state: state, entryID: entryID, catalog: catalog)
        guard case .success(let next) = result else {
            return XCTFail("expected retrieve success")
        }
        XCTAssertTrue(next.economy.shipping.pendingEntries.isEmpty)
        XCTAssertEqual(InventoryService.count(next.inventory, itemID: ContentID.mistRadishItem), 3)
    }

    func testRetrieveFailsWhenInventoryIsFullAndLeavesBinUnchanged() {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 3)
        state = try! ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 3,
            catalog: catalog
        ).get()
        state.inventoryCapacity = 1
        XCTAssertEqual(state.inventory.count, 1)
        let before = state
        let entryID = state.economy.shipping.pendingEntries[0].entryID

        let result = ShippingService.retrieve(state: state, entryID: entryID, catalog: catalog)
        XCTAssertEqual(result, .failure(.capacityExceeded))
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.economy.shipping.pendingEntries.count, 1)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: ContentID.mistRadishItem), 0)
    }

    func testPriceSnapshotIgnoresLaterCatalogChanges() {
        var state = GameState.vs0NewGame(catalog: catalog)
        addRadishes(&state, quantity: 1)
        state = try! ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: catalog
        ).get()
        let snapshot = state.economy.shipping.pendingEntries[0].unitPriceSnapshot

        var inflated = catalog
        var item = inflated.items[ContentID.mistRadishItem]!
        item.baseSellPrice = snapshot + 40
        inflated.items[ContentID.mistRadishItem] = item
        XCTAssertEqual(catalog.item(id: ContentID.mistRadishItem)?.baseSellPrice, snapshot)

        let settled = SettleShippingUseCase.settle(state: state, catalog: inflated)
        XCTAssertEqual(settled.record.total, snapshot)
        XCTAssertEqual(settled.record.lines[0].amount, snapshot)
    }

    func testSeedsMaterialsAndFacilitiesAreNotSellable() {
        let cases = [
            ContentID.mistRadishSeed,
            ContentID.creekWood,
            ContentID.mossStone,
            ContentID.reedFiber,
            ContentID.woodenCrateItem,
            ContentID.stonePathItem,
            ContentID.compostRackItem,
            ContentID.canalSegmentItem,
        ]
        for itemID in cases {
            var state = GameState.vs0NewGame(catalog: catalog)
            let added = InventoryService.tryAdd(
                state.inventory,
                capacity: state.inventoryCapacity,
                itemID: itemID,
                quantity: 1,
                stackLimit: catalog.stackLimit(for: itemID)
            )
            guard case .success(let inventory) = added else {
                return XCTFail("could not add \(itemID)")
            }
            state.inventory = inventory
            let before = state
            let result = ShippingService.deposit(
                state: state,
                itemID: itemID,
                quantity: 1,
                catalog: catalog
            )
            XCTAssertEqual(result, .failure(.itemNotSellable), itemID)
            XCTAssertEqual(state, before, itemID)
            XCTAssertTrue(state.economy.shipping.pendingEntries.isEmpty, itemID)
        }
    }

    func testDefinedZeroPriceCannotEnterShippingBin() {
        var zeroPriced = catalog
        var item = zeroPriced.items[ContentID.mistRadishItem]!
        item.baseSellPrice = 0
        zeroPriced.items[ContentID.mistRadishItem] = item
        XCTAssertEqual(zeroPriced.item(id: ContentID.mistRadishItem)?.baseSellPrice, 0)
        XCTAssertFalse(EconomyCatalog(content: zeroPriced).isShippable(itemID: ContentID.mistRadishItem))

        var state = GameState.vs0NewGame(catalog: zeroPriced)
        addRadishes(&state, quantity: 1)
        let before = state
        let result = ShippingService.deposit(
            state: state,
            itemID: ContentID.mistRadishItem,
            quantity: 1,
            catalog: zeroPriced
        )
        XCTAssertEqual(result, .failure(.itemNotSellable))
        XCTAssertEqual(state, before)
        XCTAssertTrue(state.economy.shipping.pendingEntries.isEmpty)
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
