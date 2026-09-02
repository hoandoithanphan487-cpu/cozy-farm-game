//
//  HudCopy.swift
//  CreekSprout
//
//  Presentation-only HUD copy for D0-001. Domain transaction results are
//  unchanged; this file owns information hierarchy, verification-path
//  wording (R1), and feedback prefixes that do not rely on color alone.
//

import Foundation

enum HudCopy {
    static let firstVerifyChoice = "向青砚核实"
    static let startVerifyChoice = "开始核实"
    static let optionalRecoveryChoice = "把观察痕迹交给青砚"

    static func verificationPathHint(status: GossipEventStatus?) -> String {
        switch status {
        case nil:
            return "核实入口：第 2 天到涧麦婶处用 Y/B 选择「\(startVerifyChoice)」，再在青砚处选择「\(firstVerifyChoice)」。V 不是首次核实入口。"
        case .offered:
            return "首次核实入口：先在涧麦婶处用 Y/B 选择「\(startVerifyChoice)」。不要按 V；V 只用于可选恢复。"
        case .investigating:
            return "首次核实入口：走到青砚旁，用 Y/B 选择「\(firstVerifyChoice)」。不要按 V。"
        case .verified:
            return "下一步：走到絮宁旁，用 Y/B 选择「纠正絮宁」。V 仍不是首次核实入口。"
        case .resolvedCorrected:
            return "社区事件已纠正。V 仅用于可选恢复，不会改写本次「\(firstVerifyChoice)」结果。"
        case .resolvedRelay:
            return "本次已转述未核实版本。可选恢复仍可用：走到青砚旁按 V（不是首次核实入口）。"
        case .deferred:
            return "事件已暂缓。首次核实入口已关闭；V 仍只是可选恢复，不是核实入口。"
        case .expired:
            return "事件已过截止。V 只用于可选恢复，不能补做首次「\(firstVerifyChoice)」。"
        }
    }

    static func keyHints(isDialogueActive: Bool) -> String {
        if isDialogueActive {
            return [
                "【按键】对话进行中（时钟已暂停）",
                "[空格/T]继续对白  对白结束前其他操作锁定",
            ].joined(separator: "\n")
        }
        var lines = [
            "【按键】",
            "[WASD/方向键]移动  走到石阶进出地图  [空格]面对石阶也可进出",
            "[1-4]工具  [空格/回车]动作/采集  [T]交谈（走到角色旁）",
            "[I]投入出售箱  [U]取回  [C]制作  [R]切换配方",
            "[Q]角色信息（打开/关闭）",
            "[空格]对准木蜜灶台打开加工面板  面板中 [C]加工 [R]切换配方",
            "[P]放置预览  [F]确认放置  [N]睡眠日结  [K]保存  [L]读取",
            "[Y]切换社区行动  [B]提交所选行动（首次核实：先「\(startVerifyChoice)」再「\(firstVerifyChoice)」；V 不是入口）",
            "[V]可选恢复：\(optionalRecoveryChoice)（不是首次核实入口）",
        ]
        #if DEBUG
        lines.append("[G]注入材料  [E]调试报表")
        #endif
        return lines.joined(separator: "\n")
    }

    static func evidenceAwayFromQingyan() -> String {
        "请走到青砚旁边。V 是可选恢复（\(optionalRecoveryChoice)），不是首次核实入口；首次核实请用 Y/B 选择「\(firstVerifyChoice)」。"
    }

    static func evidenceCannotComplete() -> String {
        "现在无法完成可选恢复。首次核实请在「核实中」状态下走到青砚旁，用 Y/B 选择「\(firstVerifyChoice)」。"
    }

    static func evidenceCompleted(standing: Int, optionalSummary: String) -> String {
        "已完成可选恢复：\(optionalRecoveryChoice)。风评 \(standing)。这不是首次核实入口。\(optionalSummary)"
    }

    static func dialogueLocked(intent: String) -> String {
        "对话进行中，时钟已暂停。按空格或 T 继续；结束后才能\(intent)。"
    }

    static func noNpcToTalk() -> String {
        "附近没有可以交谈的人。走到角色所在格或面对他们再按 T。"
    }

