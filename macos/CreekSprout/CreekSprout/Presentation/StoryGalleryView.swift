//
//  StoryGalleryView.swift
//  CreekSprout
//
//  结局画廊：账簿页、分支批注、英雄牌与合照、毕业结果与揭露前保护档读取。
//  Presentation-only: reads `StoryGalleryState` through a FarmScene-built
//  snapshot; `pre_reveal` recall happens through `FinaleService.recallPreReveal`
//  on the campaign coordinator (never through a Release UI mutation path).
//

import SwiftUI

/// Presentation mirror of the gallery state plus the pre-reveal recall result.
struct StoryGallerySnapshot: Equatable, Sendable {
    var isUnlocked: Bool
    var discoveredLedgerPageIDs: [String]
    var discoveredAnnotationIDs: [String]
    var keepsakeIDs: [String]
    var endingID: String?
    var preRevealRecall: StoryPreRevealRecallSnapshot?
}

struct StoryPreRevealRecallSnapshot: Equatable, Sendable {
    var day: Int
    var mapDisplayName: String
    var standing: Int
    var balance: Int
    var positionCaption: String
    var growingCropCount: Int
}

/// Stable display copy for gallery item IDs. Unknown IDs fall back to the raw
/// stable ID so the gallery never hides data it does not know.
enum StoryGalleryPresentationCatalog {
    static func endingLabel(_ endingID: String) -> String {
        switch endingID {
        case "brookseed.story.ending.water":
            return "最后浇一次水 · 留在溪谷"
        case "brookseed.story.ending.leave":
            return "从码头离开 · 远行"
        default:
            return "毕业结果：\(endingID)"
        }
    }

    static func keepsakeLabel(_ keepsakeID: String) -> String {
        switch keepsakeID {
        case "brookseed.gallery.keepsake.hero_plaque":
            return "英雄牌"
        case "brookseed.gallery.keepsake.group_photo":
            return "合照"
        default:
            return "纪念物：\(keepsakeID)"
        }
    }

    static func ledgerPageLabel(_ pageID: String) -> String {
        "账簿页 · \(pageID)"
    }

    static func annotationLabel(_ annotationID: String) -> String {
        "分支批注 · \(annotationID)"
    }
}

struct StoryGalleryView: View {
    let snapshot: StoryGallerySnapshot
    let scale: CGFloat
    let onRecallPreReveal: () -> Void
    let onClose: () -> Void

    private let copper = Color(red: 0xE2 / 255, green: 0x9A / 255, blue: 0x4A / 255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14 * scale) {
                    header
                    if snapshot.isUnlocked {
                        endingSection
                        keepsakeSection
                        ledgerSection
                        annotationSection
                        preRevealSection
                    } else {
                        lockedSection
                    }
                }
                .padding(20 * scale)
                .frame(maxWidth: 720 * scale)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("n027.story.gallery.layer")
    }

    private var header: some View {
        HStack {
            Text("结局画廊")
                .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button("关闭") { onClose() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                .accessibilityIdentifier("n027.story.gallery.close")
        }
        .padding(.bottom, 4 * scale)
    }

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text("画廊尚未解锁")
                .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(copper)
            Text("完成 Q09–Q10 的揭露与毕业行动后，这里会展示账簿页、分支批注、英雄牌、合照与毕业结果。")
                .font(.system(size: 13 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale))
    }

    private var endingSection: some View {
        sectionCard(title: "毕业结果") {
            if let endingID = snapshot.endingID {
                Text(StoryGalleryPresentationCatalog.endingLabel(endingID))
                    .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("n027.story.gallery.ending")
            } else {
                Text("尚未记录毕业行动。")
                    .font(.system(size: 13 * scale, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var keepsakeSection: some View {
        sectionCard(title: "英雄牌与合照") {
            if snapshot.keepsakeIDs.isEmpty {
                emptyLine("还没有英雄牌或合照。")
            } else {
                ForEach(snapshot.keepsakeIDs, id: \.self) { keepsakeID in
                    HStack(spacing: 8 * scale) {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(copper)
                        Text(StoryGalleryPresentationCatalog.keepsakeLabel(keepsakeID))
                            .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("n027.story.gallery.keepsake")
                }
            }
        }
    }

    private var ledgerSection: some View {
        sectionCard(title: "账簿页（\(snapshot.discoveredLedgerPageIDs.count)）") {
            if snapshot.discoveredLedgerPageIDs.isEmpty {
                emptyLine("没有发现的账簿页。")
            } else {
                ForEach(snapshot.discoveredLedgerPageIDs, id: \.self) { pageID in
                    HStack(spacing: 8 * scale) {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(copper)
                        Text(StoryGalleryPresentationCatalog.ledgerPageLabel(pageID))
                            .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .accessibilityIdentifier("n027.story.gallery.ledger_page")
                }
            }
        }
    }

    private var annotationSection: some View {
        sectionCard(title: "分支批注（\(snapshot.discoveredAnnotationIDs.count)）") {
            if snapshot.discoveredAnnotationIDs.isEmpty {
                emptyLine("没有发现的分支批注。")
            } else {
                ForEach(snapshot.discoveredAnnotationIDs, id: \.self) { annotationID in
                    HStack(spacing: 8 * scale) {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(copper)
                        Text(StoryGalleryPresentationCatalog.annotationLabel(annotationID))
                            .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .accessibilityIdentifier("n027.story.gallery.annotation")
                }
            }
        }
    }

    private var preRevealSection: some View {
        sectionCard(title: "揭露前保护存档") {
            if let recall = snapshot.preRevealRecall {
                Text("第 \(recall.day) 天 · \(recall.mapDisplayName) · 风评 \(recall.standing) · 溪票 \(recall.balance)")
                    .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Text("位置 \(recall.positionCaption) · 生长中作物 \(recall.growingCropCount) 格")
                    .font(.system(size: 12 * scale, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityIdentifier("n027.story.gallery.pre_reveal")
            } else {
                Text("保护档尚未读取。毕业后的画廊可以安全回看揭露前的农场状态。")
                    .font(.system(size: 13 * scale, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Button("读取揭露前保护档") { onRecallPreReveal() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("n027.story.gallery.pre_reveal.recall")
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text(title)
                .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(copper)
            content()
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13 * scale, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
    }
}
