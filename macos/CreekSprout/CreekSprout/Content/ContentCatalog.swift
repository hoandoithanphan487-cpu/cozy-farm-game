struct ContentCatalog: Equatable, Sendable {
    var items: [String: ItemDefinition]
    var crops: [String: CropDefinition]

    static let m1Placeholder = ContentCatalog(
        items: [
            ContentID.mistRadishSeed: ItemDefinition(
                id: ContentID.mistRadishSeed,
                nameKey: "item.mist_radish_seed",
                category: "seed",
                stackLimit: 99
            ),
            ContentID.mistRadishItem: ItemDefinition(
                id: ContentID.mistRadishItem,
                nameKey: "item.mist_radish",
                category: "crop",
                stackLimit: 99
            ),
        ],
        crops: [
            ContentID.mistRadishCrop: CropDefinition(
                id: ContentID.mistRadishCrop,
                seedItemID: ContentID.mistRadishSeed,
                harvestItemID: ContentID.mistRadishItem,
                stageDays: [1, 1, 1],
                matureStageIndex: 2,
                yield: 1
            ),
        ]
    )

    func item(id: String) -> ItemDefinition? {
        items[id]
    }

    func crop(id: String) -> CropDefinition? {
        crops[id]
    }

    func crop(seedItemID: String) -> CropDefinition? {
        crops.values.first { $0.seedItemID == seedItemID }
    }

    func stackLimit(for itemID: String) -> Int {
        item(id: itemID)?.stackLimit ?? 99
    }

    func knowsItemID(_ id: String) -> Bool {
        items[id] != nil
    }

    func knowsCropID(_ id: String) -> Bool {
        crops[id] != nil
    }
}
