import Foundation

struct StoryMaturityResult: Equatable, Sendable {
    var isMature: Bool
    var missingConditionIDs: [String]
}

enum StoryMaturityService {
    static func baseline(for state: GameState) -> StoryMetricBaseline {
        let growing = state.farmCells.values.filter(\.isGrowingCrop).count
        return StoryMetricBaseline(
            growingCropCount: growing,
            plantedCellCount: state.storyMetrics.plantedCellCount,
            maxGrowingCropCount: max(state.storyMetrics.maxGrowingCropCount, growing),
            seedBenefitPlantedCells: state.storyMetrics.seedBenefitPlantedCells,
            catShopReceiptCount: state.storyMetrics.catShopReceiptIDs.count,
            premiumReceiptCount: state.storyMetrics.catShopPremiumReceiptIDs.count,
            prepaymentCount: state.storyMetrics.catShopPrepaymentReceiptIDs.count,
            livestockCount: state.livestock.animals.count,
            inventoryInvestmentUnits: state.inventory.reduce(into: 0) { total, stack in
                let (next, overflow) = total.addingReportingOverflow(stack.quantity)
                total = overflow ? 10_000_001 : min(next, 10_000_001)
            }
        )
    }

    static func evaluate(
        _ arcID: StoryArcID,
        state: GameState,
        catalog: ContentCatalog = .vs0
    ) -> StoryMaturityResult {
        var missing: [String] = []
        func require(_ value: @autoclosure () -> Bool, _ id: String) {
            if !value() { missing.append(id) }
        }
        let metrics = state.storyMetrics
        let segment = state.storyCampaign.segment(arcID)
        let baseline = segment?.benefitBaseline
        let growing = state.farmCells.values.filter(\.isGrowingCrop).count
        let noFrontstageCrisis = state.community.activeEvents.isEmpty
            && !state.storyCampaign.segments.contains(where: { $0.phase == .eruption })

        switch arcID {
        case .q01:
            require(
                state.tutorial.completedStepIDs.count >= ContentID.tutorialStepIDs.count - 1,
                "q01.tutorial_farm_complete"
            )
            require(metrics.completedCyclesByCropID.values.reduce(0, +) >= 2, "q01.crop_cycles_2")
            require(metrics.manualWaterCellDays >= 30, "q01.manual_water_30")
            require(
                containsConsecutiveRun(metrics.temporaryCanalBenefitDays, count: 4),
                "q01.temporary_canal_days_4"
            )
            let baselineGrowing = baseline?.growingCropCount ?? Int.max
            require(
                increased(growing, over: baselineGrowing, by: 6),
                "q01.causal_expansion_6"
            )
            require(growing > 0, "q01.growing_crop_present")
            require(noFrontstageCrisis, "q01.no_frontstage_event")
        case .q02:
            require(isResolved(.q01, state), "q02.q01_resolved")
            require(
                containsConsecutiveRun(metrics.formalCanalBenefitDays, count: 5),
                "q02.formal_canal_days_5"
            )
            require(metrics.automaticWaterCellDays >= 30, "q02.auto_water_30")
            require(metrics.automaticWaterSleepDays.count >= 3, "q02.auto_sleep_days_3")
            let baselineGrowing = baseline?.growingCropCount ?? Int.max
            let requiredExpansion = max(
                1,
                (baselineGrowing / 10) * 3 + ((baselineGrowing % 10) * 3 + 9) / 10
            )
            require(
                increased(growing, over: baselineGrowing, by: requiredExpansion),
                "q02.causal_area_expansion_30_percent"
            )
            require(hasHighValueCropMaturing(within: 2, state: state, catalog: catalog), "q02.high_value_crop_due_2")
            require(previousAftermathDays(.q01, state) >= 2, "q02.q01_aftermath_2")
            require(noFrontstageCrisis, "q02.no_frontstage_event")
        case .q03:
            require(isResolved(.q02, state), "q03.q02_resolved")
            require(metrics.completedCyclesByCropID[ContentID.bellBerryCrop, default: 0] >= 2, "q03.bell_berry_cycles_2")
            require(
                metrics.deliveryRecipientIDsByCropID[ContentID.bellBerryCrop, default: []].count >= 3,
                "q03.distinct_recipients_3"
            )
            require(
                containsConsecutiveSettledRun(
                    metrics.premiumBenefitDays,
                    settledDays: metrics.dailyMetricDays,
                    count: 3
                ),
                "q03.consecutive_premium_days_3"
            )
            let held = InventoryService.count(state.inventory, itemID: ContentID.bellBerryItem)
            let planted = state.farmCells.values.filter { $0.cropID == ContentID.bellBerryCrop }.count
            require(held + planted >= 6, "q03.bell_berry_stake_6")
            require(noFrontstageCrisis, "q03.no_frontstage_event")
        case .q04:
            require(isResolved(.q03, state), "q04.q03_resolved")
            require(
                metrics.completedCyclesByCropID.values.filter { $0 >= 2 }.count >= 2,
                "q04.two_crop_types_two_cycles"
            )
            require(metrics.seedBenefitUses >= 3, "q04.seed_benefit_uses_3")
            let seedBaseline = baseline?.seedBenefitPlantedCells ?? Int.max
            require(
                increased(metrics.seedBenefitPlantedCells, over: seedBaseline, by: 8),
                "q04.causal_seed_cells_8"
            )
            require(growing > 0, "q04.immature_batch_present")
            require(previousAftermathDays(.q03, state) >= 2, "q04.q03_aftermath_2")
            require(noFrontstageCrisis, "q04.no_frontstage_event")
        case .q05:
            require(isResolved(.q04, state), "q05.q04_resolved")
            require(metrics.catShopOpened, "q05.cat_shop_open")
            require(metrics.catShopCropReceiptIDs.count >= 5, "q05.normal_supply_5")
            require(metrics.catShopPremiumReceiptIDs.count >= 3, "q05.premium_settlement_3")
            require(metrics.deliveriesByCropID[ContentID.honeyMelonCrop, default: 0] >= 1, "q05.honey_melon_delivered")
            let plantedBaseline = baseline?.plantedCellCount ?? Int.max
            let livestockBaseline = baseline?.livestockCount ?? Int.max
            require(
                increased(metrics.plantedCellCount, over: plantedBaseline, by: 8)
                    || increased(state.livestock.animals.count, over: livestockBaseline, by: 1),
                "q05.causal_investment"
            )
            require(noFrontstageCrisis, "q05.no_frontstage_event")
        case .q06:
            require(isResolved(.q05, state), "q06.q05_resolved")
            for npcID in [ContentID.neighborEvidence, ContentID.neighborConsensus] {
                require(metrics.npcTalkDays[npcID, default: []].count >= 6, "q06.talk_6.\(npcID)")
                require(metrics.npcHelpCounts[npcID, default: 0] >= 2, "q06.help_2.\(npcID)")
                require(metrics.npcCollaborationCounts[npcID, default: 0] >= 2, "q06.collab_2.\(npcID)")
            }
            require(
                hasTrailingSettledDays(metrics.quietDays, count: 4, currentDay: state.clock.day),
                "q06.conflict_free_days_4"
            )
            require(noFrontstageCrisis, "q06.no_frontstage_event")
        case .q07:
            for prior in [StoryArcID.q01, .q02, .q03, .q04, .q05, .q06] {
                require(isResolved(prior, state), "q07.prior_resolved.\(prior.rawValue)")
            }
            require(metrics.catShopCropReceiptIDs.count >= 5, "q07.crop_receipts_5")
            require(metrics.catShopAnimalReceiptIDs.count >= 1, "q07.animal_receipt_1")
            require(!metrics.animalsGrownToAdultIDs.isEmpty, "q07.animal_full_growth")
            let growingBaseline = baseline?.growingCropCount ?? Int.max
            let livestockBaseline = baseline?.livestockCount ?? Int.max
            let reservedInventory = segment.map {
                safeCounterSum($0.reservedInventoryByItemID.values)
            } ?? 0
            require(
                increased(growing, over: growingBaseline, by: 8)
                    || increased(state.livestock.animals.count, over: livestockBaseline, by: 1)
                    || reservedInventory >= 12,
                "q07.causal_celebration_investment"
            )
            let causalOfferID = segment?.benefitOfferID
            let causalBenefitDay = segment?.benefitBaselineDay
            let premiumOrPrepaid = Set(metrics.catShopPremiumReceiptIDs)
                .union(metrics.catShopPrepaymentReceiptIDs)
                .filter { receiptID in
                    causalOfferID != nil
                        && metrics.catShopReceiptOfferSourceIDs[receiptID] == causalOfferID
                }
            let causalReceiptDays = state.catShop.receipts.compactMap { receipt in
                premiumOrPrepaid.contains(receipt.receiptID)
                    && causalBenefitDay.map({ receipt.day >= $0 }) == true
                    && metrics.dailyMetricDays.contains(receipt.day)
                    ? receipt.day
                    : nil
            }
            require(
                premiumOrPrepaid.count >= 3
                    && containsConsecutiveRun(causalReceiptDays, count: 3),
                "q07.causal_premium_or_prepay_3"
            )
            require(
                hasTrailingSettledDays(metrics.quietDays, count: 5, currentDay: state.clock.day),
                "q07.quiet_days_5"
            )
            require(noFrontstageCrisis, "q07.no_frontstage_event")
        case .q08:
            for prior in [StoryArcID.q01, .q02, .q03, .q04, .q05, .q06, .q07] {
                require(isResolved(prior, state), "q08.prior_resolved.\(prior.rawValue)")
            }
            require(previousAftermathDays(.q07, state) >= 2, "q08.q07_aftermath_2")
            require(state.community.standing >= 90, "q08.standing_90")
            require(metrics.catShopOpened, "q08.cat_shop_open")
            require(state.community.activeEvents.isEmpty, "q08.no_community_crisis")
            require(!state.storyCampaign.q08Completed, "q08.never_completed")
            require(state.storyCampaign.frontstageLease == nil, "q08.no_frontstage_event")
        case .q09:
            require(state.storyCampaign.q08Completed, "q09.q08_complete")
            require(state.storyCampaign.mission?.status == .completed, "q09.return_settled")
        case .q10:
            require(state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order, "q10.discovery_complete")
        }
        return StoryMaturityResult(isMature: missing.isEmpty, missingConditionIDs: missing.sorted())
    }

