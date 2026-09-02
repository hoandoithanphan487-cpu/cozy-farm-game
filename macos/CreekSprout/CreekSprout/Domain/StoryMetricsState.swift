import Foundation

struct StoryMetricBaseline: Equatable, Codable, Sendable {
    var growingCropCount: Int
    var plantedCellCount: Int
    var maxGrowingCropCount: Int
    var seedBenefitPlantedCells: Int
    var catShopReceiptCount: Int
    var premiumReceiptCount: Int
    var prepaymentCount: Int
    var livestockCount: Int
    var inventoryInvestmentUnits: Int

    enum CodingKeys: String, CodingKey {
        case growingCropCount = "growing_crop_count"
        case plantedCellCount = "planted_cell_count"
        case maxGrowingCropCount = "max_growing_crop_count"
        case seedBenefitPlantedCells = "seed_benefit_planted_cells"
        case catShopReceiptCount = "cat_shop_receipt_count"
        case premiumReceiptCount = "premium_receipt_count"
        case prepaymentCount = "prepayment_count"
        case livestockCount = "livestock_count"
        case inventoryInvestmentUnits = "inventory_investment_units"
    }

    static let zero = StoryMetricBaseline(
        growingCropCount: 0,
        plantedCellCount: 0,
        maxGrowingCropCount: 0,
        seedBenefitPlantedCells: 0,
        catShopReceiptCount: 0,
        premiumReceiptCount: 0,
        prepaymentCount: 0,
        livestockCount: 0,
        inventoryInvestmentUnits: 0
    )
}

struct StoryAnimalSupplyHistory: Equatable, Codable, Sendable {
    var animalID: String
    var definitionID: String
    var ageDays: Int
    var careDays: Int
    var receiptID: String

    enum CodingKeys: String, CodingKey {
        case animalID = "animal_id"
        case definitionID = "definition_id"
        case ageDays = "age_days"
        case careDays = "care_days"
        case receiptID = "receipt_id"
    }
}

/// Append-only, source-backed counters used by StoryMaturityService. Every
/// mutation is guarded by a unique source receipt so reload/retry is a no-op.
struct StoryMetricsState: Equatable, Codable, Sendable {
    var recordedSourceIDs: [String]
    var tilledCellCount: Int
    var clearedWitheredCellCount: Int
    var manualWaterCellDays: Int
    var automaticWaterCellDays: Int
    var automaticWaterSleepDays: [Int]
    var temporaryCanalBenefitDays: [Int]
    var formalCanalBenefitDays: [Int]
    var plantedCellCount: Int
    var plantedCellsByCropID: [String: Int]
    var harvestedCropCount: Int
    var maxGrowingCropCount: Int
    var harvestsByCropID: [String: Int]
    var completedCyclesByCropID: [String: Int]
    var deliveriesByCropID: [String: Int]
    var deliveryRecipientIDs: [String]
    var deliveryRecipientIDsByCropID: [String: [String]]
    var premiumBenefitDays: [Int]
    var seedBenefitUses: Int
    var seedBenefitPlantedCells: Int
    var npcTalkDays: [String: [Int]]
    var npcHelpCounts: [String: Int]
    var npcCollaborationCounts: [String: Int]
    var uniqueHelpActionIDs: [String]
    var uniqueCollaborationActionIDs: [String]
    var relationshipConflictDays: [Int]
    var catShopOpened: Bool
    var catShopReceiptIDs: [String]
    var catShopCropReceiptIDs: [String]
    var catShopAnimalReceiptIDs: [String]
    var catShopPremiumReceiptIDs: [String]
    var catShopPrepaymentReceiptIDs: [String]
    /// Causal story offer that was active when a real cat-shop transaction
    /// committed. Receipt IDs not produced by CatShopSupplyService are invalid.
    var catShopReceiptOfferSourceIDs: [String: String]
    var catShopBuyerIDs: [String]
    var catShopOfferIDs: [String]
    var livestockCareDays: [String: [Int]]
    var animalsGrownToAdultIDs: [String]
    var animalSupplyHistory: [StoryAnimalSupplyHistory]
    var fosterIssuanceIDs: [String]
    var repairCommissionIDs: [String]
    var quietDays: [Int]
    var aftermathDaysByArcID: [String: [Int]]
    var relatedActionSerials: [String: Int]
    var anchorReentrySerials: [String: Int]
    var evidenceCheckSerials: [String: Int]
    var dailyMetricDays: [Int]
    var lastMajorConflictDay: Int?
    var lastFrontstageEventDay: Int?

