import Foundation

// MARK: - Q07 foster supply orders (代养供货单)

enum FosterOrderStatus: String, Codable, CaseIterable, Sendable {
    case active
    case fulfilled
    case cancelled
    case convertedToPartner = "converted_to_partner"

    var isClosed: Bool {
        self != .active
    }
}

struct FosterSupplyOrder: Equatable, Codable, Sendable {
    var issuanceID: String
    var campaignID: String
    var animalKindID: String
    var status: FosterOrderStatus
    var animalInstanceID: String?
    var issuedDay: Int
    var acceptedDay: Int?
    var closedDay: Int?
    var fulfillmentReceiptID: String?

    enum CodingKeys: String, CodingKey {
        case issuanceID = "issuance_id"
        case campaignID = "campaign_id"
        case animalKindID = "animal_kind_id"
        case status
        case animalInstanceID = "animal_instance_id"
        case issuedDay = "issued_day"
        case acceptedDay = "accepted_day"
        case closedDay = "closed_day"
        case fulfillmentReceiptID = "fulfillment_receipt_id"
    }
}

/// Per-campaign foster ledger. Anti-arbitrage invariants:
/// - one active issuance per campaign at any time;
/// - accept / cancel / convert pay nothing;
/// - cancelling atomically returns the fostered animal;
/// - converting to a partner happens at most once per campaign and makes the
///   animal permanently non-suppliable and non-exchangeable;
/// - revenue comes only from the final successful normal cat-shop receipt.
struct FosterOrderState: Equatable, Codable, Sendable {
    var orders: [FosterSupplyOrder]
    var convertedAnimalIDs: [String]
    var partnerConversionUsed: Bool

    enum CodingKeys: String, CodingKey {
        case orders
        case convertedAnimalIDs = "converted_animal_ids"
        case partnerConversionUsed = "partner_conversion_used"
    }

    static let empty = FosterOrderState(
        orders: [],
        convertedAnimalIDs: [],
        partnerConversionUsed: false
    )

    func order(issuanceID: String) -> FosterSupplyOrder? {
        orders.first { $0.issuanceID == issuanceID }
    }

    var activeOrder: FosterSupplyOrder? {
        orders.first { $0.status == .active }
    }
}

enum FosterSupplyFailure: Equatable, Error, Sendable {
    case notUnlocked
    case orderAlreadyActive
    case unknownIssuance
    case issuanceClosed
    case animalKindUnknown
    case alreadyAccepted
    case animalAlreadyAssigned
    case conversionLimitReached
    case animalAlreadyConverted
    case duplicateFulfillment
    case invalidRequest
}

/// Pure foster-order transactions. Every mutation is idempotent via issuance
/// IDs and writes metrics in the same candidate as the source transaction.
enum FosterSupplyService {
    static let maximumPartnerConversionsPerCampaign = 1

    static func isUnlocked(state: GameState) -> Bool {
        state.storyCampaign.segment(.q05)?.phase == .resolved
    }