    private static func isResolved(_ arcID: StoryArcID, _ state: GameState) -> Bool {
        state.storyCampaign.segment(arcID)?.phase == .resolved
    }

    private static func previousAftermathDays(_ arcID: StoryArcID, _ state: GameState) -> Int {
        guard let start = state.storyCampaign.segment(arcID)?.aftermathStartDay,
              start >= 1, state.clock.day >= start else { return 0 }
        return state.clock.day - start
    }

    private static func increased(_ current: Int, over baseline: Int, by delta: Int) -> Bool {
        guard current >= 0, baseline >= 0, delta >= 0, current >= baseline else { return false }
        return current - baseline >= delta
    }

    private static func safeCounterSum<S: Sequence>(_ values: S) -> Int where S.Element == Int {
        var total = 0
        for value in values {
            guard value >= 0 else { return -1 }
            let (next, overflow) = total.addingReportingOverflow(value)
            guard !overflow else { return -1 }
            total = next
        }
        return total
    }

    private static func containsConsecutiveRun(_ days: [Int], count: Int) -> Bool {
        guard count > 0 else { return true }
        let ordered = Array(Set(days)).sorted()
        var run = 0
        var previous: Int?
        for day in ordered {
            run = previous.map { day == $0 + 1 } == true ? run + 1 : 1
            if run >= count { return true }
            previous = day
        }
        return false
    }

    private static func containsConsecutiveSettledRun(
        _ days: [Int],
        settledDays: [Int],
        count: Int
    ) -> Bool {
        let settled = Set(settledDays)
        return containsConsecutiveRun(days.filter(settled.contains), count: count)
    }

    /// Day N can only use settlements through N-1. Requiring the exact suffix
    /// prevents an old quiet streak from surviving a later conflict.
    private static func hasTrailingSettledDays(
        _ days: [Int],
        count: Int,
        currentDay: Int
    ) -> Bool {
        guard count > 0, currentDay > count else { return false }
        let settled = Set(days)
        return (currentDay - count..<currentDay).allSatisfy(settled.contains)
    }

    private static func hasHighValueCropMaturing(
        within days: Int,
        state: GameState,
        catalog: ContentCatalog
    ) -> Bool {
        let highValueIDs = Set([ContentID.bellBerryCrop, ContentID.honeyMelonCrop])
        return state.farmCells.values.contains { cell in
            guard cell.isGrowingCrop,
                  highValueIDs.contains(cell.cropID),
                  let crop = catalog.crop(id: cell.cropID) else { return false }
            let total = crop.stageDays.reduce(0, +)
            guard cell.stageProgressDays <= total else { return true }
            let remaining = total - cell.stageProgressDays
            return remaining <= days
        }
    }
}

enum StorySupportTier: String, Codable, CaseIterable, Sendable {
    case careful = "0_39"
    case standard = "40_69"
    case trusted = "70_89"
    case full = "90_100"

    static func resolve(standing: Int) -> StorySupportTier {
        switch standing {
        case ...39: return .careful
        case 40...69: return .standard
        case 70...89: return .trusted
        default: return .full
        }
    }

    func snapshot(for arcID: StoryArcID) -> String {
        switch (arcID, self) {
        case (.q02, .careful): return "逐项复核闸具；全部手工作业可完成"
        case (.q02, .standard): return "两批到场；保留手工分水"
        case (.q02, .trusted): return "首批工具已复核；一项协作加速"
        case (.q02, .full): return "首批齐备；显示安全捷径"
        case (.q07, .careful): return "逐筐登记；宴会仍可完成"
        case (.q07, .standard): return "基础披肩与两批补位"
        case (.q07, .trusted): return "加宽补位通道与庆典披肩"
        case (.q07, .full): return "最快到场与完整庆典规格"
        case (.q08, .careful): return "额外证物检查；无资源惩罚"
        case (.q08, .standard): return "标准三段路线提示"
        case (.q08, .trusted): return "追加白石方向提示"
        case (.q08, .full): return "显示已验证安全捷径"
        default: return "手工保底可用"
        }
    }
}

struct FrontstageCandidate: Equatable, Sendable {
    var owner: FrontstageOwner
    var resourceID: String
    var checkpointID: String?
}

enum FrontstageEventArbiter {
    static func select(
        existing: FrontstageLease?,
        candidates: [FrontstageCandidate]
    ) -> FrontstageCandidate? {
        if let existing {
            return FrontstageCandidate(
                owner: existing.owner,
                resourceID: existing.resourceID,
                checkpointID: existing.checkpointID
            )
        }
        return candidates.sorted {
            if $0.owner.priority != $1.owner.priority {
                return $0.owner.priority > $1.owner.priority
            }
            return $0.resourceID < $1.resourceID
        }.first
    }

    static func canOpenStoryBeat(state: GameState) -> Bool {
        state.storyCampaign.frontstageLease == nil
            && state.community.activeEvents.isEmpty
            && state.storyCampaign.mission?.status != .travelling
            && state.storyCampaign.finaleBeat.order < FinaleBeat.discovery.order
    }
}

enum StoryDirectorFailure: Equatable, Error, Sendable {
    case unknownSegment
    case illegalTransition
    case maturityNotMet
    case frontstageBusy
    case communityEventActive
    case relatedActionRequired
    case sleepBoundaryRequired
    case evidenceRequired
    case aftermathTooShort
    case duplicateReceipt
}

enum StoryDirector {
    static let standingAward = 6
    static let repairCommissionAward = 6
    static let maximumRepairCommissions = 3

