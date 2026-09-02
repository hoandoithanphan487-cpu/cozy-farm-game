struct CommandFeedback: Equatable, Sendable {
    var isSuccess: Bool
    var message: String

    static func success(_ message: String) -> CommandFeedback {
        CommandFeedback(isSuccess: true, message: message)
    }

    static func failure(_ message: String) -> CommandFeedback {
        CommandFeedback(isSuccess: false, message: message)
    }
}

/// Domain command facade for M2 shipping, crafting, placement and sleep.
/// Presentation layers should call these methods and display `message`; they
/// must not copy price, settlement, or material rules.
struct M2CommandService: Sendable {
    var catalog: ContentCatalog

    func depositShipping(
        state: inout GameState,
        itemID: String,
        quantity: Int,
        quality: ItemQuality = .normal
    ) -> CommandFeedback {
        let before = state
        switch ShippingService.deposit(
            state: state,
            itemID: itemID,
            quantity: quantity,
            quality: quality,
            catalog: catalog
        ) {
        case .failure:
            state = before
            return .failure("投入失败，背包与出售箱均未改变。")
        case .success(let next):
            state = next
            let name = catalog.displayName(forItemID: itemID)
            return .success("已投入出售箱：\(name)×\(quantity)。")
        }
    }

    func retrieveShipping(state: inout GameState, entryID: String) -> CommandFeedback {
        let before = state
        switch ShippingService.retrieve(state: state, entryID: entryID, catalog: catalog) {
        case .failure(.capacityExceeded):
            state = before
            return .failure("背包空间不足，无法取回。")
        case .failure:
            state = before
            return .failure("取回失败，出售箱内容未改变。")
        case .success(let next):
            let name = catalog.displayName(forItemID: before.economy.shipping.entry(id: entryID)?.itemID ?? entryID)
            let quantity = before.economy.shipping.entry(id: entryID)?.quantity ?? 0
            state = next
            return .success("已取回：\(name)×\(quantity)。")
        }
    }

    func retrieveAllShipping(state: inout GameState) -> CommandFeedback {
        let before = state
        switch ShippingService.retrieveAll(state: state, catalog: catalog) {
        case .failure(.capacityExceeded):
            state = before
            return .failure("背包空间不足，无法取回。")
        case .failure:
            state = before
            return .failure("取回失败，出售箱内容未改变。")
        case .success(let next):
            let quantity = before.economy.shipping.pendingQuantity
            state = next
            return .success("已取回待结算物品×\(quantity)。")
        }
    }

    func craft(state: inout GameState, recipeID: String) -> CommandFeedback {
        let before = state
        if catalog.recipe(id: recipeID)?.isProcessingRecipe == true {
            let stationName = catalog.displayName(
                forNameKey: catalog.placedObject(id: catalog.recipe(id: recipeID)?.requiredPlacedObjectID ?? "")?.nameKey
                    ?? "item.woodhoney_hearth"
            )
            return .failure("请对准\(stationName)进行加工。")
        }
        switch CraftingService.craft(state: state, recipeID: recipeID, catalog: catalog) {
        case .failure(.unknownRecipe):
            state = before
            return .failure("未知配方，背包未改变。")
        case .failure(.recipeLocked):
            state = before
            return .failure("配方尚未解锁，无法制作。")
        case .failure(.insufficientMaterials):
            state = before
            return .failure("材料不足，无法制作。")
        case .failure(.outputCapacityExceeded):
            state = before
            return .failure("背包无法存放产物，制作已回滚。")
        case .success(let next):
            state = next
            let recipeName = catalog.displayName(forNameKey: catalog.recipe(id: recipeID)?.nameKey ?? recipeID)
            return .success("制作完成：\(recipeName)。")
        }
    }

