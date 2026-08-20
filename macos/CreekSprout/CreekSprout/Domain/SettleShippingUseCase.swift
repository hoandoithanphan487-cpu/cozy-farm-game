struct SettleShippingResult: Equatable, Sendable {
    var state: GameState
    var record: SettlementRecord
    var wasAlreadySettled: Bool
}

struct SettleShippingUseCase: Sendable {
    static func settle(
        state: GameState,
        catalog: ContentCatalog
    ) -> SettleShippingResult {
        let settlementID = SettlementRecord.makeID(
            scenarioID: state.scenarioID,
            gameDay: state.clock.day
        )
        if let existing = state.economy.settlementHistory.first(where: { $0.settlementID == settlementID }) {
            return SettleShippingResult(state: state, record: existing, wasAlreadySettled: true)
        }

        let prices = EconomyCatalog(content: catalog)
        let pending = state.economy.shipping.pendingEntries
        var lines: [SettlementLine] = []
        var total = 0
        for entry in pending {
            guard let amount = prices.lineTotal(unitPrice: entry.unitPriceSnapshot, quantity: entry.quantity) else {
                return SettleShippingResult(state: state, record: SettlementRecord(
                    settlementID: settlementID,
                    scenarioID: state.scenarioID,
                    gameDay: state.clock.day,
                    lines: [],
                    total: 0
                ), wasAlreadySettled: false)
            }
            let (nextTotal, overflow) = total.addingReportingOverflow(amount)
            guard !overflow, nextTotal >= 0 else {
                return SettleShippingResult(state: state, record: SettlementRecord(
                    settlementID: settlementID,
                    scenarioID: state.scenarioID,
                    gameDay: state.clock.day,
                    lines: [],
                    total: 0
                ), wasAlreadySettled: false)
            }
            total = nextTotal
            lines.append(
                SettlementLine(
                    itemID: entry.itemID,
                    quantity: entry.quantity,
                    quality: entry.quality,
                    amount: amount,
                    displayText: prices.settlementLine(
                        itemID: entry.itemID,
                        quantity: entry.quantity,
                        amount: amount
                    )
                )
            )
        }
        let record = SettlementRecord(
            settlementID: settlementID,
            scenarioID: state.scenarioID,
            gameDay: state.clock.day,
            lines: lines,
            total: total
        )

        var next = state
        next.economy.shipping.pendingEntries = []
        next.economy.settlementHistory.append(record)
        next.economy.settlementHistory.sort { $0.settlementID < $1.settlementID }

        if total != 0 {
            let transaction = CurrencyTransaction(
                reasonID: ContentID.shippingSettleReason,
                amount: total,
                sourceRef: settlementID,
                dayIndex: state.clock.day
            )
            switch EconomyService.apply(next.economy, transaction: transaction) {
            case .success(let economy):
                next.economy = economy
            case .failure:
                return SettleShippingResult(state: state, record: record, wasAlreadySettled: false)
            }
        }

        return SettleShippingResult(state: next, record: record, wasAlreadySettled: false)
    }
}
