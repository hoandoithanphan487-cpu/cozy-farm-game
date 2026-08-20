struct CurrencyTransaction: Equatable, Sendable {
    var reasonID: String
    var amount: Int
    var sourceRef: String
    var dayIndex: Int
}

struct CurrencyLedgerEntry: Equatable, Codable, Sendable {
    var reasonID: String
    var amount: Int
    var sourceRef: String
    var dayIndex: Int

    enum CodingKeys: String, CodingKey {
        case reasonID = "reason_id"
        case amount
        case sourceRef = "source_ref"
        case dayIndex = "day_index"
    }

    init(reasonID: String, amount: Int, sourceRef: String, dayIndex: Int) {
        self.reasonID = reasonID
        self.amount = amount
        self.sourceRef = sourceRef
        self.dayIndex = dayIndex
    }

    init(_ transaction: CurrencyTransaction) {
        self.init(
            reasonID: transaction.reasonID,
            amount: transaction.amount,
            sourceRef: transaction.sourceRef,
            dayIndex: transaction.dayIndex
        )
    }
}

struct ShippingEntry: Equatable, Codable, Sendable {
    var entryID: String
    var itemID: String
    var quantity: Int
    var quality: ItemQuality
    var depositedDay: Int
    var unitPriceSnapshot: Int

    enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
        case itemID = "item_id"
        case quantity
        case quality
        case depositedDay = "deposited_day"
        case unitPriceSnapshot = "unit_price_snapshot"
    }

    var lineAmount: Int {
        unitPriceSnapshot * quantity
    }

    static func mergeKey(itemID: String, quality: ItemQuality, depositedDay: Int) -> String {
        "\(itemID)#\(quality.rawValue)#day\(depositedDay)"
    }
}

struct SettlementLine: Equatable, Codable, Sendable {
    var itemID: String
    var quantity: Int
    var quality: ItemQuality
    var amount: Int
    var displayText: String

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case quantity
        case quality
        case amount
        case displayText = "display_text"
    }
}

struct SettlementRecord: Equatable, Codable, Sendable {
    var settlementID: String
    var scenarioID: String
    var gameDay: Int
    var lines: [SettlementLine]
    var total: Int

    enum CodingKeys: String, CodingKey {
        case settlementID = "settlement_id"
        case scenarioID = "scenario_id"
        case gameDay = "game_day"
        case lines
        case total
    }

    static func makeID(scenarioID: String, gameDay: Int) -> String {
        "\(scenarioID).day\(gameDay)"
    }
}

struct ShippingState: Equatable, Codable, Sendable {
    var pendingEntries: [ShippingEntry] = []

    enum CodingKeys: String, CodingKey {
        case pendingEntries = "pending_entries"
    }

    var pendingQuantity: Int {
        pendingEntries.reduce(0) { $0 + $1.quantity }
    }

    func entry(id: String) -> ShippingEntry? {
        pendingEntries.first { $0.entryID == id }
    }
}

struct EconomyState: Equatable, Codable, Sendable {
    var balance: Int = 0
    var shipping: ShippingState = ShippingState()
    var settlementHistory: [SettlementRecord] = []
    var ledger: [CurrencyLedgerEntry] = []

    enum CodingKeys: String, CodingKey {
        case balance
        case shipping
        case settlementHistory = "settlement_history"
        case ledger
    }

    static let empty = EconomyState()

    var settledIDs: Set<String> {
        Set(settlementHistory.map(\.settlementID))
    }

    func hasSettled(_ settlementID: String) -> Bool {
        settlementHistory.contains { $0.settlementID == settlementID }
    }
}

struct PlacedObjectState: Equatable, Codable, Sendable {
    var instanceID: String
    var definitionID: String
    var origin: GridPosition
    var facing: Direction

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case definitionID = "definition_id"
        case origin
        case facing
    }
}
