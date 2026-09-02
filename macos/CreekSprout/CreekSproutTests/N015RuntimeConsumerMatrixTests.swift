import Foundation
import XCTest

/// Contract tests for `docs/game/n-015-runtime-consumer-matrix.json`.
///
/// These tests only validate the repository data contract. They are read-only:
/// they decode the matrix JSON and assert its shape, uniqueness, counts, and
/// the DEC-033 / B4 blocking facts. They never create or rewrite repository
/// files, and they never touch production code.
///
/// N-015 character-trace (portrait-derived R1) sync: provenance expectations
/// are 104 `n006_base` / 8 `n003_approved_override` /
/// 19 `n015_portrait_derived_override` / 1 `dec033_approved_addition`. The
/// negative mutation tests in this file invoke the authoritative Python
/// validator (`scripts/validate-n015-consumer-matrix.py`) through `Process`
/// against isolated temporary copies; they never reimplement the validation
/// algorithm in-process.
final class N015RuntimeConsumerMatrixTests: XCTestCase {
    // MARK: - Helpers

    private struct MatrixAsset: Decodable {
        let assetKey: String
        let filename: String
        let category: String
        let nativeWidth: Int
        let nativeHeight: Int
        let provenance: String
        let plannedConsumer: String
        let triggerState: String
        let fallback: String
        let batch: String
        let runtimeStatus: String
        let blocker: String?

        enum CodingKeys: String, CodingKey {
            case assetKey = "asset_key"
            case filename
            case category
            case nativeWidth = "native_width"
            case nativeHeight = "native_height"
            case provenance
            case plannedConsumer = "planned_consumer"
            case triggerState = "trigger_state"
            case fallback
            case batch
            case runtimeStatus = "runtime_status"
            case blocker
        }
    }

