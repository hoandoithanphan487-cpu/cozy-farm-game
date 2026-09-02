import AppKit
import XCTest
@testable import CreekSprout

final class BuildingPresentationCatalogTests: XCTestCase {
    func testCatalogMapsFiveApprovedHDDisplays() {
        XCTAssertEqual(BuildingPresentationCatalog.entries.count, 5)
        XCTAssertEqual(
            Set(BuildingPresentationCatalog.entries.map(\.landmarkID)),
            Set([
                BuildingPresentationCatalog.sampleLandmarkID,
                "brookseed.landmark.farm_sluice",
                "brookseed.landmark.market_seed_shed",
                "brookseed.landmark.market_warden_post",
                "brookseed.landmark.market_wharf",
            ])
        )
        XCTAssertEqual(
            BuildingPresentationCatalog.sampleLandmarkID,
            "brookseed.landmark.farm_house"
        )
        XCTAssertEqual(BuildingPresentationCatalog.sampleDisplayName, "木构农舍")
        XCTAssertEqual(
            BuildingPresentationCatalog.assetName(for: BuildingPresentationCatalog.sampleLandmarkID),
            "building_farm_house_display_2048_v02"
        )
        XCTAssertNotNil(BuildingPresentationCatalog.entry(for: "brookseed.landmark.farm_sluice"))
        XCTAssertNotNil(BuildingPresentationCatalog.entry(for: "brookseed.landmark.market_seed_shed"))
        XCTAssertNotNil(BuildingPresentationCatalog.entry(for: "brookseed.landmark.market_warden_post"))
        XCTAssertNotNil(BuildingPresentationCatalog.entry(for: "brookseed.landmark.market_wharf"))
        XCTAssertNil(BuildingPresentationCatalog.assetName(for: "brookseed.landmark.unknown"))
    }

    func testInspectShortcutDoesNotCaptureGameplayDefaults() {
        let defaults = SettingsState.defaults.bindings.keyboardMouse
        XCTAssertFalse(
            defaults.values.flatMap { $0 }.contains(BuildingPresentationCatalog.inspectKeyboardBinding)
        )
        XCTAssertEqual(
            InputBindingsService.route(
                for: "Key:I",
                device: .keyboardMouse,
                settings: .defaults
            ),
            .action(InputBindingDefinitions.actionDeposit)
        )
        XCTAssertEqual(
            InputBindingsService.route(
                for: InputBindingDefinitions.characterInfoKeyboardBinding,
                device: .keyboardMouse,
                settings: .defaults
            ),
            .showCharacterInfo
        )
        XCTAssertNil(
            InputBindingsService.route(
                for: BuildingPresentationCatalog.inspectKeyboardBinding,
                device: .keyboardMouse,
                settings: .defaults
            )
        )
    }

    func testLayoutPreservesSquareAspectRatio() {
        let compact = BuildingPresentationCatalog.fittedSize(
            imageSize: CGSize(width: 2048, height: 2048),
            in: CGSize(width: 200, height: 176),
            inset: 0
        )
        XCTAssertEqual(compact.width, compact.height, accuracy: 0.001)
        XCTAssertLessThanOrEqual(compact.width, 176.001)

        let expanded = BuildingPresentationCatalog.fittedSize(
            imageSize: CGSize(width: 2048, height: 2048),
            in: CGSize(width: 340, height: 328),
            inset: 8
        )
        XCTAssertEqual(expanded.width, expanded.height, accuracy: 0.001)
        XCTAssertLessThanOrEqual(expanded.width, 324.001)
        XCTAssertLessThanOrEqual(expanded.height, 312.001)
    }

    func testPresentationImagesLoadAsIndependent2048RGBAResources() throws {
        for entry in BuildingPresentationCatalog.entries {
            let image = try XCTUnwrap(BuildingPresentationCatalog.image(for: entry.landmarkID))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
            XCTAssertEqual(bitmap.pixelsWide, 2048, entry.assetName)
            XCTAssertEqual(bitmap.pixelsHigh, 2048, entry.assetName)
            XCTAssertTrue(bitmap.hasAlpha, entry.assetName)
            XCTAssertGreaterThanOrEqual(bitmap.bitsPerPixel, 32, entry.assetName)
        }
    }
}
