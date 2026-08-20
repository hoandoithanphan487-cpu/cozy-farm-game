import Foundation

/// Named save slots for M4-001 multi-slot persistence.
enum SaveSlotCatalog {
    static let manualSlotNames = ["slot_manual_1", "slot_manual_2", "slot_manual_3"]
    static let autoSlotName = "slot_auto"
    /// Pre-M4 default single slot; load falls back here when a manual slot is empty.
    static let legacyDefaultSlot = "slot_0"

    static func manualSlotName(index: Int) -> String {
        let clamped = ((index % manualSlotNames.count) + manualSlotNames.count) % manualSlotNames.count
        return manualSlotNames[clamped]
    }

    static func displayLabel(for slotName: String) -> String {
        switch slotName {
        case manualSlotNames[0]: return "手动槽 1"
        case manualSlotNames[1]: return "手动槽 2"
        case manualSlotNames[2]: return "手动槽 3"
        case autoSlotName: return "自动槽（最近睡眠）"
        case legacyDefaultSlot: return "旧版槽 slot_0"
        default: return slotName
        }
    }

    static func allKnownSlotNamesIncludingLegacy() -> [String] {
        manualSlotNames + [autoSlotName, legacyDefaultSlot]
    }
}
