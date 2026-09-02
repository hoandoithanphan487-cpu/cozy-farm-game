import Foundation
import XCTest

/// Negative contract tests for `docs/game/n-015-map-layout-contract.json`.
///
/// These tests invoke the authoritative Python validator
/// (`scripts/validate-n015-map-layout-contract.py`) via `Process`. They do NOT
/// replicate the validation algorithm: each test builds a temporary mutated
/// copy of the frozen contract, runs the CLI against it, asserts a non-zero
/// exit code, and parses `result == "FAIL"` with a non-empty `failures` list.
///
/// The test host runs inside the CreekSprout App Sandbox. The `/usr/bin/python3`
/// shim is forbidden there (`xcrun: error: cannot be used within an App
/// Sandbox`), so the tests resolve a real Python interpreter by probing the
/// Xcode Developer Tools framework binary, which is directly executable from
/// within the sandbox. If no usable interpreter is found, the tests fail
/// loudly (they never fabricate a green result).
final class N015MapLayoutContractTests: XCTestCase {
    // MARK: - Interpreter + repository resolution

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
        throw NSError(domain: "N015MapLayoutContractTests", code: 1)
    }

    private func validatorPath() throws -> String {
        let root = try repositoryRoot()
        return root.appendingPathComponent("scripts/validate-n015-map-layout-contract.py").path
    }

    private func contractPath() throws -> String {
        let root = try repositoryRoot()
        return root.appendingPathComponent("docs/game/n-015-map-layout-contract.json").path
    }

    /// Resolve a real Python interpreter that can run inside the sandbox.
    private func resolveInterpreter() throws -> String {
        if let cached = Self.cachedInterpreter {
            return cached
        }
        for candidate in Self.interpreterCandidates {
            guard FileManager.default.fileExists(atPath: candidate) else { continue }
            let probe = Process()
            probe.executableURL = URL(fileURLWithPath: candidate)
            probe.arguments = ["-c", "print('n015-map-sentinel')"]
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
            if probe.terminationStatus == 0 && text.contains("n015-map-sentinel") {
                Self.cachedInterpreter = candidate
                return candidate
            }
        }
        XCTFail("no usable Python interpreter found inside the App Sandbox")
        throw NSError(domain: "N015MapLayoutContractTests", code: 2)
    }

    // MARK: - CLI runner

    private struct CliResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let json: [String: Any]?
    }

    /// Run the validator against a contract file (the frozen one or a mutated
    /// temporary copy) and return the raw CLI result. This is the ONLY way the
    /// tests exercise validation; they never reimplement the algorithm.
    private func runValidator(contractFile: String) throws -> CliResult {
        try runValidator(arguments: ["--contract", contractFile])
    }

    /// Run the validator with arbitrary arguments (e.g. the coverage audit)
    /// and return the raw CLI result. stdout/stderr are redirected to files
    /// instead of pipes: the coverage audit emits a multi-megabyte evidence
    /// JSON, which would fill an OS pipe buffer and deadlock against
    /// `waitUntilExit()`.
    private func runValidator(arguments: [String]) throws -> CliResult {
        let interpreter = try resolveInterpreter()
        let outPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("n015-cli-out-\(UUID().uuidString).txt")
        let errPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("n015-cli-err-\(UUID().uuidString).txt")
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

    /// Load the frozen contract as a mutable JSON object.
    private func loadContract() throws -> Any {
        let data = try Data(contentsOf: URL(fileURLWithPath: try contractPath()))
        return try JSONSerialization.jsonObject(with: data)
    }

    /// Write a mutated contract to a temporary file and return its path.
    private func writeTemporaryContract(_ object: Any) throws -> String {
        let dir = NSTemporaryDirectory()
        let path = (dir as NSString).appendingPathComponent("n015-map-mutated-\(UUID().uuidString).json")
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }

    /// Assert that a mutation yields a clean FAIL: exit 1, parseable JSON,
    /// result == FAIL, non-empty failures, no traceback on stderr. When
    /// `expectingPath` is given, at least one failure message must contain
    /// that JSON path substring (the review requires accurate JSON paths in
    /// failures).
    private func assertFails(_ mutationName: String, _ object: Any, expectingPath path: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        let tempPath = try writeTemporaryContract(object)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let result = try runValidator(contractFile: tempPath)

        XCTAssertEqual(result.exitCode, 1, "\(mutationName): expected exit 1, got \(result.exitCode)", file: file, line: line)
        XCTAssertNotNil(result.json, "\(mutationName): stdout must be parseable JSON", file: file, line: line)
        XCTAssertEqual(result.json?["result"] as? String, "FAIL", "\(mutationName): result must be FAIL", file: file, line: line)
        let failures = result.json?["failures"] as? [Any] ?? []
        XCTAssertFalse(failures.isEmpty, "\(mutationName): failures must be non-empty", file: file, line: line)
        XCTAssertFalse(result.stderr.contains("Traceback"), "\(mutationName): stderr must not contain a traceback", file: file, line: line)
        if let expectedPath = path {
            let matched = failures.contains { failure in
                (failure as? String)?.contains(expectedPath) == true
            }
            XCTAssertTrue(matched, "\(mutationName): no failure message contains the JSON path '\(expectedPath)'", file: file, line: line)
        }
    }

    // MARK: - 1. The frozen contract passes

    func testFrozenContractPasses() throws {
        let result = try runValidator(contractFile: try contractPath())
        XCTAssertEqual(result.exitCode, 0, "frozen contract must pass: \(result.stderr)")
        XCTAssertEqual(result.json?["result"] as? String, "PASS")
        XCTAssertEqual(result.json?["decision_id"] as? String, "DEC-035")
        XCTAssertEqual(result.json?["task"] as? String, "N-015-VSCODE-MAP-01")
        let summary = result.json?["summary"] as? [String: Any]
        XCTAssertEqual(summary?["map_count"] as? Int, 2)
        XCTAssertEqual(summary?["building_count"] as? Int, 5)
        XCTAssertEqual(summary?["building_layer_count"] as? Int, 30)
    }

    // MARK: - 2. Negative mutations (independent, one per requirement)

    func testNegativeDeleteBuildingFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        buildings.removeFirst()
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("delete building", doc)
    }

    func testNegativeFootprintOutOfBoundsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var footprint = buildings[0]["footprint"] as! [String: Any]
        footprint["origin"] = [15, 12]
        buildings[0]["footprint"] = footprint
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("footprint out of bounds", doc)
    }

    func testNegativeBuildingsOverlapFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var footprint = buildings[1]["footprint"] as! [String: Any]
        footprint["origin"] = [1, 8]
        buildings[1]["footprint"] = footprint
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("two buildings overlap", doc)
    }

    func testNegativeEntranceIntoBlockedFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        buildings[0]["door"] = [1, 8]  // a collision cell of farm_house
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("entrance into blocked", doc)
    }

    func testNegativeSpawnToExitUnreachableFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var boundary = maps[0]["environment_boundary_cells"] as! [[Int]]
        // Block the entire y=7 corridor so wake spawn cannot reach the exit.
        for x in 0..<16 {
            boundary.append([x, 7])
        }
        maps[0]["environment_boundary_cells"] = boundary
        doc["maps"] = maps
        try assertFails("spawn to exit unreachable", doc)
    }

    func testNegativeNpcNoTalkCellFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[0]["npc_positions"] as! [[String: Any]]
        // Replace approach cells with building collision cells (blocked).
        npcs[0]["approach_cells"] = [[1, 8], [2, 8], [3, 8], [4, 8]]
        maps[0]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("NPC no walkable talk cell", doc)
    }

    func testNegativeMissingLayerFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var layers = buildings[0]["layers"] as! [[String: Any]]
        layers.removeLast()
        buildings[0]["layers"] = layers
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("building missing a layer", doc)
    }

    func testNegativeLayerOrderWrongFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var layers = buildings[0]["layers"] as! [[String: Any]]
        // Swap base and structure semantics (wrong order).
        let base = layers[0]["semantic"] as! String
        let structure = layers[1]["semantic"] as! String
        layers[0]["semantic"] = structure
        layers[1]["semantic"] = base
        buildings[0]["layers"] = layers
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("layer order wrong", doc)
    }

    func testNegativeB4FilenameSwappedFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var layers = buildings[0]["layers"] as! [[String: Any]]
        layers[0]["filename"] = "building_farm_sluice_base.png"  // wrong provenance
        buildings[0]["layers"] = layers
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("B4 filename swapped", doc)
    }

    func testNegativeMutuallyExclusiveWaterTileFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var canal = maps[0]["canal_cells"] as! [[String: Any]]
        canal.append(["cell": [12, 0], "semantic": "ns"])  // [12,0] is a water corner_sw
        maps[0]["canal_cells"] = canal
        doc["maps"] = maps
        try assertFails("mutually exclusive water tile", doc)
    }

    func testNegativeDeleteSaveRelocationRuleFails() throws {
        var doc = try loadContract() as! [String: Any]
        doc.removeValue(forKey: "save_relocation")
        try assertFails("delete save relocation rule", doc)
    }

    func testNegativeFabricatedBuildingIdFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        buildings[0]["id"] = "brookseed.landmark.fabricated"
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("fabricated building ID", doc)
    }

    func testNegativeFabricatedMapIdFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps[0]["id"] = "brookseed.map.fabricated"
        doc["maps"] = maps
        try assertFails("fabricated map ID", doc)
    }

    func testNegativeFabricatedNpcIdFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[0]["npc_positions"] as! [[String: Any]]
        npcs[0]["id"] = "brookseed.npc.fabricated"
        maps[0]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("fabricated NPC ID", doc)
    }

    func testNegativeDeleteRequiredFieldFailsParseably() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        buildings[0].removeValue(forKey: "footprint")
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        // Must return a parseable FAIL JSON, not a crash/traceback.
        try assertFails("delete required field (footprint)", doc)
    }

    // MARK: - 3. r1 false positives (R2-7): the 7 mutations the review found to pass

    /// FP1: swap two buildings' same-semantic `base` filenames, keeping the
    /// 30-file set unchanged. Must FAIL (per-building/per-layer exact mapping).
    func testFalsePositiveSwapBaseFilenameFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        for i in buildings.indices {
            if buildings[i]["id"] as? String == "brookseed.landmark.farm_house" {
                var layers = buildings[i]["layers"] as! [[String: Any]]
                for j in layers.indices where layers[j]["semantic"] as? String == "base" {
                    layers[j]["filename"] = "building_farm_sluice_base.png"
                }
                buildings[i]["layers"] = layers
            }
        }
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("FP1 swap base filename (set unchanged)", doc)
    }

    /// FP2: delete the farm teaching NPC's `npc_positions` record.
    func testFalsePositiveDeleteTeachingNpcFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps[0]["npc_positions"] = [[String: Any]]()
        doc["maps"] = maps
        try assertFails("FP2 delete farm teaching NPC", doc)
    }

    /// FP3: NPC `approach_cells` changed to walkable but non-adjacent far cells.
    func testFalsePositiveNonAdjacentApproachFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[0]["npc_positions"] as! [[String: Any]]
        npcs[0]["approach_cells"] = [[5, 5], [6, 5], [7, 5]]
        maps[0]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("FP3 approach_cells non-adjacent", doc)
    }

    /// FP4: reduce the 23 required pairs down to one.
    func testFalsePositiveReducedRequiredPairsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var reach = doc["reachability"] as! [String: Any]
        var pairs = reach["required_pairs"] as! [[String: Any]]
        pairs = Array(pairs.prefix(1))
        reach["required_pairs"] = pairs
        doc["reachability"] = reach
        try assertFails("FP4 required_pairs reduced to 1", doc)
    }

    /// FP5: 960x640 `world_safe_rect_default` set out of bounds / negative.
    func testFalsePositiveOutOfBoundsHudRectFails() throws {
        var doc = try loadContract() as! [String: Any]
        var hud = doc["hud"] as! [String: Any]
        var zones = hud["safe_zones"] as! [[String: Any]]
        for i in zones.indices where zones[i]["viewport"] as? [Int] == [960, 640] {
            zones[i]["world_safe_rect_default"] = [-999, -999, 1, 1]
        }
        hud["safe_zones"] = zones
        doc["hud"] = hud
        try assertFails("FP5 world_safe_rect_default out of bounds", doc)
    }

    /// FP6: a building layer `native_size` changed to [1,1].
    func testFalsePositiveWrongNativeSizeFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var layers = buildings[0]["layers"] as! [[String: Any]]
        layers[0]["native_size"] = [1, 1]
        buildings[0]["layers"] = layers
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("FP6 native_size [1,1]", doc)
    }

    /// FP7: change every water cell semantic to `base`.
    func testFalsePositiveAllWaterBaseFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            var water = maps[m]["water_cells"] as! [[String: Any]]
            for w in water.indices {
                water[w]["semantic"] = "base"
            }
            maps[m]["water_cells"] = water
        }
        doc["maps"] = maps
        try assertFails("FP7 all water -> base", doc)
    }

    // MARK: - 4. Additional R2 negative tests

    /// R2-1: correct filename but wrong native size (must fail per-building size).
    func testNegativeWrongNativeSizeForBuildingFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var layers = buildings[0]["layers"] as! [[String: Any]]
        layers[0]["native_size"] = [100, 100]  // farm_house must be 144x144
        buildings[0]["layers"] = layers
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("wrong native size for building", doc)
    }

    /// R2-2: duplicate NPC (fabricated extra NPC entry).
    func testNegativeDuplicateNpcFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[1]["npc_positions"] as! [[String: Any]]
        npcs.append(["id": "brookseed.npc.creek_warden", "position": [13, 9], "approach_cells": [[12, 9], [13, 8], [13, 10]]])
        maps[1]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("duplicate NPC", doc)
    }

    /// R2-2: NPC on wrong map (moved to a different map).
    func testNegativeNpcWrongMapFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        // Move farm teaching NPC (water_apprentice) into the market map's list.
        var farmNpcs = maps[0]["npc_positions"] as! [[String: Any]]
        var marketNpcs = maps[1]["npc_positions"] as! [[String: Any]]
        // farm water_apprentice is at index 0; append a duplicate to market.
        marketNpcs.append(["id": "brookseed.npc.water_apprentice", "position": [8, 6], "approach_cells": [[7, 6], [8, 5], [8, 7], [9, 6]]])
        maps[1]["npc_positions"] = marketNpcs
        doc["maps"] = maps
        _ = farmNpcs
        try assertFails("NPC wrong map", doc)
    }

    /// R2-4: broken water body (isolated water cell).
    func testNegativeIsolatedWaterCellFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var water = maps[0]["water_cells"] as! [[String: Any]]
        water.append(["cell": [5, 5], "semantic": "base"])
        maps[0]["water_cells"] = water
        doc["maps"] = maps
        try assertFails("isolated water cell", doc)
    }

    /// R2-4: wrong corner semantic.
    func testNegativeWrongCornerSemanticFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var water = maps[0]["water_cells"] as! [[String: Any]]
        for w in water.indices where water[w]["cell"] as? [Int] == [12, 0] {
            water[w]["semantic"] = "corner_se"  // should be corner_sw
        }
        maps[0]["water_cells"] = water
        doc["maps"] = maps
        try assertFails("wrong corner semantic", doc)
    }

    /// R2-4: canal direction mismatch (ns -> ew).
    func testNegativeCanalDirectionMismatchFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var canal = maps[0]["canal_cells"] as! [[String: Any]]
        canal[0]["semantic"] = "ew"
        maps[0]["canal_cells"] = canal
        doc["maps"] = maps
        try assertFails("canal direction mismatch", doc)
    }

    /// R2-5: negative HUD rect origin.
    func testNegativeNegativeHudRectFails() throws {
        var doc = try loadContract() as! [String: Any]
        var hud = doc["hud"] as! [String: Any]
        var zones = hud["safe_zones"] as! [[String: Any]]
        for i in zones.indices where zones[i]["viewport"] as? [Int] == [960, 640] {
            zones[i]["status_left"] = [-16, 16, 272, 44]
        }
        hud["safe_zones"] = zones
        doc["hud"] = hud
        try assertFails("negative HUD rect origin", doc)
    }

    /// R2-5: zero-area HUD rect.
    func testNegativeZeroAreaHudRectFails() throws {
        var doc = try loadContract() as! [String: Any]
        var hud = doc["hud"] as! [String: Any]
        var zones = hud["safe_zones"] as! [[String: Any]]
        for i in zones.indices where zones[i]["viewport"] as? [Int] == [960, 640] {
            zones[i]["toolbelt"] = [300, 568, 0, 56]
        }
        hud["safe_zones"] = zones
        doc["hud"] = hud
        try assertFails("zero-area HUD rect", doc)
    }

    /// R2-5: wrong tie-break in save relocation.
    func testNegativeWrongTieBreakFails() throws {
        var doc = try loadContract() as! [String: Any]
        var sr = doc["save_relocation"] as! [String: Any]
        var nrs = sr["nearest_safe_rule"] as! [String: Any]
        nrs["tie_break"] = ["x_ascending", "y_ascending", "distance_ascending"]
        sr["nearest_safe_rule"] = nrs
        doc["save_relocation"] = sr
        try assertFails("wrong tie-break", doc)
    }

    /// R2-6: unknown field in a nested object must FAIL.
    func testNegativeUnknownNestedFieldFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        buildings[0]["fabricated_field"] = "nope"
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("unknown nested field", doc)
    }

    /// R2-2: fabricated spawn ID.
    func testNegativeFabricatedSpawnIdFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var spawns = maps[0]["spawns"] as! [[String: Any]]
        spawns[0]["id"] = "brookseed.spawn.fabricated"
        maps[0]["spawns"] = spawns
        doc["maps"] = maps
        try assertFails("fabricated spawn ID", doc)
    }

    // MARK: - 5. r2 false positives (R3-5): the 7 mutations the r2 review found to pass

    /// FP-r2-1: true bidirectional swap of seed_shed and warden_post `base`
    /// filenames. Both are 96×96, so the 30-file set and native sizes are
    /// unchanged. Must FAIL per (building_id, semantic) exact filename.
    func testFalsePositiveBidirectionalSwapBaseFilenameFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            var buildings = maps[m]["buildings"] as! [[String: Any]]
            for b in buildings.indices {
                guard let bid = buildings[b]["id"] as? String else { continue }
                guard bid == "brookseed.landmark.market_seed_shed"
                    || bid == "brookseed.landmark.market_warden_post" else { continue }
                var layers = buildings[b]["layers"] as! [[String: Any]]
                for l in layers.indices where layers[l]["semantic"] as? String == "base" {
                    if bid == "brookseed.landmark.market_seed_shed" {
                        layers[l]["filename"] = "building_market_warden_post_base.png"
                    } else {
                        layers[l]["filename"] = "building_market_seed_shed_base.png"
                    }
                }
                buildings[b]["layers"] = layers
            }
            maps[m]["buildings"] = buildings
        }
        doc["maps"] = maps
        try assertFails("FP-r2-1 bidirectional swap base filename", doc)
    }

    /// FP-r2-2: shift seed_shed footprint, collision, door, interaction,
    /// occlusion, and render anchor one cell north. Must FAIL on frozen
    /// building origin/door/interaction/occlusion/anchor coordinates.
    func testFalsePositiveWholeBuildingShiftFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            var buildings = maps[m]["buildings"] as! [[String: Any]]
            for b in buildings.indices {
                guard buildings[b]["id"] as? String == "brookseed.landmark.market_seed_shed" else { continue }
                var footprint = buildings[b]["footprint"] as! [String: Any]
                var origin = footprint["origin"] as! [Int]
                origin[1] += 1
                footprint["origin"] = origin
                buildings[b]["footprint"] = footprint
                var door = buildings[b]["door"] as! [Int]
                door[1] += 1
                buildings[b]["door"] = door
                buildings[b]["collision_cells"] = (buildings[b]["collision_cells"] as! [[Int]]).map { [$0[0], $0[1] + 1] }
                buildings[b]["interaction_cells"] = (buildings[b]["interaction_cells"] as! [[Int]]).map { [$0[0], $0[1] + 1] }
                buildings[b]["occlusion_cells"] = (buildings[b]["occlusion_cells"] as! [[Int]]).map { [$0[0], $0[1] + 1] }
                var anchor = buildings[b]["render_anchor"] as! [String: Any]
                var cell = anchor["cell"] as! [Int]
                cell[1] += 1
                anchor["cell"] = cell
                buildings[b]["render_anchor"] = anchor
            }
            maps[m]["buildings"] = buildings
        }
        doc["maps"] = maps
        try assertFails("FP-r2-2 whole building shift north", doc)
    }

    /// FP-r2-3: clear farm_house collision_cells. Must FAIL because
    /// collision_cells must equal the frozen footprint-minus-door set.
    func testFalsePositiveClearCollisionFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            var buildings = maps[m]["buildings"] as! [[String: Any]]
            for b in buildings.indices where buildings[b]["id"] as? String == "brookseed.landmark.farm_house" {
                buildings[b]["collision_cells"] = [[Int]]()
            }
            maps[m]["buildings"] = buildings
        }
        doc["maps"] = maps
        try assertFails("FP-r2-3 clear collision_cells", doc)
    }

    /// FP-r2-4: delete all path_cells from both maps. Must FAIL on frozen
    /// path-cell coordinate consistency.
    func testFalsePositiveDeleteAllPathCellsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            maps[m]["path_cells"] = [[Int]]()
        }
        doc["maps"] = maps
        try assertFails("FP-r2-4 delete all path_cells", doc)
    }

    /// FP-r2-5: set farm_house render_anchor.normalized to [99,99]. Must FAIL
    /// on normalized range and exact frozen value.
    func testFalsePositiveIllegalNormalizedFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        for m in maps.indices {
            var buildings = maps[m]["buildings"] as! [[String: Any]]
            for b in buildings.indices where buildings[b]["id"] as? String == "brookseed.landmark.farm_house" {
                var anchor = buildings[b]["render_anchor"] as! [String: Any]
                anchor["normalized"] = [99, 99]
                buildings[b]["render_anchor"] = anchor
            }
            maps[m]["buildings"] = buildings
        }
        doc["maps"] = maps
        try assertFails("FP-r2-5 illegal normalized", doc)
    }

    /// FP-r2-6: delete top-level deterministic_ordering. Must FAIL on the
    /// required-field check.
    func testFalsePositiveDeleteDeterministicOrderingFails() throws {
        var doc = try loadContract() as! [String: Any]
        doc.removeValue(forKey: "deterministic_ordering")
        try assertFails("FP-r2-6 delete deterministic_ordering", doc)
    }

    /// FP-r2-7: reverse the maps array order. Must FAIL on frozen stable order.
    func testFalsePositiveReverseMapsOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps.reverse()
        doc["maps"] = maps
        try assertFails("FP-r2-7 reverse maps order", doc)
    }

    // MARK: - 6. r3 false positives (R4): the 5 ordering mutations the r3 review found to pass

    /// FP-r3-1: reverse the creek_market buildings array. Must FAIL on the
    /// frozen buildings order (footprint origin y ascending, then x ascending).
    func testFalsePositiveReverseBuildingsOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[1]["buildings"] as! [[String: Any]]
        buildings.reverse()
        maps[1]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("FP-r3-1 reverse buildings order", doc)
    }

    /// FP-r3-2: reverse the farm_homestead path_cells array. Must FAIL on the
    /// frozen cell order (x ascending, then y ascending).
    func testFalsePositiveReversePathCellsOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var pathCells = maps[0]["path_cells"] as! [[Int]]
        pathCells.reverse()
        maps[0]["path_cells"] = pathCells
        doc["maps"] = maps
        try assertFails("FP-r3-2 reverse path_cells order", doc)
    }

    /// FP-r3-3: reverse the farm_homestead water_cells records. Must FAIL on the
    /// frozen cell-record order (by cell x ascending, then y ascending).
    func testFalsePositiveReverseWaterCellsOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var water = maps[0]["water_cells"] as! [[String: Any]]
        water.reverse()
        maps[0]["water_cells"] = water
        doc["maps"] = maps
        try assertFails("FP-r3-3 reverse water_cells order", doc)
    }

    /// FP-r3-4: reverse the creek_market npc_positions array. Must FAIL on the
    /// frozen explicit named-record order.
    func testFalsePositiveReverseNpcOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[1]["npc_positions"] as! [[String: Any]]
        npcs.reverse()
        maps[1]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("FP-r3-4 reverse npc_positions order", doc)
    }

    /// FP-r3-5: reverse the farm_homestead spawns array. Must FAIL on the frozen
    /// explicit named-record order.
    func testFalsePositiveReverseSpawnsOrderFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var spawns = maps[0]["spawns"] as! [[String: Any]]
        spawns.reverse()
        maps[0]["spawns"] = spawns
        doc["maps"] = maps
        try assertFails("FP-r3-5 reverse spawns order", doc)
    }

    // MARK: - 7. r4 false positives (R5): the 12 schema/value mutations the r4 review found to pass

    /// FP-r4-1: delete creek_market's explicit `canal_cells: []`. Must FAIL on
    /// the required-field check (missing field must not be conflated with an
    /// explicit empty array).
    func testFalsePositiveDeleteEmptyCanalCellsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps[1].removeValue(forKey: "canal_cells")
        doc["maps"] = maps
        try assertFails("FP-r4-1 delete empty canal_cells", doc)
    }

    /// FP-r4-2: delete creek_market's explicit `farm_area: null`. Must FAIL on
    /// the required-field check (missing field must not be conflated with an
    /// explicit null).
    func testFalsePositiveDeleteNullFarmAreaFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps[1].removeValue(forKey: "farm_area")
        doc["maps"] = maps
        try assertFails("FP-r4-2 delete null farm_area", doc)
    }

    /// FP-r4-3: delete `terrain.path_semantic`. Must FAIL on terrain required
    /// field + frozen value.
    func testFalsePositiveDeleteTerrainPathSemanticFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var terrain = maps[0]["terrain"] as! [String: Any]
        terrain.removeValue(forKey: "path_semantic")
        maps[0]["terrain"] = terrain
        doc["maps"] = maps
        try assertFails("FP-r4-3 delete terrain.path_semantic", doc)
    }

    /// FP-r4-4: delete `coordinate_system.screen_origin`. Must FAIL on
    /// coordinate_system required field + frozen value.
    func testFalsePositiveDeleteScreenOriginFails() throws {
        var doc = try loadContract() as! [String: Any]
        var cs = doc["coordinate_system"] as! [String: Any]
        cs.removeValue(forKey: "screen_origin")
        doc["coordinate_system"] = cs
        try assertFails("FP-r4-4 delete coordinate_system.screen_origin", doc)
    }

    /// FP-r4-5: delete `movement_semantics.walkable`. Must FAIL on movement
    /// semantics required field + frozen value.
    func testFalsePositiveDeleteWalkableFails() throws {
        var doc = try loadContract() as! [String: Any]
        var ms = doc["movement_semantics"] as! [String: Any]
        ms.removeValue(forKey: "walkable")
        doc["movement_semantics"] = ms
        try assertFails("FP-r4-5 delete movement_semantics.walkable", doc)
    }

    /// FP-r4-6: delete `immutable_stable_ids.stable_id_families`. Must FAIL on
    /// immutable object required field + frozen value.
    func testFalsePositiveDeleteStableIdFamiliesFails() throws {
        var doc = try loadContract() as! [String: Any]
        var imm = doc["immutable_stable_ids"] as! [String: Any]
        imm.removeValue(forKey: "stable_id_families")
        doc["immutable_stable_ids"] = imm
        try assertFails("FP-r4-6 delete stable_id_families", doc)
    }

    /// FP-r4-7: change `coordinate_system.x_axis` to "west". Must FAIL on frozen
    /// axis value.
    func testFalsePositiveTamperXAxisFails() throws {
        var doc = try loadContract() as! [String: Any]
        var cs = doc["coordinate_system"] as! [String: Any]
        cs["x_axis"] = "west"
        doc["coordinate_system"] = cs
        try assertFails("FP-r4-7 x_axis -> west", doc)
    }

    /// FP-r4-8: tamper `movement_semantics.walkable`. Must FAIL on frozen
    /// movement semantic value.
    func testFalsePositiveTamperWalkableFails() throws {
        var doc = try loadContract() as! [String: Any]
        var ms = doc["movement_semantics"] as! [String: Any]
        ms["walkable"] = "tampered walkable semantics"
        doc["movement_semantics"] = ms
        try assertFails("FP-r4-8 tamper movement_semantics.walkable", doc)
    }

    /// FP-r4-9: tamper `terrain.visual_variants`. Must FAIL on frozen terrain
    /// visual semantic.
    func testFalsePositiveTamperVisualVariantsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var terrain = maps[0]["terrain"] as! [String: Any]
        terrain["visual_variants"] = "tampered"
        maps[0]["terrain"] = terrain
        doc["maps"] = maps
        try assertFails("FP-r4-9 tamper terrain.visual_variants", doc)
    }

    /// FP-r4-10: change `world_safe_zone.visual_buffer_rows` to 999. Must FAIL
    /// on frozen visual buffer rows value.
    func testFalsePositiveTamperVisualBufferRowsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var wsz = maps[0]["world_safe_zone"] as! [String: Any]
        wsz["visual_buffer_rows"] = 999
        maps[0]["world_safe_zone"] = wsz
        doc["maps"] = maps
        try assertFails("FP-r4-10 visual_buffer_rows -> 999", doc)
    }

    /// FP-r4-11: tamper the teaching NPC's `scope`. Must FAIL on the
    /// record-specific frozen scope value.
    func testFalsePositiveTamperNpcScopeFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[0]["npc_positions"] as! [[String: Any]]
        for i in npcs.indices where npcs[i]["id"] as? String == "brookseed.npc.water_apprentice" {
            npcs[i]["scope"] = "tampered_scope"
        }
        maps[0]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("FP-r4-11 tamper npc scope", doc)
    }

    /// FP-r4-12: tamper the restored_brook_cache gather `required_unlock_id`.
    /// Must FAIL on the record-specific frozen value.
    func testFalsePositiveTamperRequiredUnlockIdFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var gather = maps[1]["gather_targets"] as! [[String: Any]]
        for i in gather.indices where gather[i]["id"] as? String == "brookseed.gather.restored_brook_cache" {
            gather[i]["required_unlock_id"] = "tampered_unlock"
        }
        maps[1]["gather_targets"] = gather
        doc["maps"] = maps
        try assertFails("FP-r4-12 tamper required_unlock_id", doc)
    }

    // MARK: - 8. Table-driven nested required-field deletion (R5)

    /// R5 table-driven test: for each nested object kind, delete at least one
    /// required field and assert the same failure contract (exit 1, parseable
    /// FAIL, non-empty failures, no traceback). Each mutation is produced from
    /// the frozen contract and run through the same Python validator subprocess.
    func testTableDrivenNestedRequiredFieldDeletion() throws {
        // Each entry: a label and a mutator that deletes one required field from
        // a nested object of that kind.
        let cases: [(String, (inout [String: Any]) -> Void)] = [
            ("map.building", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var buildings = maps[0]["buildings"] as! [[String: Any]]
                buildings[0].removeValue(forKey: "footprint")
                maps[0]["buildings"] = buildings
                doc["maps"] = maps
            }),
            ("map.dimension", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var dims = maps[0]["dimensions"] as! [String: Any]
                dims.removeValue(forKey: "columns")
                maps[0]["dimensions"] = dims
                doc["maps"] = maps
            }),
            ("map.legacy_bounds", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var lb = maps[0]["legacy_bounds"] as! [String: Any]
                lb.removeValue(forKey: "rows")
                maps[0]["legacy_bounds"] = lb
                doc["maps"] = maps
            }),
            ("map.world_safe_zone", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var wsz = maps[0]["world_safe_zone"] as! [String: Any]
                wsz.removeValue(forKey: "playable_bounds")
                maps[0]["world_safe_zone"] = wsz
                doc["maps"] = maps
            }),
            ("map.terrain", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var terrain = maps[0]["terrain"] as! [String: Any]
                terrain.removeValue(forKey: "default")
                maps[0]["terrain"] = terrain
                doc["maps"] = maps
            }),
            ("map.npc", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var npcs = maps[0]["npc_positions"] as! [[String: Any]]
                npcs[0].removeValue(forKey: "position")
                maps[0]["npc_positions"] = npcs
                doc["maps"] = maps
            }),
            ("map.spawn", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var spawns = maps[0]["spawns"] as! [[String: Any]]
                spawns[0].removeValue(forKey: "position")
                maps[0]["spawns"] = spawns
                doc["maps"] = maps
            }),
            ("map.exit", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var exits = maps[0]["exits"] as! [[String: Any]]
                exits[0].removeValue(forKey: "destination_map_id")
                maps[0]["exits"] = exits
                doc["maps"] = maps
            }),
            ("map.landmark", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var landmarks = maps[0]["landmarks"] as! [[String: Any]]
                landmarks[0].removeValue(forKey: "anchor")
                maps[0]["landmarks"] = landmarks
                doc["maps"] = maps
            }),
            ("map.gather", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var gather = maps[0]["gather_targets"] as! [[String: Any]]
                gather[0].removeValue(forKey: "cell")
                maps[0]["gather_targets"] = gather
                doc["maps"] = maps
            }),
            ("map.quest", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var quest = maps[0]["quest_targets"] as! [[String: Any]]
                quest[0].removeValue(forKey: "cell")
                maps[0]["quest_targets"] = quest
                doc["maps"] = maps
            }),
            ("map.farm_area", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var fa = maps[0]["farm_area"] as! [String: Any]
                fa.removeValue(forKey: "primary_rectangles")
                maps[0]["farm_area"] = fa
                doc["maps"] = maps
            }),
            ("building.footprint", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var buildings = maps[0]["buildings"] as! [[String: Any]]
                var fp = buildings[0]["footprint"] as! [String: Any]
                fp.removeValue(forKey: "origin")
                buildings[0]["footprint"] = fp
                maps[0]["buildings"] = buildings
                doc["maps"] = maps
            }),
            ("building.render_anchor", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var buildings = maps[0]["buildings"] as! [[String: Any]]
                var anchor = buildings[0]["render_anchor"] as! [String: Any]
                anchor.removeValue(forKey: "normalized")
                buildings[0]["render_anchor"] = anchor
                maps[0]["buildings"] = buildings
                doc["maps"] = maps
            }),
            ("building.layer", { doc in
                var maps = doc["maps"] as! [[String: Any]]
                var buildings = maps[0]["buildings"] as! [[String: Any]]
                var layers = buildings[0]["layers"] as! [[String: Any]]
                layers[0].removeValue(forKey: "filename")
                buildings[0]["layers"] = layers
                maps[0]["buildings"] = buildings
                doc["maps"] = maps
            }),
            ("hud.behavior", { doc in
                var hud = doc["hud"] as! [String: Any]
                var behavior = hud["behavior"] as! [String: Any]
                behavior.removeValue(forKey: "building_card")
                hud["behavior"] = behavior
                doc["hud"] = hud
            }),
            ("hud.safe_zone", { doc in
                var hud = doc["hud"] as! [String: Any]
                var zones = hud["safe_zones"] as! [[String: Any]]
                zones[0].removeValue(forKey: "viewport")
                hud["safe_zones"] = zones
                doc["hud"] = hud
            }),
            ("reachability.pair", { doc in
                var reach = doc["reachability"] as! [String: Any]
                var pairs = reach["required_pairs"] as! [[String: Any]]
                pairs[0].removeValue(forKey: "from")
                reach["required_pairs"] = pairs
                doc["reachability"] = reach
            }),
            ("save_relocation.nearest_safe_rule", { doc in
                var sr = doc["save_relocation"] as! [String: Any]
                var nrs = sr["nearest_safe_rule"] as! [String: Any]
                nrs.removeValue(forKey: "distance")
                sr["nearest_safe_rule"] = nrs
                doc["save_relocation"] = sr
            }),
            ("save_relocation.coordinate_records", { doc in
                var sr = doc["save_relocation"] as! [String: Any]
                var cr = sr["coordinate_records"] as! [String: Any]
                cr.removeValue(forKey: "player_position")
                sr["coordinate_records"] = cr
                doc["save_relocation"] = sr
            }),
            ("deterministic_ordering", { doc in
                var det = doc["deterministic_ordering"] as! [String: Any]
                det.removeValue(forKey: "cells")
                doc["deterministic_ordering"] = det
            }),
        ]

        for (label, mutate) in cases {
            var doc = try loadContract() as! [String: Any]
            mutate(&doc)
            try assertFails("table-driven delete required field: \(label)", doc)
        }
    }

    // MARK: - 9. r5 false positives (R6): the 7 mutation categories the r5 review found to pass

    /// FP-r5-1: tamper `quest_targets[].purpose` to fabricated text. Must FAIL
    /// on the frozen purpose value with the exact JSON path.
    func testFalsePositiveTamperQuestPurposeFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var quest = maps[1]["quest_targets"] as! [[String: Any]]
        quest[0]["purpose"] = "fabricated purpose text"
        maps[1]["quest_targets"] = quest
        doc["maps"] = maps
        try assertFails("FP-r5-1 tamper quest purpose", doc, expectingPath: "purpose")
    }

    /// FP-r5-2: add `static_obstacle_cells: []` to farm_homestead. The farm map
    /// must not carry this key at all (even as an explicit empty array).
    func testFalsePositiveFarmStaticObstacleKeyFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        maps[0]["static_obstacle_cells"] = [[Int]]()
        doc["maps"] = maps
        try assertFails("FP-r5-2 farm static_obstacle_cells key", doc, expectingPath: "static_obstacle_cells")
    }

    /// FP-r5-3: add `plaza_semantic` to farm_homestead terrain. plaza_semantic
    /// is market-only; the farm terrain key set must reject it.
    func testFalsePositiveFarmPlazaSemanticFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var terrain = maps[0]["terrain"] as! [String: Any]
        terrain["plaza_semantic"] = "wet_stone"
        maps[0]["terrain"] = terrain
        doc["maps"] = maps
        try assertFails("FP-r5-3 farm terrain plaza_semantic", doc, expectingPath: "plaza_semantic")
    }

    /// FP-r5-4: reverse farm_house `collision_cells`. Must FAIL on the frozen
    /// cell order (x ascending, then y ascending).
    func testFalsePositiveReverseCollisionCellsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var collision = buildings[0]["collision_cells"] as! [[Int]]
        collision.reverse()
        buildings[0]["collision_cells"] = collision
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("FP-r5-4 reverse collision_cells", doc, expectingPath: "collision_cells")
    }

    /// FP-r5-5: reverse farm_house `occlusion_cells`. Must FAIL on the frozen
    /// cell order.
    func testFalsePositiveReverseOcclusionCellsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var buildings = maps[0]["buildings"] as! [[String: Any]]
        var occlusion = buildings[0]["occlusion_cells"] as! [[Int]]
        occlusion.reverse()
        buildings[0]["occlusion_cells"] = occlusion
        maps[0]["buildings"] = buildings
        doc["maps"] = maps
        try assertFails("FP-r5-5 reverse occlusion_cells", doc, expectingPath: "occlusion_cells")
    }

    /// FP-r5-6: reverse creek_warden `approach_cells`. Must FAIL on the frozen
    /// cell order.
    func testFalsePositiveReverseApproachCellsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var maps = doc["maps"] as! [[String: Any]]
        var npcs = maps[1]["npc_positions"] as! [[String: Any]]
        var approach = npcs[0]["approach_cells"] as! [[Int]]
        approach.reverse()
        npcs[0]["approach_cells"] = approach
        maps[1]["npc_positions"] = npcs
        doc["maps"] = maps
        try assertFails("FP-r5-6 reverse approach_cells", doc, expectingPath: "approach_cells")
    }

    /// FP-r5-7: reverse `immutable_stable_ids.buildings` and `.npcs`. Must FAIL
    /// on the frozen explicit list order (no sorted() comparison allowed).
    func testFalsePositiveReverseImmutableListsFails() throws {
        var doc = try loadContract() as! [String: Any]
        var immutable = doc["immutable_stable_ids"] as! [String: Any]
        var buildings = immutable["buildings"] as! [String]
        var npcs = immutable["npcs"] as! [String]
        buildings.reverse()
        npcs.reverse()
        immutable["buildings"] = buildings
        immutable["npcs"] = npcs
        doc["immutable_stable_ids"] = immutable
        try assertFails("FP-r5-7 reverse immutable buildings/npcs", doc, expectingPath: "immutable_stable_ids")
    }

    // MARK: - 10. Automated coverage audit (R6)

    /// The validator's `--coverage-audit` mode mutates the frozen contract
    /// exhaustively — every dict key deletion, every scalar leaf mutation,
    /// every length>1 array reversal — and runs the real validator as a
    /// subprocess for each mutation. Every case must FAIL; no unwhitelisted
    /// PASS (coverage gap) may exist.
    func testCoverageAuditAllMutationsFail() throws {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("n015-coverage-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let result = try runValidator(arguments: ["--coverage-audit", dir])
        XCTAssertEqual(result.exitCode, 0, "coverage audit must exit 0, got \(result.exitCode). stderr: \(result.stderr)")
        XCTAssertNotNil(result.json, "coverage audit stdout must be parseable JSON")

        let auditPath = (dir as NSString).appendingPathComponent("coverage-audit.json")
        let auditData = try Data(contentsOf: URL(fileURLWithPath: auditPath))
        let audit = try XCTUnwrap(JSONSerialization.jsonObject(with: auditData) as? [String: Any])

        let stats = audit["statistics"] as? [String: Any]
        XCTAssertEqual(stats?["gaps"] as? Int, 0, "coverage audit must have zero gaps")
        XCTAssertEqual(stats?["passed"] as? Int, 0, "coverage audit must have zero passed mutations")
        XCTAssertEqual(stats?["whitelisted"] as? Int, 0, "coverage audit whitelist must be empty")

        let phaseCounts = audit["phase_counts"] as? [String: Any]
        XCTAssertGreaterThan(phaseCounts?["key_deletion"] as? Int ?? 0, 500, "key-deletion phase must traverse every dict key")
        XCTAssertGreaterThan(phaseCounts?["leaf_mutation"] as? Int ?? 0, 1000, "leaf-mutation phase must traverse every scalar leaf")
        XCTAssertGreaterThan(phaseCounts?["array_reverse"] as? Int ?? 0, 400, "array-reverse phase must traverse every length>1 array")

        let baseline = audit["baseline"] as? [String: Any]
        XCTAssertEqual(baseline?["result"] as? String, "PASS", "coverage audit baseline must PASS the frozen contract")

        let cases = try XCTUnwrap(audit["cases"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty, "coverage audit must emit cases")
        for (index, caseEntry) in cases.enumerated() {
            XCTAssertEqual(caseEntry["exit"] as? Int, 1, "case \(index) \(caseEntry["json_path"] ?? "?") must exit 1")
            XCTAssertEqual(caseEntry["result"] as? String, "FAIL", "case \(index) \(caseEntry["json_path"] ?? "?") must FAIL")
            XCTAssertGreaterThan(caseEntry["failures"] as? Int ?? 0, 0, "case \(index) \(caseEntry["json_path"] ?? "?") must have failures")
            XCTAssertEqual(caseEntry["matched_failure_path"] as? Bool, true, "case \(index) \(caseEntry["json_path"] ?? "?") must have a failure matching its JSON path")
            let excerpt = caseEntry["failure_excerpt"] as? String ?? ""
            XCTAssertFalse(excerpt.contains("crashed"), "case \(index) \(caseEntry["json_path"] ?? "?") must not crash the validator")
        }
    }
}
