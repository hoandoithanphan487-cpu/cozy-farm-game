import Foundation

/// Compatibility facade for existing callers. The runtime presentation now
/// uses the processed N-009 full-body layer, while the map renderer continues
/// to use its independent 32×48 assets.
enum ConceptArtCatalog {
    static func characterAssetName(for characterID: String) -> String? {
        PortraitPresentationCatalog.assetName(for: characterID)
    }
}