    enum CodingKeys: String, CodingKey {
        case recordedSourceIDs = "recorded_source_ids"
        case tilledCellCount = "tilled_cell_count"
        case clearedWitheredCellCount = "cleared_withered_cell_count"
        case manualWaterCellDays = "manual_water_cell_days"
        case automaticWaterCellDays = "automatic_water_cell_days"
        case automaticWaterSleepDays = "automatic_water_sleep_days"
        case temporaryCanalBenefitDays = "temporary_canal_benefit_days"
        case formalCanalBenefitDays = "formal_canal_benefit_days"
        case plantedCellCount = "planted_cell_count"
        case plantedCellsByCropID = "planted_cells_by_crop_id"
        case harvestedCropCount = "harvested_crop_count"
        case maxGrowingCropCount = "max_growing_crop_count"
        case harvestsByCropID = "harvests_by_crop_id"
        case completedCyclesByCropID = "completed_cycles_by_crop_id"
        case deliveriesByCropID = "deliveries_by_crop_id"
        case deliveryRecipientIDs = "delivery_recipient_ids"
        case deliveryRecipientIDsByCropID = "delivery_recipient_ids_by_crop_id"
        case premiumBenefitDays = "premium_benefit_days"
        case seedBenefitUses = "seed_benefit_uses"
        case seedBenefitPlantedCells = "seed_benefit_planted_cells"
        case npcTalkDays = "npc_talk_days"
        case npcHelpCounts = "npc_help_counts"
        case npcCollaborationCounts = "npc_collaboration_counts"
        case uniqueHelpActionIDs = "unique_help_action_ids"
        case uniqueCollaborationActionIDs = "unique_collaboration_action_ids"
        case relationshipConflictDays = "relationship_conflict_days"
        case catShopOpened = "cat_shop_opened"
        case catShopReceiptIDs = "cat_shop_receipt_ids"
        case catShopCropReceiptIDs = "cat_shop_crop_receipt_ids"
        case catShopAnimalReceiptIDs = "cat_shop_animal_receipt_ids"
        case catShopPremiumReceiptIDs = "cat_shop_premium_receipt_ids"
        case catShopPrepaymentReceiptIDs = "cat_shop_prepayment_receipt_ids"
        case catShopReceiptOfferSourceIDs = "cat_shop_receipt_offer_source_ids"
        case catShopBuyerIDs = "cat_shop_buyer_ids"
        case catShopOfferIDs = "cat_shop_offer_ids"
        case livestockCareDays = "livestock_care_days"
        case animalsGrownToAdultIDs = "animals_grown_to_adult_ids"
        case animalSupplyHistory = "animal_supply_history"
        case fosterIssuanceIDs = "foster_issuance_ids"
        case repairCommissionIDs = "repair_commission_ids"
        case quietDays = "quiet_days"
        case aftermathDaysByArcID = "aftermath_days_by_arc_id"
        case relatedActionSerials = "related_action_serials"
        case anchorReentrySerials = "anchor_reentry_serials"
        case evidenceCheckSerials = "evidence_check_serials"
        case dailyMetricDays = "daily_metric_days"
        case lastMajorConflictDay = "last_major_conflict_day"
        case lastFrontstageEventDay = "last_frontstage_event_day"
    }

