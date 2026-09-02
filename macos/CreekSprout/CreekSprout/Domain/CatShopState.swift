enum CatShopReceiptKind: String, Equatable, Codable, Sendable {
    case crop
    case animal
}

struct CatShopReceipt: Equatable, Codable, Sendable {
    var receiptID: String
    var day: Int
    var offerID: String
    var kind: CatShopReceiptKind
    var subjectID: String
    var definitionID: String
    var displayName: String
    var quantity: Int
    var unitPrice: Int
    var total: Int

    enum CodingKeys: String, CodingKey {
        case receiptID = "receipt_id"
        case day
        case offerID = "offer_id"
        case kind
        case subjectID = "subject_id"
        case definitionID = "definition_id"
        case displayName = "display_name"
        case quantity
        case unitPrice = "unit_price"
        case total
    }
}

struct CatShopState: Equatable, Codable, Sendable {
    var receipts: [CatShopReceipt] = []

    static let empty = CatShopState()

    enum CodingKeys: String, CodingKey {
        case receipts
    }

    func receipt(id: String) -> CatShopReceipt? {
        receipts.first { $0.receiptID == id }
    }

    func suppliedQuantity(offerID: String, day: Int) -> Int {
        receipts.reduce(0) { total, receipt in
            receipt.offerID == offerID && receipt.day == day ? total + receipt.quantity : total
        }
    }

    mutating func sortReceipts() {
        receipts.sort { $0.receiptID < $1.receiptID }
    }
}
