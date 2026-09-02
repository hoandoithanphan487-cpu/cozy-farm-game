struct FarmActionOutcome: Equatable, Sendable {
    var isSuccess: Bool
    var reason: String
    var event: String?

    static func success(reason: String, event: String) -> FarmActionOutcome {
        FarmActionOutcome(isSuccess: true, reason: reason, event: event)
    }

    static func failure(_ reason: String) -> FarmActionOutcome {
        FarmActionOutcome(isSuccess: false, reason: reason, event: nil)
    }
}

/// Pure transaction result used by Story/finale and save-before-commit flows.
/// A failed outcome never carries a candidate state.
struct FarmActionCandidate: Equatable, Sendable {
    var outcome: FarmActionOutcome
    var state: GameState?
}

/// Cells that accept farming tools. The legacy 10 x 6 rectangle remains the
/// only placement/save footprint for furniture; R20 adds one deliberately
/// narrow rear field without widening that older contract.
enum FarmCultivationCatalog {
    static let rearCultivableCells: Set<GridPosition> = [
        GridPosition(x: 7, y: 12),
        GridPosition(x: 8, y: 12),
        GridPosition(x: 7, y: 13),
        GridPosition(x: 8, y: 13),
    ]

    static func contains(_ position: GridPosition) -> Bool {
        position.isInsideFarm || rearCultivableCells.contains(position)
    }
}

struct FarmActionService: Sendable {
    func preview(
        state: GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog,
        seedItemID: String = ContentID.mistRadishSeed
    ) -> FarmActionOutcome {
        candidate(
            state: state,
            target: target,
            tool: tool,
            catalog: catalog,
            seedItemID: seedItemID
        ).outcome
    }

    @discardableResult
    func apply(
        to state: inout GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog,
        seedItemID: String = ContentID.mistRadishSeed
    ) -> FarmActionOutcome {
        let prepared = candidate(
            state: state,
            target: target,
            tool: tool,
            catalog: catalog,
            seedItemID: seedItemID
        )
        guard prepared.outcome.isSuccess, let next = prepared.state else {
            return prepared.outcome
        }
        state = next
        return prepared.outcome
    }

