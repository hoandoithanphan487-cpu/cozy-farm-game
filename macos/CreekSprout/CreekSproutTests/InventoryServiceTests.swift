import XCTest
@testable import CreekSprout

final class InventoryServiceTests: XCTestCase {
    func testAddAndRemoveAreAtomic() {
        let original = [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 8)]
        let failedAdd = InventoryService.tryAdd(
            original,
            capacity: 1,
            itemID: ContentID.mistRadishItem,
            quantity: 1
        )
        XCTAssertEqual(failedAdd, .failure(.capacityExceeded))
        XCTAssertEqual(InventoryService.count(original, itemID: ContentID.mistRadishSeed), 8)

        let failedRemove = InventoryService.tryRemove(original, itemID: ContentID.mistRadishSeed, quantity: 9)
        XCTAssertEqual(failedRemove, .failure(.insufficientQuantity))
        XCTAssertEqual(original, [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 8)])

        let added = InventoryService.tryAdd(
            original,
            capacity: 16,
            itemID: ContentID.mistRadishSeed,
            quantity: 2
        )
        XCTAssertEqual(added, .success([InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 10)]))
    }

    func testFullStackOpensSecondStackOfSameItem() {
        let full = InventoryService.tryAdd(
            [],
            capacity: 16,
            itemID: ContentID.mistRadishSeed,
            quantity: 99
        )
        guard case .success(let first) = full else {
            return XCTFail("expected a full stack")
        }
        XCTAssertEqual(first, [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 99)])

        let overflow = InventoryService.tryAdd(
            first,
            capacity: 16,
            itemID: ContentID.mistRadishSeed,
            quantity: 1
        )
        XCTAssertEqual(
            overflow,
            .success([
                InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 99),
                InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 1),
            ])
        )
    }

    func testPrefersExistingStacksThenEmptySlotsAndRollsBackWhenCapacityIsShort() {
        let partial = [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 50)]
        let filled = InventoryService.tryAdd(
            partial,
            capacity: 16,
            itemID: ContentID.mistRadishSeed,
            quantity: 10
        )
        XCTAssertEqual(filled, .success([InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 60)]))

        let overflowIntoEmpty = InventoryService.tryAdd(
            partial,
            capacity: 16,
            itemID: ContentID.mistRadishSeed,
            quantity: 60
        )
        XCTAssertEqual(
            overflowIntoEmpty,
            .success([
                InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 99),
                InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 11),
            ])
        )

        let original = [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 99)]
        let failedOverflow = InventoryService.tryAdd(
            original,
            capacity: 1,
            itemID: ContentID.mistRadishSeed,
            quantity: 1
        )
        XCTAssertEqual(failedOverflow, .failure(.capacityExceeded))
        XCTAssertEqual(original, [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 99)])
    }

    func testPartialFillOfExistingStackRollsBackWhenANewStackCannotOpen() {
        let original = [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 98)]
        let result = InventoryService.tryAdd(
            original,
            capacity: 1,
            itemID: ContentID.mistRadishSeed,
            quantity: 2,
            stackLimit: 99
        )
        XCTAssertEqual(result, .failure(.capacityExceeded))
        if case .success(let partial) = result {
            XCTFail("capacity failure must not expose a partial fill \(partial)")
        }
        XCTAssertEqual(original, [InventoryQuantity(itemID: ContentID.mistRadishSeed, quantity: 98)])
    }
}
