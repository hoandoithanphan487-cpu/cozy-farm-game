enum CatShopSupplyFailure: Equatable, Error, Sendable {
    case invalidRequest
    case duplicateRequest
    case offerUnavailable
    case dailyLimitExceeded
    case insufficientQuantity
    case animalNotFound
    case animalNotEligible
    case arithmeticOverflow
    case economyRejected
}

struct CatShopSupplyResult: Equatable, Sendable {
    var state: GameState
    var receipt: CatShopReceipt
}

struct CatShopSupplyService: Sendable {
    static func supplyCrop(
        state: GameState,
        offerID: String,
        itemID: String,
        quantity: Int,
        requestID: String,
        catalog: ContentCatalog
    ) -> Result<CatShopSupplyResult, CatShopSupplyFailure> {
        guard quantity >= 1, ContentID.isValid(requestID), ContentID.isValid(itemID) else {
            return .failure(.invalidRequest)
        }
        guard state.catShop.receipt(id: requestID) == nil else {
            return .failure(.duplicateRequest)
        }
        guard let offer = CatShopCatalog.offer(id: offerID, day: state.clock.day, content: catalog),
              case .crop(let offeredItemID) = offer.kind,
              offeredItemID == itemID else {
            return .failure(.offerUnavailable)
        }
        let used = state.catShop.suppliedQuantity(offerID: offer.id, day: state.clock.day)
        guard quantity <= offer.dailyLimit - used else {
            return .failure(.dailyLimitExceeded)
        }
        guard case .success(let inventory) = InventoryService.tryRemove(
            state.inventory,
            itemID: itemID,
            quantity: quantity
        ) else {
            return .failure(.insufficientQuantity)
        }
        guard StoryInventoryReservation.isPreserved(
            state: state,
            candidateInventory: inventory
        ) else {
            return .failure(.insufficientQuantity)
        }
        return commit(
            state: state,
            inventory: inventory,
            livestock: state.livestock,
            offer: offer,
            kind: .crop,
            subjectID: itemID,
            definitionID: itemID,
            displayName: offer.displayName,
            quantity: quantity,
            requestID: requestID,
            catalog: catalog
        )
    }

    static func supplyAnimal(
        state: GameState,
        offerID: String,
        animalID: String,
        requestID: String,
        catalog: ContentCatalog
    ) -> Result<CatShopSupplyResult, CatShopSupplyFailure> {
        guard ContentID.isValid(requestID), ContentID.isValid(animalID) else {
            return .failure(.invalidRequest)
        }
        guard state.catShop.receipt(id: requestID) == nil else {
            return .failure(.duplicateRequest)
        }
        guard let animalIndex = state.livestock.animals.firstIndex(where: { $0.instanceID == animalID }) else {
            return .failure(.animalNotFound)
        }
        let animal = state.livestock.animals[animalIndex]
        guard LivestockService.canSupply(animal, on: state.clock.day) else {
            return .failure(.animalNotEligible)
        }
        guard let offer = CatShopCatalog.offer(id: offerID, day: state.clock.day, content: catalog),
              case .animal(let offeredDefinitionID) = offer.kind,
              offeredDefinitionID == animal.definitionID else {
            return .failure(.offerUnavailable)
        }
        let used = state.catShop.suppliedQuantity(offerID: offer.id, day: state.clock.day)
        guard used < offer.dailyLimit else {
            return .failure(.dailyLimitExceeded)
        }
        var livestock = state.livestock
        livestock.animals.remove(at: animalIndex)
        livestock.sortAnimals()
        guard case .success(let committed) = commit(
            state: state,
            inventory: state.inventory,
            livestock: livestock,
            offer: offer,
            kind: .animal,
            subjectID: animal.instanceID,
            definitionID: animal.definitionID,
            displayName: animal.displayName,
            quantity: 1,
            requestID: requestID,
            catalog: catalog
        ) else {
            return .failure(.economyRejected)
        }
        // A fostered animal's only revenue is this final successful receipt.
        // Fulfil the matching order in the same candidate so reload/retry can
        // never double-settle the order.
        if let order = committed.state.fosterOrders.activeOrder,
           order.animalInstanceID == animal.instanceID {
            switch FosterSupplyService.fulfill(
                state: committed.state,
                issuanceID: order.issuanceID,
                receiptID: requestID,
                day: state.clock.day
            ) {
            case .success(let fulfilled):
                return .success(CatShopSupplyResult(state: fulfilled, receipt: committed.receipt))
            case .failure:
                return .failure(.economyRejected)
            }
        }
        return .success(committed)
    }

