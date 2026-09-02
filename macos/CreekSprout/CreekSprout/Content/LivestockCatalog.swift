struct LivestockDefinition: Equatable, Sendable {
    var id: String
    var displayName: String
    var maturityDays: Int
    var supplyPrice: Int
}

enum LivestockCatalog {
    static let careStaminaCost = 2

    static let definitions: [String: LivestockDefinition] = Dictionary(
        uniqueKeysWithValues: definitionList.map { ($0.id, $0) }
    )

    static let definitionList: [LivestockDefinition] = [
        LivestockDefinition(
            id: ContentID.livestockCow,
            displayName: "溪谷奶牛",
            maturityDays: 3,
            supplyPrice: 420
        ),
        LivestockDefinition(
            id: ContentID.livestockSheep,
            displayName: "雾绒羊",
            maturityDays: 2,
            supplyPrice: 300
        ),
        LivestockDefinition(
            id: ContentID.livestockGoat,
            displayName: "坡角山羊",
            maturityDays: 2,
            supplyPrice: 260
        ),
    ]

    static func definition(id: String) -> LivestockDefinition? {
        definitions[id]
    }

    static func starterHerd(startDay: Int = 1) -> LivestockState {
        _ = startDay
        var state = LivestockState(animals: [
            FarmAnimalState(
                instanceID: ContentID.starterCow,
                definitionID: ContentID.livestockCow,
                displayName: "团云",
                ageDays: 3,
                totalCareDays: 0,
                lastCaredDay: nil,
                isProtected: false
            ),
            FarmAnimalState(
                instanceID: ContentID.starterSheep,
                definitionID: ContentID.livestockSheep,
                displayName: "软铃",
                ageDays: 2,
                totalCareDays: 0,
                lastCaredDay: nil,
                isProtected: false
            ),
            FarmAnimalState(
                instanceID: ContentID.starterGoat,
                definitionID: ContentID.livestockGoat,
                displayName: "小坡",
                ageDays: 0,
                totalCareDays: 0,
                lastCaredDay: nil,
                isProtected: false
            ),
        ])
        state.sortAnimals()
        return state
    }
}
