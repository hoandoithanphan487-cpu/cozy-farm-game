struct DayEndSummary: Equatable, Sendable {
    var previousDay: Int
    var newDay: Int
    var settlement: SettlementRecord
    var wasAlreadySettled: Bool
    var balance: Int
    var headline: String
}

enum SleepPipelineStage: String, CaseIterable, Sendable {
    case shippingSettled = "shipping_settled"
    case overnightCoverageApplied = "overnight_coverage_applied"
    case cropsAdvanced = "crops_advanced"
    case livestockSettled = "livestock_settled"
    case storyMetricsRecorded = "story_metrics_recorded"
    case clockAdvanced = "clock_advanced"
    case communityAdvanced = "community_advanced"
    case storyAdvanced = "story_advanced"
    case validated
    case saved
}

struct DayCycleService {
    @discardableResult
    func settle(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog
    ) -> DayEndSummary {
        // Compatibility entry point for existing domain tests and debug tools.
        // Production sleep uses the throwing pipeline in SleepUseCase.
        try! settleTransaction(
            state: &state,
            clock: clock,
            catalog: catalog,
            stageObserver: nil
        )
    }

    @discardableResult
    func settleTransaction(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog,
        stageObserver: ((SleepPipelineStage, GameState) throws -> Void)?
    ) throws -> DayEndSummary {
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
        try stageObserver?(.shippingSettled, state)

        // Manual/rain coverage is already represented by `wateredToday`.
        // Q08 community care and deterministic canal coverage are resolved on
        // this same candidate before pressure/growth, and canal metrics commit
        // with the source transaction.
        let communityCoverage = CropCareService.previewCommunityCoverage(
            in: state,
            catalog: catalog
        )
        CropCareService.applyCoverage(to: &state, summary: communityCoverage)
        IrrigationService().applyOvernightCoverage(state: &state, catalog: catalog)
        try stageObserver?(.overnightCoverageApplied, state)
        advanceCrops(state: &state, catalog: catalog)
        try stageObserver?(.cropsAdvanced, state)
        LivestockService.advanceAfterDay(state: &state)
        try stageObserver?(.livestockSettled, state)
        StoryMetricsRecorder.recordSettledDay(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.sleep.day_\(previousDay)",
            day: previousDay,
            campaign: state.storyCampaign,
            hadMajorConflict: !state.community.activeEvents.isEmpty
                || state.storyCampaign.segments.contains(where: { $0.phase == .eruption })
        )
        StoryMetricsRecorder.recordDailySnapshot(
            metrics: &state.storyMetrics,
            sourceID: "brookseed.story.metric.crop_snapshot.day_\(previousDay)",
            day: previousDay,
            growingCropCount: state.farmCells.values.filter(\.isGrowingCrop).count
        )
        try stageObserver?(.storyMetricsRecorded, state)
        clock.beginNextDay(state: &state)
        try stageObserver?(.clockAdvanced, state)
        // Deadline expiry and event offers run once the new day's clock is set.
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        try stageObserver?(.communityAdvanced, state)
        let rainWatered = WeatherService.applyDayStart(state: &state, catalog: catalog)
        if rainWatered > 0 {
            let rainCoverage = CropCareService.currentWateredCoverage(
                in: state,
                source: .rain,
                catalog: catalog
            )
            CropCareService.applyCoverage(to: &state, summary: rainCoverage)
        }
        advanceStoryAtDayStart(state: &state)
        try stageObserver?(.storyAdvanced, state)
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

    private func advanceStoryAtDayStart(state: inout GameState) {
        for arcID in StoryArcID.allCases where arcID.sequence <= StoryArcID.q08.sequence {
            guard state.storyCampaign.segment(arcID)?.phase == .locked else { continue }
            if case .success(let candidate) = StoryDirector.unlockEligibleBenefit(
                state: state,
                arcID: arcID
            ) {
                state = candidate
            }
        }
    }

    func advanceCrops(state: inout GameState, catalog: ContentCatalog) {
        CropCareService.settleCrops(state: &state, catalog: catalog)
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

}
