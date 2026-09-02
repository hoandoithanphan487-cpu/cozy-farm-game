//
//  CommunityCommandService.swift
//  CreekSprout
//
//  Presentation-facing facade for M3-003. The scene calls these methods and
//  renders the returned text; it never recomputes standing bands, trust
//  multipliers, deadlines or reward rules.
//

struct CommunityTalkCandidate: Equatable, Sendable {
    var state: GameState
    var feedback: CommandFeedback?
}

struct CommunityCommandService: Sendable {
    var catalog: ContentCatalog

    // MARK: - Commands

    /// Ordinary conversation. Only the daily first talk with a function NPC
    /// grants trust; it never touches standing, watershed or event state, and
    /// talking to a neighbour changes nothing at all.
    func talk(state: inout GameState, npcID: String) -> CommandFeedback? {
        guard let transaction = talkCandidate(state: state, npcID: npcID) else {
            return nil
        }
        state = transaction.state
        return transaction.feedback
    }

    /// Pure candidate form for validate/save-before-commit workflows.
    func talkCandidate(state: GameState, npcID: String) -> CommunityTalkCandidate? {
        guard catalog.npc(id: npcID) != nil else {
            return nil
        }
        var candidate = state
        StoryMetricsRecorder.recordTalk(
            metrics: &candidate.storyMetrics,
            sourceID: "brookseed.story.metric.talk.day_\(state.clock.day).\(npcID)",
            npcID: npcID,
            day: state.clock.day
        )
        guard catalog.isQuestGiver(npcID) else {
            return CommunityTalkCandidate(state: candidate, feedback: nil)
        }
        switch RelationshipService.applyDailyFirstTalk(
            state: &candidate,
            npcID: npcID,
            catalog: catalog
        ) {
        case .failure:
            return nil
        case .success(let grant):
            guard grant.didApply else {
                return CommunityTalkCandidate(state: candidate, feedback: nil)
            }
            let name = catalog.npc(id: npcID)?.displayName ?? npcID
            if grant.wasZeroGrowth {
                return CommunityTalkCandidate(
                    state: candidate,
                    feedback: .success("\(name)：今天的信任增长为 0.00（转述造成的误会尚未澄清）。")
                )
            }
            let awarded = TrustRecord(npcID: npcID, subpoints: grant.awardedSubpoints).displayPoints
            let total = TrustRecord(npcID: npcID, subpoints: grant.totalSubpoints).displayPoints
            return CommunityTalkCandidate(
                state: candidate,
                feedback: .success("\(name)：今日首次交谈，信任 +\(awarded)（合计 \(total)）。")
            )
        }
    }

    func submit(state: inout GameState, actionID: String, npcID: String) -> CommandFeedback {
        let before = state
        let choiceText = catalog.gossipAction(id: actionID)?.choiceText ?? actionID
        switch ResolveGossipActionUseCase.submit(
            state: &state,
            actionID: actionID,
            npcID: npcID,
            catalog: catalog
        ) {
        case .failure(let failure):
            // `state` may already carry a committed deadline expiry; only the
            // rejected action itself is rolled back inside the use case.
            return .failure(message(for: failure, actionID: actionID, choiceText: choiceText))
        case .success(let outcome):
            guard outcome.didApply else {
                return .success("\(choiceText) 已提交过，状态仍为 \(outcome.event.status.displayName)，未重复发放奖励。")
            }
            var parts = [
                "已提交：\(choiceText)。",
                "事件状态 \(outcome.event.status.displayName)。",
            ]
            if outcome.standingAfter != outcome.standingBefore {
                parts.append("风评 \(outcome.standingBefore)→\(outcome.standingAfter)。")
            } else {
                parts.append("风评保持 \(outcome.standingAfter)。")
            }
            if outcome.watershedPointsAwarded > 0 {
                parts.append("水脉 +\(outcome.watershedPointsAwarded)。")
            }
            if outcome.trustSubpointsAwarded > 0 {
                let display = TrustRecord(npcID: "", subpoints: outcome.trustSubpointsAwarded).displayPoints
                parts.append("一次性信任 +\(display)。")
            }
            if before.community.standing != state.community.standing {
                let questID = ContentID.marketNoticeQuest
                let beforeStatus = QuestService.optionalNodeStatus(
                    of: questID,
                    state: before,
                    catalog: catalog
                )
                let afterStatus = QuestService.optionalNodeStatus(
                    of: questID,
                    state: state,
                    catalog: catalog
                )
                if beforeStatus == .paused && afterStatus == .available {
                    parts.append("可选节点已从暂停恢复为可用。")
                } else if beforeStatus == .available && afterStatus == .paused {
                    parts.append("可选节点已暂停（主线不受影响）。")
                }
                parts.append(optionalNodeSummary(state: state))
            }
            return .success(parts.joined(separator: " "))
        }
    }

    // MARK: - Derived text

    func standingLine(state: GameState) -> String {
        let balance = catalog.communityBalance
        let standing = state.community.standing
        return "风评 \(standing)/\(balance.maxStanding)  \(balance.standingLabel(for: standing))"
    }

