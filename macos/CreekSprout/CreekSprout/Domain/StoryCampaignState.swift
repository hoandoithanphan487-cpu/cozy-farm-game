import Foundation

enum StoryPhase: String, Codable, CaseIterable, Sendable {
    case locked
    case benefit
    case warningOne = "warning_1"
    case warningTwo = "warning_2"
    case eruption
    case aftermath
    case resolved

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

enum StoryAftermathQuality: String, Codable, CaseIterable, Sendable {
    case pending
    case responsible
}

enum StoryQ06Outcome: String, Codable, CaseIterable, Sendable {
    case love
    case tender
    case friend
}

enum FinaleBeat: String, Codable, CaseIterable, Sendable {
    case locked
    case preRevealSavePending = "pre_reveal_save_pending"
    case discovery
    case confrontation
    case finalActionPending = "final_action_pending"
    case graduated

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

struct StoryPhaseDay: Equatable, Codable, Sendable {
    var phase: StoryPhase
    var day: Int

    enum CodingKeys: String, CodingKey {
        case phase
        case day
    }
}

struct StorySegmentState: Equatable, Codable, Sendable {
    var arcID: StoryArcID
    var phase: StoryPhase
    var phaseDays: [StoryPhaseDay]
    var benefitOfferID: String?
    var benefitBaselineDay: Int?
    var benefitBaseline: StoryMetricBaseline?
    var aftermathQuality: StoryAftermathQuality
    var aftermathStartDay: Int?
    var resolvedDay: Int?
    var selectedChoiceIDsBySlot: [String: String]
    var completedActionIDs: [String]
    /// Inventory explicitly held for Q07's celebration offer. These stacks
    /// remain in the player's inventory, but consumers must treat the recorded
    /// quantities as reserved until the celebration resolves.
    var reservedInventoryByItemID: [String: Int]
    var inventoryReservationReceipts: [StoryInventoryReservationRecord]
    var effectReceiptIDs: [String]
    var standingAwardReceiptID: String?
    var lastRelatedActionSerial: Int
    var warningOneEvidenceSerial: Int?
    var warningOneEvidenceCheckSerial: Int?
    var warningTwoEvidenceSerial: Int?
    var warningOneSleepEpoch: Int?
    var warningTwoSleepEpoch: Int?

    enum CodingKeys: String, CodingKey {
        case arcID = "arc_id"
        case phase
        case phaseDays = "phase_days"
        case benefitOfferID = "benefit_offer_id"
        case benefitBaselineDay = "benefit_baseline_day"
        case benefitBaseline = "benefit_baseline"
        case aftermathQuality = "aftermath_quality"
        case aftermathStartDay = "aftermath_start_day"
        case resolvedDay = "resolved_day"
        case selectedChoiceIDsBySlot = "selected_choice_ids_by_slot"
        case completedActionIDs = "completed_action_ids"
        case reservedInventoryByItemID = "reserved_inventory_by_item_id"
        case inventoryReservationReceipts = "inventory_reservation_receipts"
        case effectReceiptIDs = "effect_receipt_ids"
        case standingAwardReceiptID = "standing_award_receipt_id"
        case lastRelatedActionSerial = "last_related_action_serial"
        case warningOneEvidenceSerial = "warning_one_evidence_serial"
        case warningOneEvidenceCheckSerial = "warning_one_evidence_check_serial"
        case warningTwoEvidenceSerial = "warning_two_evidence_serial"
        case warningOneSleepEpoch = "warning_one_sleep_epoch"
        case warningTwoSleepEpoch = "warning_two_sleep_epoch"
    }

    static func locked(_ arcID: StoryArcID) -> StorySegmentState {
        StorySegmentState(
            arcID: arcID,
            phase: .locked,
            phaseDays: [],
            benefitOfferID: nil,
            benefitBaselineDay: nil,
            benefitBaseline: nil,
            aftermathQuality: .pending,
            aftermathStartDay: nil,
            resolvedDay: nil,
            selectedChoiceIDsBySlot: [:],
            completedActionIDs: [],
            reservedInventoryByItemID: [:],
            inventoryReservationReceipts: [],
            effectReceiptIDs: [],
            standingAwardReceiptID: nil,
            lastRelatedActionSerial: 0,
            warningOneEvidenceSerial: nil,
            warningOneEvidenceCheckSerial: nil,
            warningTwoEvidenceSerial: nil,
            warningOneSleepEpoch: nil,
            warningTwoSleepEpoch: nil
        )
    }

