//
//  StoryDialoguePresentationLayer.swift
//  CreekSprout
//
//  SwiftUI presentation for the N-027 multi-speaker story runtime.
//  Renders exactly what `StoryDialogueView` produces: one page of 1–3
//  consecutive same-speaker lines, intent buttons labelled with their
//  stable button meaning (`dialogueIntentLabel`), the four text-speed
//  levels applied instantly, and a cancel path that returns control.
//  This file never mutates GameState; it only forwards player intent.
//

import SwiftUI

/// Routing context consumed by `StoryDialogueInputRouter`. FarmScene builds it
/// from the persisted dialogue session; ContentView forwards rebindable action
/// IDs into it.
struct StoryDialogueRoutingContext: Equatable, Sendable {
    var intentsPending: Bool
    var atBoundary: Bool
    var hasSelectedIntent: Bool
    var focusedIntentIndex: Int?
    var intentCount: Int
}

/// The on-screen multi-speaker story dialogue layer.
struct StoryDialoguePresentationLayer: View {
    let view: StoryDialogueView
    let scale: CGFloat
    let focusedIntentIndex: Int
    let advanceBindingLabel: String
    let cancelBindingLabel: String
    let onAdvance: () -> Void
    let onSelectIntent: (Int) -> Void
    let onCancel: () -> Void

    private let glass = Color(red: 0.045, green: 0.06, blue: 0.05).opacity(0.97)
    private let copper = Color(red: 0xE2 / 255, green: 0x9A / 255, blue: 0x4A / 255)
    private let mist = Color(red: 0.62, green: 0.78, blue: 0.72)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    pageCard
                        .padding(.horizontal, 16 * scale)
                        .padding(.bottom, 16 * scale)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(view.accessibilitySummary)
        .accessibilityIdentifier("n027.story.dialogue.layer")
    }

    // MARK: - Page card

    private var pageCard: some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            header
            Divider().overlay(Color.white.opacity(0.16))
            ForEach(Array(view.pageLines.enumerated()), id: \.element.id) { _, line in
                lineRow(line)
            }
            if !view.pendingIntents.isEmpty {
                intentRow
            }
            footer
        }
        .padding(16 * scale)
        .frame(maxWidth: 760 * scale, alignment: .leading)
        .background(glass)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 16 * scale)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
    }

    private var header: some View {
        HStack(spacing: 10 * scale) {
            Text("\(view.arcID.shortCode.uppercased()) · \(view.stageKind.rawValue)")
                .font(.system(size: 11 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(mist)
                .padding(.horizontal, 8 * scale)
                .padding(.vertical, 3 * scale)
                .background(mist.opacity(0.14))
                .clipShape(Capsule())
                .accessibilityIdentifier("n027.story.dialogue.stage")
            Text("\(view.pageNumber) / \(view.pageCount)")
                .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityIdentifier("n027.story.dialogue.page")
            Spacer()
            Text("文字速度 · \(view.textSpeedDisplayName)")
                .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .accessibilityIdentifier("n027.story.dialogue.text_speed")
        }
    }

    private func lineRow(_ line: StoryDialogueView.Line) -> some View {
        HStack(alignment: .top, spacing: 12 * scale) {
            portrait(for: line)
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack(spacing: 8 * scale) {
                    Text(line.speakerName)
                        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(copper)
                    if let annotation = line.speakerAnnotation {
                        Text(annotation)
                            .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .accessibilityIdentifier("n027.story.dialogue.speaker")
                Text(line.text)
                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("n027.story.dialogue.line.\(line.id)")
            }
        }
    }

    @ViewBuilder
    private func portrait(for line: StoryDialogueView.Line) -> some View {
        let portraitID = line.portraitID ?? line.speakerID
        if let image = PortraitPresentationCatalog.image(for: portraitID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 64 * scale, height: 76 * scale)
                .clipShape(RoundedRectangle(cornerRadius: 10 * scale))
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(Color.white.opacity(0.26), lineWidth: 1)
                )
                .accessibilityLabel("\(line.speakerName) 立绘")
                .accessibilityIdentifier("n027.story.dialogue.portrait")
        } else {
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(Color.white.opacity(0.07))
                .frame(width: 64 * scale, height: 76 * scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    Text(line.speakerName.prefix(1))
                        .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                )
                .accessibilityLabel("\(line.speakerName)")
                .accessibilityIdentifier("n027.story.dialogue.portrait_fallback")
        }
    }

    // MARK: - Intent buttons

    private var intentRow: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text("选择行动")
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            ForEach(Array(view.pendingIntents.enumerated()), id: \.element.stableID) { index, intent in
                let isFocused = index == focusedIntentIndex
                Button {
                    onSelectIntent(index)
                } label: {
                    HStack(spacing: 8 * scale) {
                        Text(intent.label)
                            .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        if isFocused {
                            Text("←")
                                .font(.system(size: 13 * scale, weight: .bold, design: .monospaced))
                                .foregroundStyle(copper)
                        }
                    }
                    .padding(.horizontal, 12 * scale)
                    .padding(.vertical, 8 * scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .background(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .fill(
                            isFocused
                                ? Color(red: 0xE2 / 255, green: 0x9A / 255, blue: 0x4A / 255).opacity(0.28)
                                : Color.white.opacity(0.08)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(
                            isFocused ? copper : Color.white.opacity(0.16),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .accessibilityLabel(intent.label)
                .accessibilityIdentifier("n027.story.dialogue.intent.\(index)")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("[\(advanceBindingLabel)] 继续")
                .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("[\(cancelBindingLabel)] 取消对话")
                .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
        }
        .accessibilityIdentifier("n027.story.dialogue.hints")
    }
}
