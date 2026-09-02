import SwiftUI

enum FormalGameCopy {
    static let welcomeItems = ["新游戏", "继续游戏", "设置", "操作说明"]
    static let pauseItems = ["继续", "设置", "操作说明", "重新开始本档", "返回标题"]
    static let continueUnavailable = "没有可安全继续的正式存档"
    static let restartTitle = "重新开始当前存档槽？"
    static let restartBody = "会在当前手动槽建立一个新的 campaign；其他两个手动槽不会改变。"
    static let restartAction = "确认重新开始"
    static let chooseSlotTitle = "选择新游戏存档槽"
    static let chooseSlotBody = "新游戏只会替换所选槽及其所属剧情伴随档。其他存档槽不会改变。"
    static let overwriteTitle = "确认替换这个农场？"
    static let overwriteAction = "替换并开始新游戏"
    static let emptySlot = "空槽"
    static let unreadableSlot = "存档不可读取；不会自动覆盖"
}

struct FormalNewGameSlotPickerView: View {
    var slots: [FormalManualSlotSummary]
    var selectedIndex: Int
    var scale: CGFloat
    var onSelect: (Int) -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14 * scale) {
                Text(FormalGameCopy.chooseSlotTitle)
                    .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                Text(FormalGameCopy.chooseSlotBody)
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(slots, id: \.slotIndex) { slot in
                    FormalNewGameSlotRow(
                        slot: slot,
                        isSelected: selectedIndex == slot.slotIndex,
                        scale: scale,
                        detail: detail(for: slot),
                        onSelect: { onSelect(slot.slotIndex) }
                    )
                }

                HStack {
                    Button("取消", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                        .focusable(false)
                        .accessibilityIdentifier("n027.formal.new_game.cancel")
                    Spacer()
                    Text("点击一个可用槽继续")
                        .font(.system(size: 12 * scale, design: .rounded))
                        .opacity(0.72)
                }
            }
            .foregroundStyle(Color.white)
            .padding(22 * scale)
            .frame(maxWidth: 620 * scale)
            .background(Color(red: 0.09, green: 0.14, blue: 0.12).opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
            .overlay(
                RoundedRectangle(cornerRadius: 16 * scale)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(24)
        }
    }

    private func detail(for slot: FormalManualSlotSummary) -> String {
        switch slot.state {
        case .empty:
            return FormalGameCopy.emptySlot
        case .unreadable:
            return FormalGameCopy.unreadableSlot
        case .occupied(let campaign):
            let mission = campaign.missionStatus.map { " · 旅程 \($0.rawValue)" } ?? ""
            return "第 \(campaign.day) 天 · \(campaign.currentMapID) · 溪票 \(campaign.balance) · 风评 \(campaign.standing)\(mission)\n\(campaign.campaignID)"
        }
    }
}

private struct FormalNewGameSlotRow: View {
    var slot: FormalManualSlotSummary
    var isSelected: Bool
    var scale: CGFloat
    var detail: String
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12 * scale) {
                slotBadge
                VStack(alignment: .leading, spacing: 4 * scale) {
                    Text(slot.displayLabel)
                        .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 12 * scale, weight: .regular, design: .monospaced))
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(12 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(slot.isUnreadable)
        .opacity(slot.isUnreadable ? 0.58 : 1)
        .background(rowBackground)
        .overlay(rowBorder)
        .focusable(false)
        .accessibilityLabel("\(slot.displayLabel)，\(detail)")
        .accessibilityIdentifier("n027.formal.new_game.slot.\(slot.slotIndex)")
    }

    private var slotBadge: some View {
        Text("\(slot.slotIndex + 1)")
            .font(.system(size: 14 * scale, weight: .bold, design: .monospaced))
            .frame(width: 24 * scale, height: 24 * scale)
            .background(Circle().fill(Color.white.opacity(0.14)))
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10 * scale)
            .fill(Color.white.opacity(isSelected ? 0.20 : 0.08))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 10 * scale)
            .stroke(
                isSelected
                    ? Color(red: 0.93, green: 0.69, blue: 0.31)
                    : Color.white.opacity(0.18),
                lineWidth: isSelected ? 2 : 1
            )
    }
}

struct FormalOverwriteConfirmView: View {
    var request: FormalNewGameRequest
    var scale: CGFloat
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14 * scale) {
                Text(FormalGameCopy.overwriteTitle)
                    .font(.system(size: 23 * scale, weight: .bold, design: .rounded))
                Text(overwriteDescription)
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("只有 \(request.slot.displayLabel) 及上述 campaign 的伴随档会被替换。")
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.46))
                HStack {
                    Button("取消", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                        .focusable(false)
                        .accessibilityIdentifier("n027.formal.overwrite.cancel")
                    Spacer()
                    Button(FormalGameCopy.overwriteAction, action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .focusable(false)
                        .accessibilityIdentifier("n027.formal.overwrite.confirm")
                }
            }
            .foregroundStyle(Color.white)
            .padding(22 * scale)
            .frame(maxWidth: 540 * scale)
            .background(Color(red: 0.13, green: 0.14, blue: 0.11).opacity(0.99))
            .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
            .padding(24)
        }
    }

    private var overwriteDescription: String {
        guard let campaign = request.replacingCampaign else {
            return "\(request.slot.displayLabel) 目前为空，将在这里建立新的农场。"
        }
        return "\(request.slot.displayLabel) 当前是第 \(campaign.day) 天，campaign：\(campaign.campaignID)。这个 campaign 的手动档、自动档和保护档会由新农场替换。"
    }
}

struct FormalSessionAlertView: View {
    var message: String
    var scale: CGFloat
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14 * scale) {
                Text("无法开始")
                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                Text(message)
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("返回", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .focusable(false)
                        .accessibilityIdentifier("n027.formal.alert.close")
                }
            }
            .foregroundStyle(Color.white)
            .padding(22 * scale)
            .frame(maxWidth: 480 * scale)
            .background(Color(red: 0.12, green: 0.14, blue: 0.12).opacity(0.99))
            .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
            .padding(24)
        }
    }
}

private extension FormalManualSlotSummary {
    var isUnreadable: Bool {
        if case .unreadable = state { return true }
        return false
    }
}
