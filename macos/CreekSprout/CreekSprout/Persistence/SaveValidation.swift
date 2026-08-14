enum SaveValidation {
    static let maxQuantity = 99
    static let maxCapacity = 999
    static let maxStamina = 100
    static let maxMinute = 1439

    static func validate(_ state: GameState, catalog: ContentCatalog) throws {
        guard state.position.isInsideFarm else {
            throw SaveStoreError.invalidContents
        }
        guard (0...Self.maxStamina).contains(state.stamina) else {
            throw SaveStoreError.invalidContents
        }
        guard (1...Self.maxCapacity).contains(state.inventoryCapacity) else {
            throw SaveStoreError.invalidContents
        }
        guard state.clock.day >= 1, (0...Self.maxMinute).contains(state.clock.minute) else {
            throw SaveStoreError.invalidContents
        }
        guard state.inventory.count <= state.inventoryCapacity else {
            throw SaveStoreError.invalidContents
        }
        for stack in state.inventory {
            guard ContentID.isValid(stack.itemID), catalog.knowsItemID(stack.itemID) else {
                throw SaveStoreError.invalidContents
            }
            let stackLimit = catalog.stackLimit(for: stack.itemID)
            guard (1...stackLimit).contains(stack.quantity) else {
                throw SaveStoreError.invalidContents
            }
        }
        for (coordinate, cell) in state.farmCells {
            guard coordinate.isInsideFarm else {
                throw SaveStoreError.invalidContents
            }
            guard cell.fertility >= 0, cell.cropStage >= 0, cell.stageProgressDays >= 0, cell.plantedDay >= 0 else {
                throw SaveStoreError.invalidContents
            }
            if cell.cropID.isEmpty {
                continue
            }
            guard ContentID.isValid(cell.cropID), catalog.knowsCropID(cell.cropID) else {
                throw SaveStoreError.invalidContents
            }
        }
    }
}