    private static func commit(
        state: GameState,
        inventory: [InventoryQuantity],
        livestock: LivestockState,
        offer: CatShopOffer,
        kind: CatShopReceiptKind,
        subjectID: String,
        definitionID: String,
        displayName: String,
        quantity: Int,
        requestID: String,
        catalog: ContentCatalog
    ) -> Result<CatShopSupplyResult, CatShopSupplyFailure> {
        let metricSourceID = "brookseed.story.metric.cat_shop.\(requestID)"
        // A claimed metric source without its corresponding domain receipt is
        // a corrupt/partial transaction. Do not commit the source half and
        // leave SaveValidation to reject the existing state.
        guard !state.storyMetrics.recordedSourceIDs.contains(metricSourceID) else {
            return .failure(.duplicateRequest)
        }
        let (total, overflow) = offer.unitPrice.multipliedReportingOverflow(by: quantity)
        guard !overflow, total > 0 else {
            return .failure(.arithmeticOverflow)
        }
        let transaction = CurrencyTransaction(
            reasonID: ContentID.catShopSupplyReason,
            amount: total,
            sourceRef: requestID,
            dayIndex: state.clock.day
        )
        guard case .success(let economy) = EconomyService.apply(state.economy, transaction: transaction) else {
            return .failure(.economyRejected)
        }
        let receipt = CatShopReceipt(
            receiptID: requestID,
            day: state.clock.day,
            offerID: offer.id,
            kind: kind,
            subjectID: subjectID,
            definitionID: definitionID,
            displayName: displayName,
            quantity: quantity,
            unitPrice: offer.unitPrice,
            total: total
        )
        var next = state
        next.inventory = inventory
        next.livestock = livestock
        next.economy = economy
        next.catShop.receipts.append(receipt)
        next.catShop.sortReceipts()
        if next.storyMetrics.claimSource(metricSourceID) {
            next.storyMetrics.catShopOpened = true
            next.storyMetrics.catShopReceiptIDs.append(requestID)
            next.storyMetrics.catShopOfferIDs.append(offer.id)
            next.storyMetrics.catShopBuyerIDs.append("brookseed.npc.cat_shop_black")
            next.storyMetrics.deliveryRecipientIDs.append("brookseed.npc.cat_shop_black")
            switch kind {
            case .crop:
                next.storyMetrics.catShopCropReceiptIDs.append(requestID)
                if let crop = catalog.crops.values.first(where: { $0.harvestItemID == definitionID }) {
                    next.storyMetrics.deliveriesByCropID[crop.id, default: 0] += quantity
                    next.storyMetrics.deliveryRecipientIDsByCropID[crop.id, default: []]
                        .append("brookseed.npc.cat_shop_black")
                }
                if let base = catalog.item(id: definitionID)?.baseSellPrice,
                   offer.unitPrice > base {
                    next.storyMetrics.catShopPremiumReceiptIDs.append(requestID)
                    next.storyMetrics.premiumBenefitDays.append(state.clock.day)
                }
            case .animal:
                next.storyMetrics.catShopAnimalReceiptIDs.append(requestID)
                if let animal = state.livestock.animals.first(where: { $0.instanceID == subjectID }) {
                    next.storyMetrics.animalSupplyHistory.append(
                        StoryAnimalSupplyHistory(
                            animalID: animal.instanceID,
                            definitionID: animal.definitionID,
                            ageDays: animal.ageDays,
                            careDays: animal.totalCareDays,
                            receiptID: requestID
                        )
                    )
                    if LivestockService.isAdult(animal) {
                        next.storyMetrics.animalsGrownToAdultIDs.append(animal.instanceID)
                    }
                }
            }
            if let q07 = state.storyCampaign.segment(.q07),
               q07.phase == .benefit,
               let causalOfferID = q07.benefitOfferID {
                next.storyMetrics.catShopReceiptOfferSourceIDs[requestID] = causalOfferID
            }
            next.storyMetrics.canonicalize()
        }
        return .success(CatShopSupplyResult(state: next, receipt: receipt))
    }
}
