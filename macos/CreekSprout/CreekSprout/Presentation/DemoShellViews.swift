import SwiftUI

struct DemoWelcomeView: View {
    var continueAvailable: Bool
    var selectedIndex: Int
    var scale: CGFloat
    var items: [String] = DemoCopy.welcomeItems
    var continueUnavailableText: String = DemoCopy.continueUnavailable
    var accessibilityPrefix: String = "n017.welcome"
    var onSelect: (Int) -> Void
    var onActivate: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let layout = DemoChromeLayout.welcome(in: geometry.size)
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.18, blue: 0.16),
                        Color(red: 0.16, green: 0.28, blue: 0.24),
                        Color(red: 0.08, green: 0.12, blue: 0.11),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if let image = BuildingPresentationCatalog.image(for: BuildingPresentationCatalog.sampleLandmarkID) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .opacity(0.28)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                }

                demoCard {
                    Text(DemoCopy.title)
                        .font(.system(size: 36 * scale, weight: .bold, design: .rounded))
                }
                .frame(width: layout.title.width, height: layout.title.height)
                .position(x: layout.title.midX, y: layout.title.midY)

                demoCard {
                    Text(DemoCopy.subtitle)
                        .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(width: layout.subtitle.width, height: layout.subtitle.height)
                .position(x: layout.subtitle.midX, y: layout.subtitle.midY)

                demoCard {
                    Text(DemoCopy.localSinglePlayer)
                        .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                }
                .frame(width: layout.localBadge.width, height: layout.localBadge.height)
                .position(x: layout.localBadge.midX, y: layout.localBadge.midY)

                ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                    let enabled = index != 1 || continueAvailable
                    Button {
                        onSelect(index)
                        onActivate(index)
                    } label: {
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                                .opacity(0.7)
                            Text(title)
                                .font(.system(size: 18 * scale, weight: .semibold, design: .rounded))
                            Spacer()
                            if index == 1 && !continueAvailable {
                                Text(continueUnavailableText)
                                    .font(.system(size: 11 * scale, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("\(accessibilityPrefix).\(index)")
                    .foregroundStyle(Color(red: 0.15, green: 0.22, blue: 0.18))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.94, green: 0.86, blue: 0.68).opacity(enabled ? 0.96 : 0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                selectedIndex == index
                                    ? Color(red: 0.78, green: 0.43, blue: 0.24)
                                    : Color.black.opacity(0.25),
                                lineWidth: selectedIndex == index ? 3 : 1
                            )
                    )
                    .opacity(enabled ? 1 : 0.7)
                    .frame(width: layout.buttons[index].width, height: layout.buttons[index].height)
                    .position(x: layout.buttons[index].midX, y: layout.buttons[index].midY)
                    .disabled(!enabled)
                }

                Text(DemoCopy.keyboardHint)
                    .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .frame(width: layout.footer.width, height: layout.footer.height)
                    .position(x: layout.footer.midX, y: layout.footer.midY)
            }
        }
    }

    private func demoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
}

struct DemoPauseView: View {
    var selectedIndex: Int
    var scale: CGFloat
    var items: [String] = DemoCopy.pauseItems
    var onSelect: (Int) -> Void
    var onActivate: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let layout = DemoPauseLayout.pause(in: geometry.size)
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 10) {
                    Text(DemoCopy.pauseTitle)
                        .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                    ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                        DemoPauseRow(
                            index: index,
                            title: title,
                            selected: selectedIndex == index,
                            scale: scale,
                            height: layout.buttons[index].height,
                            onSelect: { onSelect(index) },
                            onActivate: { onActivate(index) }
                        )
                    }
                }
                .padding(22)
                .frame(width: layout.panel.width, height: layout.panel.height, alignment: .topLeading)
                .background(Color(red: 0.09, green: 0.13, blue: 0.12).opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
        .allowsHitTesting(true)
    }
}

private struct DemoPauseRow: View {
    let index: Int
    let title: String
    let selected: Bool
    let scale: CGFloat
    let height: CGFloat
    let onSelect: () -> Void
    let onActivate: () -> Void

    var body: some View {
        Button {
            onSelect()
            onActivate()
        } label: {
            HStack {
                Text("\(index + 1)")
                    .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                Text(title)
                    .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityIdentifier("n017.pause.\(index)")
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(selected ? 0.22 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(selected ? 0.9 : 0.2), lineWidth: 1)
        )
        .frame(height: height)
    }
}

struct DemoTextPanelView: View {
    var title: String
    var bodyText: String
    var scale: CGFloat
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                    Spacer()
                    Button("关闭") { onClose() }
                        .buttonStyle(.bordered)
                        .focusable(false)
                }
                ScrollView {
                    Text(bodyText)
                        .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Esc 或 关闭 返回上一页")
                    .font(.system(size: 12 * scale, design: .rounded))
                    .opacity(0.75)
            }
            .foregroundStyle(Color.white)
            .padding(22)
            .frame(maxWidth: 560, maxHeight: 420)
            .background(Color(red: 0.09, green: 0.13, blue: 0.12).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct DemoConfirmView: View {
    var scale: CGFloat
    var title: String = DemoCopy.confirmRestartTitle
    var bodyText: String = DemoCopy.confirmRestartBody
    var confirmTitle: String = DemoCopy.confirmRestart
    var cancelTitle: String = DemoCopy.cancelRestart
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                Text(bodyText)
                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                HStack {
                    Button(cancelTitle, action: onCancel)
                        .focusable(false)
                    Spacer()
                    Button(confirmTitle, action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .focusable(false)
                }
            }
            .foregroundStyle(Color.white)
            .padding(22)
            .frame(maxWidth: 480)
            .background(Color(red: 0.12, green: 0.14, blue: 0.12).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
