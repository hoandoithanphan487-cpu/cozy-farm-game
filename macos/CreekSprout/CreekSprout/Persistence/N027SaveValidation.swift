extension SaveValidation {
    static func validateN027(
        _ state: GameState,
        catalog: ContentCatalog = .vs0
    ) throws {
        try StoryStateValidation.validate(
            state: state,
            catalog: catalog
        )
        if let lease = state.storyCampaign.frontstageLease {
            switch lease.owner {
            case .story, .journey, .finale:
                guard state.community.activeEvents.isEmpty else {
                    throw SaveStoreError.invalidContents
                }
            case .communityEvent:
                guard state.community.activeEvents.contains(where: {
                    $0.instanceID == lease.resourceID
                }) else {
                    throw SaveStoreError.invalidContents
                }
            case .forcedTutorial, .resumedSession, .hint:
                break
            }
        }
        for cell in state.farmCells.values {
            guard (0...3).contains(cell.dryStreak) else {
                throw SaveStoreError.invalidContents
            }
            if !cell.hasCrop {
                guard cell.dryStreak == 0, cell.cropCondition == .healthy else {
                    throw SaveStoreError.invalidContents
                }
                continue
            }
            if cell.readyToHarvest {
                guard cell.dryStreak == 0, cell.cropCondition == .healthy else {
                    throw SaveStoreError.invalidContents
                }
                continue
            }
            switch cell.cropCondition {
            case .healthy:
                guard cell.dryStreak == 0 else { throw SaveStoreError.invalidContents }
            case .thirsty:
                guard cell.dryStreak == 1 else { throw SaveStoreError.invalidContents }
            case .wilted:
                guard cell.dryStreak == 2 else { throw SaveStoreError.invalidContents }
            case .withered:
                guard cell.dryStreak == 3,
                      !cell.readyToHarvest,
                      !cell.wateredToday else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        if let mission = state.storyCampaign.mission {
            guard mission.coveredCropCellIDs.allSatisfy({
                FarmCellIdentity.position(for: $0) != nil
            }) else {
                throw SaveStoreError.invalidContents
            }
        }
        try validateFosterOrders(state)
    }

    /// Foster supply ledger invariants: unique sorted issuances, at most one
    /// active order, conversions bounded and permanent, fulfilment only via
    /// real cat-shop receipts.
    private static func validateFosterOrders(_ state: GameState) throws {
        let foster = state.fosterOrders
        let orders = foster.orders
        guard orders.map(\.issuanceID) == orders.map(\.issuanceID).sorted(),
              Set(orders.map(\.issuanceID)).count == orders.count,
              Set(orders.map(\.issuanceID)) == Set(state.storyMetrics.fosterIssuanceIDs),
              orders.allSatisfy({ order in
                  ContentID.isValid(order.issuanceID)
                      && order.issuanceID.hasPrefix("brookseed.story.foster.issue.")
                      && ContentID.isValid(order.campaignID)
                      && order.campaignID == state.campaignID
                      && ContentID.isValid(order.animalKindID)
                      && LivestockCatalog.definition(id: order.animalKindID) != nil
                      && (1...state.clock.day).contains(order.issuedDay)
                      && (order.acceptedDay.map { (1...state.clock.day).contains($0) } ?? true)
                      && (order.closedDay.map { (1...state.clock.day).contains($0) } ?? true)
                      && (order.fulfillmentReceiptID.map(ContentID.isValid) ?? true)
                      && (order.animalInstanceID.map(ContentID.isValid) ?? true)
                      && order.status == .active
                          ? order.acceptedDay == nil || order.closedDay == nil
                          : order.closedDay != nil
              }),
              foster.orders.filter({ $0.status == .active }).count <= 1,
              foster.convertedAnimalIDs == Array(Set(foster.convertedAnimalIDs)).sorted(),
              foster.convertedAnimalIDs.allSatisfy(ContentID.isValid),
              foster.partnerConversionUsed == !foster.convertedAnimalIDs.isEmpty,
              foster.convertedAnimalIDs.allSatisfy({ animalID in
                  state.livestock.animals.contains(where: {
                      $0.instanceID == animalID && $0.isProtected
                  })
              }) else {
            throw SaveStoreError.invalidContents
        }
        for order in orders where order.status == .fulfilled {
            guard let receiptID = order.fulfillmentReceiptID,
                  let animalID = order.animalInstanceID,
                  state.catShop.receipt(id: receiptID)?.kind == .animal,
                  state.storyMetrics.catShopAnimalReceiptIDs.contains(receiptID),
                  state.storyMetrics.animalSupplyHistory.contains(where: {
                      $0.animalID == animalID && $0.receiptID == receiptID
                  }) else {
                throw SaveStoreError.invalidContents
            }
        }
        for order in orders where order.status == .convertedToPartner {
            guard let animalID = order.animalInstanceID,
                  foster.convertedAnimalIDs.contains(animalID) else {
                throw SaveStoreError.invalidContents
            }
        }
        for order in orders where order.status == .cancelled {
            guard order.animalInstanceID == nil else {
                throw SaveStoreError.invalidContents
            }
        }
    }
}
