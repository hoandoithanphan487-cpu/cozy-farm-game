struct EconomyDebugReport: Equatable, Sendable {
    var balance: Int
    var pendingQuantity: Int
    var settlementCount: Int
    var lines: [String]

    var text: String {
        lines.joined(separator: "\n")
    }

    static func make(from state: GameState, catalog: ContentCatalog) -> EconomyDebugReport {
        var lines: [String] = [
            "balance=\(state.economy.balance)",
            "pending=\(state.economy.shipping.pendingQuantity)",
            "settlements=\(state.economy.settlementHistory.count)",
            "ledger=\(state.economy.ledger.count)",
        ]
        for entry in state.economy.ledger {
            lines.append(
                "ledger \(entry.dayIndex) \(entry.reasonID) \(entry.amount) \(entry.sourceRef)"
            )
        }
        for record in state.economy.settlementHistory {
            lines.append("settlement \(record.settlementID) total=\(record.total)")
            for line in record.lines {
                lines.append("  \(line.displayText)")
            }
        }
        lines.append("watershed=\(state.watershed.restorationPoints)")
        lines.append("ambience=\(state.watershed.ambienceLayerID)")
        lines.append("quest=\(state.questLog.status(of: ContentID.restoreOldCanalQuest).rawValue)")
        _ = catalog
        return EconomyDebugReport(
            balance: state.economy.balance,
            pendingQuantity: state.economy.shipping.pendingQuantity,
            settlementCount: state.economy.settlementHistory.count,
            lines: lines
        )
    }
}