    mutating func enter(_ next: StoryPhase, day: Int) {
        phase = next
        if let index = phaseDays.firstIndex(where: { $0.phase == next }) {
            phaseDays[index].day = day
        } else {
            phaseDays.append(StoryPhaseDay(phase: next, day: day))
        }
        phaseDays.sort { $0.phase.order < $1.phase.order }
        if next == .aftermath {
            aftermathStartDay = day
        }
        if next == .resolved {
            resolvedDay = day
        }
    }

    func enteredDay(for phase: StoryPhase) -> Int? {
        phaseDays.first(where: { $0.phase == phase })?.day
    }
}

enum FrontstageOwner: String, Codable, CaseIterable, Sendable {
    case forcedTutorial = "forced_tutorial"
    case resumedSession = "resumed_session"
    case journey
    case finale
    case communityEvent = "community_event"
    case story
    case hint

    var priority: Int {
        switch self {
        case .forcedTutorial, .resumedSession: return 600
        case .journey, .finale: return 500
        case .communityEvent: return 400
        case .story: return 300
        case .hint: return 100
        }
    }
}

struct FrontstageLease: Equatable, Codable, Sendable {
    var leaseID: String
    var owner: FrontstageOwner
    var resourceID: String
    var acquiredDay: Int
    var checkpointID: String?

    enum CodingKeys: String, CodingKey {
        case leaseID = "lease_id"
        case owner
        case resourceID = "resource_id"
        case acquiredDay = "acquired_day"
        case checkpointID = "checkpoint_id"
    }
}

struct StoryRuntimeCursor: Equatable, Codable, Sendable {
    var eventID: String?
    var sceneID: String?
    var beatID: String?
    var lineID: String?
    var lineIndex: Int
    var cueID: String?
    var checkpointID: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case sceneID = "scene_id"
        case beatID = "beat_id"
        case lineID = "line_id"
        case lineIndex = "line_index"
        case cueID = "cue_id"
        case checkpointID = "checkpoint_id"
    }

    static let empty = StoryRuntimeCursor(
        eventID: nil,
        sceneID: nil,
        beatID: nil,
        lineID: nil,
        lineIndex: 0,
        cueID: nil,
        checkpointID: nil
    )
}

struct StoryChoiceRecord: Equatable, Codable, Sendable {
    var arcID: StoryArcID
    var slotID: StoryChoiceSlotID
    var choiceID: String
    var day: Int

    enum CodingKeys: String, CodingKey {
        case arcID = "arc_id"
        case slotID = "slot_id"
        case choiceID = "choice_id"
        case day
    }
}

struct StoryReceiptRecord: Equatable, Codable, Sendable {
    var receiptID: String
    var sourceID: String
    var day: Int

    enum CodingKeys: String, CodingKey {
        case receiptID = "receipt_id"
        case sourceID = "source_id"
        case day
    }
}

struct StoryInventoryReservationRecord: Equatable, Codable, Sendable {
    var receiptID: String
    var requestID: String
    var offerID: String
    var itemID: String
    var quantity: Int
    var day: Int

    enum CodingKeys: String, CodingKey {
        case receiptID = "receipt_id"
        case requestID = "request_id"
        case offerID = "offer_id"
        case itemID = "item_id"
        case quantity
        case day
    }
}

enum StoryMissionStatus: String, Codable, CaseIterable, Sendable {
    case prepared
    case travelling
    case returning
    case completed
}

enum StoryJourneyCheckpoint: String, Codable, CaseIterable, Sendable {
    case departure
    case oldWaterway = "old_waterway"
    case mistRidgeFork = "mist_ridge_fork"
    case greyFenceFarm = "grey_fence_farm"
    case homecoming
}

struct MissionShippingEntrySnapshot: Equatable, Codable, Sendable {
    var entryID: String
    var itemID: String
    var quantity: Int
    var unitPrice: Int

    enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
        case itemID = "item_id"
        case quantity
        case unitPrice = "unit_price"
    }
}

/// Deliberately finite Q08 state. Full rollback lives only in pre_mist_ridge.
struct StoryMissionSnapshot: Equatable, Codable, Sendable {
    var campaignID: String
    var missionInstanceID: String
    var startDay: Int
    var status: StoryMissionStatus
    var coveredCropCellIDs: [String]
    var protectedAnimalIDs: [String]
    var frozenOrderIDs: [String]
    var frozenDeadlineIDs: [String]
    var frozenOfferIDs: [String]
    var shippingEntries: [MissionShippingEntrySnapshot]
    var checkpoint: StoryJourneyCheckpoint
    var settlementReceiptID: String
    var canAbandonToProtection: Bool

    enum CodingKeys: String, CodingKey {
        case campaignID = "campaign_id"
        case missionInstanceID = "mission_instance_id"
        case startDay = "start_day"
        case status
        case coveredCropCellIDs = "covered_crop_cell_ids"
        case protectedAnimalIDs = "protected_animal_ids"
        case frozenOrderIDs = "frozen_order_ids"
        case frozenDeadlineIDs = "frozen_deadline_ids"
        case frozenOfferIDs = "frozen_offer_ids"
        case shippingEntries = "shipping_entries"
        case checkpoint
        case settlementReceiptID = "settlement_receipt_id"
        case canAbandonToProtection = "can_abandon_to_protection"
    }
}

struct StoryProtectionState: Equatable, Codable, Sendable {
    var preMistRidgeVerified: Bool
    var preRevealVerified: Bool
    var orphanProtectionDiagnostics: [String]

    enum CodingKeys: String, CodingKey {
        case preMistRidgeVerified = "pre_mist_ridge_verified"
        case preRevealVerified = "pre_reveal_verified"
        case orphanProtectionDiagnostics = "orphan_protection_diagnostics"
    }

    static let empty = StoryProtectionState(
        preMistRidgeVerified: false,
        preRevealVerified: false,
        orphanProtectionDiagnostics: []
    )
}

struct StoryGalleryState: Equatable, Codable, Sendable {
    var isUnlocked: Bool
    var discoveredLedgerPageIDs: [String]
    var discoveredAnnotationIDs: [String]
    var keepsakeIDs: [String]
    var endingID: String?

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case discoveredLedgerPageIDs = "discovered_ledger_page_ids"
        case discoveredAnnotationIDs = "discovered_annotation_ids"
        case keepsakeIDs = "keepsake_ids"
        case endingID = "ending_id"
    }

    static let locked = StoryGalleryState(
        isUnlocked: false,
        discoveredLedgerPageIDs: [],
        discoveredAnnotationIDs: [],
        keepsakeIDs: [],
        endingID: nil
    )
}

struct StoryCampaignState: Equatable, Codable, Sendable {
    var segments: [StorySegmentState]
    var finaleBeat: FinaleBeat
    var finaleBeatDay: Int?
    var cursor: StoryRuntimeCursor
    var frontstageLease: FrontstageLease?
    var choices: [StoryChoiceRecord]
    var actionReceipts: [StoryReceiptRecord]
    var effectReceipts: [StoryReceiptRecord]
    var romanceTender: Bool
    var q06Outcome: StoryQ06Outcome?
    var mission: StoryMissionSnapshot?
    var q08Completed: Bool
    var protection: StoryProtectionState
    var m3OffersPaused: Bool
    var repairCommissionIDs: [String]
    var gallery: StoryGalleryState
    var communityEvaluationDisabled: Bool
    /// Active multi-speaker story dialogue. Optional so older v10 saves keep
    /// decoding; a nil value simply means no session is open.
    var dialogueSession: StoryDialogueSession?

