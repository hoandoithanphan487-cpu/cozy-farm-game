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

struct FarmActionService: Sendable {
    func preview(
        state: GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog
    ) -> FarmActionOutcome {
        prepare(state: state, target: target, tool: tool, catalog: catalog).outcome
    }

    @discardableResult
    func apply(
        to state: inout GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog
    ) -> FarmActionOutcome {
        let prepared = prepare(state: state, target: target, tool: tool, catalog: catalog)
        guard prepared.outcome.isSuccess, let next = prepared.state else {
            return prepared.outcome
        }
        state = next
        return prepared.outcome
    }

    private struct Preparation {
        var outcome: FarmActionOutcome
        var state: GameState?
    }

    private func prepare(
        state: GameState,
        target: GridPosition,
        tool: FarmTool,
        catalog: ContentCatalog
    ) -> Preparation {
        guard target.isInsideFarm else {
            return Preparation(outcome: .failure("目标格不可达。"), state: nil)
        }
        if state.currentMapID != ContentID.farmHomestead {
            return Preparation(outcome: .failure("只能在农场耕作。"), state: nil)
        }
        if state.stamina < tool.staminaCost {
            return Preparation(outcome: .failure("体力不足，不能继续劳动。"), state: nil)
        }
        var next = state
        var cell = next.farmCells[target] ?? FarmCell()
        switch tool {
        case .hoe:
            if cell.prepared || cell.hasCrop {
                return Preparation(outcome: .failure("这块地已经处理过了。"), state: nil)
            }
            cell.prepared = true
            next.farmCells[target] = cell
            next.stamina -= tool.staminaCost
            return Preparation(outcome: .success(reason: "翻土完成。", event: "tilled"), state: next)
        case .seed:
            if !cell.prepared || cell.hasCrop {
                return Preparation(outcome: .failure("只能在空的已翻土地块播种。"), state: nil)
            }
            guard let crop = catalog.crop(seedItemID: ContentID.mistRadishSeed) else {
                return Preparation(outcome: .failure("没有可用的种子定义。"), state: nil)
            }
            switch InventoryService.tryRemove(next.inventory, itemID: crop.seedItemID, quantity: 1) {
            case .failure:
                return Preparation(outcome: .failure("所需物品不足。"), state: nil)
            case .success(let inventory):
                cell.cropID = crop.id
                cell.cropStage = 0
                cell.stageProgressDays = 0
                cell.plantedDay = next.clock.day
                cell.readyToHarvest = false
                next.farmCells[target] = cell
                next.inventory = inventory
                next.stamina -= tool.staminaCost
                return Preparation(outcome: .success(reason: "播种完成。", event: "planted"), state: next)
            }
        case .water:
            if !cell.hasCrop || cell.wateredToday {
                return Preparation(outcome: .failure("这里没有需要浇水的作物。"), state: nil)
            }
            cell.wateredToday = true
            next.farmCells[target] = cell
            next.stamina -= tool.staminaCost
            return Preparation(outcome: .success(reason: "浇水完成。", event: "watered"), state: next)
        case .harvest:
            guard cell.readyToHarvest, let crop = catalog.crop(id: cell.cropID) else {
                return Preparation(outcome: .failure("作物尚未成熟。"), state: nil)
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
                return Preparation(outcome: .failure("背包已满，物品留在原处。"), state: nil)
            case .success(let inventory):
                cell.cropID = ""
                cell.cropStage = 0
                cell.stageProgressDays = 0
                cell.plantedDay = 0
                cell.readyToHarvest = false
                cell.wateredToday = false
                next.farmCells[target] = cell
                next.inventory = inventory
                next.stamina -= tool.staminaCost
                return Preparation(outcome: .success(reason: "收获完成，已放入背包。", event: "harvested"), state: next)
            }
        }
    }
}