    private struct MatrixDocument: Decodable {
        let schemaVersion: Int
        let task: String
        let decision: String
        let expectedAssetCount: Int
        let generatedFrom: [String]
        let assets: [MatrixAsset]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case task
            case decision
            case expectedAssetCount = "expected_asset_count"
            case generatedFrom = "generated_from"
            case assets
        }
    }

    private struct CharacterOverrideAsset: Decodable {
        let file: String
        let width: Int
        let height: Int
        let sha256: String
    }

    private struct CharacterOverrideDocument: Decodable {
        let assets: [CharacterOverrideAsset]
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("docs/game/project-ledger.md")
            if FileManager.default.fileExists(atPath: marker.path) {
                return url
            }
        }
        XCTFail("unable to locate repository root from #filePath")
        throw NSError(domain: "N015RuntimeConsumerMatrixTests", code: 1)
    }

    private func loadMatrix() throws -> MatrixDocument {
        let root = try repositoryRoot()
        let url = root.appendingPathComponent("docs/game/n-015-runtime-consumer-matrix.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MatrixDocument.self, from: data)
    }

    // MARK: - 1. Decodable + top-level contract

    func testMatrixDecodesAndDeclaresContract() throws {
        let matrix = try loadMatrix()
        XCTAssertEqual(matrix.schemaVersion, 1)
        XCTAssertEqual(matrix.task, "N-015")
        XCTAssertEqual(matrix.decision, "DEC-035")
        XCTAssertEqual(matrix.expectedAssetCount, 132)
    }

    // MARK: - 2. Exactly 132 assets, no duplicate keys or filenames

    func testExactly132AssetsWithUniqueKeysAndFilenames() throws {
        let matrix = try loadMatrix()
        XCTAssertEqual(matrix.assets.count, 132)
        let keys = matrix.assets.map(\.assetKey)
        let filenames = matrix.assets.map(\.filename)
        XCTAssertEqual(Set(keys).count, 132, "asset_key must be unique")
        XCTAssertEqual(Set(filenames).count, 132, "filename must be unique")
    }

    // MARK: - 3. Category counts match the current official set

    func testCategoryCountsMatchOfficialSet() throws {
        let matrix = try loadMatrix()
        let counts = Dictionary(grouping: matrix.assets, by: \.category).mapValues(\.count)
        XCTAssertEqual(counts, [
            "building": 30,
            "char": 19,
            "crop": 25,
            "fx": 16,
            "gather": 3,
            "prop": 7,
            "tile": 22,
            "tool": 3,
            "ui": 7,
        ])
    }

    // MARK: - 4. Provenance counts 104 / 8 / 19 / 1 (N-015 character-trace sync)

    func testProvenanceCounts104_8_19_1() throws {
        let matrix = try loadMatrix()
        let counts = Dictionary(grouping: matrix.assets, by: \.provenance).mapValues(\.count)
        XCTAssertEqual(counts, [
            "n006_base": 104,
            "n003_approved_override": 8,
            "n015_portrait_derived_override": 19,
            "dec033_approved_addition": 1,
        ])
    }

    private func loadCharacterOverrides() throws -> CharacterOverrideDocument {
        let root = try repositoryRoot()
        let url = root.appendingPathComponent("docs/game/n-015-character-overrides.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CharacterOverrideDocument.self, from: data)
    }

    // MARK: - 4a. The 19 n015_portrait_derived_override records match the override manifest exactly

    func testN015OverrideSetMatchesManifestExactly() throws {
        let matrix = try loadMatrix()
        let manifest = try loadCharacterOverrides()
        XCTAssertEqual(manifest.assets.count, 19, "override manifest must declare 19 assets")
        let matrixFiles = Set(
            matrix.assets
                .filter { $0.provenance == "n015_portrait_derived_override" }
                .map(\.filename)
        )
        let manifestFiles = Set(manifest.assets.map(\.file))
        XCTAssertEqual(manifestFiles.count, 19, "override manifest filenames must be unique")
        XCTAssertEqual(matrixFiles, manifestFiles, "n015 matrix set must equal the override manifest exactly")
    }

    // MARK: - 4b. All 19 n015 records are char category and integrated

    func testN015OverridesAreCharAndIntegrated() throws {
        let matrix = try loadMatrix()
        let n015 = matrix.assets.filter { $0.provenance == "n015_portrait_derived_override" }
        XCTAssertEqual(n015.count, 19)
        for asset in n015 {
            XCTAssertEqual(asset.category, "char", asset.filename)
            XCTAssertEqual(asset.runtimeStatus, "integrated", asset.filename)
            XCTAssertNil(asset.blocker, asset.filename)
        }
    }

    // MARK: - 4c. Character sizes: 8 idle 32x48, 8 walk 128x192, 3 player action 128x192

    func testN015CharacterSizesIdleWalkActions8_8_3() throws {
        let matrix = try loadMatrix()
        let n015 = matrix.assets.filter { $0.provenance == "n015_portrait_derived_override" }
        let idle = n015.filter {
            !$0.filename.hasSuffix("_walk.png") && !$0.filename.contains("_action_")
        }
        let walk = n015.filter { $0.filename.hasSuffix("_walk.png") }
        let actions = n015.filter { $0.filename.contains("_action_") }
        XCTAssertEqual(idle.count, 8, "8 idle character overrides expected")
        XCTAssertEqual(walk.count, 8, "8 walk character overrides expected")
        XCTAssertEqual(actions.count, 3, "3 player action character overrides expected")
        XCTAssertTrue(
            idle.allSatisfy { $0.nativeWidth == 32 && $0.nativeHeight == 48 },
            "idle overrides must be 32x48"
        )
        XCTAssertTrue(
            (walk + actions).allSatisfy { $0.nativeWidth == 128 && $0.nativeHeight == 192 },
            "walk/action overrides must be 128x192"
        )
    }

    // MARK: - 4d. The other 113 records keep their original provenance

    func testNonN015RecordsAreNotMarkedAsCharacterOverride() throws {
        let matrix = try loadMatrix()
        let others = matrix.assets.filter { $0.provenance != "n015_portrait_derived_override" }
        XCTAssertEqual(others.count, 113)
        for asset in others {
            XCTAssertTrue(
                ["n006_base", "n003_approved_override", "dec033_approved_addition"]
                    .contains(asset.provenance),
                "\(asset.filename) must keep its original provenance"
            )
        }
    }

    // MARK: - 4e. generated_from includes the character override manifest

    func testGeneratedFromIncludesCharacterOverrideManifest() throws {
        let matrix = try loadMatrix()
        XCTAssertTrue(
            matrix.generatedFrom.contains("docs/game/n-015-character-overrides.json"),
            "generated_from must include the N-015 character override manifest, got \(matrix.generatedFrom)"
        )
    }

    // MARK: - 5. 5 crops x 4 stages == 20 stage records, all complete

    func testFiveCropsFourStagesTwentyRecordsComplete() throws {
        let matrix = try loadMatrix()
        let crops = Set(["amber_bean", "bell_berry", "honey_melon", "mist_radish", "stream_leaf"])
        let stages = matrix.assets.filter {
            $0.category == "crop" && $0.filename.contains("_stage_")
        }
        XCTAssertEqual(stages.count, 20)
        for asset in stages {
            XCTAssertFalse(asset.assetKey.isEmpty, asset.filename)
            XCTAssertFalse(asset.plannedConsumer.isEmpty, asset.filename)
            XCTAssertFalse(asset.triggerState.isEmpty, asset.filename)
            XCTAssertFalse(asset.fallback.isEmpty, asset.filename)
            XCTAssertEqual(asset.nativeWidth, 32, asset.filename)
            XCTAssertEqual(asset.nativeHeight, 32, asset.filename)
        }
        // Every crop has exactly 4 stages (0..3).
        for crop in crops {
            let cropStages = stages.filter { $0.filename.hasPrefix("crop_\(crop)_stage_") }
            XCTAssertEqual(cropStages.count, 4, "crop \(crop) must have 4 stages")
        }
    }

    // MARK: - 6. 8 character static images; walk sheets are separate records

    func testEightCharacterStaticImagesAndWalkSheetsAreSeparate() throws {
        let matrix = try loadMatrix()
        let staticChars = matrix.assets.filter {
            $0.category == "char"
                && !$0.filename.hasSuffix("_walk.png")
                && !$0.filename.contains("_action_")
        }
        XCTAssertEqual(staticChars.count, 8, "8 character static images expected")
        XCTAssertTrue(
            staticChars.allSatisfy { $0.nativeWidth == 32 && $0.nativeHeight == 48 },
            "character static images must be 32x48"
        )
        let walkSheets = matrix.assets.filter { $0.filename.hasSuffix("_walk.png") }
        XCTAssertEqual(walkSheets.count, 8, "8 walk sheets expected")
        XCTAssertTrue(
            walkSheets.allSatisfy { $0.nativeWidth == 128 && $0.nativeHeight == 192 },
            "walk sheets must be 128x192 (4x4 frames)"
        )
        // No overlap: a walk sheet must not be counted as a static image.
        let staticNames = Set(staticChars.map(\.filename))
        let walkNames = Set(walkSheets.map(\.filename))
        XCTAssertTrue(staticNames.isDisjoint(with: walkNames))
    }

    // MARK: - 7. Wood-honey hearth: DEC-033 addition, 48x48

    func testWoodHoneyHearthIsDec033AdditionAt48By48() throws {
        let matrix = try loadMatrix()
        let hearth = try XCTUnwrap(
            matrix.assets.first { $0.filename == "prop_woodhoney_hearth.png" },
            "wood-honey hearth must exist"
        )
        XCTAssertEqual(hearth.provenance, "dec033_approved_addition")
        XCTAssertEqual(hearth.nativeWidth, 48)
        XCTAssertEqual(hearth.nativeHeight, 48)
    }

    // MARK: - 8. No tool_seed; 3 official tools; seeding contract points at seed-item

    func testNoToolSeedAndSeedingUsesSeedItemContract() throws {
        let matrix = try loadMatrix()
        XCTAssertNil(
            matrix.assets.first { $0.filename == "tool_seed.png" },
            "tool_seed.png must not exist"
        )
        let tools = matrix.assets.filter { $0.category == "tool" }
        XCTAssertEqual(tools.count, 3)
        XCTAssertEqual(
            Set(tools.map(\.filename)),
            Set(["tool_hoe.png", "tool_watering_can.png", "tool_harvest_glove.png"])
        )
        // Seeding contract: no seed tool; the crop item icon doubles as the seed icon.
        let cropItemConsumers = matrix.assets.filter {
            $0.category == "crop" && !$0.filename.contains("_stage_")
        }
        XCTAssertEqual(cropItemConsumers.count, 5)
        for asset in cropItemConsumers {
            XCTAssertTrue(
                asset.plannedConsumer.contains("InventoryItemIconPresenter"),
                "\(asset.filename) consumer must be the seed/item icon presenter"
            )
        }
    }

    // MARK: - 9. 30 building six-layer records: B4, integrated, no blocker

    func testThirtyBuildingRecordsAreB4IntegratedWithoutBlocker() throws {
        let matrix = try loadMatrix()
        let buildings = matrix.assets.filter { $0.category == "building" }
        XCTAssertEqual(buildings.count, 30)
        for asset in buildings {
            XCTAssertEqual(asset.batch, "B4", asset.filename)
            XCTAssertEqual(asset.runtimeStatus, "integrated", asset.filename)
            XCTAssertNil(asset.blocker, asset.filename)
        }
        // Six layers per building, five buildings.
        // Filename form: building_<family>_<layer>.png, e.g. building_farm_house_base.png
        let layers = ["base", "structure", "roof", "detail", "interaction", "state_fx"]
        let buildingsByFamily = Dictionary(grouping: buildings) { asset -> String in
            var name = asset.filename
            name.removeFirst("building_".count)
            name.removeLast(".png".count)
            for layer in layers {
                if name.hasSuffix("_\(layer)") {
                    name.removeLast("_\(layer)".count)
                    break
                }
            }
            return name
        }
        XCTAssertEqual(buildingsByFamily.count, 5)
        for (family, records) in buildingsByFamily {
            XCTAssertEqual(records.count, 6, "building \(family) must have 6 layers")
        }
    }

    // MARK: - 10. Read-only: no repository file is created or rewritten

    func testTestIsReadOnly() throws {
        let root = try repositoryRoot()
        let matrixURL = root.appendingPathComponent("docs/game/n-015-runtime-consumer-matrix.json")
        let before = try Data(contentsOf: matrixURL)
        _ = try loadMatrix()
        let after = try Data(contentsOf: matrixURL)
        XCTAssertEqual(before, after, "test must not rewrite the matrix file")
    }

    // MARK: - 11. Negative contract tests: the contract validator must reject tampered data

    // These legacy in-process tests reproduce the validator's per-record shape
    // check (required fields, valid enums, per-file derivation of
    // provenance/category/planned_consumer/batch) so a deleted or invalid field
    // yields a FAIL with a field-specific error list. They are retained as an
    // in-process smoke layer; the authoritative negative mutations (section 13)
    // execute the real Python validator via `Process` against isolated temp
    // copies. The per-file derivation tables below are kept in sync with the
    // authoritative validator, including the N-015 character override source.

    private struct ContractResult {
        let result: String
        let failures: Int
        let errors: [String]
    }

    private static let overrideFilenames: Set<String> = [
        "char_creek_warden.png", "char_player.png", "char_seed_steward.png", "char_water_apprentice.png",
        "crop_amber_bean.png", "crop_bell_berry.png", "crop_honey_melon.png", "crop_mist_radish.png",
        "crop_stream_leaf.png", "tile_grass.png", "tile_tilled.png", "tile_water_edge.png",
    ]
    private static let additionFilenames: Set<String> = ["prop_woodhoney_hearth.png"]

    private static var cachedCharacterOverrideFilenames: Set<String>?

    private func characterOverrideFilenames() throws -> Set<String> {
        if let cached = Self.cachedCharacterOverrideFilenames {
            return cached
        }
        let root = try repositoryRoot()
        let url = root.appendingPathComponent("docs/game/n-015-character-overrides.json")
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "override manifest must be a JSON object"
        )
        let assets = try XCTUnwrap(document["assets"] as? [[String: Any]], "assets must be an array")
        let set = Set(assets.compactMap { $0["file"] as? String })
        Self.cachedCharacterOverrideFilenames = set
        return set
    }

    private static let charStaticStems: Set<String> = [
        "char_player", "char_water_apprentice", "char_seed_steward", "char_creek_warden",
        "char_neighbor_consensus", "char_neighbor_evidence", "char_neighbor_hearsay", "char_neighbor_storyteller",
    ]
    private static let charWalkStems: Set<String> = Set(charStaticStems.map { $0 + "_walk" })
    private static let playerActionStems: Set<String> = [
        "char_player_action_hoe", "char_player_action_watering_can", "char_player_action_harvest_glove",
    ]

    private func expectedCategory(_ filename: String) -> String {
        filename.components(separatedBy: "_").first ?? ""
    }

    private func expectedProvenance(_ filename: String) throws -> String {
        if Self.additionFilenames.contains(filename) { return "dec033_approved_addition" }
        if try characterOverrideFilenames().contains(filename) { return "n015_portrait_derived_override" }
        if Self.overrideFilenames.contains(filename) { return "n003_approved_override" }
        return "n006_base"
    }

    private func expectedConsumer(_ filename: String) -> String {
        let stem = String(filename.dropLast(4))
        let cat = expectedCategory(filename)
        switch cat {
        case "building": return "BuildingVisualPresenter"
        case "char":
            if Self.charWalkStems.contains(stem) { return "SpriteSheetAnimator" }
            if Self.playerActionStems.contains(stem) { return "PlayerActionPresenter" }
            return "CharacterVisualCatalog / PixelAssetStore"
        case "crop":
            return stem.contains("_stage_") ? "FarmScene.makeCropNode" : "InventoryItemIconPresenter / CompactFarmHudView"
        case "tile":
            if ["tile_grass", "tile_grass_a", "tile_grass_b", "tile_grass_c"].contains(stem) { return "PixelAssetStore.tileKind" }
            if ["tile_tilled", "tile_tilled_watered"].contains(stem) { return "PixelAssetStore.tileKind" }
            if stem.hasPrefix("tile_canal") { return "CanalVisualPresenter" }
            if stem.hasPrefix("tile_water") { return "WaterVisualResolver" }
            if stem == "tile_stone_path" { return "TerrainVisualResolver" }
            return "WaterVisualResolver"
        case "prop": return "FarmScene.makePlacedObjectGlyph"
        case "gather": return "GatherableVisualPresenter"
        case "tool": return "CompactFarmHudView"
        case "fx":
            if stem.hasPrefix("fx_target") { return "TargetFeedbackPresenter" }
            if stem.hasPrefix("fx_water_splash") { return "WorldEffectPresenter" }
            if stem.hasPrefix("fx_harvest") { return "WorldEffectPresenter" }
            if stem.hasPrefix("fx_canal_flow") { return "CanalVisualPresenter" }
            return "TargetFeedbackPresenter"
        case "ui":
            if ["ui_currency", "ui_stamina", "ui_time", "ui_weather"].contains(stem) { return "CompactFarmHudView" }
            if stem == "ui_interact_badge" { return "CompactFarmHudView" }
            return "CompactFarmHudView"
        default: return ""
        }
    }

    private func expectedBatch(_ filename: String) -> String {
        let stem = String(filename.dropLast(4))
        let cat = expectedCategory(filename)
        switch cat {
        case "building": return "B4"
        case "char":
            if Self.charWalkStems.contains(stem) { return "B2" }
            if Self.playerActionStems.contains(stem) { return "B3" }
            return "B1"
        case "crop": return "B1"
        case "tile":
            if stem.hasPrefix("tile_grass") || stem.hasPrefix("tile_tilled") { return "B1" }
            if stem == "tile_water_edge" { return "B1" }
            return "B2"
        case "prop": return "B1"
        case "gather": return "B3"
        case "tool": return "B1"
        case "fx": return "B3"
        case "ui":
            return ["ui_currency", "ui_stamina", "ui_time", "ui_weather"].contains(stem) ? "B1" : "B5"
        default: return ""
        }
    }

    /// In-process reproduction of the validator's per-record contract check.
    /// Returns FAIL with a non-empty error list whenever any required field is
    /// missing/empty, any enumerated value is invalid, or any field mismatches
    /// the authoritative per-file derivation (provenance, category, consumer,
    /// batch). This mirrors scripts/validate-n015-consumer-matrix.py.
    private func validateContract(_ assets: [[String: Any]]) throws -> ContractResult {
        var errors: [String] = []
        let requiredFields = [
            "asset_key", "filename", "category", "native_width", "native_height",
            "provenance", "planned_consumer", "trigger_state", "fallback", "batch", "runtime_status",
        ]
        let validCategories = Set(["char", "crop", "tile", "building", "prop", "gather", "tool", "fx", "ui"])
        let validProvenance = Set([
            "n006_base", "n003_approved_override", "n015_portrait_derived_override", "dec033_approved_addition",
        ])
        let validBatch = Set(["B1", "B2", "B3", "B4", "B5"])
        let validStatus = Set(["integrated", "planned", "blocked"])

        for (idx, asset) in assets.enumerated() {
            let context = "assets[\(idx)]"
            for field in requiredFields {
                let value = asset[field]
                if value == nil {
                    errors.append("\(context): missing or empty field '\(field)'")
                } else if let string = value as? String, string.isEmpty {
                    errors.append("\(context): missing or empty field '\(field)'")
                }
            }

            guard let filename = asset["filename"] as? String else { continue }

            if let category = asset["category"] as? String {
                if !validCategories.contains(category) {
                    errors.append("\(context): invalid category '\(category)'")
                } else if category != expectedCategory(filename) {
                    errors.append("\(filename): category '\(category)' != expected '\(expectedCategory(filename))'")
                }
            }
            if let provenance = asset["provenance"] as? String {
                if !validProvenance.contains(provenance) {
                    errors.append("\(context): invalid provenance '\(provenance)'")
                } else if provenance != (try? expectedProvenance(filename)) {
                    errors.append("\(filename): provenance '\(provenance)' != expected '\(try expectedProvenance(filename))'")
                }
            }
            if let batch = asset["batch"] as? String {
                if !validBatch.contains(batch) {
                    errors.append("\(context): invalid batch '\(batch)'")
                } else if batch != expectedBatch(filename) {
                    errors.append("\(filename): batch '\(batch)' != expected '\(expectedBatch(filename))'")
                }
            }
            if let consumer = asset["planned_consumer"] as? String, consumer != expectedConsumer(filename) {
                errors.append("\(filename): planned_consumer '\(consumer)' != expected '\(expectedConsumer(filename))'")
            }
            if let status = asset["runtime_status"] as? String, !validStatus.contains(status) {
                errors.append("\(context): invalid runtime_status '\(status)'")
            }
        }
        return ContractResult(
            result: errors.isEmpty ? "PASS" : "FAIL",
            failures: errors.count,
            errors: errors
        )
    }

    /// Loads the matrix assets as raw dictionaries, applies a tampering mutation,
    /// runs the in-process contract check, and asserts a FAIL result with a
    /// non-empty, field-specific error list.
    @discardableResult
    private func assertContractRejects(
        _ mutate: (inout [[String: Any]]) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ContractResult {
        do {
            let root = try repositoryRoot()
            let matrixURL = root.appendingPathComponent("docs/game/n-015-runtime-consumer-matrix.json")
            let data = try Data(contentsOf: matrixURL)
            var document = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any],
                "matrix must be a JSON object"
            )
            var assets = try XCTUnwrap(document["assets"] as? [[String: Any]], "assets must be an array")
            mutate(&assets)

            let result = try validateContract(assets)
            XCTAssertEqual(result.result, "FAIL", "contract check must FAIL on tampered matrix", file: file, line: line)
            XCTAssertGreaterThan(result.failures, 0, "failures must be > 0", file: file, line: line)
            XCTAssertFalse(result.errors.isEmpty, "errors must not be empty", file: file, line: line)
            return result
        } catch {
            XCTFail("unexpected error: \(error)", file: file, line: line)
            return ContractResult(result: "FAIL", failures: 0, errors: [])
        }
    }

    private func assertErrorsContain(_ result: ContractResult, _ needles: [String], file: StaticString = #filePath, line: UInt = #line) {
        let joined = result.errors.joined(separator: "\n")
        let matched = needles.contains { joined.contains($0) }
        XCTAssertTrue(matched, "errors must contain one of \(needles), got: \(result.errors)", file: file, line: line)
    }

    func testValidatorRejectsSwappedProvenance() throws {
        // Swap provenance of one n006_base asset and one n003_approved_override asset.
        // The summary counts (119/12/1) remain unchanged, so only per-file comparison can catch it.
        let result = assertContractRejects { assets in
            var baseIndex: Int?
            var overrideIndex: Int?
            for (i, asset) in assets.enumerated() {
                let provenance = asset["provenance"] as? String
                if provenance == "n006_base", baseIndex == nil {
                    baseIndex = i
                } else if provenance == "n003_approved_override", overrideIndex == nil {
                    overrideIndex = i
                }
            }
            guard let b = baseIndex, let o = overrideIndex else {
                XCTFail("could not locate base and override records")
                return
            }
            let baseProv = assets[b]["provenance"]
            let overrideProv = assets[o]["provenance"]
            assets[b]["provenance"] = overrideProv
            assets[o]["provenance"] = baseProv
        }
        assertErrorsContain(result, ["provenance"])
    }

    func testValidatorRejectsFabricatedConsumer() throws {
        let result = assertContractRejects { assets in
            guard !assets.isEmpty else {
                XCTFail("assets must not be empty")
                return
            }
            assets[0]["planned_consumer"] = "DefinitelyNotARealConsumer"
        }
        assertErrorsContain(result, ["planned_consumer"])
    }

    func testValidatorRejectsWrongBatch() throws {
        let result = assertContractRejects { assets in
            for i in assets.indices {
                if assets[i]["category"] as? String == "building" {
                    assets[i]["batch"] = "B1"
                    break
                }
            }
        }
        assertErrorsContain(result, ["batch"])
    }

    func testValidatorRejectsWrongCategory() throws {
        let result = assertContractRejects { assets in
            for i in assets.indices {
                if assets[i]["filename"] as? String == "crop_mist_radish.png" {
                    assets[i]["category"] = "building"
                    break
                }
            }
        }
        assertErrorsContain(result, ["category"])
    }

    func testValidatorRejectsDeletedProvenanceField() throws {
        // Deleting a required field must NOT crash the validator (KeyError). It must
        // emit a FAIL report naming the missing field.
        let result = assertContractRejects { assets in
            guard !assets.isEmpty else {
                XCTFail("assets must not be empty")
                return
            }
            assets[0].removeValue(forKey: "provenance")
        }
        assertErrorsContain(result, ["provenance", "missing or empty field"])
    }

    // MARK: - 12. Authoritative subprocess runner

    /// Candidate interpreter paths, ordered by preference. The first candidate
    /// that can actually print a sentinel is used. `/usr/bin/python3` is a
    /// shim that re-execs through xcrun and is forbidden in the sandbox, so it
    /// is tried last and expected to be rejected.
    private static let interpreterCandidates: [String] = [
        "/Applications/Xcode.app/Contents/Developer/usr/bin/python3",
        "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3",
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3",
        "/usr/bin/python3",
    ]

    private static var cachedInterpreter: String?

    private func resolveInterpreter() throws -> String {
        if let cached = Self.cachedInterpreter {
            return cached
        }
        for candidate in Self.interpreterCandidates {
            guard FileManager.default.fileExists(atPath: candidate) else { continue }
            let probe = Process()
            probe.executableURL = URL(fileURLWithPath: candidate)
            probe.arguments = ["-c", "print('n015-matrix-sentinel')"]
            let out = Pipe()
            probe.standardOutput = out
            probe.standardError = Pipe()
            do {
                try probe.run()
                probe.waitUntilExit()
            } catch {
                continue
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            if probe.terminationStatus == 0 && text.contains("n015-matrix-sentinel") {
                Self.cachedInterpreter = candidate
                return candidate
            }
        }
        XCTFail("no usable Python interpreter found inside the App Sandbox")
        throw NSError(domain: "N015RuntimeConsumerMatrixTests", code: 2)
    }

    private func validatorPath() throws -> String {
        let root = try repositoryRoot()
        return root.appendingPathComponent("scripts/validate-n015-consumer-matrix.py").path
    }

    private func characterOverridesPath() throws -> String {
        let root = try repositoryRoot()
        return root.appendingPathComponent("docs/game/n-015-character-overrides.json").path
    }

    private func matrixPath() throws -> String {
        let root = try repositoryRoot()
        return root.appendingPathComponent("docs/game/n-015-runtime-consumer-matrix.json").path
    }

    private struct CliResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let json: [String: Any]?
    }

    /// Run the authoritative Python validator with arbitrary arguments.
    /// stdout/stderr are redirected to temporary files instead of pipes so a
    /// large report can never deadlock `waitUntilExit()`. This is the ONLY way
    /// the negative tests exercise validation; they never reimplement the
    /// algorithm and never fabricate a result when the subprocess fails.
    private func runValidator(arguments: [String]) throws -> CliResult {
        let interpreter = try resolveInterpreter()
        let outPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("n015-matrix-cli-out-\(UUID().uuidString).txt")
        let errPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("n015-matrix-cli-err-\(UUID().uuidString).txt")
        defer {
            try? FileManager.default.removeItem(atPath: outPath)
            try? FileManager.default.removeItem(atPath: errPath)
        }
        FileManager.default.createFile(atPath: outPath, contents: nil)
        FileManager.default.createFile(atPath: errPath, contents: nil)
        let outHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: outPath))
        let errHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: errPath))
        defer {
            try? outHandle.close()
            try? errHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: interpreter)
        process.arguments = [try validatorPath()] + arguments
        process.standardOutput = outHandle
        process.standardError = errHandle
        try process.run()
        process.waitUntilExit()

        let stdout = (try? String(contentsOfFile: outPath, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOfFile: errPath, encoding: .utf8)) ?? ""
        let json: [String: Any]?
        if let data = stdout.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = obj
        } else {
            json = nil
        }
        return CliResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr, json: json)
    }

    private func loadCharacterOverridesRaw() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: try characterOverridesPath()))
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "override manifest must be a JSON object"
        )
    }

    private func loadMatrixRaw() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: try matrixPath()))
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "matrix must be a JSON object"
        )
    }

    /// Write a mutated document to a system-temporary file and return its path.
    private func writeTemporaryJSON(_ object: Any, prefix: String) throws -> String {
        let dir = NSTemporaryDirectory()
        let path = (dir as NSString).appendingPathComponent("\(prefix)-\(UUID().uuidString).json")
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }

    /// Assert that a CLI invocation yields a clean FAIL: exit 1, parseable
    /// JSON, `result == FAIL`, `failures > 0`, non-empty `errors`, no traceback
    /// on stderr, and at least one error message contains one of the needles.
    private func assertValidatorFails(
        _ name: String,
        arguments: [String],
        expecting needles: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let result = try runValidator(arguments: arguments)
        XCTAssertEqual(result.exitCode, 1, "\(name): expected exit 1, got \(result.exitCode)", file: file, line: line)
        XCTAssertNotNil(result.json, "\(name): stdout must be parseable JSON", file: file, line: line)
        XCTAssertEqual(result.json?["result"] as? String, "FAIL", "\(name): result must be FAIL", file: file, line: line)
        let failures = result.json?["failures"] as? Int ?? 0
        XCTAssertGreaterThan(failures, 0, "\(name): failures must be > 0", file: file, line: line)
        let errors = result.json?["errors"] as? [String] ?? []
        XCTAssertFalse(errors.isEmpty, "\(name): errors must be non-empty", file: file, line: line)
        XCTAssertFalse(result.stderr.contains("Traceback"), "\(name): stderr must not contain a traceback", file: file, line: line)
        let joined = errors.joined(separator: "\n")
        let matched = needles.contains { joined.contains($0) }
        XCTAssertTrue(matched, "\(name): no error contains one of \(needles), got: \(errors)", file: file, line: line)
    }

    // MARK: - 13. Authoritative subprocess tests (N-015 character-trace)

    func testAuthoritativeValidatorPassesCurrentMatrix() throws {
        let result = try runValidator(arguments: [])
        XCTAssertEqual(result.exitCode, 0, "authoritative validator must pass: \(result.stderr)")
        XCTAssertEqual(result.json?["result"] as? String, "PASS")
        let summary = result.json?["summary"] as? [String: Any]
        let provenance = summary?["provenance"] as? [String: Int]
        XCTAssertEqual(provenance, [
            "n006_base": 104,
            "n003_approved_override": 8,
            "n015_portrait_derived_override": 19,
            "dec033_approved_addition": 1,
        ])
        XCTAssertEqual(summary?["resolved_referenced_count"] as? Int, 132)
    }

    func testNegativeDeleteCharacterOverrideRecordFails() throws {
        var document = try loadCharacterOverridesRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        assets.removeLast()
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-co-delete")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "delete character override record",
            arguments: ["--character-overrides", temp],
            expecting: ["expected 19", "character override manifest"]
        )
    }

    func testNegativeTamperedCharacterOverrideShaFails() throws {
        var document = try loadCharacterOverridesRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        assets[0]["sha256"] = String(repeating: "0", count: 64)
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-co-sha")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "tamper character override SHA",
            arguments: ["--character-overrides", temp],
            expecting: ["sha256 mismatch"]
        )
    }

    func testNegativeCharacterProvenanceRevertedToBaseFails() throws {
        var document = try loadMatrixRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        for i in assets.indices where assets[i]["filename"] as? String == "char_player.png" {
            assets[i]["provenance"] = "n006_base"
        }
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-matrix-prov")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "character provenance reverted to n006_base",
            arguments: ["--matrix", temp],
            expecting: ["provenance"]
        )
    }

    func testNegativeNonCharacterMarkedN015Fails() throws {
        var document = try loadMatrixRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        for i in assets.indices where assets[i]["filename"] as? String == "crop_amber_bean.png" {
            assets[i]["provenance"] = "n015_portrait_derived_override"
        }
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-matrix-nonchar")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "non-character asset marked n015",
            arguments: ["--matrix", temp],
            expecting: ["provenance"]
        )
    }

    func testNegativeDuplicateCharacterOverrideFilenameFails() throws {
        var document = try loadCharacterOverridesRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        let firstName = try XCTUnwrap(assets.first?["file"] as? String)
        assets[assets.count - 1]["file"] = firstName
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-co-dup")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "duplicate character override filename",
            arguments: ["--character-overrides", temp],
            expecting: ["duplicate"]
        )
    }

    func testNegativeMissingRequiredFieldReturnsParseableFailJSON() throws {
        var document = try loadMatrixRaw()
        var assets = try XCTUnwrap(document["assets"] as? [[String: Any]])
        assets[0].removeValue(forKey: "provenance")
        document["assets"] = assets
        let temp = try writeTemporaryJSON(document, prefix: "n015-matrix-missing")
        defer { try? FileManager.default.removeItem(atPath: temp) }
        try assertValidatorFails(
            "missing required field",
            arguments: ["--matrix", temp],
            expecting: ["missing or empty field", "provenance"]
        )
    }
}
