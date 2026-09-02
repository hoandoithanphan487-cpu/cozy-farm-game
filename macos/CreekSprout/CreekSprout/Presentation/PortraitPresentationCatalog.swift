import AppKit
import Foundation
import OSLog

/// Presentation-only mapping for the N-009 full-body portraits.
/// It deliberately lives outside the content and save layers: portrait IDs
/// never become domain state and never replace the 32×48 map sprites.
enum PortraitPresentationCatalog {
    struct Entry: Equatable, Sendable {
        let characterID: String
        let assetName: String
    }

    private static let logger = Logger(subsystem: "com.brookseed.CreekSprout", category: "Portraits")
    private static let directory = "Presentation/Portraits"

    static let entries: [Entry] = [
        Entry(characterID: PlayerVisualID.sprout, assetName: "portrait_player_clean_v01"),
        Entry(characterID: ContentID.waterApprentice, assetName: "portrait_water_apprentice_clean_v01"),
        Entry(characterID: ContentID.seedSteward, assetName: "portrait_seed_steward_clean_v01"),
        Entry(characterID: ContentID.creekWarden, assetName: "portrait_creek_warden_clean_v01"),
        Entry(characterID: ContentID.neighborHearsay, assetName: "portrait_neighbor_hearsay_clean_v01"),
        Entry(characterID: ContentID.neighborStoryteller, assetName: "portrait_neighbor_storyteller_clean_v01"),
        Entry(characterID: ContentID.neighborEvidence, assetName: "portrait_neighbor_evidence_clean_v01"),
        Entry(characterID: ContentID.neighborConsensus, assetName: "portrait_neighbor_consensus_clean_v01"),
    ]

    private static let byCharacterID = Dictionary(uniqueKeysWithValues: entries.map { ($0.characterID, $0) })

    static func entry(for characterID: String) -> Entry? {
        guard let entry = byCharacterID[characterID] else {
            logger.warning("Unknown portrait character ID: \(characterID, privacy: .public)")
            return nil
        }
        return entry
    }

    static func assetName(for characterID: String) -> String? {
        entry(for: characterID)?.assetName
    }

    static func image(for characterID: String, bundle: Bundle = .main) -> NSImage? {
        guard let entry = entry(for: characterID) else { return nil }
        let url = bundle.url(
            forResource: entry.assetName,
            withExtension: "png",
            subdirectory: directory
        ) ?? bundle.url(forResource: entry.assetName, withExtension: "png")
        guard let url else {
            logger.error("Missing portrait resource: \(entry.assetName, privacy: .public)")
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            logger.error("Failed to load portrait resource: \(url.path, privacy: .public)")
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