    func eventLine(state: GameState) -> String {
        guard let event = GossipService.latestEvent(state: state) else {
            return "社区事件：暂无（第 2 天由涧麦婶处出现）"
        }
        let claimName = catalog.gossipClaim(id: event.claimID).map { claim in
            event.truthVerified ? claim.verifiedText : claim.rumorText
        } ?? event.claimID
        return "社区事件 \(event.status.displayName)  截止 \(event.deadlineCaption)  行动记录 \(event.actionHistory.count) 条\n说法：\(claimName)"
    }

    func verificationPathLine(state: GameState) -> String {
        guard shouldShowVerificationPath(state: state) else {
            return ""
        }
        return HudCopy.verificationPathHint(status: GossipService.latestEvent(state: state)?.status)
    }

    private func shouldShowVerificationPath(state: GameState) -> Bool {
        guard let event = GossipService.latestEvent(state: state) else {
            return state.clock.day < 3
        }
        if state.clock.day >= 3 {
            switch event.status {
            case .resolvedCorrected, .resolvedRelay, .deferred, .expired:
                return false
            default:
                return true
            }
        }
        return true
    }

    func actionLine(state: GameState, npcID: String?, selectedIndex: Int) -> String {
        guard let npcID else {
            return "可用行动：走到涧麦婶 / 青砚 / 絮宁 旁边查看"
        }
        let actions = availableActions(state: state, npcID: npcID)
        let name = catalog.npc(id: npcID)?.displayName ?? npcID
        guard !actions.isEmpty else {
            return "可用行动（\(name)）：无"
        }
        let index = actions.isEmpty ? 0 : selectedIndex % actions.count
        let listing = actions.enumerated().map { offset, action in
            offset == index ? "▶ \(action.choiceText)" : "· \(action.choiceText)"
        }.joined(separator: "  ")
        return "可用行动（\(name)）\(index + 1)/\(actions.count)：\(listing)"
    }

    func optionalNodeSummary(state: GameState) -> String {
        let questID = ContentID.marketNoticeQuest
        guard let quest = catalog.quest(id: questID), let minStanding = quest.minStanding else {
            return "可选节点：无门槛"
        }
        let status = QuestService.optionalNodeStatus(of: questID, state: state, catalog: catalog)
        let recovery = QuestService.recoveryPathIDs(for: questID, catalog: catalog)
            .map { recoveryDisplayName($0) }
            .joined(separator: "、")
        let standing = state.community.standing
        switch status {
        case .paused:
            return "可选节点 \(quest.title)：暂停（风评 \(standing) < 门槛 \(minStanding)；主线不受影响）  恢复路径：\(recovery)（V 不是首次核实入口）"
        case .available:
            return "可选节点 \(quest.title)：可用（风评 \(standing) ≥ \(minStanding)）  恢复路径仍可用：\(recovery)（V 不是首次核实入口）"
        case .ungated:
            return "可选节点 \(quest.title)：无门槛"
        }
    }

    func trustLine(state: GameState) -> String {
        let targetID = claimTargetID(state: state) ?? ContentID.waterApprentice
        let name = catalog.npc(id: targetID)?.displayName ?? targetID
        let record = state.relationships.record(targetID) ?? TrustRecord(npcID: targetID)
        let effects = state.relationships.activeEffects(for: targetID)
        var suffix = ""
        if effects.contains(where: { $0.zeroesGrowth(on: state.clock.day) }) {
            suffix = "  今日增长归零"
        } else if let effect = effects.first(where: { $0.appliesFirstTalkMultiplier(on: state.clock.day) }) {
            suffix = "  误会期首次交谈 ×\(Double(effect.firstTalkMultiplierBP) / 10_000.0)"
        }
        return "信任 \(name) \(record.displayPoints)（子点 \(record.subpoints)，余数 \(record.remainder)）\(suffix)"
    }

    func availableActions(state: GameState, npcID: String) -> [GossipActionDefinition] {
        GossipService.availableActions(state: state, npcID: npcID, catalog: catalog)
    }

    func claimTargetID(state: GameState) -> String? {
        guard let event = GossipService.latestEvent(state: state) else {
            return catalog.gossipClaims.values.sorted { $0.id < $1.id }.first?.targetNpcID
        }
        return catalog.gossipClaim(id: event.claimID)?.targetNpcID
    }

    private func recoveryDisplayName(_ id: String) -> String {
        if let action = catalog.gossipAction(id: id) {
            return action.choiceText
        }
        if let quest = catalog.quest(id: id) {
            return quest.title
        }
        return id
    }

    private func message(for failure: GossipFailure, actionID: String, choiceText: String) -> String {
        switch failure {
        case .unknownAction, .unknownEvent, .invalidContent:
            return "无法提交：\(choiceText) 的内容配置不可用。"
        case .noActiveEvent:
            return "无法提交：当前没有进行中的社区事件。"
        case .illegalTransition:
            if actionID == ContentID.verifyWithCAction {
                return "无法提交：首次「向青砚核实」需要事件处于核实中。请先在涧麦婶处用 Y/B 选择「开始核实」。V 不是首次核实入口。"
            }
            return "无法提交：\(choiceText) 与当前事件状态不匹配。"
        case .wrongInteractionNpc:
            return "无法提交：需要在对应邻居旁边提交 \(choiceText)。"
        case .conditionsNotMet:
            return "无法提交：还没有可观察的证据。"
        case .deadlinePassed:
            return "无法提交：事件已过截止时间。"
        }
    }
}
