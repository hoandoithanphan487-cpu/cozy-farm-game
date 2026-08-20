enum NpcRole: String, Equatable, Sendable {
    case questGiver = "quest_giver"
    case neighbor = "neighbor"
}

enum PersonalityArchetype: String, Equatable, Sendable {
    case helpfulHearsay = "helpful_hearsay"
    case dramaticStoryteller = "dramatic_storyteller"
    case evidenceMinded = "evidence_minded"
    case consensusFollower = "consensus_follower"
}

struct NpcDefinition: Equatable, Sendable {
    var id: String
    var nameKey: String
    var displayName: String
    var role: NpcRole
    var personalityArchetype: PersonalityArchetype?
    var dialoguePoolID: String
    var mapID: String
    var position: GridPosition
    var scheduleID: String = ""
}

struct NpcPresence: Equatable, Sendable {
    var npcID: String
    var displayName: String
    var position: GridPosition
    var dialogueID: String
    var role: NpcRole
    var isTeachingSpawn: Bool
}
