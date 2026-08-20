import SwiftUI

struct SettingsPanelView: View {
    @Binding var settings: SettingsState
    @Binding var selectedTab: Int
    @Binding var selectedRow: Int
    @Binding var rebindingActionID: String?
    @Binding var statusMessage: String?

    var onPersist: () -> Void
    var onRestoreDefaults: () -> Void
    var onClose: () -> Void

    private let tabs = ["无障碍", "输入绑定", "音量"]
    private let accessibilityRows = ["UI 缩放", "文字速度", "屏幕震动", "闪烁减弱"]
    private let volumeRows = ["主音量", "音乐", "环境", "音效", "界面"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.title3.weight(.semibold))
            Text("Esc / 界面-取消 关闭  ·  ↑↓ 选择  ·  回车 修改")
                .font(.caption)
                .opacity(0.85)

            HStack(spacing: 12) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .font(.caption.weight(selectedTab == index ? .bold : .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedTab == index ? Color.white.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if selectedTab == 0 {
                        accessibilitySection
                    } else if selectedTab == 1 {
                        bindingSection
                    } else {
                        volumeSection
                    }
                }
            }
            .frame(maxHeight: 280)

            if let rebindingActionID {
                Text("请按下新键绑定「\(InputBindingDefinitions.displayName(for: rebindingActionID))」…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.yellow)
            } else if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }

            HStack {
                Button("恢复默认") { onRestoreDefaults() }
                Spacer()
                Button("关闭") { onClose() }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(width: 420)
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var accessibilitySection: some View {
        ForEach(Array(accessibilityRows.enumerated()), id: \.offset) { index, title in
            rowLine(
                index: index,
                title: title,
                value: accessibilityValue(for: index)
            )
        }
    }

    @ViewBuilder
    private var bindingSection: some View {
        Text("设备：\(settings.lastUsedDevice == .keyboardMouse ? "键盘/鼠标" : "手柄")")
            .font(.caption)
        ForEach(Array(InputBindingDefinitions.allActionIDs.enumerated()), id: \.offset) { index, actionID in
            rowLine(
                index: index,
                title: InputBindingDefinitions.displayName(for: actionID),
                value: InputBindingsService.primaryBindingLabel(
                    actionID: actionID,
                    device: settings.lastUsedDevice,
                    settings: settings
                )
            )
        }
    }

    @ViewBuilder
    private var volumeSection: some View {
        ForEach(Array(volumeRows.enumerated()), id: \.offset) { index, title in
            rowLine(
                index: index,
                title: title,
                value: volumeValue(for: index)
            )
        }
    }

    private func rowLine(index: Int, title: String, value: String) -> some View {
        let selected = index == selectedRow
        return HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .font(.system(size: 13, weight: selected ? .semibold : .regular, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(selected ? Color.white.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func accessibilityValue(for index: Int) -> String {
        switch index {
        case 0: return "\(settings.uiScale)%"
        case 1: return settings.textSpeed.displayName
        case 2: return settings.vibrationEnabled ? "开" : "关"
        case 3: return settings.reduceFlashing ? "开" : "关"
        default: return ""
        }
    }

    private func volumeValue(for index: Int) -> String {
        let value: Double
        switch index {
        case 0: value = settings.volumes.master
        case 1: value = settings.volumes.music
        case 2: value = settings.volumes.ambience
        case 3: value = settings.volumes.sfx
        default: value = settings.volumes.ui
        }
        return "\(Int((value * 100).rounded()))%"
    }

    func cycleSelectedRowForward() {
        let count = rowCount(for: selectedTab)
        guard count > 0 else { return }
        selectedRow = (selectedRow + 1) % count
        statusMessage = nil
    }

    func cycleSelectedRowBackward() {
        let count = rowCount(for: selectedTab)
        guard count > 0 else { return }
        selectedRow = (selectedRow - 1 + count) % count
        statusMessage = nil
    }

    private func rowCount(for tab: Int) -> Int {
        switch tab {
        case 0: return accessibilityRows.count
        case 1: return InputBindingDefinitions.allActionIDs.count
        default: return volumeRows.count
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
