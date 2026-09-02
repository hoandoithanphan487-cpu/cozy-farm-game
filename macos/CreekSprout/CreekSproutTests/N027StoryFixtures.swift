import Foundation
@testable import CreekSprout

/// Shared legal story fixtures for N-027 runtime tests. Every fixture is a
/// save-valid `GameState` (passes `SaveValidation.validateN027`), so tests can
/// validate mid-flow without constructing invalid intermediate states.
enum N027StoryFixtures {
    static func legalResolvedSegment(
        arcID: StoryArcID,
        baseDay: Int
    ) -> StorySegmentState {
        var segment = StorySegmentState.locked(arcID)
        segment.enter(.benefit, day: baseDay)
        segment.benefitOfferID = "brookseed.story.offer.\(arcID.shortCode).day_\(baseDay)"
        segment.benefitBaselineDay = baseDay
        segment.benefitBaseline = StoryMetricBaseline.zero
        segment.enter(.warningOne, day: baseDay + 1)
        segment.warningOneEvidenceSerial = 0
        segment.warningOneEvidenceCheckSerial = 0
        segment.warningOneSleepEpoch = 1
        segment.enter(.warningTwo, day: baseDay + 2)
        segment.warningTwoEvidenceSerial = 1
        segment.warningTwoSleepEpoch = (arcID == .q02 || arcID == .q07) ? 2 : 1
        segment.enter(.eruption, day: baseDay + 3)
        segment.enter(.aftermath, day: baseDay + 3)
        segment.enter(.resolved, day: baseDay + 5)
        segment.aftermathQuality = .responsible
        segment.lastRelatedActionSerial = 2
        segment.completedActionIDs = [
            "brookseed.story.\(arcID.shortCode).action.between_warnings",
            "brookseed.story.\(arcID.shortCode).action.pre_eruption",
        ]
        let choice = StoryChoiceID.choices(for: arcID)[0]
        segment.selectedChoiceIDsBySlot[choice.slot(in: arcID).rawValue] =
            choice.stableID(in: arcID)
        return segment
    }