    enum CodingKeys: String, CodingKey {
        case segments
        case finaleBeat = "finale_beat"
        case finaleBeatDay = "finale_beat_day"
        case cursor
        case frontstageLease = "frontstage_lease"
        case choices
        case actionReceipts = "action_receipts"
        case effectReceipts = "effect_receipts"
        case romanceTender = "romance_tender"
        case q06Outcome = "q06_outcome"
        case mission
        case q08Completed = "q08_completed"
        case protection
        case m3OffersPaused = "m3_offers_paused"
        case repairCommissionIDs = "repair_commission_ids"
        case gallery
        case communityEvaluationDisabled = "community_evaluation_disabled"
        case dialogueSession = "dialogue_session"
    }

    static let newGame = StoryCampaignState(
        segments: [
            .locked(.q01), .locked(.q02), .locked(.q03), .locked(.q04),
            .locked(.q05), .locked(.q06), .locked(.q07), .locked(.q08),
        ],
        finaleBeat: .locked,
        finaleBeatDay: nil,
        cursor: .empty,
        frontstageLease: nil,
        choices: [],
        actionReceipts: [],
        effectReceipts: [],
        romanceTender: false,
        q06Outcome: nil,
        mission: nil,
        q08Completed: false,
        protection: .empty,
        m3OffersPaused: false,
        repairCommissionIDs: [],
        gallery: .locked,
        communityEvaluationDisabled: false,
        dialogueSession: nil
    )

    func segment(_ arcID: StoryArcID) -> StorySegmentState? {
        segments.first { $0.arcID == arcID }
    }

    mutating func updateSegment(_ segment: StorySegmentState) {
        if let index = segments.firstIndex(where: { $0.arcID == segment.arcID }) {
            segments[index] = segment
        } else {
            segments.append(segment)
        }
        segments.sort { $0.arcID.sequence < $1.arcID.sequence }
    }

    mutating func canonicalize() {
        for index in segments.indices {
            segments[index].phaseDays.sort { $0.phase.order < $1.phase.order }
            segments[index].completedActionIDs = Array(
                Set(segments[index].completedActionIDs)
            ).sorted()
            segments[index].effectReceiptIDs = Array(
                Set(segments[index].effectReceiptIDs)
            ).sorted()
            segments[index].inventoryReservationReceipts.sort {
                $0.receiptID < $1.receiptID
            }
        }
        segments.sort { $0.arcID.sequence < $1.arcID.sequence }
        choices.sort {
            if $0.arcID.sequence != $1.arcID.sequence {
                return $0.arcID.sequence < $1.arcID.sequence
            }
            if $0.slotID.rawValue != $1.slotID.rawValue {
                return $0.slotID.rawValue < $1.slotID.rawValue
            }
            return $0.choiceID < $1.choiceID
        }
        actionReceipts.sort { $0.receiptID < $1.receiptID }
        effectReceipts.sort { $0.receiptID < $1.receiptID }
        repairCommissionIDs = Array(Set(repairCommissionIDs)).sorted()
        protection.orphanProtectionDiagnostics = Array(
            Set(protection.orphanProtectionDiagnostics)
        ).sorted()
        gallery.discoveredLedgerPageIDs = Array(Set(gallery.discoveredLedgerPageIDs)).sorted()
        gallery.discoveredAnnotationIDs = Array(Set(gallery.discoveredAnnotationIDs)).sorted()
        gallery.keepsakeIDs = Array(Set(gallery.keepsakeIDs)).sorted()
        if mission != nil {
            mission?.coveredCropCellIDs.sort()
            mission?.protectedAnimalIDs.sort()
            mission?.frozenOrderIDs.sort()
            mission?.frozenDeadlineIDs.sort()
            mission?.frozenOfferIDs.sort()
            mission?.shippingEntries.sort { $0.entryID < $1.entryID }
        }
    }
}

enum StoryInventoryReservation {
    /// Every inventory-consuming domain transaction calls this against its
    /// candidate inventory, keeping Q07's accepted celebration stock intact.
    static func isPreserved(state: GameState, candidateInventory: [InventoryQuantity]) -> Bool {
        guard let reservation = state.storyCampaign.segment(.q07)?.reservedInventoryByItemID,
              !reservation.isEmpty else { return true }
        return reservation.allSatisfy { itemID, quantity in
            InventoryService.count(candidateInventory, itemID: itemID) >= quantity
        }
    }
}