    static func playerToast(message: String, isSuccess: Bool) -> String {
        isSuccess ? "成功  \(message)" : "失败  \(message)"
    }

    static func compactGoal(_ goalLine: String) -> String {
        goalLine
            .replacingOccurrences(of: "当前目标：", with: "")
            .replacingOccurrences(of: "  ", with: " · ")
    }

    static func feedbackLine(message: String, isSuccess: Bool) -> String {
        let icon = isSuccess ? "[+]" : "[!]"
        if isSuccess {
            return "\(icon) 成功：\(message)"
        }
        return "\(icon) 失败：\(message)"
    }

    static func weatherCaption(_ weather: String) -> String {
        switch weather {
        case "雨": return "雨~"
        case "晴": return "晴*"
        default: return weather
        }
    }

    static func watershedLine(state: GameState, catalog: ContentCatalog = .vs0) -> String {
        let points = state.watershed.restorationPoints
        let threshold = ContentID.watershedThreshold
        let channel = state.watershed.channelLabel
        let ambience = state.watershed.ambienceLabel
        let correctionPoints = catalog.contribution(id: ContentID.correctDBonusContribution)?.points ?? 2
        if points >= threshold {
            if state.watershed.hasApplied(ContentID.correctDBonusContribution), points > threshold {
                return "水脉 \(threshold) 已达成（含纠正 +\(correctionPoints) → \(points)）  水道 \(channel)  环境音 \(ambience)"
            }
            return "水脉 \(threshold) 已达成  水道 \(channel)  环境音 \(ambience)"
        }
        return "水脉 \(points)/\(threshold)  水道 \(channel)  环境音 \(ambience)"
    }

    static func compactAssemble(
        mapName: String,
        day: Int,
        time: String,
        weather: String,
        goalLine: String,
        recipe: String,
        saveSlotLine: String,
        feedback: String,
        collapsedHint: String
    ) -> String {
        [
            "【状态】\(mapName)  第 \(day) 天  \(time)  天气 \(weatherCaption(weather))  配方 \(recipe)",
            "【目标】\(goalLine)",
            saveSlotLine,
            feedback,
            collapsedHint,
        ].joined(separator: "\n")
    }

    static func assemble(
        mapName: String,
        day: Int,
        time: String,
        weather: String,
        goalLine: String,
        questSummary: String,
        watershedLine: String,
        standingLine: String,
        eventLine: String,
        verificationHint: String,
        trustLine: String,
        optionalNodeLine: String,
        actionLine: String,
        stamina: Int,
        balance: Int,
        pending: Int,
        inventory: String,
        recipe: String,
        settlement: String,
        tool: String,
        playerCaption: String,
        targetCaption: String,
        dialogueLine: String?,
        feedback: String,
        isDialogueActive: Bool,
        accessibilityLine: String? = nil,
        volumeLine: String? = nil,
        inputHintBlock: String? = nil
    ) -> String {
        var lines = [
            "【状态】\(mapName)  第 \(day) 天  \(time)  天气 \(weatherCaption(weather))  体力 \(stamina)/100  溪票 \(balance)  待结算 \(pending)",
            "【目标】\(goalLine)",
            questSummary,
            watershedLine,
            "【社区】\(standingLine)",
            eventLine,
        ]
        if !verificationHint.isEmpty {
            lines.append(verificationHint)
        }
        lines += [
            trustLine,
            optionalNodeLine,
            actionLine,
            "【资源】\(inventory)",
            "配方 \(recipe)",
            settlement,
            "工具 \(tool)  玩家 \(playerCaption)  目标 \(targetCaption)",
        ]
        if let dialogueLine {
            lines.append("【对话】\(dialogueLine)  （时钟已暂停，按空格或 T 继续）")
        }
        lines.append(feedback)
        if let accessibilityLine {
            lines.append("【无障碍】\(accessibilityLine)")
        }
        if let volumeLine {
            lines.append("【音量】\(volumeLine)")
        }
        lines.append(inputHintBlock ?? keyHints(isDialogueActive: isDialogueActive))
        return lines.joined(separator: "\n")
    }
}