    static func unlockEligibleBenefit(
        state: GameState,
        arcID: StoryArcID
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID) else { return .failure(.unknownSegment) }
        guard segment.phase == .locked else { return .success(state) }
        guard benefitPrerequisiteMet(arcID, state: state) else { return .failure(.maturityNotMet) }
        var next = state
        segment.benefitOfferID = "\(arcID.rawValue).offer.day_\(state.clock.day)"
        segment.benefitBaselineDay = state.clock.day
        segment.benefitBaseline = StoryMaturityService.baseline(for: state)
        segment.enter(.benefit, day: state.clock.day)
        next.storyCampaign.updateSegment(segment)
        return .success(next)
    }

    static func requestWarningOne(
        state: GameState,
        arcID: StoryArcID,
        sleepEpoch: Int
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID) else { return .failure(.unknownSegment) }
        guard segment.phase == .benefit else { return .failure(.illegalTransition) }
        guard StoryMaturityService.evaluate(arcID, state: state).isMature else {
            return .failure(.maturityNotMet)
        }
        guard state.community.activeEvents.isEmpty else { return .failure(.communityEventActive) }
        guard FrontstageEventArbiter.canOpenStoryBeat(state: state) else { return .failure(.frontstageBusy) }
        var next = state
        segment.enter(.warningOne, day: state.clock.day)
        segment.warningOneEvidenceSerial = relatedSerial(arcID, state)
        segment.warningOneEvidenceCheckSerial = state.storyMetrics.evidenceCheckSerials[
            arcID.rawValue,
            default: 0
        ]
        segment.warningOneSleepEpoch = sleepEpoch
        next.storyCampaign.updateSegment(segment)
        next.storyCampaign.frontstageLease = lease(arcID: arcID, phase: .warningOne, day: state.clock.day)
        guard let cursor = cursor(arcID: arcID, phase: .warningOne) else {
            return .failure(.illegalTransition)
        }
        next.storyCampaign.cursor = cursor
        if arcID == .q01 {
            next.storyCampaign.m3OffersPaused = true
        }
        return .success(next)
    }

    static func requestWarningTwo(
        state: GameState,
        arcID: StoryArcID,
        sleepEpoch: Int
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID) else { return .failure(.unknownSegment) }
        guard segment.phase == .warningOne, state.storyCampaign.frontstageLease == nil else {
            return .failure(.illegalTransition)
        }
        guard state.community.activeEvents.isEmpty else { return .failure(.communityEventActive) }
        let currentSerial = relatedSerial(arcID, state)
        guard currentSerial > (segment.warningOneEvidenceSerial ?? currentSerial) else {
            return .failure(.relatedActionRequired)
        }
        if arcID == .q02 || arcID == .q07 {
            guard sleepEpoch > (segment.warningOneSleepEpoch ?? sleepEpoch),
                  let warningOneDay = segment.enteredDay(for: .warningOne),
                  state.clock.day > warningOneDay else {
                return .failure(.sleepBoundaryRequired)
            }
        }
        if arcID == .q08 {
            let evidence = state.storyMetrics.evidenceCheckSerials[arcID.rawValue, default: 0]
            guard evidence > (segment.warningOneEvidenceCheckSerial ?? evidence) else {
                return .failure(.evidenceRequired)
            }
        }
        var next = state
        segment.enter(.warningTwo, day: state.clock.day)
        segment.warningTwoEvidenceSerial = currentSerial
        segment.warningTwoSleepEpoch = sleepEpoch
        next.storyCampaign.updateSegment(segment)
        next.storyCampaign.frontstageLease = lease(arcID: arcID, phase: .warningTwo, day: state.clock.day)
        guard let cursor = cursor(arcID: arcID, phase: .warningTwo) else {
            return .failure(.illegalTransition)
        }
        next.storyCampaign.cursor = cursor
        return .success(next)
    }

    static func requestEruption(
        state: GameState,
        arcID: StoryArcID,
        sleepEpoch: Int
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID) else { return .failure(.unknownSegment) }
        guard segment.phase == .warningTwo, state.storyCampaign.frontstageLease == nil else {
            return .failure(.illegalTransition)
        }
        guard state.community.activeEvents.isEmpty else { return .failure(.communityEventActive) }
        guard !state.storyCampaign.segments.contains(where: { $0.phase == .eruption }) else {
            return .failure(.frontstageBusy)
        }
        let serial = relatedSerial(arcID, state)
        guard serial > (segment.warningTwoEvidenceSerial ?? serial) else {
            return .failure(.relatedActionRequired)
        }
        if arcID == .q02 || arcID == .q07 {
            guard sleepEpoch > (segment.warningTwoSleepEpoch ?? sleepEpoch),
                  let warningTwoDay = segment.enteredDay(for: .warningTwo),
                  state.clock.day > warningTwoDay else {
                return .failure(.sleepBoundaryRequired)
            }
        }
        var next = state
        segment.enter(.eruption, day: state.clock.day)
        next.storyCampaign.updateSegment(segment)
        next.storyCampaign.frontstageLease = lease(arcID: arcID, phase: .eruption, day: state.clock.day)
        guard let cursor = cursor(arcID: arcID, phase: .eruption) else {
            return .failure(.illegalTransition)
        }
        next.storyCampaign.cursor = cursor
        next.storyMetrics.lastFrontstageEventDay = state.clock.day
        return .success(next)
    }

    /// Closing a dialogue always releases control. warning_2 therefore cannot
    /// chain into eruption in the same StoryDialogueSession.
    static func closeDialogue(
        state: GameState,
        arcID: StoryArcID,
        completedPhase: StoryPhase
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID),
              [.warningOne, .warningTwo, .eruption].contains(completedPhase),
              segment.phase == completedPhase,
              state.storyCampaign.frontstageLease?.owner == .story,
              state.storyCampaign.frontstageLease?.resourceID == arcID.rawValue,
              state.storyCampaign.cursor.eventID == arcID.rawValue,
              state.storyCampaign.cursor.beatID == completedPhase.rawValue,
              state.storyCampaign.cursor.cueID != nil else {
            return .failure(.illegalTransition)
        }
        var next = state
        next.storyCampaign.frontstageLease = nil
        next.storyCampaign.cursor = .empty
        next.storyCampaign.dialogueSession = nil
        if completedPhase == .eruption {
            if arcID != .q08 {
                let requiredSlot: StoryChoiceSlotID = arcID == .q06 ? .eruption : .primary
                guard state.storyCampaign.choices.contains(where: {
                    $0.arcID == arcID && $0.slotID == requiredSlot
                }) else {
                    return .failure(.illegalTransition)
                }
                segment.enter(.aftermath, day: state.clock.day)
                next.storyCampaign.updateSegment(segment)
            }
        }
        return .success(next)
    }

    static func resolveResponsibleAftermath(
        state: GameState,
        arcID: StoryArcID
    ) -> Result<GameState, StoryDirectorFailure> {
        guard var segment = state.storyCampaign.segment(arcID), segment.phase == .aftermath else {
            return .failure(.illegalTransition)
        }
        guard let start = segment.aftermathStartDay,
              start >= 1,
              state.clock.day >= start,
              state.clock.day - start >= 2 else {
            return .failure(.aftermathTooShort)
        }
        let requiredSlot: StoryChoiceSlotID = arcID == .q06 ? .aftermath : .primary
        guard state.storyCampaign.choices.contains(where: {
            $0.arcID == arcID && $0.slotID == requiredSlot
        }) else {
            return .failure(.illegalTransition)
        }
        if arcID == .q08 {
            guard state.storyCampaign.mission?.status == .completed,
                  state.storyCampaign.mission?.checkpoint == .homecoming else {
                return .failure(.illegalTransition)
            }
        }
        var next = state
        segment.aftermathQuality = .responsible
        segment.enter(.resolved, day: state.clock.day)
        if arcID == .q07 {
            segment.reservedInventoryByItemID = [:]
        }
        if arcID.sequence <= StoryArcID.q07.sequence {
            let receiptID = "brookseed.story.receipt.\(arcID.shortCode).standing"
            if segment.standingAwardReceiptID == nil {
                segment.standingAwardReceiptID = receiptID
                segment.effectReceiptIDs.append(receiptID)
                next.community.standing = min(100, next.community.standing + standingAward)
                next.storyCampaign.effectReceipts.append(
                    StoryReceiptRecord(receiptID: receiptID, sourceID: arcID.rawValue, day: state.clock.day)
                )
            }
        }
        if arcID == .q08 {
            next.storyCampaign.q08Completed = true
        }
        next.storyCampaign.updateSegment(segment)
        next.storyCampaign.canonicalize()
        return .success(next)
    }

    static func completeRepairCommission(
        state: GameState,
        commissionID: String
    ) -> Result<GameState, StoryDirectorFailure> {
        guard ContentID.isValid(commissionID) else { return .failure(.illegalTransition) }
        guard state.storyCampaign.segment(.q07)?.phase == .resolved,
              state.community.standing < 90 else { return .failure(.illegalTransition) }
        guard !state.storyCampaign.repairCommissionIDs.contains(commissionID) else {
            return .failure(.duplicateReceipt)
        }
        guard state.storyCampaign.repairCommissionIDs.count < maximumRepairCommissions else {
            return .failure(.illegalTransition)
        }
        var next = state
        next.storyCampaign.repairCommissionIDs.append(commissionID)
        next.storyMetrics.repairCommissionIDs.append(commissionID)
        next.community.standing = min(100, next.community.standing + repairCommissionAward)
        next.storyCampaign.effectReceipts.append(
            StoryReceiptRecord(
                receiptID: "brookseed.story.receipt.repair_\(next.storyCampaign.repairCommissionIDs.count)",
                sourceID: commissionID,
                day: state.clock.day
            )
        )
        next.storyCampaign.canonicalize()
        next.storyMetrics.canonicalize()
        return .success(next)
    }

    private static func relatedSerial(_ arcID: StoryArcID, _ state: GameState) -> Int {
        state.storyMetrics.relatedActionSerials[arcID.rawValue, default: 0]
    }

    private static func benefitPrerequisiteMet(_ arcID: StoryArcID, state: GameState) -> Bool {
        switch arcID {
        case .q01:
            return QuestService.status(of: ContentID.restoreOldCanalQuest, in: state) == .completed
        case .q02: return state.storyCampaign.segment(.q01)?.phase == .resolved
        case .q03: return state.storyCampaign.segment(.q02)?.phase == .resolved
        case .q04: return state.storyCampaign.segment(.q03)?.phase == .resolved
        case .q05: return state.storyCampaign.segment(.q04)?.phase == .resolved
        case .q06: return state.storyCampaign.segment(.q05)?.phase == .resolved
        case .q07: return state.storyCampaign.segment(.q06)?.phase == .resolved
        case .q08: return state.storyCampaign.segment(.q07)?.phase == .resolved
        case .q09: return state.storyCampaign.q08Completed
        case .q10: return state.storyCampaign.finaleBeat.order >= FinaleBeat.discovery.order
        }
    }

    private static func lease(arcID: StoryArcID, phase: StoryPhase, day: Int) -> FrontstageLease {
        FrontstageLease(
            leaseID: "brookseed.story.lease.\(arcID.shortCode).\(phase.rawValue).day_\(day)",
            owner: .story,
            resourceID: arcID.rawValue,
            acquiredDay: day,
            checkpointID: nil
        )
    }

    private static func cursor(
        arcID: StoryArcID,
        phase: StoryPhase,
        catalog: StoryContentCatalog = .shared
    ) -> StoryRuntimeCursor? {
        guard let stageKind = StoryStageID(rawValue: phase.rawValue),
              let stage = catalog.stage(arcID: arcID, kind: stageKind),
              let cueID = stage.lines.compactMap(\.blockingCueID).first,
              let cue = catalog.visibleBlockingCue(id: cueID, finaleUnlocked: false) else {
            return nil
        }
        return StoryRuntimeCursor(
            eventID: arcID.rawValue,
            sceneID: cue.sceneID,
            beatID: phase.rawValue,
            lineID: nil,
            lineIndex: 0,
            cueID: cueID,
            checkpointID: nil
        )
    }
}

