enum ProcessingFailure: Equatable, Error, Sendable {
    case unknownRecipe
    case recipeLocked
    case notProcessingRecipe
    case stationMissing
    case notAdjacent
    case insufficientStamina
    case insufficientMaterials
    case outputCapacityExceeded
}

/// Instant crop processing at a placed station. Reuses `CraftingService.craft`
/// for inventory atomicity; adds station, adjacency, and stamina checks.
/// Failures never mutate the caller's state and never consume materials.
struct ProcessingService: Sendable {
    static func process(
        state: GameState,
        recipeID: String,
        catalog: ContentCatalog
    ) -> Result<GameState, ProcessingFailure> {
        guard let recipe = catalog.recipe(id: recipeID) else {
            return .failure(.unknownRecipe)
        }
        guard recipe.isProcessingRecipe, let stationID = recipe.requiredPlacedObjectID else {
            return .failure(.notProcessingRecipe)
        }
        if let required = recipe.requiredUnlockID,
           !state.watershed.unlockedNodes.contains(required) {
            return .failure(.recipeLocked)
        }
        guard hasPlacedStation(stationID, in: state) else {
            return .failure(.stationMissing)
        }
        guard isAdjacentToStation(stationID, state: state, catalog: catalog) else {
            return .failure(.notAdjacent)
        }
        let staminaCost = max(0, recipe.staminaCost)
        guard state.stamina >= staminaCost else {
            return .failure(.insufficientStamina)
        }

        switch CraftingService.craft(state: state, recipeID: recipeID, catalog: catalog) {
        case .failure(.unknownRecipe):
            return .failure(.unknownRecipe)
        case .failure(.recipeLocked):
            return .failure(.recipeLocked)
        case .failure(.insufficientMaterials):
            return .failure(.insufficientMaterials)
        case .failure(.outputCapacityExceeded):
            return .failure(.outputCapacityExceeded)
        case .success(let crafted):
            var next = crafted
            next.stamina -= staminaCost
            return .success(next)
        }
    }

    static func hasPlacedStation(_ definitionID: String, in state: GameState) -> Bool {
        state.placedObjects.contains { $0.definitionID == definitionID }
    }

    static func isAdjacentToStation(
        _ definitionID: String,
        state: GameState,
        catalog: ContentCatalog
    ) -> Bool {
        let cells = stationCells(definitionID, state: state, catalog: catalog)
        if cells.contains(state.position) {
            return true
        }
        let target = state.currentMapID == ContentID.farmHomestead
            ? state.targetCell
            : state.targetCell(in: catalog.map(id: state.currentMapID) ?? WorldCatalog.farmHomestead)
        return cells.contains(target)
    }

    static func stationCells(
        _ definitionID: String,
        state: GameState,
        catalog: ContentCatalog
    ) -> Set<GridPosition> {
        var cells = Set<GridPosition>()
        for object in state.placedObjects where object.definitionID == definitionID {
            PlacementService.absoluteFootprint(
                definitionID: object.definitionID,
                origin: object.origin,
                facing: object.facing,
                catalog: catalog
            ).forEach { cells.insert($0) }
        }
        return cells
    }
}