    /// Applies a legally resolved arc (segment, choice record, standing
    /// receipt, metrics serials). Q06 additionally records both care actions
    /// and the love aftermath so `validateChoiceCausality` passes.
    static func applyLegalResolved(
        to state: inout GameState,
        arcID: StoryArcID,
        baseDay: Int
    ) {
        var segment = legalResolvedSegment(arcID: arcID, baseDay: baseDay)
        let standingID = "brookseed.story.receipt.\(arcID.shortCode).standing"
        segment.standingAwardReceiptID = standingID
        segment.effectReceiptIDs = [standingID]
        let choice = StoryChoiceID.choices(for: arcID)[0]
        if arcID == .q06 {
            // Eruption intent must be one of talk/noSide/pause; care actions
            // make romance_tender true → love.
            let eruptionChoice = StoryChoiceID.talk
            let aftermathChoice = StoryChoiceID.love
            segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.eruption.rawValue] =
                eruptionChoice.stableID(in: .q06)
            segment.selectedChoiceIDsBySlot[StoryChoiceSlotID.aftermath.rawValue] =
                aftermathChoice.stableID(in: .q06)
            let careIDs = [
                "brookseed.story.q06.care.shared_log",
                "brookseed.story.q06.care.tea_and_roster",
            ]
            segment.completedActionIDs.append(contentsOf: careIDs)
            segment.lastRelatedActionSerial += careIDs.count
            state.storyCampaign.romanceTender = true
            state.storyCampaign.q06Outcome = .love
            // Aftermath slot sorts before eruption slot in the persisted
            // choice ledger.
            state.storyCampaign.choices.append(
                StoryChoiceRecord(arcID: .q06, slotID: .aftermath, choiceID: aftermathChoice.stableID(in: .q06), day: baseDay + 4)
            )
            state.storyCampaign.choices.append(
                StoryChoiceRecord(arcID: .q06, slotID: .eruption, choiceID: eruptionChoice.stableID(in: .q06), day: baseDay + 3)
            )
        } else {
            state.storyCampaign.choices.append(
                StoryChoiceRecord(
                    arcID: arcID,
                    slotID: choice.slot(in: arcID),
                    choiceID: choice.stableID(in: arcID),
                    day: baseDay + 3
                )
            )
        }
        state.storyCampaign.updateSegment(segment)
        state.storyCampaign.effectReceipts.append(
            StoryReceiptRecord(
                receiptID: standingID,
                sourceID: arcID.rawValue,
                day: baseDay + 5
            )
        )
        // validateReceiptLinks: every completed action needs its action
        // receipt; Q06 care receipts must land inside
        // [benefitDay, warningOneDay].
        for (offset, actionID) in (segment.completedActionIDs).enumerated() {
            let day: Int
            if arcID == .q06, actionID.hasPrefix("brookseed.story.q06.care.") {
                day = baseDay
            } else {
                day = baseDay + min(offset, 1)
            }
            state.storyCampaign.actionReceipts.append(
                StoryReceiptRecord(
                    receiptID: "brookseed.story.receipt.action.\(arcID.shortCode).\(actionID)",
                    sourceID: actionID,
                    day: day
                )
            )
        }
        state.storyMetrics.relatedActionSerials[arcID.rawValue] =
            segment.lastRelatedActionSerial
        state.storyMetrics.canonicalize()
        state.storyCampaign.canonicalize()
    }

    /// All arcs before `target` legally resolved (Q06 handled specially).
    static func applyAllPriorResolved(
        to state: inout GameState,
        before target: StoryArcID
    ) {
        let prior = StoryArcID.allCases.filter { $0.sequence < target.sequence }
        for (offset, arcID) in prior.enumerated() {
            applyLegalResolved(to: &state, arcID: arcID, baseDay: 2 + offset * 8)
        }
    }

    /// A state with every arc before `target` resolved and the target at
    /// `phase` with legal evidence serials. `baseDay` is a hint; the effective
    /// benefit day is pushed past every prior arc's resolution day. A
    /// `.resolved` target is fully legal (standing receipt, choice, effects).
    static func targetFixture(
        target: StoryArcID,
        phase: StoryPhase,
        baseDay: Int,
        standing: Int,
        q06CaresCompleted: Bool = true
    ) -> GameState {
        var state = GameState.vs0NewGame(catalog: .vs0)
        let priorCount = target.sequence - 1
        let effectiveBaseDay = max(baseDay, 2 + priorCount * 8)
        state.clock = GameClock(day: effectiveBaseDay + 6, minute: GameClock.dayStartMinute)
        state.community.standing = standing
        applyAllPriorResolved(to: &state, before: target)
        var segment = StorySegmentState.locked(target)
        segment.enter(.benefit, day: effectiveBaseDay)
        segment.benefitOfferID = "brookseed.story.offer.\(target.shortCode).day_\(effectiveBaseDay)"
        segment.benefitBaselineDay = effectiveBaseDay
        segment.benefitBaseline = StoryMetricBaseline.zero
        if phase.order >= StoryPhase.warningOne.order {
            segment.enter(.warningOne, day: effectiveBaseDay + 1)
            segment.warningOneEvidenceSerial = 0
            segment.warningOneEvidenceCheckSerial = 0
            segment.warningOneSleepEpoch = 1
        }
        if phase.order >= StoryPhase.warningTwo.order {
            segment.enter(.warningTwo, day: effectiveBaseDay + 2)
            segment.warningTwoEvidenceSerial = 1
            segment.warningTwoSleepEpoch = (target == .q02 || target == .q07) ? 2 : 1
        }
        if phase.order >= StoryPhase.eruption.order {
            segment.enter(.eruption, day: effectiveBaseDay + 3)
            var actionIDs = [
                "brookseed.story.\(target.shortCode).action.between_warnings",
                "brookseed.story.\(target.shortCode).action.pre_eruption",
            ]
            // Q06 care actions legally complete during benefit; recording
            // them through StoryCommandService is rejected after benefit, so
            // the eruption-phase fixture carries both care completions.
            // The friend outcome requires neither care action to complete.
            if target == .q06, q06CaresCompleted {
                actionIDs.append(contentsOf: [
                    "brookseed.story.q06.care.shared_log",
                    "brookseed.story.q06.care.tea_and_roster",
                ])
            }
            segment.completedActionIDs = actionIDs.sorted()
            segment.lastRelatedActionSerial = actionIDs.count
        }
        if phase.order >= StoryPhase.aftermath.order {
            segment.enter(.aftermath, day: effectiveBaseDay + 3)
        }
        state.storyCampaign.updateSegment(segment)
        // validateReceiptLinks: every completed action needs its action
        // receipt; Q06 care receipts land inside [benefitDay, warningOneDay].
        for (offset, actionID) in (state.storyCampaign.segment(target)?.completedActionIDs ?? []).enumerated() {
            let day: Int
            if target == .q06, actionID.hasPrefix("brookseed.story.q06.care.") {
                day = effectiveBaseDay
            } else {
                day = effectiveBaseDay + min(offset, 1)
            }
            state.storyCampaign.actionReceipts.append(
                StoryReceiptRecord(
                    receiptID: "brookseed.story.receipt.action.\(target.shortCode).\(actionID)",
                    sourceID: actionID,
                    day: day
                )
            )
        }
        if target == .q06, phase.order >= StoryPhase.eruption.order, q06CaresCompleted {
            state.storyCampaign.romanceTender = true
        }
        // Q01 warning_1 through graduation pauses new M3 rumour offers.
        state.storyCampaign.m3OffersPaused =
            (state.storyCampaign.segment(.q01)?.phase.order ?? 0)
            >= StoryPhase.warningOne.order
        state.storyMetrics.relatedActionSerials[target.rawValue] =
            state.storyCampaign.segment(target)?.lastRelatedActionSerial ?? 2
        state.storyMetrics.anchorReentrySerials[target.rawValue] = 2
        state.storyMetrics.canonicalize()
        state.storyCampaign.canonicalize()
        if phase == .resolved {
            var resolved = state.storyCampaign.segment(target)!
            resolved.enter(.resolved, day: effectiveBaseDay + 5)
            resolved.aftermathQuality = .responsible
            let standingID = "brookseed.story.receipt.\(target.shortCode).standing"
            resolved.standingAwardReceiptID = standingID
            resolved.effectReceiptIDs = [standingID]
            if target == .q06 {
                // A resolved Q06 needs both slots. With both care actions
                // completed, talk derives love; without them, noSide derives
                // friend.
                let eruptionChoice = q06CaresCompleted
                    ? StoryChoiceID.talk : StoryChoiceID.noSide
                let aftermathChoice = q06CaresCompleted
                    ? StoryChoiceID.love : StoryChoiceID.friend
                resolved.selectedChoiceIDsBySlot[StoryChoiceSlotID.eruption.rawValue] =
                    eruptionChoice.stableID(in: .q06)
                resolved.selectedChoiceIDsBySlot[StoryChoiceSlotID.aftermath.rawValue] =
                    aftermathChoice.stableID(in: .q06)
                state.storyCampaign.romanceTender = q06CaresCompleted
                state.storyCampaign.q06Outcome = q06CaresCompleted ? .love : .friend
                state.storyCampaign.choices.append(
                    StoryChoiceRecord(
                        arcID: .q06,
                        slotID: .aftermath,
                        choiceID: aftermathChoice.stableID(in: .q06),
                        day: effectiveBaseDay + 4
                    )
                )
                state.storyCampaign.choices.append(
                    StoryChoiceRecord(
                        arcID: .q06,
                        slotID: .eruption,
                        choiceID: eruptionChoice.stableID(in: .q06),
                        day: effectiveBaseDay + 3
                    )
                )
            } else {
                let choice = StoryChoiceID.choices(for: target)[0]
                resolved.selectedChoiceIDsBySlot[choice.slot(in: target).rawValue] =
                    choice.stableID(in: target)
                state.storyCampaign.choices.append(
                    StoryChoiceRecord(
                        arcID: target,
                        slotID: choice.slot(in: target),
                        choiceID: choice.stableID(in: target),
                        day: effectiveBaseDay + 3
                    )
                )
            }
            state.storyCampaign.updateSegment(resolved)
            state.storyCampaign.effectReceipts.append(
                StoryReceiptRecord(
                    receiptID: standingID,
                    sourceID: target.rawValue,
                    day: effectiveBaseDay + 5
                )
            )
            state.storyCampaign.canonicalize()
            state.storyMetrics.canonicalize()
        }
        return state
    }
}