enum StoryStateValidation {
    static func validate(
        state: GameState,
        catalog: ContentCatalog,
        storyCatalog: StoryContentCatalog = .shared
    ) throws {
        let campaignID = state.campaignID
        let campaign = state.storyCampaign
        let metrics = state.storyMetrics
        let currentDay = state.clock.day
        guard (1...1_000_000).contains(currentDay),
              ContentID.isValid(campaignID), campaignID.hasPrefix("brookseed.campaign.") else {
            throw SaveStoreError.invalidContents
        }
        let expected = [StoryArcID.q01, .q02, .q03, .q04, .q05, .q06, .q07, .q08]
        guard campaign.segments.map(\.arcID) == expected else {
            throw SaveStoreError.invalidContents
        }
        let progressPhases: [StoryPhase] = [
            .benefit, .warningOne, .warningTwo, .eruption, .aftermath, .resolved,
        ]
        for segment in campaign.segments {
            let phases = segment.phaseDays.map(\.phase)
            let expectedPhases: [StoryPhase]
            if segment.phase == .locked {
                expectedPhases = []
            } else if let index = progressPhases.firstIndex(of: segment.phase) {
                expectedPhases = Array(progressPhases.prefix(index + 1))
            } else {
                throw SaveStoreError.invalidContents
            }
            guard Set(phases).count == phases.count,
                  phases == expectedPhases,
                  segment.phaseDays.allSatisfy({ (1...currentDay).contains($0.day) }),
                  zip(segment.phaseDays, segment.phaseDays.dropFirst()).allSatisfy({ lhs, rhs in
                      lhs.day <= rhs.day
                  }),
                  segment.completedActionIDs == segment.completedActionIDs.sorted(),
                  Set(segment.completedActionIDs).count == segment.completedActionIDs.count,
                  segment.completedActionIDs.allSatisfy(ContentID.isValid),
                  segment.effectReceiptIDs == segment.effectReceiptIDs.sorted(),
                  Set(segment.effectReceiptIDs).count == segment.effectReceiptIDs.count,
                  segment.effectReceiptIDs.allSatisfy(ContentID.isValid),
                  (0...10_000_000).contains(segment.lastRelatedActionSerial),
                  segment.lastRelatedActionSerial == segment.completedActionIDs.count,
                  validReservedInventory(
                      segment,
                      state: state,
                      catalog: catalog
                  ) else {
                throw SaveStoreError.invalidContents
            }
            let segmentChoiceRecords = campaign.choices.filter { $0.arcID == segment.arcID }
            var segmentChoices: [String: String] = [:]
            for record in segmentChoiceRecords {
                guard segmentChoices.updateValue(
                    record.choiceID,
                    forKey: record.slotID.rawValue
                ) == nil else {
                    throw SaveStoreError.invalidContents
                }
            }
            guard segment.selectedChoiceIDsBySlot == segmentChoices else {
                throw SaveStoreError.invalidContents
            }
            if segment.phase == .locked {
                guard segment.benefitOfferID == nil,
                      segment.benefitBaselineDay == nil,
                      segment.benefitBaseline == nil,
                      segment.aftermathQuality == .pending,
                      segment.aftermathStartDay == nil,
                      segment.resolvedDay == nil,
                      segment.selectedChoiceIDsBySlot.isEmpty,
                      segment.completedActionIDs.isEmpty,
                      segment.reservedInventoryByItemID.isEmpty,
                      segment.inventoryReservationReceipts.isEmpty,
                      segment.effectReceiptIDs.isEmpty,
                      segment.standingAwardReceiptID == nil,
                      segment.lastRelatedActionSerial == 0,
                      segment.warningOneEvidenceSerial == nil,
                      segment.warningOneEvidenceCheckSerial == nil,
                      segment.warningTwoEvidenceSerial == nil,
                      segment.warningOneSleepEpoch == nil,
                      segment.warningTwoSleepEpoch == nil else {
                    throw SaveStoreError.invalidContents
                }
            } else {
                guard let offerID = segment.benefitOfferID,
                      ContentID.isValid(offerID),
                      let baselineDay = segment.benefitBaselineDay,
                      (1...currentDay).contains(baselineDay),
                      baselineDay == segment.enteredDay(for: .benefit),
                      let baseline = segment.benefitBaseline,
                      validBaseline(baseline) else {
                    throw SaveStoreError.invalidContents
                }
            }
            try validateWarningEvidence(
                segment,
                metrics: metrics,
                currentDay: currentDay
            )
            if segment.phase.order >= StoryPhase.aftermath.order {
                guard let aftermathDay = segment.aftermathStartDay,
                      aftermathDay == segment.enteredDay(for: .aftermath),
                      (1...currentDay).contains(aftermathDay) else {
                    throw SaveStoreError.invalidContents
                }
            } else {
                guard segment.aftermathStartDay == nil,
                      segment.aftermathQuality == .pending else {
                    throw SaveStoreError.invalidContents
                }
            }
            if segment.phase == .resolved {
                guard segment.aftermathQuality == .responsible,
                      segment.resolvedDay == segment.enteredDay(for: .resolved),
                      segment.resolvedDay.map({ (1...currentDay).contains($0) }) == true else {
                    throw SaveStoreError.invalidContents
                }
                if segment.arcID.sequence <= StoryArcID.q07.sequence {
                    guard let receiptID = segment.standingAwardReceiptID,
                          segment.effectReceiptIDs.contains(receiptID),
                          campaign.effectReceipts.contains(where: { $0.receiptID == receiptID }) else {
                        throw SaveStoreError.invalidContents
                    }
                } else {
                    guard segment.standingAwardReceiptID == nil,
                          !segment.effectReceiptIDs.contains(where: { $0.contains("standing") }) else {
                        throw SaveStoreError.invalidContents
                    }
                }
            } else {
                guard segment.resolvedDay == nil,
                      segment.aftermathQuality == .pending,
                      segment.standingAwardReceiptID == nil else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        for index in campaign.segments.indices where index > 0 {
            if campaign.segments[index].phase != .locked {
                guard campaign.segments[index - 1].phase == .resolved,
                      let previousResolvedDay = campaign.segments[index - 1].resolvedDay,
                      let benefitDay = campaign.segments[index].benefitBaselineDay,
                      previousResolvedDay <= benefitDay else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        let shouldPauseM3 = (campaign.segment(.q01)?.phase.order ?? 0) >= StoryPhase.warningOne.order
            && campaign.finaleBeat != .graduated
        guard campaign.q08Completed == (campaign.segment(.q08)?.phase == .resolved),
              campaign.segments.filter({ $0.phase == .eruption }).count <= 1,
              campaign.m3OffersPaused == shouldPauseM3,
              !shouldPauseM3 || state.community.activeEvents.isEmpty,
              campaign.repairCommissionIDs == Array(Set(campaign.repairCommissionIDs)).sorted(),
              campaign.repairCommissionIDs.count <= StoryDirector.maximumRepairCommissions,
              campaign.repairCommissionIDs.allSatisfy(ContentID.isValid),
              campaign.repairCommissionIDs == metrics.repairCommissionIDs,
              campaign.choices.count == Set(campaign.choices.map {
                  "\($0.arcID.rawValue)#\($0.slotID.rawValue)"
              }).count,
              campaign.choices.allSatisfy({ record in
                  StoryChoiceID.choices(for: record.arcID).contains { choice in
                      choice.stableID(in: record.arcID) == record.choiceID
                          && choice.slot(in: record.arcID) == record.slotID
                  } && (1...currentDay).contains(record.day)
              }) else {
            throw SaveStoreError.invalidContents
        }
        try validateChoiceCausality(campaign: campaign, currentDay: currentDay)
        if campaign.q08Completed {
            guard campaign.mission?.status == .completed,
                  campaign.mission?.checkpoint == .homecoming else {
                throw SaveStoreError.invalidContents
            }
        }
        let actionReceiptIDs = campaign.actionReceipts.map(\.receiptID)
        let effectReceiptIDs = campaign.effectReceipts.map(\.receiptID)
        guard uniqueSorted(actionReceiptIDs),
              uniqueSorted(effectReceiptIDs),
              Set(actionReceiptIDs).isDisjoint(with: Set(effectReceiptIDs)),
              campaign.actionReceipts.allSatisfy({
                  ContentID.isValid($0.receiptID)
                      && ContentID.isValid($0.sourceID)
                      && (1...currentDay).contains($0.day)
              }),
              campaign.effectReceipts.allSatisfy({
                  ContentID.isValid($0.receiptID)
                      && ContentID.isValid($0.sourceID)
                      && (1...currentDay).contains($0.day)
              }) else {
            throw SaveStoreError.invalidContents
        }
        try validateReceiptLinks(campaign)
        try validateDialogueSession(
            campaign: campaign,
            state: state,
            currentDay: currentDay,
            catalog: storyCatalog
        )
        if let lease = campaign.frontstageLease {
            guard ContentID.isValid(lease.leaseID),
                  ContentID.isValid(lease.resourceID),
                  (1...currentDay).contains(lease.acquiredDay),
                  (0...10_000).contains(campaign.cursor.lineIndex) else {
                throw SaveStoreError.invalidContents
            }
            switch lease.owner {
            case .story:
                try validateStoryCursor(
                    campaign: campaign,
                    lease: lease,
                    catalog: storyCatalog
                )
            case .journey:
                guard let mission = campaign.mission,
                      mission.status == .travelling,
                      lease.resourceID == mission.missionInstanceID,
                      lease.checkpointID == mission.checkpoint.rawValue,
                      campaign.cursor.eventID == StoryArcID.q08.rawValue,
                      campaign.cursor.beatID == "journey",
                      campaign.cursor.checkpointID == mission.checkpoint.rawValue,
                      campaign.cursor.lineID == nil,
                      campaign.cursor.cueID == nil else {
                    throw SaveStoreError.invalidContents
                }
            case .finale:
                guard campaign.finaleBeat.order >= FinaleBeat.discovery.order,
                      campaign.finaleBeat != .graduated,
                      campaign.cursor.eventID == lease.resourceID else {
                    throw SaveStoreError.invalidContents
                }
            case .communityEvent, .forcedTutorial, .resumedSession, .hint:
                guard campaign.cursor == .empty else { throw SaveStoreError.invalidContents }
            }
        } else if campaign.cursor != .empty {
            throw SaveStoreError.invalidContents
        }
        if let mission = campaign.mission {
            guard mission.campaignID == campaignID,
                  (1...currentDay).contains(mission.startDay),
                  !mission.missionInstanceID.isEmpty,
                  ContentID.isValid(mission.missionInstanceID),
                  ContentID.isValid(mission.settlementReceiptID),
                  uniqueSorted(mission.coveredCropCellIDs),
                  mission.coveredCropCellIDs.allSatisfy(ContentID.isValid),
                  uniqueSorted(mission.protectedAnimalIDs),
                  mission.protectedAnimalIDs.allSatisfy(ContentID.isValid),
                  uniqueSorted(mission.frozenOrderIDs),
                  mission.frozenOrderIDs.allSatisfy(ContentID.isValid),
                  uniqueSorted(mission.frozenDeadlineIDs),
                  mission.frozenDeadlineIDs.allSatisfy(ContentID.isValid),
                  uniqueSorted(mission.frozenOfferIDs),
                  mission.frozenOfferIDs.allSatisfy(ContentID.isValid),
                  mission.shippingEntries.map(\.entryID)
                    == mission.shippingEntries.map(\.entryID).sorted(),
                  mission.shippingEntries.allSatisfy({ entry in
                      validMissionShippingEntryID(entry.entryID)
                          && ContentID.isValid(entry.itemID)
                          && catalog.knowsItemID(entry.itemID)
                          && (1...SaveValidation.maxShippingQuantity).contains(entry.quantity)
                          && (0...SaveValidation.maxUnitPriceSnapshot).contains(entry.unitPrice)
                          && validProduct(entry.quantity, entry.unitPrice)
                  }),
                  Set(mission.shippingEntries.map(\.entryID)).count == mission.shippingEntries.count else {
                throw SaveStoreError.invalidContents
            }
            guard let q08Phase = campaign.segment(.q08)?.phase,
                  q08Phase.order >= StoryPhase.eruption.order else {
                throw SaveStoreError.invalidContents
            }
            switch mission.status {
            case .prepared:
                guard mission.checkpoint == .departure else { throw SaveStoreError.invalidContents }
            case .travelling:
                guard mission.checkpoint != .homecoming else { throw SaveStoreError.invalidContents }
            case .returning:
                guard mission.checkpoint == .greyFenceFarm || mission.checkpoint == .homecoming else {
                    throw SaveStoreError.invalidContents
                }
            case .completed:
                guard mission.checkpoint == .homecoming,
                      !mission.canAbandonToProtection else {
                    throw SaveStoreError.invalidContents
                }
            }
            if mission.status != .completed {
                guard campaign.segment(.q08)?.phase == .eruption
                        || campaign.segment(.q08)?.phase == .aftermath,
                      !mission.canAbandonToProtection
                        || campaign.protection.preMistRidgeVerified else {
                    throw SaveStoreError.invalidContents
                }
            }
        } else if campaign.protection.preMistRidgeVerified {
            throw SaveStoreError.invalidContents
        }
        try validateFinale(campaign: campaign, currentDay: currentDay)
        guard campaign.protection.orphanProtectionDiagnostics
                == Array(Set(campaign.protection.orphanProtectionDiagnostics)).sorted(),
              campaign.protection.orphanProtectionDiagnostics.allSatisfy({ !$0.isEmpty && $0.count <= 240 }),
              uniqueSorted(campaign.gallery.discoveredLedgerPageIDs),
              uniqueSorted(campaign.gallery.discoveredAnnotationIDs),
              uniqueSorted(campaign.gallery.keepsakeIDs),
              campaign.gallery.discoveredLedgerPageIDs.allSatisfy(ContentID.isValid),
              campaign.gallery.discoveredAnnotationIDs.allSatisfy(ContentID.isValid),
              campaign.gallery.keepsakeIDs.allSatisfy(ContentID.isValid),
              campaign.gallery.endingID.map(ContentID.isValid) ?? true else {
            throw SaveStoreError.invalidContents
        }
        let metricDayLists: [[Int]] = [
            metrics.automaticWaterSleepDays,
            metrics.temporaryCanalBenefitDays,
            metrics.formalCanalBenefitDays,
            metrics.premiumBenefitDays,
            metrics.relationshipConflictDays,
            metrics.dailyMetricDays,
            metrics.quietDays,
        ] + Array(metrics.npcTalkDays.values)
            + Array(metrics.livestockCareDays.values)
            + Array(metrics.aftermathDaysByArcID.values)
        let boundedCounters = [
            metrics.tilledCellCount,
            metrics.clearedWitheredCellCount,
            metrics.manualWaterCellDays,
            metrics.automaticWaterCellDays,
            metrics.plantedCellCount,
            metrics.harvestedCropCount,
            metrics.maxGrowingCropCount,
            metrics.seedBenefitUses,
            metrics.seedBenefitPlantedCells,
        ] + Array(metrics.plantedCellsByCropID.values)
            + Array(metrics.harvestsByCropID.values)
            + Array(metrics.completedCyclesByCropID.values)
            + Array(metrics.deliveriesByCropID.values)
            + Array(metrics.npcHelpCounts.values)
            + Array(metrics.npcCollaborationCounts.values)
            + Array(metrics.relatedActionSerials.values)
            + Array(metrics.anchorReentrySerials.values)
            + Array(metrics.evidenceCheckSerials.values)
        let receiptSet = Set(metrics.catShopReceiptIDs)
        let realReceiptsByID = Dictionary(uniqueKeysWithValues: state.catShop.receipts.map {
            ($0.receiptID, $0)
        })
        let cropReceiptSet = Set(metrics.catShopCropReceiptIDs)
        let animalReceiptSet = Set(metrics.catShopAnimalReceiptIDs)
        let expectedPremiumDays = Set(metrics.catShopPremiumReceiptIDs.compactMap {
            realReceiptsByID[$0]?.day
        })
        let catMetricPrefix = "brookseed.story.metric.cat_shop."
        let recordedCatReceiptIDs = Set(metrics.recordedSourceIDs.compactMap { sourceID in
            sourceID.hasPrefix(catMetricPrefix) ? String(sourceID.dropFirst(catMetricPrefix.count)) : nil
        })
        let validArcKeys = Set(StoryArcID.allCases.map(\.rawValue))
        let validSegmentArcKeys = Set(expected.map(\.rawValue))
        guard uniqueSorted(metrics.recordedSourceIDs),
              uniqueSorted(metrics.catShopReceiptIDs),
              uniqueSorted(metrics.catShopCropReceiptIDs),
              uniqueSorted(metrics.catShopAnimalReceiptIDs),
              uniqueSorted(metrics.catShopPremiumReceiptIDs),
              uniqueSorted(metrics.catShopPrepaymentReceiptIDs),
              uniqueSorted(metrics.deliveryRecipientIDs),
              uniqueSorted(metrics.catShopBuyerIDs),
              uniqueSorted(metrics.catShopOfferIDs),
              uniqueSorted(metrics.animalsGrownToAdultIDs),
              uniqueSorted(metrics.fosterIssuanceIDs),
              uniqueSorted(metrics.uniqueHelpActionIDs),
              uniqueSorted(metrics.uniqueCollaborationActionIDs),
              uniqueSorted(metrics.repairCommissionIDs),
              metrics.tilledCellCount >= 0,
              metrics.clearedWitheredCellCount >= 0,
              metrics.clearedWitheredCellCount <= metrics.tilledCellCount,
              metrics.manualWaterCellDays >= 0,
              metrics.automaticWaterCellDays >= 0,
              metrics.plantedCellCount >= 0,
              metrics.harvestedCropCount >= 0,
              metrics.maxGrowingCropCount >= 0,
              metrics.seedBenefitUses >= 0,
              metrics.seedBenefitPlantedCells >= 0,
              metrics.seedBenefitPlantedCells <= metrics.plantedCellCount,
              boundedCounters.allSatisfy({ (0...10_000_000).contains($0) }),
              metrics.recordedSourceIDs.allSatisfy(ContentID.isValid),
              metricDayLists.allSatisfy({ uniqueSortedDays($0, maximum: currentDay) }),
              metrics.lastMajorConflictDay.map({ (1...currentDay).contains($0) }) ?? true,
              metrics.lastFrontstageEventDay.map({ (1...currentDay).contains($0) }) ?? true,
              Set(metrics.quietDays).isDisjoint(with: Set(metrics.relationshipConflictDays)),
              Set(metrics.quietDays).union(metrics.relationshipConflictDays)
                .isSubset(of: Set(metrics.dailyMetricDays)),
              metrics.plantedCellCount == boundedSum(metrics.plantedCellsByCropID.values),
              metrics.harvestedCropCount == boundedSum(metrics.harvestsByCropID.values),
              metrics.harvestsByCropID == metrics.completedCyclesByCropID,
              validCropKeys(metrics.plantedCellsByCropID.keys, catalog: catalog),
              validCropKeys(metrics.harvestsByCropID.keys, catalog: catalog),
              validCropKeys(metrics.completedCyclesByCropID.keys, catalog: catalog),
              validCropKeys(metrics.deliveriesByCropID.keys, catalog: catalog),
              validCropKeys(metrics.deliveryRecipientIDsByCropID.keys, catalog: catalog),
              validNPCKeys(metrics.npcTalkDays.keys, catalog: catalog),
              validNPCKeys(metrics.npcHelpCounts.keys, catalog: catalog),
              validNPCKeys(metrics.npcCollaborationCounts.keys, catalog: catalog),
              Set(metrics.relatedActionSerials.keys).isSubset(of: validArcKeys),
              Set(metrics.anchorReentrySerials.keys).isSubset(of: validArcKeys),
              Set(metrics.evidenceCheckSerials.keys).isSubset(of: validArcKeys),
              Set(metrics.aftermathDaysByArcID.keys).isSubset(of: validSegmentArcKeys),
              metrics.deliveryRecipientIDsByCropID.values.allSatisfy({ uniqueSorted($0) }),
              metrics.deliveryRecipientIDs.allSatisfy(ContentID.isValid),
              metrics.deliveryRecipientIDsByCropID.values
                .flatMap({ $0 }).allSatisfy(ContentID.isValid),
              metrics.catShopBuyerIDs.allSatisfy(ContentID.isValid),
              metrics.catShopOfferIDs.allSatisfy(ContentID.isValid),
              metrics.animalsGrownToAdultIDs.allSatisfy(ContentID.isValid),
              metrics.fosterIssuanceIDs.allSatisfy(ContentID.isValid),
              metrics.uniqueHelpActionIDs.allSatisfy(ContentID.isValid),
              metrics.uniqueCollaborationActionIDs.allSatisfy(ContentID.isValid),
              metrics.repairCommissionIDs.allSatisfy(ContentID.isValid),
              cropReceiptSet.isSubset(of: receiptSet),
              animalReceiptSet.isSubset(of: receiptSet),
              cropReceiptSet.isDisjoint(with: animalReceiptSet),
              cropReceiptSet.union(animalReceiptSet) == receiptSet,
              Set(metrics.catShopPremiumReceiptIDs).isSubset(of: receiptSet),
              Set(metrics.catShopPrepaymentReceiptIDs).isSubset(of: receiptSet),
              receiptSet.isSubset(of: Set(realReceiptsByID.keys)),
              cropReceiptSet.allSatisfy({ realReceiptsByID[$0]?.kind == .crop }),
              animalReceiptSet.allSatisfy({ realReceiptsByID[$0]?.kind == .animal }),
              Set(metrics.catShopPremiumReceiptIDs).allSatisfy({ receiptID in
                  guard let receipt = realReceiptsByID[receiptID], receipt.kind == .crop,
                        let base = catalog.item(id: receipt.definitionID)?.baseSellPrice else { return false }
                  return receipt.unitPrice > base
              }),
              expectedPremiumDays.isSubset(of: Set(metrics.premiumBenefitDays)),
              recordedCatReceiptIDs == receiptSet,
              Set(metrics.catShopReceiptOfferSourceIDs.keys).isSubset(of: receiptSet),
              metrics.catShopReceiptOfferSourceIDs.values.allSatisfy(ContentID.isValid),
              metrics.catShopReceiptOfferSourceIDs.allSatisfy({ receiptID, offerID in
                  guard let q07 = campaign.segment(.q07),
                        offerID == q07.benefitOfferID,
                        let benefitDay = q07.benefitBaselineDay,
                        let receipt = realReceiptsByID[receiptID],
                        receipt.day >= benefitDay else {
                      return false
                  }
                  guard let warningOneDay = q07.enteredDay(for: .warningOne) else {
                      return true
                  }
                  return receipt.day <= warningOneDay
              }),
              Set(metrics.catShopOfferIDs).isSubset(of: Set(receiptSet.compactMap {
                  realReceiptsByID[$0]?.offerID
              })),
              metrics.animalSupplyHistory.map(\.receiptID)
                == metrics.animalSupplyHistory.map(\.receiptID).sorted(),
              Set(metrics.animalSupplyHistory.map(\.receiptID)).count
                == metrics.animalSupplyHistory.count,
              metrics.anchorReentrySerials.allSatisfy({ key, value in
                  value <= metrics.relatedActionSerials[key, default: 0]
              }),
              metrics.evidenceCheckSerials.allSatisfy({ key, value in
                  value <= metrics.relatedActionSerials[key, default: 0]
              }),
              metrics.animalSupplyHistory.allSatisfy({ history in
                  ContentID.isValid(history.animalID)
                      && ContentID.isValid(history.definitionID)
                      && LivestockCatalog.definition(id: history.definitionID) != nil
                      && ContentID.isValid(history.receiptID)
                      && animalReceiptSet.contains(history.receiptID)
                      && (0...SaveValidation.maxAnimalAgeDays).contains(history.ageDays)
                      && (0...SaveValidation.maxAnimalCareDays).contains(history.careDays)
              }),
              Set(metrics.animalsGrownToAdultIDs).isSubset(of: Set(
                  state.livestock.animals.map(\.instanceID)
                      + metrics.animalSupplyHistory.map(\.animalID)
              )) else {
            throw SaveStoreError.invalidContents
        }
    }

    private static func validBaseline(_ baseline: StoryMetricBaseline) -> Bool {
        [
            baseline.growingCropCount,
            baseline.plantedCellCount,
            baseline.maxGrowingCropCount,
            baseline.seedBenefitPlantedCells,
            baseline.catShopReceiptCount,
            baseline.premiumReceiptCount,
            baseline.prepaymentCount,
            baseline.livestockCount,
            baseline.inventoryInvestmentUnits,
        ].allSatisfy { (0...10_000_000).contains($0) }
    }

    private static func validReservedInventory(
        _ segment: StorySegmentState,
        state: GameState,
        catalog: ContentCatalog
    ) -> Bool {
        guard segment.arcID == .q07 || (
            segment.reservedInventoryByItemID.isEmpty
                && segment.inventoryReservationReceipts.isEmpty
        ) else {
            return false
        }
        guard segment.inventoryReservationReceipts.map(\.receiptID)
                == segment.inventoryReservationReceipts.map(\.receiptID).sorted(),
              Set(segment.inventoryReservationReceipts.map(\.receiptID)).count
                == segment.inventoryReservationReceipts.count else {
            return false
        }
        if segment.phase == .locked {
            return segment.reservedInventoryByItemID.isEmpty
                && segment.inventoryReservationReceipts.isEmpty
        }
        guard let offerID = segment.benefitOfferID,
              let benefitDay = segment.benefitBaselineDay else { return false }
        var aggregate: [String: Int] = [:]
        for record in segment.inventoryReservationReceipts {
            guard ContentID.isValid(record.receiptID),
                  ContentID.isValid(record.requestID),
                  record.offerID == offerID,
                  ContentID.isValid(record.itemID),
                  catalog.knowsItemID(record.itemID),
                  (1...SaveValidation.maxQuantity).contains(record.quantity),
                  (benefitDay...state.clock.day).contains(record.day),
                  state.storyCampaign.actionReceipts.contains(where: {
                      $0.receiptID == record.receiptID
                          && $0.sourceID == record.requestID
                          && $0.day == record.day
                  }) else {
                return false
            }
            let current = aggregate[record.itemID, default: 0]
            let (next, overflow) = current.addingReportingOverflow(record.quantity)
            guard !overflow, next <= 10_000_000 else { return false }
            aggregate[record.itemID] = next
        }
        if segment.phase == .resolved {
            return segment.reservedInventoryByItemID.isEmpty
        }
        guard aggregate == segment.reservedInventoryByItemID else { return false }
        var total = 0
        for (itemID, quantity) in aggregate {
            guard ContentID.isValid(itemID),
                  catalog.knowsItemID(itemID),
                  InventoryService.count(state.inventory, itemID: itemID) >= quantity else {
                return false
            }
            let (next, overflow) = total.addingReportingOverflow(quantity)
            guard !overflow, next <= 10_000_000 else { return false }
            total = next
        }
        return true
    }

    private static func validateWarningEvidence(
        _ segment: StorySegmentState,
        metrics: StoryMetricsState,
        currentDay: Int
    ) throws {
        let related = metrics.relatedActionSerials[segment.arcID.rawValue, default: 0]
        let evidence = metrics.evidenceCheckSerials[segment.arcID.rawValue, default: 0]
        guard segment.lastRelatedActionSerial <= related else {
            throw SaveStoreError.invalidContents
        }
        if segment.phase.order < StoryPhase.warningOne.order {
            guard segment.warningOneEvidenceSerial == nil,
                  segment.warningOneEvidenceCheckSerial == nil,
                  segment.warningOneSleepEpoch == nil,
                  segment.warningTwoEvidenceSerial == nil,
                  segment.warningTwoSleepEpoch == nil else {
                throw SaveStoreError.invalidContents
            }
            return
        }
        guard let warningOneSerial = segment.warningOneEvidenceSerial,
              let warningOneEvidence = segment.warningOneEvidenceCheckSerial,
              let warningOneSleep = segment.warningOneSleepEpoch,
              (0...10_000_000).contains(warningOneSerial),
              (0...10_000_000).contains(warningOneEvidence),
              (0...currentDay).contains(warningOneSleep),
              warningOneSerial <= related,
              warningOneEvidence <= evidence else {
            throw SaveStoreError.invalidContents
        }
        if segment.phase.order < StoryPhase.warningTwo.order {
            guard segment.warningTwoEvidenceSerial == nil,
                  segment.warningTwoSleepEpoch == nil else {
                throw SaveStoreError.invalidContents
            }
            return
        }
        guard let warningTwoSerial = segment.warningTwoEvidenceSerial,
              let warningTwoSleep = segment.warningTwoSleepEpoch,
              (0...10_000_000).contains(warningTwoSerial),
              (0...currentDay).contains(warningTwoSleep),
              warningTwoSerial > warningOneSerial,
              warningTwoSerial <= related,
              warningTwoSleep >= warningOneSleep else {
            throw SaveStoreError.invalidContents
        }
        if segment.arcID == .q02 || segment.arcID == .q07 {
            guard warningTwoSleep > warningOneSleep,
                  let warningOneDay = segment.enteredDay(for: .warningOne),
                  let warningTwoDay = segment.enteredDay(for: .warningTwo),
                  warningTwoDay > warningOneDay else {
                throw SaveStoreError.invalidContents
            }
        }
        if segment.arcID == .q08 {
            guard evidence > warningOneEvidence else {
                throw SaveStoreError.invalidContents
            }
        }
        if segment.phase.order >= StoryPhase.eruption.order {
            guard related > warningTwoSerial else {
                throw SaveStoreError.invalidContents
            }
            if segment.arcID == .q02 || segment.arcID == .q07 {
                guard let warningTwoDay = segment.enteredDay(for: .warningTwo),
                      let eruptionDay = segment.enteredDay(for: .eruption),
                      eruptionDay > warningTwoDay else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
    }

    private static func validateChoiceCausality(
        campaign: StoryCampaignState,
        currentDay: Int
    ) throws {
        let sortedChoices = campaign.choices.sorted { lhs, rhs in
            if lhs.arcID.sequence != rhs.arcID.sequence {
                return lhs.arcID.sequence < rhs.arcID.sequence
            }
            if lhs.slotID.rawValue != rhs.slotID.rawValue {
                return lhs.slotID.rawValue < rhs.slotID.rawValue
            }
            return lhs.choiceID < rhs.choiceID
        }
        guard campaign.choices == sortedChoices else { throw SaveStoreError.invalidContents }
        for record in campaign.choices where record.arcID.sequence <= StoryArcID.q08.sequence {
            guard let segment = campaign.segment(record.arcID) else {
                throw SaveStoreError.invalidContents
            }
            let earliest: Int?
            switch record.slotID {
            case .primary, .eruption:
                earliest = segment.enteredDay(for: .eruption)
            case .aftermath:
                earliest = segment.enteredDay(for: .aftermath)
            case .ledgerIntent, .confrontationIntent, .finalAction:
                earliest = nil
            }
            guard let earliest, earliest <= record.day, record.day <= currentDay else {
                throw SaveStoreError.invalidContents
            }
        }
        for segment in campaign.segments
            where segment.phase.order >= StoryPhase.aftermath.order && segment.arcID != .q06 {
            guard campaign.choices.contains(where: {
                $0.arcID == segment.arcID && $0.slotID == .primary
            }) else {
                throw SaveStoreError.invalidContents
            }
        }

        let q06 = campaign.segment(.q06)!
        let careIDs = Set([
            "brookseed.story.q06.care.shared_log",
            "brookseed.story.q06.care.tea_and_roster",
        ])
        let completedCare = careIDs.intersection(q06.completedActionIDs)
        guard campaign.romanceTender == (completedCare.count == careIDs.count) else {
            throw SaveStoreError.invalidContents
        }
        if !completedCare.isEmpty {
            guard let benefitDay = q06.enteredDay(for: .benefit) else {
                throw SaveStoreError.invalidContents
            }
            let warningDay = q06.enteredDay(for: .warningOne) ?? currentDay
            for actionID in completedCare {
                guard campaign.actionReceipts.contains(where: {
                    $0.sourceID == actionID
                        && (benefitDay...warningDay).contains($0.day)
                }) else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        let eruptionChoice = campaign.choices.first {
            $0.arcID == .q06 && $0.slotID == .eruption
        }
        let aftermathChoice = campaign.choices.first {
            $0.arcID == .q06 && $0.slotID == .aftermath
        }
        if let eruptionChoice {
            let derived: StoryQ06Outcome
            if eruptionChoice.choiceID == StoryChoiceID.pause.stableID(in: .q06) {
                derived = .tender
            } else {
                derived = campaign.romanceTender ? .love : .friend
            }
            guard campaign.q06Outcome == derived else { throw SaveStoreError.invalidContents }
            if let aftermathChoice {
                guard aftermathChoice.choiceID == "\(StoryArcID.q06.rawValue).choice.\(derived.rawValue)" else {
                    throw SaveStoreError.invalidContents
                }
                if derived == .tender,
                   eruptionChoice.choiceID == StoryChoiceID.pause.stableID(in: .q06) {
                    guard aftermathChoice.day > eruptionChoice.day else {
                        throw SaveStoreError.invalidContents
                    }
                }
            }
        } else {
            guard campaign.q06Outcome == nil, aftermathChoice == nil else {
                throw SaveStoreError.invalidContents
            }
        }
        if q06.phase.order >= StoryPhase.aftermath.order {
            guard eruptionChoice != nil else { throw SaveStoreError.invalidContents }
        }
        if q06.phase == .resolved {
            guard aftermathChoice != nil else { throw SaveStoreError.invalidContents }
        }

        let q09Choices = campaign.choices.filter { $0.arcID == .q09 }
        let q10Choices = campaign.choices.filter { $0.arcID == .q10 }
        switch campaign.finaleBeat {
        case .locked, .preRevealSavePending:
            guard q09Choices.isEmpty, q10Choices.isEmpty else { throw SaveStoreError.invalidContents }
        case .discovery:
            guard q10Choices.isEmpty else { throw SaveStoreError.invalidContents }
        case .confrontation:
            guard q09Choices.count == 1,
                  !q10Choices.contains(where: { $0.slotID == .finalAction }) else {
                throw SaveStoreError.invalidContents
            }
        case .finalActionPending:
            guard q09Choices.count == 1,
                  q10Choices.contains(where: { $0.slotID == .confrontationIntent }) else {
                throw SaveStoreError.invalidContents
            }
        case .graduated:
            guard q09Choices.count == 1,
                  q10Choices.contains(where: { $0.slotID == .confrontationIntent }),
                  q10Choices.contains(where: { $0.slotID == .finalAction }) else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateReceiptLinks(_ campaign: StoryCampaignState) throws {
        let actionByID = Dictionary(uniqueKeysWithValues: campaign.actionReceipts.map {
            ($0.receiptID, $0)
        })
        let effectByID = Dictionary(uniqueKeysWithValues: campaign.effectReceipts.map {
            ($0.receiptID, $0)
        })
        for segment in campaign.segments {
            for actionID in segment.completedActionIDs {
                let receiptID = "brookseed.story.receipt.action.\(segment.arcID.shortCode).\(actionID)"
                guard actionByID[receiptID]?.sourceID == actionID else {
                    throw SaveStoreError.invalidContents
                }
            }
            guard segment.effectReceiptIDs.allSatisfy({ effectByID[$0] != nil }) else {
                throw SaveStoreError.invalidContents
            }
            if segment.arcID.sequence <= StoryArcID.q07.sequence,
               segment.phase == .resolved {
                let expectedID = "brookseed.story.receipt.\(segment.arcID.shortCode).standing"
                guard segment.standingAwardReceiptID == expectedID,
                      effectByID[expectedID]?.sourceID == segment.arcID.rawValue else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        for receipt in campaign.actionReceipts where receipt.receiptID.contains(".receipt.action.") {
            guard campaign.segments.contains(where: { segment in
                segment.completedActionIDs.contains(receipt.sourceID)
            }) else {
                throw SaveStoreError.invalidContents
            }
        }
        let expectedRepairReceiptIDs = Set((0..<campaign.repairCommissionIDs.count).map {
            "brookseed.story.receipt.repair_\($0 + 1)"
        })
        let repairReceipts = campaign.effectReceipts.filter {
            $0.receiptID.hasPrefix("brookseed.story.receipt.repair_")
        }
        guard Set(repairReceipts.map(\.receiptID)) == expectedRepairReceiptIDs,
              Set(repairReceipts.map(\.sourceID)) == Set(campaign.repairCommissionIDs) else {
            throw SaveStoreError.invalidContents
        }
    }

    private static func validateStoryCursor(
        campaign: StoryCampaignState,
        lease: FrontstageLease,
        catalog: StoryContentCatalog
    ) throws {
        guard let arcID = StoryArcID(rawValue: lease.resourceID),
              arcID.sequence <= StoryArcID.q08.sequence,
              let segment = campaign.segment(arcID),
              segment.phase != .locked,
              segment.phase != .resolved,
              campaign.cursor.eventID == arcID.rawValue,
              campaign.cursor.beatID == segment.phase.rawValue,
              lease.checkpointID == nil,
              campaign.cursor.checkpointID == nil,
              lease.acquiredDay >= (segment.enteredDay(for: segment.phase) ?? Int.max),
              let cueID = campaign.cursor.cueID,
              let cue = catalog.visibleBlockingCue(
                  id: cueID,
                  finaleUnlocked: campaign.finaleBeat.order >= FinaleBeat.discovery.order
              ),
              cue.arcID == arcID,
              campaign.cursor.sceneID == cue.sceneID,
              let stageKind = StoryStageID(rawValue: segment.phase.rawValue),
              let stage = catalog.stage(arcID: arcID, kind: stageKind) else {
            throw SaveStoreError.invalidContents
        }
        if let lineID = campaign.cursor.lineID {
            guard let index = stage.lines.firstIndex(where: { $0.id == lineID }),
                  index == campaign.cursor.lineIndex,
                  let line = catalog.visibleLine(
                      id: lineID,
                      finaleUnlocked: campaign.finaleBeat.order >= FinaleBeat.discovery.order
                  ),
                  line.blockingCueID == nil || line.blockingCueID == cueID else {
                throw SaveStoreError.invalidContents
            }
        } else if campaign.cursor.lineIndex != 0 {
            throw SaveStoreError.invalidContents
        }
    }

    /// A persisted dialogue session must match its frontstage lease and be
    /// exactly reproducible from the current campaign state.
    private static func validateDialogueSession(
        campaign: StoryCampaignState,
        state: GameState,
        currentDay: Int,
        catalog: StoryContentCatalog
    ) throws {
        guard let session = campaign.dialogueSession else { return }
        let finaleUnlocked = campaign.finaleBeat.order >= FinaleBeat.discovery.order
        guard !session.isClosed,
              session.sessionID.hasPrefix("brookseed.story.session."),
              ContentID.isValid(session.sessionID),
              (1...currentDay).contains(session.createdAtDay),
              session.lineIndex >= 0,
              session.lineIndex <= session.presentedLineIDs.count,
              !session.presentedLineIDs.isEmpty,
              Set(session.presentedLineIDs).count == session.presentedLineIDs.count,
              session.presentedLineIDs.allSatisfy(ContentID.isValid),
              let stage = catalog.stage(arcID: session.arcID, kind: session.stageKind) else {
            throw SaveStoreError.invalidContents
        }
        for lineID in session.presentedLineIDs {
            guard stage.lines.contains(where: { $0.id == lineID }),
                  catalog.visibleLine(
                      id: lineID,
                      finaleUnlocked: finaleUnlocked
                  )?.blockingCueID == session.cueID else {
                throw SaveStoreError.invalidContents
            }
        }
        let expected = StoryLineConditionResolver.presentedSequence(
            for: stage,
            state: state,
            arcID: session.arcID
        )
        guard session.presentedLineIDs == expected.lineIDs,
              session.choiceBoundaryLineIndex == expected.boundary else {
            throw SaveStoreError.invalidContents
        }
        if session.selectedChoiceID != nil {
            guard session.pendingChoiceIDs.isEmpty,
                  let choiceID = session.selectedChoiceID,
                  campaign.choices.contains(where: {
                      $0.arcID == session.arcID && $0.choiceID == choiceID
                  }) else {
                throw SaveStoreError.invalidContents
            }
        }
        guard let lease = campaign.frontstageLease else {
            throw SaveStoreError.invalidContents
        }
        switch lease.owner {
        case .story, .finale:
            guard lease.resourceID == session.arcID.rawValue,
                  campaign.cursor.eventID == session.arcID.rawValue,
                  campaign.cursor.beatID == session.stageKind.rawValue,
                  campaign.cursor.sceneID == session.sceneID,
                  campaign.cursor.cueID == session.cueID else {
                throw SaveStoreError.invalidContents
            }
        case .journey:
            guard session.arcID == .q08,
                  campaign.cursor.eventID == StoryArcID.q08.rawValue,
                  campaign.cursor.beatID == "journey",
                  campaign.cursor.lineID == nil,
                  campaign.cursor.cueID == nil else {
                throw SaveStoreError.invalidContents
            }
        case .communityEvent, .forcedTutorial, .resumedSession, .hint:
            throw SaveStoreError.invalidContents
        }
    }

    private static func validateFinale(
        campaign: StoryCampaignState,
        currentDay: Int
    ) throws {
        if campaign.finaleBeat == .locked {
            guard campaign.finaleBeatDay == nil,
                  !campaign.protection.preRevealVerified,
                  !campaign.communityEvaluationDisabled,
                  !campaign.gallery.isUnlocked else {
                throw SaveStoreError.invalidContents
            }
            return
        }
        guard campaign.q08Completed,
              campaign.mission?.status == .completed,
              campaign.mission?.checkpoint == .homecoming,
              campaign.protection.preRevealVerified,
              let beatDay = campaign.finaleBeatDay,
              (1...currentDay).contains(beatDay),
              campaign.communityEvaluationDisabled == (campaign.finaleBeat == .graduated),
              campaign.gallery.isUnlocked == (campaign.finaleBeat == .graduated) else {
            throw SaveStoreError.invalidContents
        }
        if campaign.finaleBeat == .graduated {
            guard campaign.segments.allSatisfy({ $0.phase == .resolved }),
                  campaign.gallery.endingID != nil else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validProduct(_ lhs: Int, _ rhs: Int) -> Bool {
        let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return !overflow && (0...SaveValidation.maxLineAmount).contains(product)
    }

    /// Mission snapshots freeze the real pending-entry identifiers, which are
    /// `ShippingEntry.mergeKey` strings (`<itemID>#<quality>#day<N>`), so the
    /// `#` separator is expected here even though it is not a ContentID char.
    private static func validMissionShippingEntryID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 120 else { return false }
        let parts = value.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        guard ContentID.isValid(String(parts[0])),
              ["normal", "good", "excellent"].contains(String(parts[1])),
              parts[2].hasPrefix("day") else { return false }
        let dayPart = String(parts[2].dropFirst(3))
        guard !dayPart.isEmpty, dayPart.allSatisfy(\.isNumber) else { return false }
        return true
    }

    private static func boundedSum<S: Sequence>(_ values: S) -> Int where S.Element == Int {
        var total = 0
        for value in values {
            let (next, overflow) = total.addingReportingOverflow(value)
            guard !overflow, next <= 10_000_000 else { return Int.max }
            total = next
        }
        return total
    }

    private static func validCropKeys<S: Sequence>(
        _ keys: S,
        catalog: ContentCatalog
    ) -> Bool where S.Element == String {
        keys.allSatisfy { ContentID.isValid($0) && catalog.knowsCropID($0) }
    }

    private static func validNPCKeys<S: Sequence>(
        _ keys: S,
        catalog: ContentCatalog
    ) -> Bool where S.Element == String {
        keys.allSatisfy { ContentID.isValid($0) && catalog.npc(id: $0) != nil }
    }

    private static func uniqueSorted(_ values: [String]) -> Bool {
        values == values.sorted() && Set(values).count == values.count
    }

    private static func uniqueSortedDays(_ values: [Int], maximum: Int) -> Bool {
        values.allSatisfy { (1...maximum).contains($0) }
            && values == values.sorted()
            && Set(values).count == values.count
    }
}
