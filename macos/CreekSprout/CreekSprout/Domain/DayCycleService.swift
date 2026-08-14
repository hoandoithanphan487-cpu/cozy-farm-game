struct DayCycleService {
    func settle(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog
    ) {
        clock.addPauseReason(.sleep)
        advanceCrops(state: &state, catalog: catalog)
        clock.beginNextDay(state: &state)
        clock.removePauseReason(.sleep)
    }

    func advanceCrops(state: inout GameState, catalog: ContentCatalog) {
        for coordinate in state.farmCells.keys {
            var cell = state.farmCells[coordinate] ?? FarmCell()
            if let crop = catalog.crop(id: cell.cropID), cell.wateredToday, !cell.readyToHarvest {
                cell.stageProgressDays += 1
                cell.cropStage = Self.stage(for: crop, wateredDays: cell.stageProgressDays)
                cell.readyToHarvest = cell.cropStage >= crop.matureStageIndex
            }
            cell.wateredToday = false
            state.farmCells[coordinate] = cell
        }
    }

    private static func stage(for crop: CropDefinition, wateredDays: Int) -> Int {
        var stage = 0
        var cumulativeDays = 0
        for (index, days) in crop.stageDays.enumerated() {
            cumulativeDays += days
            if wateredDays >= cumulativeDays {
                stage = min(index + 1, crop.matureStageIndex)
            }
        }
        return stage
    }
}
