enum CraftingFailure: Equatable, Error, Sendable {
    case unknownRecipe
    case recipeLocked
    case insufficientMaterials
    case outputCapacityExceeded
}

struct CraftingService: Sendable {
    static func craft(
        state: GameState,
        recipeID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, CraftingFailure> {
        guard let recipe = catalog.recipe(id: recipeID) else {
            return .failure(.unknownRecipe)
        }
        if let required = recipe.requiredUnlockID,
           !state.watershed.unlockedNodes.contains(required) {
            return .failure(.recipeLocked)
        }
        var inventory = state.inventory
        for input in recipe.inputs {
            switch InventoryService.tryRemove(inventory, itemID: input.itemID, quantity: input.quantity) {
            case .failure:
                return .failure(.insufficientMaterials)
            case .success(let next):
                inventory = next
            }
        }
        for output in recipe.outputs {
            let stackLimit = catalog.stackLimit(for: output.itemID)
            switch InventoryService.tryAdd(
                inventory,
                capacity: state.inventoryCapacity,
                itemID: output.itemID,
                quantity: output.quantity,
                stackLimit: stackLimit
            ) {
            case .failure(.capacityExceeded):
                return .failure(.outputCapacityExceeded)
            case .failure:
                return .failure(.insufficientMaterials)
            case .success(let next):
                inventory = next
            }
        }
        var next = state
        next.inventory = inventory
        return .success(next)
    }
}
