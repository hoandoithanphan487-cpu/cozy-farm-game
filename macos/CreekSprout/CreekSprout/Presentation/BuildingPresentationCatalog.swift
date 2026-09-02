import AppKit
import Foundation
import OSLog
import SwiftUI

/// Presentation-only mapping for N-015's five approved HD building displays.
/// The catalog never becomes domain state, never owns collision or map
/// topology, and never replaces the native pixel runtime assets.
enum BuildingPresentationCatalog {
    struct Entry: Equatable, Sendable {
        let landmarkID: String
        let displayName: String
        let assetName: String
    }

    /// Presentation-shell shortcut. It lives outside the rebinding table so
    /// gameplay actions keep priority if a player later binds the same key.
    static let inspectKeyboardBinding = "Key:E"
    static let inspectKeyboardLabel = "E"

    static let sampleLandmarkID = "brookseed.landmark.farm_house"
    static let sampleDisplayName = "木构农舍"

    private static let logger = Logger(subsystem: "com.brookseed.CreekSprout", category: "BuildingPresentation")
    private static let directory = "Presentation/Buildings"

    static let entries: [Entry] = [
        Entry(
            landmarkID: sampleLandmarkID,
            displayName: sampleDisplayName,
            assetName: "building_farm_house_display_2048_v02"
        ),
        Entry(
            landmarkID: "brookseed.landmark.farm_sluice",
            displayName: "铜闸工位",
            assetName: "building_farm_sluice_display_2048_v02"
        ),
        Entry(
            landmarkID: "brookseed.landmark.market_wharf",
            displayName: "苔石埠头",
            assetName: "building_market_wharf_display_2048_v02"
        ),
        Entry(
            landmarkID: "brookseed.landmark.market_seed_shed",
            displayName: "种源棚",
            assetName: "building_market_seed_shed_display_2048_v02"
        ),
        Entry(
            landmarkID: "brookseed.landmark.market_warden_post",
            displayName: "巡护亭",
            assetName: "building_market_warden_post_display_2048_v02"
        ),
    ]

    private static let byLandmarkID = Dictionary(uniqueKeysWithValues: entries.map { ($0.landmarkID, $0) })

    static func entry(for landmarkID: String) -> Entry? {
        guard let entry = byLandmarkID[landmarkID] else {
            logger.warning("Unknown building presentation ID: \(landmarkID, privacy: .public)")
            return nil
        }
        return entry
    }

    static func contains(_ landmarkID: String) -> Bool {
        byLandmarkID[landmarkID] != nil
    }

    static func assetName(for landmarkID: String) -> String? {
        entry(for: landmarkID)?.assetName
    }

    static func image(for landmarkID: String, bundle: Bundle = .main) -> NSImage? {
        guard let entry = entry(for: landmarkID) else { return nil }
        let url = bundle.url(
            forResource: entry.assetName,
            withExtension: "png",
            subdirectory: directory
        ) ?? bundle.url(forResource: entry.assetName, withExtension: "png")
        guard let url else {
            logger.error("Missing building presentation resource: \(entry.assetName, privacy: .public)")
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            logger.error("Failed to load building presentation resource: \(url.path, privacy: .public)")
            return nil
        }
        return image
    }

    static func fittedSize(imageSize: CGSize, in container: CGSize, inset: CGFloat = 0) -> CGSize {
        let available = CGSize(
            width: max(container.width - inset * 2, 1),
            height: max(container.height - inset * 2, 1)
        )
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

struct BuildingPresentationCard: View {
    var expanded: Bool
    var landmarkID: String = BuildingPresentationCatalog.sampleLandmarkID

    var body: some View {
        Group {
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    buildingImage.frame(maxWidth: .infinity, maxHeight: .infinity)
                    caption
                }
            } else {
                HStack(spacing: 8) {
                    buildingImage.frame(width: 96, height: 96)
                    caption.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
        .accessibilityLabel("\(BuildingPresentationCatalog.entry(for: landmarkID)?.displayName ?? "建筑")高清展示")
    }

    @ViewBuilder private var buildingImage: some View {
        if let image = BuildingPresentationCatalog.image(for: landmarkID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            BuildingPresentationFallbackView(label: "建筑展示暂不可用")
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BuildingPresentationCatalog.entry(for: landmarkID)?.displayName ?? "建筑展示")
                .font(.system(size: expanded ? 16 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
            Text("[\(BuildingPresentationCatalog.inspectKeyboardLabel)] \(expanded ? "关闭" : "展开")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.78))
        }
    }
}

private struct BuildingPresentationFallbackView: View {
    let label: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2)))
            VStack(spacing: 8) {
                Image(systemName: "house")
                    .font(.system(size: 28))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.82))
        }
    }
}
