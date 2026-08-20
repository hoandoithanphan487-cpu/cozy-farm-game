enum EconomyFailure: Equatable, Error, Sendable {
    case invalidTransaction
    case negativeBalanceRejected
}

struct EconomyService: Sendable {
    static func apply(
        _ economy: EconomyState,
        transaction: CurrencyTransaction
    ) -> Result<EconomyState, EconomyFailure> {
        guard !transaction.reasonID.isEmpty,
              !transaction.sourceRef.isEmpty,
              transaction.dayIndex >= 1,
              transaction.amount != 0 else {
            return .failure(.invalidTransaction)
        }
        let nextBalance = economy.balance + transaction.amount
        guard nextBalance >= 0 else {
            return .failure(.negativeBalanceRejected)
        }
        var next = economy
        next.balance = nextBalance
        next.ledger.append(CurrencyLedgerEntry(transaction))
        return .success(next)
    }
}
