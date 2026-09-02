import Foundation
import XCTest
@testable import CreekSprout

final class N022LivestockAndCatShopTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testNewGameStartsWithThreeNamedLivestockAndOneJuvenile() {
        let state = GameState.vs0NewGame(catalog: catalog)

        XCTAssertEqual(state.livestock.animals.count, 3)
        XCTAssertEqual(Set(state.livestock.animals.map(\.instanceID)).count, 3)
        XCTAssertEqual(Set(state.livestock.animals.map(\.definitionID)), Set(ContentID.livestockDefinitionIDs))
        XCTAssertEqual(state.livestock.animal(id: ContentID.starterCow)?.displayName, "团云")
        XCTAssertEqual(state.livestock.animal(id: ContentID.starterSheep)?.displayName, "软铃")
        XCTAssertFalse(try XCTUnwrap(state.livestock.animal(id: ContentID.starterGoat)).isProtected)
        XCTAssertFalse(LivestockService.isAdult(try XCTUnwrap(state.livestock.animal(id: ContentID.starterGoat))))
    }

    func testLivestockShortcutDoesNotReplaceExistingLoadBinding() {
        XCTAssertEqual(
            InputBindingsService.route(for: "Key:L", device: .keyboardMouse, settings: .defaults),
            .action(InputBindingDefinitions.actionLoadGame)
        )
        XCTAssertNil(InputBindingsService.route(for: "Key:M", device: .keyboardMouse, settings: .defaults))
    }

    func testCareCostsTwoStaminaAndCannotRepeatOnSameDay() throws {
        let state = GameState.vs0NewGame(catalog: catalog)
        let cared = try LivestockService.care(state: state, animalID: ContentID.starterCow).get()

        XCTAssertEqual(cared.stamina, state.stamina - 2)
        XCTAssertEqual(cared.livestock.animal(id: ContentID.starterCow)?.lastCaredDay, 1)
        XCTAssertEqual(cared.livestock.animal(id: ContentID.starterCow)?.totalCareDays, 1)
        XCTAssertEqual(
            LivestockService.care(state: cared, animalID: ContentID.starterCow),
            .failure(.alreadyCaredToday)
        )
    }

    func testCareFailureIsAtomicWhenStaminaIsInsufficient() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.stamina = 1
        let before = state

        XCTAssertEqual(
            LivestockService.care(state: state, animalID: ContentID.starterCow),
            .failure(.insufficientStamina)
        )
        XCTAssertEqual(state, before)
    }

    func testSleepAdvancesAnimalAgeWithoutDeathOrDecay() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let before = state.livestock.animals
        let clock = ClockSystem()

        DayCycleService().settle(state: &state, clock: clock, catalog: catalog)

        XCTAssertEqual(state.clock.day, 2)
        XCTAssertEqual(state.livestock.animals.count, before.count)
        for animal in before {
            XCTAssertEqual(state.livestock.animal(id: animal.instanceID)?.ageDays, animal.ageDays + 1)
        }
    }

    func testDailyBoardHasTwoPremiumCropOffersAndThreeAnimalOffers() throws {
        let offers = CatShopCatalog.offers(day: 1, content: catalog)
        let cropOffers = offers.filter {
            if case .crop = $0.kind { return true }
            return false
        }
        let animalOffers = offers.filter {
            if case .animal = $0.kind { return true }
            return false
        }

        XCTAssertEqual(cropOffers.count, 2)
        XCTAssertEqual(animalOffers.count, 3)
        XCTAssertEqual(Set(cropOffers.map(\.id)).count, 2)
        for offer in cropOffers {
            guard case .crop(let itemID) = offer.kind else { continue }
            let basePrice = try XCTUnwrap(catalog.item(id: itemID)?.baseSellPrice)
            XCTAssertGreaterThan(offer.unitPrice, basePrice)
            XCTAssertEqual(offer.dailyLimit, 6)
        }
    }

    func testCropSupplyPaysImmediatelyRecordsReceiptAndRejectsDuplicate() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        let offer = try firstCropOffer(day: state.clock.day)
        guard case .crop(let itemID) = offer.kind else { return XCTFail("expected crop offer") }
        state.inventory = try InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: itemID,
            quantity: 3,
            stackLimit: catalog.stackLimit(for: itemID)
        ).get()
        let beforeBalance = state.economy.balance
        let requestID = "n022.crop.day1.receipt1"

        let result = try CatShopSupplyService.supplyCrop(
            state: state,
            offerID: offer.id,
            itemID: itemID,
            quantity: 3,
            requestID: requestID,
            catalog: catalog
        ).get()

        XCTAssertEqual(result.state.economy.balance, beforeBalance + offer.unitPrice * 3)
        XCTAssertEqual(result.receipt.total, offer.unitPrice * 3)
        XCTAssertEqual(result.state.catShop.receipts, [result.receipt])
        XCTAssertEqual(result.state.economy.ledger.last?.sourceRef, requestID)
        XCTAssertEqual(result.state.economy.ledger.last?.reasonID, ContentID.catShopSupplyReason)
        XCTAssertEqual(
            CatShopSupplyService.supplyCrop(
                state: result.state,
                offerID: offer.id,
                itemID: itemID,
                quantity: 1,
                requestID: requestID,
                catalog: catalog
            ),
            .failure(.duplicateRequest)
        )
    }

    func testCropSupplyEnforcesDailyCapAndFailureDoesNotRemoveInventory() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        let offer = try firstCropOffer(day: state.clock.day)
        guard case .crop(let itemID) = offer.kind else { return XCTFail("expected crop offer") }
        state.inventory = try InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: itemID,
            quantity: 7,
            stackLimit: catalog.stackLimit(for: itemID)
        ).get()
        state = try CatShopSupplyService.supplyCrop(
            state: state,
            offerID: offer.id,
            itemID: itemID,
            quantity: 6,
            requestID: "n022.cap.day1.receipt1",
            catalog: catalog
        ).get().state
        let before = state

        XCTAssertEqual(
            CatShopSupplyService.supplyCrop(
                state: state,
                offerID: offer.id,
                itemID: itemID,
                quantity: 1,
                requestID: "n022.cap.day1.receipt2",
                catalog: catalog
            ),
            .failure(.dailyLimitExceeded)
        )
        XCTAssertEqual(state, before)
        XCTAssertEqual(InventoryService.count(state.inventory, itemID: itemID), 1)
    }

    func testAnimalMustBeAdultAndCaredBeforeSupplyThenLeavesRoster() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        let cowOffer = try XCTUnwrap(CatShopCatalog.offers(day: 1, content: catalog).first {
            $0.kind == .animal(definitionID: ContentID.livestockCow)
        })

        XCTAssertEqual(
            CatShopSupplyService.supplyAnimal(
                state: state,
                offerID: cowOffer.id,
                animalID: ContentID.starterCow,
                requestID: "n022.cow.day1.receipt1",
                catalog: catalog
            ),
            .failure(.animalNotEligible)
        )

        state = try LivestockService.care(state: state, animalID: ContentID.starterCow).get()
        let beforeBalance = state.economy.balance
        let supplied = try CatShopSupplyService.supplyAnimal(
            state: state,
            offerID: cowOffer.id,
            animalID: ContentID.starterCow,
            requestID: "n022.cow.day1.receipt1",
            catalog: catalog
        ).get()

        XCTAssertNil(supplied.state.livestock.animal(id: ContentID.starterCow))
        XCTAssertEqual(supplied.state.economy.balance, beforeBalance + cowOffer.unitPrice)
        XCTAssertEqual(supplied.receipt.kind, .animal)
        XCTAssertEqual(supplied.receipt.subjectID, ContentID.starterCow)
        XCTAssertFalse(WorldLifeCatalog.shouldRender(.farmCow, livestock: supplied.state.livestock))
        XCTAssertTrue(WorldLifeCatalog.shouldRender(.farmSheep, livestock: supplied.state.livestock))
        XCTAssertTrue(WorldLifeCatalog.shouldRender(.farmGoat, livestock: supplied.state.livestock))
        XCTAssertTrue(WorldLifeCatalog.shouldRender(.farmHen, livestock: supplied.state.livestock))
    }

    func testJuvenileAndProtectedAnimalsCannotBeSupplied() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state = try LivestockService.care(state: state, animalID: ContentID.starterGoat).get()
        let goatOffer = try XCTUnwrap(CatShopCatalog.offers(day: 1, content: catalog).first {
            $0.kind == .animal(definitionID: ContentID.livestockGoat)
        })
        XCTAssertEqual(
            CatShopSupplyService.supplyAnimal(
                state: state,
                offerID: goatOffer.id,
                animalID: ContentID.starterGoat,
                requestID: "n022.goat.day1.receipt1",
                catalog: catalog
            ),
            .failure(.animalNotEligible)
        )

        let sheepIndex = try XCTUnwrap(state.livestock.animals.firstIndex {
            $0.instanceID == ContentID.starterSheep
        })
        state.livestock.animals[sheepIndex].isProtected = true
        state = try LivestockService.care(state: state, animalID: ContentID.starterSheep).get()
        let sheepOffer = try XCTUnwrap(CatShopCatalog.offers(day: 1, content: catalog).first {
            $0.kind == .animal(definitionID: ContentID.livestockSheep)
        })
        XCTAssertEqual(
            CatShopSupplyService.supplyAnimal(
                state: state,
                offerID: sheepOffer.id,
                animalID: ContentID.starterSheep,
                requestID: "n022.sheep.day1.receipt1",
                catalog: catalog
            ),
            .failure(.animalNotEligible)
        )
    }

    func testSchemaTenRoundTripAndV8Migration() throws {
        var state = GameState.vs0NewGame(catalog: catalog)
        state = try LivestockService.care(state: state, animalID: ContentID.starterCow).get()
        let encoded = try SaveCodec.encode(state)
        let decoded = try SaveCodec.decode(encoded, catalog: catalog)
        XCTAssertEqual(decoded, state)

        var v8JSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        v8JSON["schema_version"] = 8
        v8JSON.removeValue(forKey: "livestock")
        v8JSON.removeValue(forKey: "cat_shop")
        let migrated = try SaveMigrator.migrate(JSONSerialization.data(withJSONObject: v8JSON))

        XCTAssertEqual(migrated.schemaVersion, 10)
        XCTAssertEqual(migrated.livestock, LivestockCatalog.starterHerd(startDay: state.clock.day))
        XCTAssertEqual(migrated.catShop, .empty)
    }

    private func firstCropOffer(day: Int) throws -> CatShopOffer {
        try XCTUnwrap(CatShopCatalog.offers(day: day, content: catalog).first {
            if case .crop = $0.kind { return true }
            return false
        })
    }
}
