struct FarmAnimalState: Equatable, Codable, Sendable {
    var instanceID: String
    var definitionID: String
    var displayName: String
    var ageDays: Int
    var totalCareDays: Int
    var lastCaredDay: Int?
    var isProtected: Bool

    enum CodingKeys: String, CodingKey {
        case instanceID = "instance_id"
        case definitionID = "definition_id"
        case displayName = "display_name"
        case ageDays = "age_days"
        case totalCareDays = "total_care_days"
        case lastCaredDay = "last_cared_day"
        case isProtected = "is_protected"
    }
}

struct LivestockState: Equatable, Codable, Sendable {
    var animals: [FarmAnimalState] = []

    static let empty = LivestockState()

    enum CodingKeys: String, CodingKey {
        case animals
    }

    func animal(id: String) -> FarmAnimalState? {
        animals.first { $0.instanceID == id }
    }

    func contains(definitionID: String) -> Bool {
        animals.contains { $0.definitionID == definitionID }
    }

    mutating func sortAnimals() {
        animals.sort { $0.instanceID < $1.instanceID }
    }
}

enum LivestockFailure: Equatable, Error, Sendable {
    case animalNotFound
    case alreadyCaredToday
    case insufficientStamina
}

struct LivestockService: Sendable {
    /// Adds a new animal to the pen. Used by the Q07 foster supply orders;
    /// no stamina, money or receipt is involved.
    static func addAnimal(
        state: GameState,
        instanceID: String,
        definitionID: String,
        displayName: String,
        startDay: Int
    ) -> Result<GameState, LivestockFailure> {
        guard LivestockCatalog.definition(id: definitionID) != nil,
              ContentID.isValid(instanceID),
              !state.livestock.animals.contains(where: { $0.instanceID == instanceID }) else {
            return .failure(.animalNotFound)
        }
        var next = state
        next.livestock.animals.append(
            FarmAnimalState(
                instanceID: instanceID,
                definitionID: definitionID,
                displayName: displayName,
                ageDays: 0,
                totalCareDays: 0,
                lastCaredDay: nil,
                isProtected: false
            )
        )
        next.livestock.sortAnimals()
        return .success(next)
    }

    /// Removes an animal from the pen. Used to atomically return a fostered
    /// animal when its order is cancelled.
    static func removeAnimal(
        state: GameState,
        animalID: String
    ) -> Result<GameState, LivestockFailure> {
        guard state.livestock.animals.contains(where: { $0.instanceID == animalID }) else {
            return .failure(.animalNotFound)
        }
        var next = state
        next.livestock.animals.removeAll { $0.instanceID == animalID }
        next.livestock.sortAnimals()
        return .success(next)
    }

    static func care(
        state: GameState,
        animalID: String
    ) -> Result<GameState, LivestockFailure> {
        guard let index = state.livestock.animals.firstIndex(where: { $0.instanceID == animalID }) else {
            return .failure(.animalNotFound)
        }
        guard state.livestock.animals[index].lastCaredDay != state.clock.day else {
            return .failure(.alreadyCaredToday)
        }
        guard state.stamina >= LivestockCatalog.careStaminaCost else {
            return .failure(.insufficientStamina)
        }
        var next = state
        next.stamina -= LivestockCatalog.careStaminaCost
        next.livestock.animals[index].lastCaredDay = state.clock.day
        next.livestock.animals[index].totalCareDays += 1
        next.livestock.sortAnimals()
        let sourceID = "brookseed.story.metric.livestock.care.day_\(state.clock.day).\(animalID)"
        if next.storyMetrics.claimSource(sourceID) {
            next.storyMetrics.livestockCareDays[animalID, default: []].append(state.clock.day)
            next.storyMetrics.canonicalize()
        }
        return .success(next)
    }

    static func advanceAfterDay(state: inout GameState) {
        for index in state.livestock.animals.indices {
            let wasAdult = isAdult(state.livestock.animals[index])
            state.livestock.animals[index].ageDays += 1
            if !wasAdult, isAdult(state.livestock.animals[index]) {
                state.storyMetrics.animalsGrownToAdultIDs.append(
                    state.livestock.animals[index].instanceID
                )
            }
        }
        state.livestock.sortAnimals()
        state.storyMetrics.canonicalize()
    }

    static func isAdult(_ animal: FarmAnimalState) -> Bool {
        guard let definition = LivestockCatalog.definition(id: animal.definitionID) else {
            return false
        }
        return animal.ageDays >= definition.maturityDays
    }

    static func canSupply(_ animal: FarmAnimalState, on day: Int) -> Bool {
        isAdult(animal) && animal.lastCaredDay == day && !animal.isProtected
    }
}
