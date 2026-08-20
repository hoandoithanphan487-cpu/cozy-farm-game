import XCTest
@testable import CreekSprout

/// D0-001 presentation copy: R1 verification-entry clarification, HUD sections,
/// and pause/resume wording. Domain standing/trust/watershed numbers are not
/// re-asserted here.
final class HudCopyTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private var community: CommunityCommandService { CommunityCommandService(catalog: catalog) }

    func testKeyHintsNeverPresentVAsFirstVerifyEntry() {
        let hints = HudCopy.keyHints(isDialogueActive: false)
        XCTAssertTrue(hints.contains("向青砚核实"))
        XCTAssertTrue(hints.contains("开始核实"))
        XCTAssertTrue(hints.contains("[Y]切换社区行动"))
        XCTAssertTrue(hints.contains("[B]提交所选行动"))
        XCTAssertTrue(hints.contains("可选恢复"))
        XCTAssertTrue(hints.contains("不是首次核实入口"))
        XCTAssertTrue(hints.contains("V 不是入口") || hints.contains("不是首次核实入口"))
        XCTAssertFalse(hints.contains("完成青砚的一步核实"))
        XCTAssertFalse(hints.contains("[V]完成"))
    }

    func testDialogueHintsLockOtherActionsInWords() {
        let hints = HudCopy.keyHints(isDialogueActive: true)
        XCTAssertTrue(hints.contains("时钟已暂停"))
        XCTAssertTrue(hints.contains("对白结束前其他操作锁定"))
        XCTAssertFalse(hints.contains("[V]"))
    }

    func testVerificationHintForEachEventStatus() {
        XCTAssertTrue(
            HudCopy.verificationPathHint(status: nil).contains("开始核实")
        )
        let offered = HudCopy.verificationPathHint(status: .offered)
        XCTAssertTrue(offered.contains("开始核实"))
        XCTAssertTrue(offered.contains("不要按 V"))
        XCTAssertTrue(offered.contains("不是首次核实入口") || offered.contains("只用于可选恢复"))

        let investigating = HudCopy.verificationPathHint(status: .investigating)
        XCTAssertTrue(investigating.contains("向青砚核实"))
        XCTAssertTrue(investigating.contains("Y/B"))
        XCTAssertTrue(investigating.contains("不要按 V"))

        let verified = HudCopy.verificationPathHint(status: .verified)
        XCTAssertTrue(verified.contains("纠正絮宁"))
        XCTAssertTrue(verified.contains("不是首次核实入口"))

        XCTAssertTrue(
            HudCopy.verificationPathHint(status: .resolvedCorrected).contains("向青砚核实")
        )
    }

    func testEvidenceObjectiveCopyDistinguishesOptionalRecovery() {
        XCTAssertTrue(HudCopy.evidenceAwayFromQingyan().contains("不是首次核实入口"))
        XCTAssertTrue(HudCopy.evidenceAwayFromQingyan().contains("向青砚核实"))
        XCTAssertTrue(HudCopy.evidenceCannotComplete().contains("核实中"))
        XCTAssertTrue(HudCopy.evidenceCannotComplete().contains("向青砚核实"))
        let done = HudCopy.evidenceCompleted(standing: 55, optionalSummary: "节点")
        XCTAssertTrue(done.contains("可选恢复"))
        XCTAssertTrue(done.contains("这不是首次核实入口"))
        XCTAssertTrue(done.contains("风评 55"))
    }

    func testFeedbackPrefixesDoNotRelyOnColorAlone() {
        XCTAssertEqual(HudCopy.feedbackLine(message: "保存成功。", isSuccess: true), "[+] 成功：保存成功。")
        XCTAssertEqual(HudCopy.feedbackLine(message: "无法交谈。", isSuccess: false), "[!] 失败：无法交谈。")
        XCTAssertFalse(HudCopy.feedbackLine(message: "ok", isSuccess: true).contains("✅"))
        XCTAssertFalse(HudCopy.feedbackLine(message: "no", isSuccess: false).contains("❌"))
    }

    func testAssembledHudKeepsInformationHierarchyAndR1Copy() {
        let hud = HudCopy.assemble(
            mapName: "农场与农舍",
            day: 2,
            time: "07:00",
            weather: "雨",
            goalLine: "当前目标：示例",
            questSummary: "任务 让旧水渠再次流动：未接取",
            watershedLine: "水脉 0/20  水道 干涸  环境音 静水层",
            standingLine: "风评 50/100  常规区间（信任增长无修正）",
            eventLine: "社区事件 待回应  截止 第 3 天 23:30  行动记录 0 条",
            verificationHint: HudCopy.verificationPathHint(status: .offered),
            trustLine: "信任 水工学徒 0.00",
            optionalNodeLine: "可选节点 邻里告示板：溪岸互助：可用",
            actionLine: "可用行动：走到涧麦婶 / 青砚 / 絮宁 旁边查看",
            stamina: 100,
            balance: 894,
            pending: 0,
            inventory: "背包 1/16",
            recipe: "水渠接片",
            settlement: "最近日结：雾萝卜×3 = 174（总额 174）",
            tool: "锄头",
            playerCaption: "(5, 4)",
            targetCaption: "(5, 5)",
            dialogueLine: nil,
            feedback: HudCopy.feedbackLine(message: "日结完成。", isSuccess: true),
            isDialogueActive: false
        )
        XCTAssertTrue(hud.contains("【状态】"))
        XCTAssertTrue(hud.contains("天气 雨"))
        XCTAssertTrue(hud.contains("【目标】"))
        XCTAssertTrue(hud.contains("【社区】"))
        XCTAssertTrue(hud.contains("【资源】"))
        XCTAssertTrue(hud.contains("【按键】"))
        XCTAssertTrue(hud.contains("风评 50/100"))
        XCTAssertTrue(hud.contains("水脉 0/20"))
        XCTAssertTrue(hud.contains("截止 第 3 天 23:30"))
        XCTAssertTrue(hud.contains("向青砚核实"))
        XCTAssertTrue(hud.contains("不是首次核实入口") || hud.contains("不要按 V"))
        XCTAssertTrue(hud.contains("成功：日结完成。"))
        XCTAssertFalse(hud.contains("[V]完成青砚的一步核实"))
    }

    func testShippedEvidenceQuestTitleIsOptionalRecovery() throws {
        let quest = try XCTUnwrap(catalog.quest(id: ContentID.evidenceOneStepQuest))
        XCTAssertEqual(quest.title, "可选恢复：把观察痕迹交给青砚")
        XCTAssertEqual(
            catalog.displayName(forNameKey: "quest.evidence_one_step"),
            "可选恢复：把观察痕迹交给青砚"
        )
        XCTAssertFalse(quest.title.contains("一步核实"))
        XCTAssertEqual(catalog.gossipAction(id: ContentID.verifyWithCAction)?.choiceText, "向青砚核实")
    }

    func testOfferedEventHudPointsAtStartThenQingyanChoice() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        let hint = community.verificationPathLine(state: state)
        XCTAssertTrue(hint.contains("开始核实"))
        XCTAssertTrue(hint.contains("不要按 V") || hint.contains("不是首次核实入口"))
        XCTAssertTrue(community.eventLine(state: state).contains("待回应"))
        XCTAssertTrue(community.eventLine(state: state).contains("第 3 天 23:30"))
        XCTAssertTrue(community.optionalNodeSummary(state: state).contains("可用"))
        XCTAssertTrue(community.optionalNodeSummary(state: state).contains("V 不是首次核实入口"))
    }

    func testInvestigatingEventHudNamesFirstVerifyChoiceNotV() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        _ = community.submit(
            state: &state,
            actionID: ContentID.startVerificationAction,
            npcID: ContentID.neighborHearsay
        )
        let hint = community.verificationPathLine(state: state)
        XCTAssertTrue(hint.contains("向青砚核实"))
        XCTAssertTrue(hint.contains("不要按 V"))
        XCTAssertTrue(community.eventLine(state: state).contains("核实中"))
        XCTAssertFalse(hint.contains("一步核实"))
    }

    func testVerifyWithCRejectedBeforeInvestigatingExplainsTheEntry() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        let feedback = community.submit(
            state: &state,
            actionID: ContentID.verifyWithCAction,
            npcID: ContentID.neighborEvidence
        )
        XCTAssertFalse(feedback.isSuccess)
        XCTAssertTrue(feedback.message.contains("向青砚核实"))
        XCTAssertTrue(feedback.message.contains("开始核实"))
        XCTAssertTrue(feedback.message.contains("V 不是首次核实入口"))
        XCTAssertEqual(GossipService.activeEvent(state: state)?.status, .offered)
    }

    func testRelayPausesOptionalNodeWithExplicitResumeCopy() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        state.community.standing = 41
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        let relayed = community.submit(
            state: &state,
            actionID: ContentID.relayUnverifiedAction,
            npcID: ContentID.neighborHearsay
        )
        XCTAssertTrue(relayed.isSuccess)
        XCTAssertTrue(relayed.message.contains("可选节点已暂停（主线不受影响）"))
        XCTAssertTrue(community.optionalNodeSummary(state: state).contains("暂停"))
        XCTAssertTrue(community.optionalNodeSummary(state: state).contains("风评 33"))
        XCTAssertEqual(state.community.standing, 33)
    }

    func testCorrectionResumesOptionalNodeWithExplicitCopy() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.clock = GameClock(day: 2, minute: GameClock.dayStartMinute)
        state.community.standing = 39
        GossipService.advanceToDayStart(state: &state, catalog: catalog)
        _ = community.submit(
            state: &state,
            actionID: ContentID.startVerificationAction,
            npcID: ContentID.neighborHearsay
        )
        _ = community.submit(
            state: &state,
            actionID: ContentID.verifyWithCAction,
            npcID: ContentID.neighborEvidence
        )
        let corrected = community.submit(
            state: &state,
            actionID: ContentID.correctDAction,
            npcID: ContentID.neighborConsensus
        )
        XCTAssertTrue(corrected.isSuccess)
        XCTAssertTrue(corrected.message.contains("可选节点已从暂停恢复为可用"))
        XCTAssertTrue(community.optionalNodeSummary(state: state).contains("可用"))
        XCTAssertEqual(state.community.standing, 47)
    }

    func testNewGameSceneHudContainsR1Copy() {
        let scene = FarmScene(size: CGSize(width: 960, height: 640))
        let hud = scene.hudText
        XCTAssertTrue(hud.contains("【状态】"))
        XCTAssertTrue(hud.contains("天气 晴"))
        XCTAssertTrue(hud.contains("【社区】"))
        XCTAssertTrue(hud.contains("向青砚核实"))
        XCTAssertTrue(hud.contains("不是首次核实入口") || hud.contains("不要按 V"))
        XCTAssertTrue(hud.contains("成功：") || hud.contains("失败："))
        XCTAssertFalse(hud.contains("[V]完成青砚的一步核实"))
        XCTAssertFalse(hud.contains("一步核实"))
    }
}