    func process(state: inout GameState, recipeID: String) -> CommandFeedback {
        let before = state
        switch ProcessingService.process(state: state, recipeID: recipeID, catalog: catalog) {
        case .failure(.unknownRecipe):
            state = before
            return .failure("❌ 未知配方，无法加工。")
        case .failure(.recipeLocked):
            state = before
            return .failure("❌ 配方尚未解锁，无法加工。")
        case .failure(.notProcessingRecipe):
            state = before
            return .failure("❌ 该配方不能在加工站使用。")
        case .failure(.stationMissing):
            state = before
            return .failure("❌ 尚未放置加工站，无法加工。")
        case .failure(.notAdjacent):
            state = before
            return .failure("❌ 请对准加工站再加工。")
        case .failure(.insufficientStamina):
            state = before
            return .failure("❌ 体力不足，无法加工。")
        case .failure(.insufficientMaterials):
            state = before
            return .failure("❌ 原料不足，无法加工。")
        case .failure(.outputCapacityExceeded):
            state = before
            return .failure("❌ 背包已满，无法加工。")
        case .success(let next):
            state = next
            let recipe = catalog.recipe(id: recipeID)
            let recipeName = catalog.displayName(forNameKey: recipe?.nameKey ?? recipeID)
            let input = recipe?.inputs.first
            let output = recipe?.outputs.first
            let inputName = catalog.displayName(forItemID: input?.itemID ?? "")
            let outputName = catalog.displayName(forItemID: output?.itemID ?? "")
            let stamina = recipe?.staminaCost ?? ContentID.processingStaminaCost
            return .success(
                "✅ 加工完成：\(recipeName)。\(inputName)−\(input?.quantity ?? 1)，\(outputName)+\(output?.quantity ?? 1)，体力 −\(stamina)。"
            )
        }
    }

    func previewPlacement(
        state: GameState,
        definitionID: String,
        origin: GridPosition,
        facing: Direction
    ) -> PlacementPreview {
        PlacementService.preview(
            state: state,
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        )
    }

    func place(
        state: inout GameState,
        definitionID: String,
        origin: GridPosition,
        facing: Direction
    ) -> CommandFeedback {
        let before = state
        switch PlacementService.place(
            state: state,
            definitionID: definitionID,
            origin: origin,
            facing: facing,
            catalog: catalog
        ) {
        case .failure(.outOfBounds):
            state = before
            return .failure("无法放置：超出农场边界。")
        case .failure(.occupancyConflict):
            state = before
            return .failure("无法放置：目标被占用。")
        case .failure(.notAdjacentToPlayer), .failure(.exitUnreachable):
            state = before
            return .failure("无法放置：玩家或出口不可达。")
        case .failure:
            state = before
            return .failure("放置失败，未消耗材料。")
        case .success(let placed):
            switch CanalProgressionService.commitCanalPlacementIfNeeded(
                state: placed,
                definitionID: definitionID,
                catalog: catalog
            ) {
            case .failure:
                state = before
                return .failure("放置失败，未消耗材料。")
            case .success(let next):
                state = next
                let name = catalog.displayName(forNameKey: catalog.placedObject(id: definitionID)?.nameKey ?? definitionID)
                if definitionID == ContentID.canalSegmentObject {
                    return .success(
                        "放置完成：\(name)。水脉 \(before.watershed.restorationPoints)→\(next.watershed.restorationPoints)。"
                    )
                }
                return .success("放置完成：\(name)。")
            }
        }
    }

    func gatherFacingNode(state: inout GameState) -> CommandFeedback {
        let before = state
        guard let node = GatherService.node(facingOrStanding: state, catalog: catalog) else {
            return .failure("附近没有可采集的节点。")
        }
        switch GatherService.harvest(state: state, nodeID: node.id, catalog: catalog) {
        case .failure(.alreadyHarvested):
            state = before
            return .failure("\(node.label)已经采集过了。")
        case .failure(.locked):
            state = before
            return .failure("\(node.label)尚未开放。")
        case .failure(.insufficientStamina):
            state = before
            return .failure("体力不足，无法采集。")
        case .failure(.capacityExceeded):
            state = before
            return .failure("背包空间不足，采集已回滚。")
        case .failure:
            state = before
            return .failure("采集失败，未获得物品。")
        case .success(let next):
            state = next
            let loot = node.yields.map { yield in
                "\(catalog.displayName(forItemID: yield.itemID))×\(yield.quantity)"
            }.joined(separator: "、")
            return .success("采集完成：\(node.label)（\(loot)）。")
        }
    }

    func sleep(
        state: inout GameState,
        clock: ClockSystem,
        store: SaveStore? = nil,
        persist: (@Sendable (GameState) throws -> Void)? = nil
    ) -> CommandFeedback {
        do {
            let summary = try SleepUseCase().sleep(
                state: &state,
                clock: clock,
                catalog: catalog,
                store: store,
                persist: persist
            )
            return .success(summary.headline)
        } catch {
            return .failure("日结自动保存失败。")
        }
    }

    func debugReport(state: GameState) -> String {
        EconomyDebugReport.make(from: state, catalog: catalog).text
    }

    func hudSnapshot(state: GameState, lastFeedback: CommandFeedback) -> String {
        let pending = state.economy.shipping.pendingQuantity
        let mark = lastFeedback.isSuccess ? "✅" : "❌"
        return """
        溪票 \(state.economy.balance)
        待结算 \(pending)
        \(mark) \(lastFeedback.message)
        """
    }
}
