enum IrrigationTier: String, Equatable, Codable, Sendable {
    case inactive
    case temporary
    case formal
}

struct IrrigationTierDefinition: Equatable, Sendable {
    var tier: IrrigationTier
    var maximumCoveredCells: Int
}

struct IrrigationDefinition: Equatable, Sendable {
    var temporary: IrrigationTierDefinition
    var formal: IrrigationTierDefinition

    /// Q01's temporary flow leaves meaningful manual work. The responsible
    /// aftermath upgrades the same restored canal to enough capacity for Q02's
    /// five-day / thirty-cell maturity contract without changing map topology.
    static let n027 = IrrigationDefinition(
        temporary: IrrigationTierDefinition(tier: .temporary, maximumCoveredCells: 4),
        formal: IrrigationTierDefinition(tier: .formal, maximumCoveredCells: 8)
    )
}

struct IrrigationService: Sendable {
    private static let maximumMetricCounter = 10_000_000

    var definition: IrrigationDefinition

    init(definition: IrrigationDefinition = .n027) {
        self.definition = definition
    }

    func activeTier(in state: GameState) -> IrrigationTier {
        guard state.watershed.isRestored,
              QuestService.status(of: ContentID.restoreOldCanalQuest, in: state) == .completed else {
            return .inactive
        }
        return state.storyCampaign.segment(.q01)?.phase == .resolved
            ? .formal
            : .temporary
    }

    /// Pure deterministic preview used by both the sleep confirmation/morning
    /// report and the committing pipeline. Dictionary insertion order never
    /// changes which real growing cells are selected.
    func previewOvernightCoverage(
        state: GameState,
        catalog: ContentCatalog
    ) -> CropCoverageSummary {
        let tier = activeTier(in: state)
        guard tier != .inactive else {
            return .empty(day: state.clock.day)
        }
        let tierDefinition = tier == .formal ? definition.formal : definition.temporary
        guard tierDefinition.tier == tier,
              tierDefinition.maximumCoveredCells > 0 else {
            return .empty(day: state.clock.day)
        }
        let sourceID = metricSourceID(day: state.clock.day, tier: tier)
        guard !state.storyMetrics.recordedSourceIDs.contains(sourceID),
              state.storyMetrics.recordedSourceIDs.count < Self.maximumMetricCounter else {
            return .empty(day: state.clock.day)
        }

        let positions = state.farmCells
            .filter { _, cell in
                cell.isGrowingCrop
                    && !cell.wateredToday
                    && catalog.crop(id: cell.cropID) != nil
            }
            .map(\.key)
            .sorted(by: CropCareService.positionOrder)
            .prefix(tierDefinition.maximumCoveredCells)
        let source: CropCoverageSource = tier == .formal ? .formalCanal : .temporaryCanal
        return CropCoverageSummary(
            day: state.clock.day,
            records: positions.map { CropCoverageRecord(position: $0, source: source) }
        )
    }

    /// Commits coverage and its causal StoryMetrics receipt to the same
    /// candidate. If the append-only metric cannot be claimed, no crop is
    /// watered and the caller receives an empty result.
    @discardableResult
    func applyOvernightCoverage(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> CropCoverageSummary {
        let tier = activeTier(in: state)
        let preview = previewOvernightCoverage(state: state, catalog: catalog)
        guard tier != .inactive, preview.count > 0 else { return preview }

        let sourceID = metricSourceID(day: state.clock.day, tier: tier)
        var metrics = state.storyMetrics
        let previousCellDays = metrics.automaticWaterCellDays
        let (expectedCellDays, overflow) = previousCellDays.addingReportingOverflow(preview.count)
        guard !overflow, expectedCellDays <= Self.maximumMetricCounter else {
            return .empty(day: state.clock.day)
        }
        StoryMetricsRecorder.recordAutomaticWater(
            metrics: &metrics,
            sourceID: sourceID,
            day: state.clock.day,
            cellDays: preview.count,
            isFormal: tier == .formal
        )
        guard metrics.recordedSourceIDs.contains(sourceID),
              metrics.automaticWaterCellDays == expectedCellDays else {
            return .empty(day: state.clock.day)
        }

        var candidate = state
        let applied = CropCareService.applyCoverage(to: &candidate, summary: preview)
        guard applied.count == preview.count else {
            return .empty(day: state.clock.day)
        }
        candidate.storyMetrics = metrics
        state = candidate
        return applied
    }

    private func metricSourceID(day: Int, tier: IrrigationTier) -> String {
        "brookseed.story.metric.irrigation.\(tier.rawValue).day_\(day)"
    }
}
