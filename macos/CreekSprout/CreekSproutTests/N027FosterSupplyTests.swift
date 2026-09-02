import Foundation
import XCTest
@testable import CreekSprout

final class N027FosterSupplyTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    private func unlockedState() -> GameState {
        // Fully legal: q01–q04 resolved, q05 resolved with receipt. The
        // fixture clock stays at its effective day 40: a q01–q05 resolved
        // chain cannot fit inside day 8, and `SaveValidation` requires every
        // entered day to be at most the current clock day.
        return N027StoryFixtures.targetFixture(
            target: .q05,
            phase: .resolved,
            baseDay: 2,
            standing: 56
        )
    }

    private func adultCarefulAnimal(state: GameState, animalID: String) -> GameState {
        // The fostered animal matures and is cared for today so it can be
        // supplied through the normal cat-shop receipt path.
        var next = state
        if let index = next.livestock.animals.firstIndex(where: { $0.instanceID == animalID }) {
            let definition = LivestockCatalog.definition(
                id: next.livestock.animals[index].definitionID
            )
            next.livestock.animals[index].ageDays = definition?.maturityDays ?? 1
            next.livestock.animals[index].lastCaredDay = state.clock.day
            next.livestock.animals[index].totalCareDays = 1
        }
        next.livestock.sortAnimals()
        return next
    }

    func testIssueRequiresQ05ResolvedAndSingleActivePerCampaign() throws {
        let locked = GameState.vs0NewGame(catalog: catalog)
        XCTAssertEqual(
            FosterSupplyService.issue(
                state: locked,
                animalKindID: ContentID.livestockCow
            ),
            .failure(.notUnlocked)
        )
        var state = unlockedState()
        do {
            try SaveValidation.validateN027(state, catalog: catalog)
        } catch {
            XCTFail("bare fixture invalid: \(error)")
        }
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        XCTAssertTrue(order.issuanceID.hasPrefix("brookseed.story.foster.issue."))
        XCTAssertEqual(order.campaignID, state.campaignID)
        XCTAssertEqual(order.animalKindID, ContentID.livestockCow)
        XCTAssertEqual(state.storyMetrics.fosterIssuanceIDs, [order.issuanceID])
        XCTAssertEqual(
            FosterSupplyService.issue(
                state: state,
                animalKindID: ContentID.livestockSheep
            ),
            .failure(.orderAlreadyActive)
        )
        XCTAssertEqual(
            FosterSupplyService.issue(
                state: state,
                animalKindID: "brookseed.livestock.unknown"
            ),
            .failure(.animalKindUnknown)
        )
        try SaveValidation.validateN027(state, catalog: catalog)
    }

    func testAcceptAddsAnimalWithoutMoney() throws {
        var state = unlockedState()
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        let balanceBefore = state.economy.balance
        let animalCountBefore = state.livestock.animals.count

        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        XCTAssertEqual(state.livestock.animals.count, animalCountBefore + 1)
        XCTAssertEqual(state.economy.balance, balanceBefore, "accept pays nothing")
        let accepted = try XCTUnwrap(state.fosterOrders.activeOrder)
        XCTAssertNotNil(accepted.animalInstanceID)
        XCTAssertEqual(accepted.status, .active)
        XCTAssertEqual(accepted.acceptedDay, 40)
        // Double accept is rejected.
        XCTAssertEqual(
            FosterSupplyService.accept(state: state, issuanceID: order.issuanceID),
            .failure(.alreadyAccepted)
        )
        try SaveValidation.validateN027(state, catalog: catalog)
    }

    func testCancelAtomicallyReturnsAnimalWithoutMoney() throws {
        var state = unlockedState()
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockSheep
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        let accepted = try XCTUnwrap(state.fosterOrders.activeOrder)
        let fosteredID = try XCTUnwrap(accepted.animalInstanceID)
        XCTAssertNotNil(state.livestock.animal(id: fosteredID))

        let balanceBefore = state.economy.balance
        state = try FosterSupplyService.cancel(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        XCTAssertNil(state.livestock.animal(id: fosteredID), "animal is atomically returned")
        XCTAssertEqual(state.economy.balance, balanceBefore, "cancel pays nothing")
        let closed = try XCTUnwrap(state.fosterOrders.order(issuanceID: order.issuanceID))
        XCTAssertEqual(closed.status, .cancelled)
        XCTAssertNil(closed.animalInstanceID)
        XCTAssertEqual(closed.closedDay, 40)
        XCTAssertNil(state.fosterOrders.activeOrder)

        // A replacement issuance is then available.
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockGoat
        ).get()
        XCTAssertNotNil(state.fosterOrders.activeOrder)
        try SaveValidation.validateN027(state, catalog: catalog)
    }

    func testConvertToPartnerOncePerCampaignAndPermanentlyBlocksSupply() throws {
        var state = unlockedState()
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        let accepted = try XCTUnwrap(state.fosterOrders.activeOrder)
        let fosteredID = try XCTUnwrap(accepted.animalInstanceID)

        let balanceBefore = state.economy.balance
        state = try FosterSupplyService.convertToPartner(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        XCTAssertEqual(state.economy.balance, balanceBefore, "conversion pays nothing")
        XCTAssertTrue(state.fosterOrders.partnerConversionUsed)
        XCTAssertEqual(state.fosterOrders.convertedAnimalIDs, [fosteredID])
        let animal = try XCTUnwrap(state.livestock.animal(id: fosteredID))
        XCTAssertTrue(animal.isProtected, "partner animals are permanently protected")
        XCTAssertFalse(
            LivestockService.canSupply(animal, on: state.clock.day),
            "partner animals can never be supplied"
        )
        XCTAssertTrue(FosterSupplyService.isNonSupplyable(state: state, animalID: fosteredID))

        // A second conversion in the same campaign is rejected.
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockSheep
        ).get()
        let second = try XCTUnwrap(state.fosterOrders.activeOrder)
        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: second.issuanceID
        ).get()
        XCTAssertEqual(
            FosterSupplyService.convertToPartner(state: state, issuanceID: second.issuanceID),
            .failure(.conversionLimitReached)
        )
        try SaveValidation.validateN027(state, catalog: catalog)
    }

    func testFulfilmentOnlyThroughFinalSuccessfulCatShopReceipt() throws {
        var state = unlockedState()
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        let accepted = try XCTUnwrap(state.fosterOrders.activeOrder)
        let fosteredID = try XCTUnwrap(accepted.animalInstanceID)
        state = adultCarefulAnimal(state: state, animalID: fosteredID)

        let offerID = "\(ContentID.catShopAnimalOfferPrefix).cow"
        let requestID = "brookseed.catshop.receipt.foster_fulfil_1"
        let balanceBefore = state.economy.balance
        let result = try CatShopSupplyService.supplyAnimal(
            state: state,
            offerID: offerID,
            animalID: fosteredID,
            requestID: requestID,
            catalog: catalog
        ).get()
        XCTAssertEqual(
            result.state.economy.balance - balanceBefore,
            result.receipt.total,
            "the only revenue is the final successful receipt"
        )
        let fulfilled = try XCTUnwrap(
            result.state.fosterOrders.order(issuanceID: order.issuanceID)
        )
        XCTAssertEqual(fulfilled.status, .fulfilled)
        XCTAssertEqual(fulfilled.fulfillmentReceiptID, requestID)
        XCTAssertEqual(fulfilled.closedDay, 40)
        XCTAssertNil(result.state.fosterOrders.activeOrder)
        XCTAssertTrue(result.state.storyMetrics.catShopAnimalReceiptIDs.contains(requestID))
        // The animal is gone. Repeating the same request would hit the
        // exactly-once receipt guard (duplicateRequest); a fresh request
        // proves the animal itself is gone (animalNotFound), so the fostered
        // animal can never settle twice under any request ID.
        XCTAssertNil(result.state.livestock.animal(id: fosteredID))
        XCTAssertEqual(
            CatShopSupplyService.supplyAnimal(
                state: result.state,
                offerID: offerID,
                animalID: fosteredID,
                requestID: "brookseed.catshop.receipt.foster_fulfil_2",
                catalog: catalog
            ),
            .failure(.animalNotFound)
        )
        try SaveValidation.validateN027(result.state, catalog: catalog)
    }

    func testReplacementAfterCloseAndOriginalAnimalNeverRequalifies() throws {
        var state = unlockedState()
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        let order = try XCTUnwrap(state.fosterOrders.activeOrder)
        state = try FosterSupplyService.accept(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        let accepted = try XCTUnwrap(state.fosterOrders.activeOrder)
        let fosteredID = try XCTUnwrap(accepted.animalInstanceID)
        state = try FosterSupplyService.cancel(
            state: state,
            issuanceID: order.issuanceID
        ).get()
        // The instance is atomically returned and never re-enters the pen;
        // the converted-animal list is untouched by cancellations.
        XCTAssertFalse(
            state.fosterOrders.convertedAnimalIDs.contains(fosteredID)
        )
        XCTAssertNil(state.livestock.animal(id: fosteredID))
        // New issuance works after the old one is closed.
        state = try FosterSupplyService.issue(
            state: state,
            animalKindID: ContentID.livestockCow
        ).get()
        XCTAssertNotNil(state.fosterOrders.activeOrder)
        try SaveValidation.validateN027(state, catalog: catalog)
    }
}