    static let empty = StoryMetricsState(
        recordedSourceIDs: [],
        tilledCellCount: 0,
        clearedWitheredCellCount: 0,
        manualWaterCellDays: 0,
        automaticWaterCellDays: 0,
        automaticWaterSleepDays: [],
        temporaryCanalBenefitDays: [],
        formalCanalBenefitDays: [],
        plantedCellCount: 0,
        plantedCellsByCropID: [:],
        harvestedCropCount: 0,
        maxGrowingCropCount: 0,
        harvestsByCropID: [:],
        completedCyclesByCropID: [:],
        deliveriesByCropID: [:],
        deliveryRecipientIDs: [],
        deliveryRecipientIDsByCropID: [:],
        premiumBenefitDays: [],
        seedBenefitUses: 0,
        seedBenefitPlantedCells: 0,
        npcTalkDays: [:],
        npcHelpCounts: [:],
        npcCollaborationCounts: [:],
        uniqueHelpActionIDs: [],
        uniqueCollaborationActionIDs: [],
        relationshipConflictDays: [],
        catShopOpened: false,
        catShopReceiptIDs: [],
        catShopCropReceiptIDs: [],
        catShopAnimalReceiptIDs: [],
        catShopPremiumReceiptIDs: [],
        catShopPrepaymentReceiptIDs: [],
        catShopReceiptOfferSourceIDs: [:],
        catShopBuyerIDs: [],
        catShopOfferIDs: [],
        livestockCareDays: [:],
        animalsGrownToAdultIDs: [],
        animalSupplyHistory: [],
        fosterIssuanceIDs: [],
        repairCommissionIDs: [],
        quietDays: [],
        aftermathDaysByArcID: [:],
        relatedActionSerials: [:],
        anchorReentrySerials: [:],
        evidenceCheckSerials: [:],
        dailyMetricDays: [],
        lastMajorConflictDay: nil,
        lastFrontstageEventDay: nil
    )

    @discardableResult
    mutating func claimSource(_ sourceID: String) -> Bool {
        guard ContentID.isValid(sourceID),
              recordedSourceIDs.count < 10_000_000,
              !recordedSourceIDs.contains(sourceID) else { return false }
        recordedSourceIDs.append(sourceID)
        recordedSourceIDs.sort()
        return true
    }

    mutating func canonicalize() {
        recordedSourceIDs = Array(Set(recordedSourceIDs)).sorted()
        automaticWaterSleepDays = Array(Set(automaticWaterSleepDays)).sorted()
        temporaryCanalBenefitDays = Array(Set(temporaryCanalBenefitDays)).sorted()
        formalCanalBenefitDays = Array(Set(formalCanalBenefitDays)).sorted()
        deliveryRecipientIDs = Array(Set(deliveryRecipientIDs)).sorted()
        premiumBenefitDays = Array(Set(premiumBenefitDays)).sorted()
        relationshipConflictDays = Array(Set(relationshipConflictDays)).sorted()
        catShopReceiptIDs = Array(Set(catShopReceiptIDs)).sorted()
        catShopCropReceiptIDs = Array(Set(catShopCropReceiptIDs)).sorted()
        catShopAnimalReceiptIDs = Array(Set(catShopAnimalReceiptIDs)).sorted()
        catShopPremiumReceiptIDs = Array(Set(catShopPremiumReceiptIDs)).sorted()
        catShopPrepaymentReceiptIDs = Array(Set(catShopPrepaymentReceiptIDs)).sorted()
        catShopBuyerIDs = Array(Set(catShopBuyerIDs)).sorted()
        catShopOfferIDs = Array(Set(catShopOfferIDs)).sorted()
        animalsGrownToAdultIDs = Array(Set(animalsGrownToAdultIDs)).sorted()
        fosterIssuanceIDs = Array(Set(fosterIssuanceIDs)).sorted()
        repairCommissionIDs = Array(Set(repairCommissionIDs)).sorted()
        uniqueHelpActionIDs = Array(Set(uniqueHelpActionIDs)).sorted()
        uniqueCollaborationActionIDs = Array(Set(uniqueCollaborationActionIDs)).sorted()
        quietDays = Array(Set(quietDays)).sorted()
        dailyMetricDays = Array(Set(dailyMetricDays)).sorted()
        for key in deliveryRecipientIDsByCropID.keys {
            deliveryRecipientIDsByCropID[key] = Array(
                Set(deliveryRecipientIDsByCropID[key] ?? [])
            ).sorted()
        }
        for key in npcTalkDays.keys {
            npcTalkDays[key] = Array(Set(npcTalkDays[key] ?? [])).sorted()
        }
        for key in livestockCareDays.keys {
            livestockCareDays[key] = Array(Set(livestockCareDays[key] ?? [])).sorted()
        }
        for key in aftermathDaysByArcID.keys {
            aftermathDaysByArcID[key] = Array(Set(aftermathDaysByArcID[key] ?? [])).sorted()
        }
        animalSupplyHistory.sort { $0.receiptID < $1.receiptID }
    }
}