    func candidate(
        state: GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog,
        seedItemID: String = ContentID.mistRadishSeed
    ) -> FarmActionCandidate {
        guard FarmCultivationCatalog.contains(target) else {
            return FarmActionCandidate(outcome: .failure("目标格不可达。"), state: nil)
        }
        if state.currentMapID != ContentID.farmHomestead {
            return FarmActionCandidate(outcome: .failure("只能在农场耕作。"), state: nil)
        }
        if state.stamina < tool.staminaCost {
            return FarmActionCandidate(outcome: .failure("体力不足，不能继续劳动。"), state: nil)
        }
        var next = state
        var cell = next.farmCells[target] ?? FarmCell()
        switch tool {
        case .hoe:
            if cell.hasCrop, cell.cropCondition == .withered {
                cell.cropID = ""
                cell.cropStage = 0
                cell.stageProgressDays = 0
                cell.plantedDay = 0
                cell.readyToHarvest = false
                cell.wateredToday = false
                cell.dryStreak = 0
                cell.cropCondition = .healthy
                cell.prepared = true
                next.farmCells[target] = cell
                next.stamina -= tool.staminaCost
                StoryMetricsRecorder.recordTilling(
                    metrics: &next.storyMetrics,
                    sourceID: metricSourceID(state: next, target: target, action: "clear_withered"),
                    clearedWithered: true
                )
                return FarmActionCandidate(
                    outcome: .success(reason: "枯萎残株已清理，土地可以重新播种。", event: "cleared_withered"),
                    state: next
                )
            }
            if cell.prepared || cell.hasCrop {
                return FarmActionCandidate(outcome: .failure("这块地已经处理过了。"), state: nil)
            }
            cell.prepared = true
            next.farmCells[target] = cell
            next.stamina -= tool.staminaCost
            StoryMetricsRecorder.recordTilling(
                metrics: &next.storyMetrics,
                sourceID: metricSourceID(state: next, target: target, action: "till"),
                clearedWithered: false
            )
            return FarmActionCandidate(outcome: .success(reason: "翻土完成。", event: "tilled"), state: next)
        case .seed:
            if !cell.prepared || cell.hasCrop {
                return FarmActionCandidate(outcome: .failure("只能在空的已翻土地块播种。"), state: nil)
            }
            guard let crop = catalog.crop(seedItemID: seedItemID) else {
                return FarmActionCandidate(outcome: .failure("没有可用的种子定义。"), state: nil)
            }
            switch InventoryService.tryRemove(next.inventory, itemID: crop.seedItemID, quantity: 1) {
            case .failure:
                return FarmActionCandidate(outcome: .failure("所需物品不足。"), state: nil)
            case .success(let inventory):
                guard StoryInventoryReservation.isPreserved(
                    state: next,
                    candidateInventory: inventory
                ) else {
                    return FarmActionCandidate(outcome: .failure("这批物资已为百桌宴预留。"), state: nil)
                }
                cell.cropID = crop.id
                cell.cropStage = 0
                cell.stageProgressDays = 0
                cell.plantedDay = next.clock.day
                cell.readyToHarvest = false
                cell.dryStreak = 0
                cell.cropCondition = .healthy
                next.farmCells[target] = cell
                next.inventory = inventory
                next.stamina -= tool.staminaCost
                StoryMetricsRecorder.recordPlant(
                    metrics: &next.storyMetrics,
                    sourceID: metricSourceID(state: next, target: target, action: "plant"),
                    cropID: crop.id,
                    growingCropCount: next.farmCells.values.filter(\.isGrowingCrop).count,
                    usedSeedBenefit: isSeedBenefitActive(next.storyCampaign)
                )
                return FarmActionCandidate(outcome: .success(reason: "播种完成。", event: "planted"), state: next)
            }
        case .water:
            if cell.cropCondition == .withered {
                return FarmActionCandidate(outcome: .failure("这株作物已经枯萎，请先清理残株。"), state: nil)
            }
            if !cell.hasCrop || cell.wateredToday {
                return FarmActionCandidate(outcome: .failure("这里没有需要浇水的作物。"), state: nil)
            }
            cell.wateredToday = true
            cell.dryStreak = 0
            cell.cropCondition = .healthy
            next.farmCells[target] = cell
            next.stamina -= tool.staminaCost
            StoryMetricsRecorder.recordManualWater(
                metrics: &next.storyMetrics,
                sourceID: metricSourceID(state: next, target: target, action: "water"),
                cellDays: 1
            )
            return FarmActionCandidate(outcome: .success(reason: "浇水完成。", event: "watered"), state: next)
        case .harvest:
            guard cell.readyToHarvest, let crop = catalog.crop(id: cell.cropID) else {
                return FarmActionCandidate(outcome: .failure("作物尚未成熟。"), state: nil)
            }
            let stackLimit = catalog.stackLimit(for: crop.harvestItemID)
            switch InventoryService.tryAdd(
                next.inventory,
                capacity: next.inventoryCapacity,
                itemID: crop.harvestItemID,
                quantity: crop.yield,
                stackLimit: stackLimit
            ) {
            case .failure:
                return FarmActionCandidate(outcome: .failure("背包已满，物品留在原处。"), state: nil)
            case .success(let inventory):
                cell.cropID = ""
                cell.cropStage = 0
                cell.stageProgressDays = 0
                cell.plantedDay = 0
                cell.readyToHarvest = false
                cell.wateredToday = false
                cell.dryStreak = 0
                cell.cropCondition = .healthy
                next.farmCells[target] = cell
                next.inventory = inventory
                next.stamina -= tool.staminaCost
                StoryMetricsRecorder.recordHarvest(
                    metrics: &next.storyMetrics,
                    sourceID: metricSourceID(state: next, target: target, action: "harvest"),
                    cropID: crop.id
                )
                return FarmActionCandidate(outcome: .success(reason: "收获完成，已放入背包。", event: "harvested"), state: next)
            }
        }
    }

    private func metricSourceID(
        state: GameState,
        target: GridPosition,
        action: String
    ) -> String {
        let ordinal = state.storyMetrics.recordedSourceIDs.count + 1
        return "brookseed.story.metric.farm.\(action).day_\(state.clock.day).cell_\(target.x)_\(target.y).event_\(ordinal)"
    }

    private func isSeedBenefitActive(_ campaign: StoryCampaignState) -> Bool {
        guard let phase = campaign.segment(.q04)?.phase else { return false }
        return phase != .locked
    }
}
