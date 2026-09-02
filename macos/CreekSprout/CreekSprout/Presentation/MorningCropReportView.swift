import SwiftUI

enum MorningCropReportUIContext: Equatable, Sendable {
    case reportHidden
    case reportPresented
    case sleepRiskPresented(token: CropSleepRiskToken)
}

enum MorningCropReportUIAction: Equatable, Sendable {
    case reopenReport
    case closeReport
    case confirmSleep(CropSleepRiskToken)
    case cancelSleep(CropSleepRiskToken)
}

/// Physical keyboard/gamepad bindings are resolved by InputBindingsService.
/// This router consumes the resulting stable action ID, so rebinding remains
/// effective without teaching the report about key codes or controller names.
enum MorningCropReportActionRouter {
    static func route(
        actionID: String,
        context: MorningCropReportUIContext
    ) -> MorningCropReportUIAction? {
        switch context {
        case .reportHidden:
            guard actionID == InputBindingDefinitions.actionInteract
                    || actionID == InputBindingDefinitions.actionUIAccept else {
                return nil
            }
            return .reopenReport
        case .reportPresented:
            guard actionID == InputBindingDefinitions.actionUICancel
                    || actionID == InputBindingDefinitions.actionUIAccept else {
                return nil
            }
            return .closeReport
        case .sleepRiskPresented(let token):
            if actionID == InputBindingDefinitions.actionUIAccept {
                return .confirmSleep(token)
            }
            if actionID == InputBindingDefinitions.actionUICancel {
                return .cancelSleep(token)
            }
            return nil
        }
    }
}

struct MorningCropReportControlHints: Equatable, Sendable {
    var reopen: String
    var close: String
    var confirm: String
    var cancel: String

    static let defaults = MorningCropReportControlHints(
        reopen: "动作/交互",
        close: "Esc / 手柄 B",
        confirm: "回车 / 手柄 A",
        cancel: "Esc / 手柄 B"
    )

    static func resolve(settings: SettingsState) -> MorningCropReportControlHints {
        let device = settings.lastUsedDevice
        return MorningCropReportControlHints(
            reopen: InputBindingsService.primaryBindingLabel(
                actionID: InputBindingDefinitions.actionInteract,
                device: device,
                settings: settings
            ),
            close: InputBindingsService.primaryBindingLabel(
                actionID: InputBindingDefinitions.actionUICancel,
                device: device,
                settings: settings
            ),
            confirm: InputBindingsService.primaryBindingLabel(
                actionID: InputBindingDefinitions.actionUIAccept,
                device: device,
                settings: settings
            ),
            cancel: InputBindingsService.primaryBindingLabel(
                actionID: InputBindingDefinitions.actionUICancel,
                device: device,
                settings: settings
            )
        )
    }
}

struct MorningCropReportReopenButton: View {
    let scale: CGFloat
    var controlHints: MorningCropReportControlHints = .defaults
    let onAction: (MorningCropReportUIAction) -> Void

    private var resolvedScale: CGFloat {
        min(max(scale, 0.75), 2.0)
    }

