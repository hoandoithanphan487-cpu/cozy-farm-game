import Foundation

enum CatShopOfferKind: Equatable, Sendable {
    case crop(itemID: String)
    case animal(definitionID: String)
}

struct CatShopOffer: Equatable, Sendable, Identifiable {
    var id: String
    var kind: CatShopOfferKind
    var displayName: String
    var unitPrice: Int
    var dailyLimit: Int
}

enum CatShopCatalog {
    static let cropPremiumBasisPoints = 110
    static let cropDailyLimit = 6
    static let animalDailyLimit = 1

    private static let cropRotation: [String] = [
        ContentID.mistRadishItem,
        ContentID.creekGreensItem,
        ContentID.amberBeanItem,
        ContentID.bellBerryItem,
        ContentID.honeyMelonItem,
    ]

    static func offers(day: Int, content: ContentCatalog) -> [CatShopOffer] {
        let safeDay = max(day, 1)
        let firstIndex = (safeDay - 1) % cropRotation.count
        let secondIndex = (firstIndex + 2) % cropRotation.count
        let cropIDs = [cropRotation[firstIndex], cropRotation[secondIndex]]
        let cropOffers = cropIDs.compactMap { itemID -> CatShopOffer? in
            guard let basePrice = content.item(id: itemID)?.baseSellPrice, basePrice > 0 else {
                return nil
            }
            let premiumPrice = max(basePrice + 1, (basePrice * cropPremiumBasisPoints) / 100)
            return CatShopOffer(
                id: "\(ContentID.catShopCropOfferPrefix).\(itemID.replacingOccurrences(of: "brookseed.item.", with: ""))",
                kind: .crop(itemID: itemID),
                displayName: content.displayName(forItemID: itemID),
                unitPrice: premiumPrice,
                dailyLimit: cropDailyLimit
            )
        }
        let animalOffers = LivestockCatalog.definitionList.map { definition in
            CatShopOffer(
                id: "\(ContentID.catShopAnimalOfferPrefix).\(definition.id.replacingOccurrences(of: "brookseed.livestock.", with: ""))",
                kind: .animal(definitionID: definition.id),
                displayName: definition.displayName,
                unitPrice: definition.supplyPrice,
                dailyLimit: animalDailyLimit
            )
        }
        return cropOffers + animalOffers
    }

    static func offer(id: String, day: Int, content: ContentCatalog) -> CatShopOffer? {
        offers(day: day, content: content).first { $0.id == id }
    }
}