    /// Issues a transparent foster supply order. Only one active issuance may
    /// exist per campaign; the previous issuance must be closed first.
    static func issue(
        state: GameState,
        animalKindID: String,
        catalog: ContentCatalog = .vs0
    ) -> Result<GameState, FosterSupplyFailure> {
        guard isUnlocked(state: state) else { return .failure(.notUnlocked) }
        guard catalog.livestockDefinition(id: animalKindID) != nil else {
            return .failure(.animalKindUnknown)
        }
        guard state.fosterOrders.activeOrder == nil else {
            return .failure(.orderAlreadyActive)
        }
        let serial = state.fosterOrders.orders.count + 1
        // The serial is embedded in an identifier-safe segment: a bare
        // numeric dot-segment ("...day_8.1") fails `ContentID.isValid`, which
        // `SaveValidation.validateFosterOrders` requires of every issuanceID.
        let issuanceID = "brookseed.story.foster.issue.day_\(state.clock.day)_serial_\(serial)"
        var next = state
        next.fosterOrders.orders.append(
            FosterSupplyOrder(
                issuanceID: issuanceID,
                campaignID: state.campaignID,
                animalKindID: animalKindID,
                status: .active,
                animalInstanceID: nil,
                issuedDay: state.clock.day,
                acceptedDay: nil,
                closedDay: nil,
                fulfillmentReceiptID: nil
            )
        )
        next.fosterOrders.orders.sort { $0.issuanceID < $1.issuanceID }
        next.storyMetrics.fosterIssuanceIDs.append(issuanceID)
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    /// Accepts the order by adding a new, clearly-labelled foster animal to
    /// the pen. Pays nothing.
    static func accept(
        state: GameState,
        issuanceID: String
    ) -> Result<GameState, FosterSupplyFailure> {
        guard var order = state.fosterOrders.order(issuanceID: issuanceID) else {
            return .failure(.unknownIssuance)
        }
        guard order.status == .active else { return .failure(.issuanceClosed) }
        guard order.animalInstanceID == nil else { return .failure(.alreadyAccepted) }
        let animalID = "brookseed.foster.animal.\(issuanceID.replacingOccurrences(of: ".", with: "_"))"
        let displayName = "代养\(state.fosterOrders.orders.count + 1)号"
        var next = state
        switch LivestockService.addAnimal(
            state: next,
            instanceID: animalID,
            definitionID: order.animalKindID,
            displayName: displayName,
            startDay: state.clock.day
        ) {
        case .success(let candidate):
            next = candidate
        case .failure:
            return .failure(.invalidRequest)
        }
        order.animalInstanceID = animalID
        order.acceptedDay = state.clock.day
        guard let index = next.fosterOrders.orders.firstIndex(where: {
            $0.issuanceID == issuanceID
        }) else {
            return .failure(.unknownIssuance)
        }
        next.fosterOrders.orders[index] = order
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    /// Cancels the order and atomically returns the fostered animal. Pays
    /// nothing; the animal never remains in the player's pen.
    static func cancel(
        state: GameState,
        issuanceID: String
    ) -> Result<GameState, FosterSupplyFailure> {
        guard var order = state.fosterOrders.order(issuanceID: issuanceID) else {
            return .failure(.unknownIssuance)
        }
        guard order.status == .active else { return .failure(.issuanceClosed) }
        var next = state
        if let animalID = order.animalInstanceID {
            switch LivestockService.removeAnimal(state: next, animalID: animalID) {
            case .success(let candidate):
                next = candidate
            case .failure:
                return .failure(.invalidRequest)
            }
            order.animalInstanceID = nil
        }
        order.status = .cancelled
        order.closedDay = state.clock.day
        guard let index = next.fosterOrders.orders.firstIndex(where: {
            $0.issuanceID == issuanceID
        }) else {
            return .failure(.unknownIssuance)
        }
        next.fosterOrders.orders[index] = order
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    /// Converts the fostered animal into a permanent partner (once per
    /// campaign). The animal stays in the pen, becomes permanently
    /// non-suppliable and can never re-qualify for a replacement issuance.
    static func convertToPartner(
        state: GameState,
        issuanceID: String
    ) -> Result<GameState, FosterSupplyFailure> {
        guard var order = state.fosterOrders.order(issuanceID: issuanceID) else {
            return .failure(.unknownIssuance)
        }
        guard order.status == .active else { return .failure(.issuanceClosed) }
        guard !state.fosterOrders.partnerConversionUsed else {
            return .failure(.conversionLimitReached)
        }
        guard let animalID = order.animalInstanceID,
              let animalIndex = state.livestock.animals.firstIndex(where: {
                  $0.instanceID == animalID
              }) else {
            return .failure(.invalidRequest)
        }
        guard !state.fosterOrders.convertedAnimalIDs.contains(animalID) else {
            return .failure(.animalAlreadyConverted)
        }
        var next = state
        next.livestock.animals[animalIndex].isProtected = true
        next.livestock.sortAnimals()
        next.fosterOrders.convertedAnimalIDs.append(animalID)
        next.fosterOrders.convertedAnimalIDs.sort()
        next.fosterOrders.partnerConversionUsed = true
        order.status = .convertedToPartner
        order.closedDay = state.clock.day
        guard let index = next.fosterOrders.orders.firstIndex(where: {
            $0.issuanceID == issuanceID
        }) else {
            return .failure(.unknownIssuance)
        }
        next.fosterOrders.orders[index] = order
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    /// Marks the order fulfilled using the final successful cat-shop receipt.
    /// Called from the same candidate as `CatShopSupplyService.supplyAnimal`.
    static func fulfill(
        state: GameState,
        issuanceID: String,
        receiptID: String,
        day: Int
    ) -> Result<GameState, FosterSupplyFailure> {
        guard var order = state.fosterOrders.order(issuanceID: issuanceID) else {
            return .failure(.unknownIssuance)
        }
        guard order.status == .active else { return .failure(.issuanceClosed) }
        guard order.animalInstanceID != nil else { return .failure(.alreadyAccepted) }
        guard order.fulfillmentReceiptID == nil else {
            return .failure(.duplicateFulfillment)
        }
        var next = state
        order.status = .fulfilled
        order.closedDay = day
        order.fulfillmentReceiptID = receiptID
        guard let index = next.fosterOrders.orders.firstIndex(where: {
            $0.issuanceID == issuanceID
        }) else {
            return .failure(.unknownIssuance)
        }
        next.fosterOrders.orders[index] = order
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    /// Whether this animal may never be supplied or exchanged again (partner
    /// conversion or a cancelled/fulfilled foster order's animal).
    static func isNonSupplyable(state: GameState, animalID: String) -> Bool {
        state.fosterOrders.convertedAnimalIDs.contains(animalID)
    }
}

extension ContentCatalog {
    func livestockDefinition(id: String) -> LivestockDefinition? {
        LivestockCatalog.definition(id: id)
    }
}