enum StoryMetricsRecorder {
    private static let maximumCounter = 10_000_000

    private static func canAdd(_ delta: Int, to current: Int) -> Bool {
        guard delta >= 0, current >= 0 else { return false }
        let (result, overflow) = current.addingReportingOverflow(delta)
        return !overflow && result <= maximumCounter
    }

    static func recordTilling(
        metrics: inout StoryMetricsState,
        sourceID: String,
        clearedWithered: Bool
    ) {
        guard canAdd(1, to: metrics.tilledCellCount),
              !clearedWithered || canAdd(1, to: metrics.clearedWitheredCellCount) else {
            return
        }
        guard metrics.claimSource(sourceID) else { return }
        metrics.tilledCellCount += 1
        if clearedWithered {
            metrics.clearedWitheredCellCount += 1
        }
    }

    static func recordManualWater(
        metrics: inout StoryMetricsState,
        sourceID: String,
        cellDays: Int
    ) {
        guard cellDays > 0,
              canAdd(cellDays, to: metrics.manualWaterCellDays),
              metrics.claimSource(sourceID) else { return }
        metrics.manualWaterCellDays += cellDays
    }

    static func recordAutomaticWater(
        metrics: inout StoryMetricsState,
        sourceID: String,
        day: Int,
        cellDays: Int,
        isFormal: Bool
    ) {
        guard day >= 1,
              cellDays > 0,
              canAdd(cellDays, to: metrics.automaticWaterCellDays),
              metrics.claimSource(sourceID) else { return }
        metrics.automaticWaterCellDays += cellDays
        metrics.automaticWaterSleepDays.append(day)
        if isFormal {
            metrics.formalCanalBenefitDays.append(day)
        } else {
            metrics.temporaryCanalBenefitDays.append(day)
        }
        metrics.canonicalize()
    }

    static func recordPlant(
        metrics: inout StoryMetricsState,
        sourceID: String,
        cropID: String,
        growingCropCount: Int,
        usedSeedBenefit: Bool
    ) {
        guard growingCropCount >= 0,
              canAdd(1, to: metrics.plantedCellCount),
              canAdd(1, to: metrics.plantedCellsByCropID[cropID, default: 0]),
              !usedSeedBenefit || (
                  canAdd(1, to: metrics.seedBenefitUses)
                      && canAdd(1, to: metrics.seedBenefitPlantedCells)
              ),
              metrics.claimSource(sourceID) else { return }
        metrics.plantedCellCount += 1
        metrics.plantedCellsByCropID[cropID, default: 0] += 1
        metrics.maxGrowingCropCount = max(metrics.maxGrowingCropCount, growingCropCount)
        if usedSeedBenefit {
            metrics.seedBenefitUses += 1
            metrics.seedBenefitPlantedCells += 1
        }
    }

