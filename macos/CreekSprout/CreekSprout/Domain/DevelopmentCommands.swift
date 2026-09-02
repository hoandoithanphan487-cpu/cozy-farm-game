/// Isolated development helpers for M2-001 verification.
/// Presentation wiring must stay behind DEBUG builds; these functions do not
/// change production rules and are not part of the player-facing feature set.
enum DevelopmentCommands {
    static let materialKit: [InventoryQuantity] = [
        InventoryQuantity(itemID: ContentID.creekWood, quantity: 12),
        InventoryQuantity(itemID: ContentID.mossStone, quantity: 4),
        InventoryQuantity(itemID: ContentID.reedFiber, quantity: 6),
        InventoryQuantity(itemID: ContentID.creekGreensItem, quantity: 2),
    ]

    static func grantMaterialKit(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> CommandFeedback {
        var inventory = state.inventory
        for stack in materialKit {
            switch InventoryService.tryAdd(
                inventory,
                capacity: state.inventoryCapacity,
                itemID: stack.itemID,
                quantity: stack.quantity,
                stackLimit: catalog.stackLimit(for: stack.itemID)
            ) {
            case .failure:
                return .failure("调试注入失败：背包无法容纳材料。")
            case .success(let next):
                inventory = next
            }
        }
        state.inventory = inventory
        return .success("调试注入：已加入制作材料。")
    }

    static func grantCurrency(
        state: inout GameState,
        amount: Int,
        sourceRef: String = "brookseed.debug.currency"
    ) -> CommandFeedback {
        let transaction = CurrencyTransaction(
            reasonID: ContentID.debugGrantReason,
            amount: amount,
            sourceRef: sourceRef,
            dayIndex: state.clock.day
        )
        switch EconomyService.apply(state.economy, transaction: transaction) {
        case .failure:
            return .failure("调试注入失败：货币事务被拒绝。")
        case .success(let economy):
            state.economy = economy
            return .success("调试注入：溪票\(amount > 0 ? "+" : "")\(amount)。")
        }
    }
}
