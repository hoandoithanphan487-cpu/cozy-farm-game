struct EconomyCatalog: Equatable, Sendable {
    var content: ContentCatalog

    init(content: ContentCatalog) {
        self.content = content
    }

    /// Defined non-negative list price after quality, or `nil` when the item has no sell price.
    func unitPrice(itemID: String, quality: ItemQuality) -> Int? {
        guard let base = content.item(id: itemID)?.baseSellPrice, base >= 0 else {
            return nil
        }
        return Self.resolvedUnitPrice(baseSellPrice: base, quality: quality)
    }

    /// Only a defined positive base price may enter the shipping bin.
    func isShippable(itemID: String) -> Bool {
        guard let base = content.item(id: itemID)?.baseSellPrice else {
            return false
        }
        return base > 0
    }

    static func resolvedUnitPrice(baseSellPrice: Int, quality: ItemQuality) -> Int {
        (baseSellPrice * quality.multiplierBp) / 100
    }

    func lineTotal(unitPrice: Int, quantity: Int) -> Int? {
        let (product, overflow) = unitPrice.multipliedReportingOverflow(by: quantity)
        guard !overflow, product >= 0 else {
            return nil
        }
        return product
    }

    func settlementLine(itemID: String, quantity: Int, amount: Int) -> String {
        "\(content.displayName(forItemID: itemID))×\(quantity) = \(amount)"
    }
}
