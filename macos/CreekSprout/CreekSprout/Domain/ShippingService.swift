enum ShippingFailure: Equatable, Error, Sendable {
    case invalidParameters
    case itemNotSellable
    case insufficientQuantity
    case capacityExceeded
}

struct ShippingService: Sendable {
    static func deposit(
        state: GameState,
        itemID: String,
        quantity: Int,
        quality: ItemQuality = .normal,
        catalog: ContentCatalog
    ) -> Result<GameState, ShippingFailure> {
        guard quantity >= 1, ContentID.isValid(itemID), catalog.knowsItemID(itemID) else {
            return .failure(.invalidParameters)
        }
        let prices = EconomyCatalog(content: catalog)
        guard prices.isShippable(itemID: itemID),
              let unitPrice = prices.unitPrice(itemID: itemID, quality: quality),
              unitPrice > 0 else {
            return .failure(.itemNotSellable)
        }
        switch InventoryService.tryRemove(state.inventory, itemID: itemID, quantity: quantity) {
        case .failure(.insufficientQuantity), .failure(.invalidParameters):
            return .failure(.insufficientQuantity)
        case .failure(.capacityExceeded):
            return .failure(.capacityExceeded)
        case .success(let inventory):
            var next = state
            next.inventory = inventory
            let mergeKey = ShippingEntry.mergeKey(
                itemID: itemID,
                quality: quality,
                depositedDay: state.clock.day
            )
            if let index = next.economy.shipping.pendingEntries.firstIndex(where: {
                $0.itemID == itemID && $0.quality == quality && $0.depositedDay == state.clock.day
            }) {
                next.economy.shipping.pendingEntries[index].quantity += quantity
            } else {
                next.economy.shipping.pendingEntries.append(
                    ShippingEntry(
                        entryID: mergeKey,
                        itemID: itemID,
                        quantity: quantity,
                        quality: quality,
                        depositedDay: state.clock.day,
                        unitPriceSnapshot: unitPrice
                    )
                )
                next.economy.shipping.pendingEntries.sort { $0.entryID < $1.entryID }
            }
            return .success(next)
        }
    }

    static func retrieve(
        state: GameState,
        entryID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, ShippingFailure> {
        guard let entry = state.economy.shipping.entry(id: entryID) else {
            return .failure(.invalidParameters)
        }
        let stackLimit = catalog.stackLimit(for: entry.itemID)
        switch InventoryService.tryAdd(
            state.inventory,
            capacity: state.inventoryCapacity,
            itemID: entry.itemID,
            quantity: entry.quantity,
            stackLimit: stackLimit
        ) {
        case .failure(.capacityExceeded):
            return .failure(.capacityExceeded)
        case .failure:
            return .failure(.invalidParameters)
        case .success(let inventory):
            var next = state
            next.inventory = inventory
            next.economy.shipping.pendingEntries.removeAll { $0.entryID == entryID }
            return .success(next)
        }
    }

    static func retrieveAll(
        state: GameState,
        catalog: ContentCatalog
    ) -> Result<GameState, ShippingFailure> {
        var next = state
        for entry in state.economy.shipping.pendingEntries {
            switch retrieve(state: next, entryID: entry.entryID, catalog: catalog) {
            case .failure(let failure):
                return .failure(failure)
            case .success(let updated):
                next = updated
            }
        }
        return .success(next)
    }
}