    var body: some View {
        Button {
            onAction(.reopenReport)
        } label: {
            Label("保苗报告 [\(controlHints.reopen)]", systemImage: "list.bullet.clipboard")
                .font(.system(size: 13 * resolvedScale, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.bordered)
        .focusable(false)
        .accessibilityLabel("重新打开今天的晨间保苗报告")
        .accessibilityHint("报告只读取当前农田，不会改动作物")
        .accessibilityIdentifier("n027.morningCropReport.reopen")
    }
}

struct MorningCropReportView: View {
    let snapshot: MorningCropReportSnapshot
    let scale: CGFloat
    var controlHints: MorningCropReportControlHints = .defaults
    let onAction: (MorningCropReportUIAction) -> Void

    private var resolvedScale: CGFloat {
        min(max(scale, 0.75), 2.0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12 * resolvedScale) {
                header
                safetyBanner
                ScrollView {
                    VStack(alignment: .leading, spacing: 12 * resolvedScale) {
                        reportSection(
                            title: "必须 · 今晚不处理会枯萎",
                            emptyText: "没有必须处理的地块。",
                            entries: snapshot.requiredCells,
                            detail: { "\($0.cropName) · 格位 \($0.coordinateText) · 已连续缺水 \($0.dryStreak) 天" },
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        reportSection(
                            title: "建议 · 今天不处理只会暂停成长",
                            emptyText: "没有建议浇水的地块。",
                            entries: snapshot.recommendedCells,
                            detail: { "\($0.cropName) · 格位 \($0.coordinateText) · 当前不会在今晚枯萎" },
                            systemImage: "drop.fill"
                        )
                        reportSection(
                            title: "已经成熟 · 可按自己的安排收获",
                            emptyText: "今天没有新成熟的作物。",
                            entries: snapshot.matureCells,
                            detail: { "\($0.cropName) · 格位 \($0.coordinateText) · 成熟作物不会因缺水枯萎" },
                            systemImage: "leaf.fill"
                        )
                        reportSection(
                            title: "已有照料覆盖",
                            emptyText: "今天没有雨水、水渠或托管覆盖。",
                            entries: snapshot.coveredCells,
                            detail: { "\($0.cropName) · 格位 \($0.coordinateText) · \($0.coverageText)" },
                            systemImage: "checkmark.shield.fill"
                        )
                    }
                }
                footer
            }
            .padding(22 * resolvedScale)
            .frame(maxWidth: 820 * resolvedScale, maxHeight: 660 * resolvedScale)
            .background(Color(red: 0.94, green: 0.91, blue: 0.76))
            .clipShape(RoundedRectangle(cornerRadius: 18 * resolvedScale))
            .shadow(radius: 24)
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(snapshot.accessibilitySummary)
        .accessibilityIdentifier("n027.morningCropReport")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12 * resolvedScale) {
            VStack(alignment: .leading, spacing: 4 * resolvedScale) {
                Text("我先看看今天的田")
                    .font(.system(size: 24 * resolvedScale, weight: .bold, design: .rounded))
                Text("第 \(snapshot.day) 天 · 天气：\(snapshot.weather.displayName)")
                    .font(.system(size: 15 * resolvedScale, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button("关闭 [\(controlHints.close)]") {
                onAction(.closeReport)
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .accessibilityLabel("关闭晨间保苗报告")
            .accessibilityHint("今天仍可从农场界面再次打开")
            .accessibilityIdentifier("n027.morningCropReport.close")
        }
    }

    private var safetyBanner: some View {
        VStack(alignment: .leading, spacing: 5 * resolvedScale) {
            Text(snapshot.safetyMessage)
                .font(.system(size: 17 * resolvedScale, weight: .bold, design: .rounded))
            Text("保住危险作物预计至少需要 \(snapshot.estimatedMinimumStamina) 点体力；若连建议地块也照料，共需 \(snapshot.estimatedFullCareStamina) 点。")
                .font(.system(size: 13 * resolvedScale, weight: .medium, design: .rounded))
        }
        .padding(11 * resolvedScale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(snapshot.allDangerousCropsSafe ? Color.green.opacity(0.15) : Color.orange.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10 * resolvedScale))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("n027.morningCropReport.safety")
    }

    private var footer: some View {
        HStack {
            Text("关闭后可用 [\(controlHints.reopen)] 再次打开；报告只读取当前农田，不会改动作物。")
                .font(.system(size: 12 * resolvedScale, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func reportSection(
        title: String,
        emptyText: String,
        entries: [MorningCropReportCellSnapshot],
        detail: @escaping (MorningCropReportCellSnapshot) -> String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7 * resolvedScale) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16 * resolvedScale, weight: .bold, design: .rounded))
            if entries.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13 * resolvedScale, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    Text(detail(entry))
                        .font(.system(size: 13 * resolvedScale, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8 * resolvedScale)
                        .background(Color.white.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: 8 * resolvedScale))
                        .accessibilityIdentifier("n027.morningCropReport.\(entry.id)")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct CropSleepRiskConfirmationView: View {
    let request: CropSleepRiskRequest
    let scale: CGFloat
    var controlHints: MorningCropReportControlHints = .defaults
    let onAction: (MorningCropReportUIAction) -> Void

    private var resolvedScale: CGFloat {
        min(max(scale, 0.75), 2.0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.56).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14 * resolvedScale) {
                Label("睡前再确认一次", systemImage: "moon.zzz.fill")
                    .font(.system(size: 23 * resolvedScale, weight: .bold, design: .rounded))
                Text("还有 \(request.count) 格作物会在今晚枯萎")
                    .font(.system(size: 17 * resolvedScale, weight: .bold, design: .rounded))
                Text("格位：\(request.positionText)")
                    .font(.system(size: 14 * resolvedScale, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                Text(request.consequence)
                    .font(.system(size: 14 * resolvedScale, weight: .medium, design: .rounded))
                Text("取消会立即返回农场；时间、体力和田块状态都不会改变。")
                    .font(.system(size: 13 * resolvedScale, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12 * resolvedScale) {
                    Button("取消 [\(controlHints.cancel)]") {
                        onAction(.cancelSleep(request.token))
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("取消睡眠，返回农场")
                    .accessibilityHint("不会推进时间或改变作物")
                    .accessibilityIdentifier("n027.sleepRisk.cancel")
                    Spacer()
                    Button("仍然睡觉 [\(controlHints.confirm)]") {
                        onAction(.confirmSleep(request.token))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("确认睡眠")
                    .accessibilityHint(request.consequence)
                    .accessibilityIdentifier("n027.sleepRisk.confirm")
                }
            }
            .padding(22 * resolvedScale)
            .frame(maxWidth: 580 * resolvedScale)
            .background(Color(red: 0.95, green: 0.88, blue: 0.70))
            .clipShape(RoundedRectangle(cornerRadius: 18 * resolvedScale))
            .shadow(radius: 24)
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(request.accessibilitySummary)
        .accessibilityIdentifier("n027.sleepRisk")
    }
}
