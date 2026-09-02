import Foundation

/// Stable story identifiers. These values are persisted by the N-027 runtime;
/// changing them would orphan campaign progress.
enum StoryArcID: String, CaseIterable, Codable, Sendable {
    case q01 = "brookseed.story.q01"
    case q02 = "brookseed.story.q02"
    case q03 = "brookseed.story.q03"
    case q04 = "brookseed.story.q04"
    case q05 = "brookseed.story.q05"
    case q06 = "brookseed.story.q06"
    case q07 = "brookseed.story.q07"
    case q08 = "brookseed.story.q08"
    case q09 = "brookseed.story.q09"
    case q10 = "brookseed.story.q10"

    var sequence: Int {
        switch self {
        case .q01: 1
        case .q02: 2
        case .q03: 3
        case .q04: 4
        case .q05: 5
        case .q06: 6
        case .q07: 7
        case .q08: 8
        case .q09: 9
        case .q10: 10
        }
    }

    var shortCode: String {
        String(format: "q%02d", sequence)
    }
}

/// Exact branch values frozen by the N-027 brief. `stableID` is used by the
/// content graph while `rawValue` remains the compact persisted branch value.
enum StoryChoiceID: String, CaseIterable, Codable, Sendable {
    case fieldFirst = "field_first"
    case reedFirst = "reed_first"
    case inspectFirst = "inspect_first"

    case harvest
    case sandbag
    case patrol
    case livestock

    case cutTest = "cut_test"
    case traceRumor = "trace_rumor"
    case protectInventory = "protect_inventory"

    case regroup
    case parallelCrop = "parallel_crop"
    case publishMissingPage = "publish_missing_page"

    case publicOrder = "public"
    case coop
    case delay

    case talk
    case noSide = "no_side"
    case pause
    case love
    case tender
    case friend

    case menu
    case inventory

    case evidence
    case tradeUnion = "trade_union"
    case oldWaterway = "old_waterway"

    case takeLedger = "take_ledger"
    case keepReading = "keep_reading"
    case closeLedger = "close_ledger"
    case returnTitles = "return_titles"

    case whyMe = "why_me"
    case anyTruth = "any_truth"
    case silence
    case breakTitles = "break_titles"
    case water
    case leave

    var arcID: StoryArcID {
        switch self {
        case .fieldFirst, .reedFirst, .inspectFirst:
            .q01
        case .harvest, .sandbag, .patrol, .livestock:
            .q02
        case .cutTest, .traceRumor, .protectInventory:
            .q03
        case .regroup, .parallelCrop, .publishMissingPage:
            .q04
        case .publicOrder, .coop, .delay:
            .q05
        case .talk, .noSide, .pause, .love, .tender, .friend:
            .q06
        case .menu, .inventory:
            // Harvest and livestock are shared spelling with Q02, so their
            // persisted enum values deliberately remain single cases. The
            // context arc resolves them for Q07 in `choices(for:)`.
            .q07
        case .evidence, .tradeUnion, .oldWaterway:
            .q08
        case .takeLedger, .keepReading, .closeLedger, .returnTitles:
            .q09
        case .whyMe, .anyTruth, .silence, .breakTitles, .water, .leave:
            .q10
        }
    }

    func stableID(in arcID: StoryArcID? = nil) -> String {
        let resolvedArc = arcID ?? self.arcID
        return "\(resolvedArc.rawValue).choice.\(rawValue)"
    }

    static func choices(for arcID: StoryArcID) -> [StoryChoiceID] {
        switch arcID {
        case .q01: [.fieldFirst, .reedFirst, .inspectFirst]
        case .q02: [.harvest, .sandbag, .patrol, .livestock]
        case .q03: [.cutTest, .traceRumor, .protectInventory]
        case .q04: [.regroup, .parallelCrop, .publishMissingPage]
        case .q05: [.publicOrder, .coop, .delay]
        case .q06: [.talk, .noSide, .pause, .love, .tender, .friend]
        case .q07: [.menu, .inventory, .harvest, .livestock]
        case .q08: [.evidence, .tradeUnion, .oldWaterway]
        case .q09: [.takeLedger, .keepReading, .closeLedger, .returnTitles]
        case .q10: [.whyMe, .anyTruth, .silence, .breakTitles, .water, .leave]
        }
    }

    func slot(in arcID: StoryArcID) -> StoryChoiceSlotID {
        switch arcID {
        case .q06:
            switch self {
            case .talk, .noSide, .pause: return .eruption
            case .love, .tender, .friend: return .aftermath
            default: return .primary
            }
        case .q09:
            return .ledgerIntent
        case .q10:
            switch self {
            case .water, .leave: return .finalAction
            default: return .confrontationIntent
            }
        default:
            return .primary
        }
    }
}

enum StoryChoiceSlotID: String, CaseIterable, Codable, Sendable {
    case primary
    case eruption
    case aftermath
    case ledgerIntent = "ledger_intent"
    case confrontationIntent = "confrontation_intent"
    case finalAction = "final_action"
}

enum StoryStageID: String, CaseIterable, Codable, Sendable {
    case benefit
    case warningOne = "warning_1"
    case warningTwo = "warning_2"
    case eruption
    case departureConfirmation = "departure_confirmation"
    case climax
    case aftermath
    case revealCallback = "reveal_callback"
    case discovery
    case interrupt
    case playerIntent = "player_intent"
    case turningPoint = "turning_point"
    case confrontationOpen = "confrontation_open"
    case allEvil = "all_evil"
    case lastFarmAction = "last_farm_action"
    case graduation
}

