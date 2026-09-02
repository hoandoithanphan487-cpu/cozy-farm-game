import Foundation

enum SaveGenerationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case campaignAuto = "campaign_auto"
    case missionCurrent = "mission_current"
    case preMistRidge = "pre_mist_ridge"
    case preReveal = "pre_reveal"
    case legacy

    var participatesInAutomaticContinue: Bool {
        switch self {
        case .manual, .campaignAuto, .missionCurrent: return true
        case .preMistRidge, .preReveal, .legacy: return false
        }
    }

    var isProtection: Bool {
        self == .preMistRidge || self == .preReveal
    }
}

/// The physical location of a save generation carries authority that the JSON
/// payload cannot grant to itself. Callers that know that authority provide an
/// expectation so a valid-but-misplaced generation is ignored just like a
/// corrupt generation.
struct SaveGenerationExpectation: Equatable, Sendable {
    var campaignID: String?
    var ownerManualSlot: String?
    var generationKinds: Set<SaveGenerationKind>?

    init(
        campaignID: String? = nil,
        ownerManualSlot: String? = nil,
        generationKinds: Set<SaveGenerationKind>? = nil
    ) {
        self.campaignID = campaignID
        self.ownerManualSlot = ownerManualSlot
        self.generationKinds = generationKinds
    }

    func accepts(_ metadata: SaveGenerationMetadata) -> Bool {
        if let campaignID, metadata.campaignID != campaignID {
            return false
        }
        if let ownerManualSlot, metadata.ownerManualSlot != ownerManualSlot {
            return false
        }
        if let generationKinds, !generationKinds.contains(metadata.generationKind) {
            return false
        }
        return true
    }
}

struct SaveGenerationMetadata: Equatable, Codable, Sendable {
    var campaignID: String
    var ownerManualSlot: String
    var generationKind: SaveGenerationKind
    var saveSequence: Int
    var writtenAtMilliseconds: Int64

    enum CodingKeys: String, CodingKey {
        case campaignID = "campaign_id"
        case ownerManualSlot = "owner_manual_slot"
        case generationKind = "generation_kind"
        case saveSequence = "save_sequence"
        case writtenAtMilliseconds = "written_at_milliseconds"
    }

    static func neutral(campaignID: String, sourceSlotName: String) -> SaveGenerationMetadata {
        SaveGenerationMetadata(
            campaignID: campaignID,
            ownerManualSlot: sourceSlotName,
            generationKind: .legacy,
            saveSequence: 0,
            writtenAtMilliseconds: 0
        )
    }

    /// Structural checks shared by every SaveStore, including generic stores
    /// that have no location expectation. Legacy generations are deliberately
    /// sequence-neutral; otherwise copied legacy files could outrank verified
    /// campaign generations during Continue selection.
    var isStructurallyValid: Bool {
        guard ContentID.isValid(campaignID),
              campaignID.hasPrefix("brookseed.campaign."),
              Self.isSafeSlotToken(ownerManualSlot) else {
            return false
        }
        switch generationKind {
        case .legacy:
            return saveSequence == 0 && writtenAtMilliseconds == 0
        case .manual, .campaignAuto, .missionCurrent, .preMistRidge, .preReveal:
            return SaveSlotCatalog.manualSlotNames.contains(ownerManualSlot)
                && saveSequence > 0
                && writtenAtMilliseconds > 0
        }
    }

    private static func isSafeSlotToken(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 120 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 48...57, 65...90, 95, 97...122:
                return true
            default:
                return false
            }
        }
    }
}

struct SaveGeneration: Equatable, Sendable {
    var state: GameState
    var metadata: SaveGenerationMetadata
}

struct SaveMigrationContext: Equatable, Sendable {
    var sourceSlotName: String

    static let unspecified = SaveMigrationContext(sourceSlotName: "slot_0")
}

enum CampaignIdentity {
    static let placeholder = "brookseed.campaign.c_unassigned"

    static func make() -> String {
        let normalized = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "brookseed.campaign.c_\(normalized)"
    }

    /// Stable across repeated migration of the same legacy bytes from the same
    /// owner slot. FNV-1a is used only as a deterministic identity digest, not
    /// for security or corruption detection.
    static func legacy(data: Data, context: SaveMigrationContext) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in context.sourceSlotName.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        hash ^= 0xff
        hash &*= 1_099_511_628_211
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "brookseed.campaign.legacy_\(String(hash, radix: 16))"
    }
}
