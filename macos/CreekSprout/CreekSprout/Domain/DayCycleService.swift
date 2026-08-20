struct DayEndSummary: Equatable, Sendable {
    var previousDay: Int
    var newDay: Int
    var settlement: SettlementRecord
    var wasAlreadySettled: Bool
    var balance: Int
    var headline: String
}

struct DayCycleService {
    @discardableResult
    func settle(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog
    ) -> DayEndSummary {
        if clock.containsPauseReason(.sleep) {
            let settlementID = SettlementRecord.makeID(
                scenarioID: state.scenarioID,
                gameDay: max(state.clock.day - 1, 1)
            )
            let record = state.economy.settlementHistory.first { $0.settlementID == settlementID }
                ?? SettlementRecord(
                    settlementID: settlementID,
                    scenarioID: state.scenarioID,
                    gameDay: max(state.clock.day - 1, 1),
                    lines: [],
                    total: 0
                )
            return DayEndSummary(
                previousDay: record.gameDay,
                newDay: state.clock.day,
                settlement: record,
                wasAlreadySettled: true,
                balance: state.economy.balance,
                headline: headline(for: record, balance: state.economy.balance)
            )
        }

        clock.addPauseReason(.sleep)
        let previousDay = state.clock.day
        let settled = SettleShippingUseCase.settle(state: state, catalog: catalog)
        state = settled.state
        advanceCrops(state: &state, catalog: catalog)
        clock.beginNextDay(state: &state)
        // Deadline expiry and event offers run once the new day's clock is set.
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        let rainWatered = WeatherService.applyDayStart(state: &state, catalog: catalog)
        clock.removePauseReason(.sleep)
        return DayEndSummary(
            previousDay: previousDay,
            newDay: state.clock.day,
            settlement: settled.record,
            wasAlreadySettled: settled.wasAlreadySettled,
            balance: state.economy.balance,
            headline: headline(
                for: settled.record,
                balance: state.economy.balance,
                weather: catalog.scenario.weather(on: state.clock.day),
                rainWateredPlotCount: rainWatered
            )
        )
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

    private func headline(
        for record: SettlementRecord,
        balance: Int,
        weather: WeatherKind = .clear,
        rainWateredPlotCount: Int = 0
    ) -> String {
        let base: String
        if record.total == 0 {
            base = "日结完成，今日无出售。余额 \(balance)。"
        } else {
            let lines = record.lines.map(\.displayText).joined(separator: "；")
            base = "日结完成：\(lines)。余额 \(balance)。"
        }
        guard weather == .rain else {
            return base
        }
        return "\(base) 今天是雨天，露天地块已被雨水浇过（\(rainWateredPlotCount) 格）。"
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