enum StoryContentVisibility: String, Codable, Sendable {
    case ordinary
    case finaleOnly = "finale_only"
}

enum StoryDialogueOrigin: String, Codable, Sendable {
    /// One of the 236 frozen N-026 manuscript lines.
    case manuscript
    /// A response printed inline under an intent; excluded from the 236 count.
    case inlineChoiceResponse = "inline_choice_response"
}

enum StoryLineCondition: Hashable, Codable, Sendable {
    case always
    case selectedChoice(StoryChoiceID, arcID: StoryArcID)
    case selectedAction(String)
    case romanceTender(Bool)
    case q05Resolution(StoryChoiceID)
}

enum StoryActorKind: String, Codable, Sendable {
    case npc
    case system
    case ledger
}

struct StoryActorDefinition: Equatable, Codable, Sendable {
    var id: String
    var displayName: String
    var portraitID: String?
    var kind: StoryActorKind
    var isConspirator: Bool
}

struct StoryDialogueLineDefinition: Equatable, Codable, Sendable {
    var id: String
    var sourceID: String?
    var origin: StoryDialogueOrigin
    var speakerID: String
    var attributedActorID: String?
    var speakerAnnotation: String?
    var text: String
    var portraitID: String?
    var condition: StoryLineCondition
    var blockingCueID: String?
    var visibility: StoryContentVisibility
}

struct StoryStageDefinition: Equatable, Codable, Sendable {
    var id: String
    var kind: StoryStageID
    var visibility: StoryContentVisibility
    var lines: [StoryDialogueLineDefinition]
    var choices: [StoryChoiceID]
    var nextStageIDs: [String]
}

struct StoryDefinition: Equatable, Codable, Sendable {
    var id: StoryArcID
    var title: String
    var stages: [StoryStageDefinition]
    var branchChoices: [StoryChoiceID]
}

struct StoryNormalizedPoint: Equatable, Codable, Sendable {
    var x: Double
    var y: Double
}

enum StoryAnchorPurpose: String, Codable, Sendable {
    case entry
    case exit
    case npcStart = "npc_start"
    case npcExit = "npc_exit"
    case playerWaypoint = "player_waypoint"
    case interaction
    case camera
    case prop
}

struct WorldGridStoryAnchor: Equatable, Codable, Sendable {
    var id: String
    var mapID: String
    var cell: GridPosition
    var landmarkID: String?
    var purpose: StoryAnchorPurpose
    var requiresWalkableCell: Bool
    var requiresInteractionCell: Bool
}

struct JourneyLocalStoryAnchor: Equatable, Codable, Sendable {
    var id: String
    var sceneID: String
    var point: StoryNormalizedPoint
    var purpose: StoryAnchorPurpose
    var pairedAnchorID: String?
}

enum StoryAnchorDefinition: Equatable, Codable, Sendable {
    case worldGrid(WorldGridStoryAnchor)
    case journeyLocal(JourneyLocalStoryAnchor)

    var id: String {
        switch self {
        case let .worldGrid(anchor): anchor.id
        case let .journeyLocal(anchor): anchor.id
        }
    }

    var sceneID: String? {
        switch self {
        case .worldGrid: nil
        case let .journeyLocal(anchor): anchor.sceneID
        }
    }
}

struct StoryCollisionRect: Equatable, Codable, Sendable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    func contains(_ point: StoryNormalizedPoint) -> Bool {
        (minX...maxX).contains(point.x) && (minY...maxY).contains(point.y)
    }
}

struct StoryJourneySceneDefinition: Equatable, Codable, Sendable {
    var id: String
    var displayName: String
    var entryAnchorID: String
    var exitAnchorID: String
    var localCollision: [StoryCollisionRect]
}

enum StoryCrossingOrInterruptKind: String, Codable, Sendable {
    case none
    case crossing
    case interrupt
    case fadeCut = "fade_cut"
}

struct StoryCrossingOrInterruptDefinition: Equatable, Codable, Sendable {
    var kind: StoryCrossingOrInterruptKind
    var actorID: String?
    var atAnchorID: String?
    var destinationSceneID: String?
}

struct StoryTemporaryBlockedCell: Equatable, Codable, Sendable {
    var mapID: String
    var cell: GridPosition
}

enum StoryRevealPolicy: String, Codable, Sendable {
    case never
    case finaleOnly = "finale_only"
}

struct StoryRevealCameraOrPropDefinition: Equatable, Codable, Sendable {
    var policy: StoryRevealPolicy
    var cameraAnchorID: String?
    var propID: String?
    var accessibleDescription: String?
}

struct StoryBlockingCueDefinition: Equatable, Codable, Sendable {
    var id: String
    var arcID: StoryArcID
    var sceneID: String
    var sourceBlockingID: String
    var entryAnchor: String
    var npcStartAnchors: [String: String]
    var playerWaypoints: [String]
    var interactionAnchor: String
    var crossingOrInterrupt: StoryCrossingOrInterruptDefinition
    var branchMovement: [String: [String]]
    var npcExitAnchors: [String: String]
    var temporarilyBlockedCells: [StoryTemporaryBlockedCell]
    var revealCameraOrProp: StoryRevealCameraOrPropDefinition
}