    static func recordHarvest(
        metrics: inout StoryMetricsState,
        sourceID: String,
        cropID: String
    ) {
        guard canAdd(1, to: metrics.harvestedCropCount),
              canAdd(1, to: metrics.harvestsByCropID[cropID, default: 0]),
              canAdd(1, to: metrics.completedCyclesByCropID[cropID, default: 0]),
              metrics.claimSource(sourceID) else { return }
        metrics.harvestedCropCount += 1
        metrics.harvestsByCropID[cropID, default: 0] += 1
        metrics.completedCyclesByCropID[cropID, default: 0] += 1
    }

    static func recordTalk(
        metrics: inout StoryMetricsState,
        sourceID: String,
        npcID: String,
        day: Int
    ) {
        guard day >= 1, metrics.claimSource(sourceID) else { return }
        metrics.npcTalkDays[npcID, default: []].append(day)
        metrics.canonicalize()
    }

    static func recordRelatedAction(
        metrics: inout StoryMetricsState,
        sourceID: String,
        arcID: StoryArcID,
        anchorReentry: Bool = false,
        evidenceCheck: Bool = false
    ) {
        let key = arcID.rawValue
        guard canAdd(1, to: metrics.relatedActionSerials[key, default: 0]),
              !anchorReentry || canAdd(1, to: metrics.anchorReentrySerials[key, default: 0]),
              !evidenceCheck || canAdd(1, to: metrics.evidenceCheckSerials[key, default: 0]),
              metrics.claimSource(sourceID) else { return }
        metrics.relatedActionSerials[key, default: 0] += 1
        if anchorReentry {
            metrics.anchorReentrySerials[key, default: 0] += 1
        }
        if evidenceCheck {
            metrics.evidenceCheckSerials[key, default: 0] += 1
        }
    }

    static func recordDailySnapshot(
        metrics: inout StoryMetricsState,
        sourceID: String,
        day: Int,
        growingCropCount: Int
    ) {
        guard day >= 1, growingCropCount >= 0, metrics.claimSource(sourceID) else { return }
        metrics.dailyMetricDays.append(day)
        metrics.maxGrowingCropCount = max(metrics.maxGrowingCropCount, growingCropCount)
        metrics.canonicalize()
    }

    static func recordUniqueHelp(
        metrics: inout StoryMetricsState,
        sourceID: String,
        actionID: String,
        npcID: String,
        isCollaboration: Bool
    ) {
        if isCollaboration {
            guard !metrics.uniqueCollaborationActionIDs.contains(actionID) else { return }
            guard canAdd(1, to: metrics.npcCollaborationCounts[npcID, default: 0]) else { return }
            guard metrics.claimSource(sourceID) else { return }
            metrics.uniqueCollaborationActionIDs.append(actionID)
            metrics.npcCollaborationCounts[npcID, default: 0] += 1
        } else {
            guard !metrics.uniqueHelpActionIDs.contains(actionID) else { return }
            guard canAdd(1, to: metrics.npcHelpCounts[npcID, default: 0]) else { return }
            guard metrics.claimSource(sourceID) else { return }
            metrics.uniqueHelpActionIDs.append(actionID)
            metrics.npcHelpCounts[npcID, default: 0] += 1
        }
        metrics.canonicalize()
    }

    static func recordSettledDay(
        metrics: inout StoryMetricsState,
        sourceID: String,
        day: Int,
        campaign: StoryCampaignState,
        hadMajorConflict: Bool
    ) {
        guard day >= 1, metrics.claimSource(sourceID) else { return }
        metrics.dailyMetricDays.append(day)
        if hadMajorConflict {
            metrics.lastMajorConflictDay = day
            metrics.relationshipConflictDays.append(day)
        } else {
            metrics.quietDays.append(day)
        }
        for segment in campaign.segments where segment.phase == .aftermath {
            metrics.aftermathDaysByArcID[segment.arcID.rawValue, default: []].append(day)
        }
        metrics.canonicalize()
    }
}
