import Foundation
import XCTest
@testable import CreekSprout

/// Release wall-clock perf evidence for NFR-001/002 (M4-001 REVISE).
final class M4PerformanceTests: XCTestCase {
    private struct ExportRequest: Decodable {
        let warmupSeconds: TimeInterval
        let measureSeconds: TimeInterval
        let evidenceDirectory: String

        enum CodingKeys: String, CodingKey {
            case warmupSeconds = "warmup_seconds"
            case measureSeconds = "measure_seconds"
            case evidenceDirectory = "evidence_directory"
        }
    }

    private var repoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let xcodeproj = url.appendingPathComponent("macos/CreekSprout/CreekSprout.xcodeproj")
            if FileManager.default.fileExists(atPath: xcodeproj.path) {
                return url
            }
        }
        XCTFail("Unable to locate repo root for perf export")
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func exportRequestURL() -> URL {
        repoRoot.appendingPathComponent("artifacts/integration/m4-001-xcode/perf/export-request.json")
    }

    private func loadExportRequest() -> ExportRequest? {
        let url = exportRequestURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let request = try? JSONDecoder().decode(ExportRequest.self, from: data) else {
            return nil
        }
        return request
    }

    private func warmupSeconds() -> TimeInterval {
        if let request = loadExportRequest() {
            return request.warmupSeconds
        }
        if let value = ProcessInfo.processInfo.environment["M4_PERF_WARMUP"],
           let seconds = TimeInterval(value) {
            return seconds
        }
        return 2
    }

    private func measureSeconds() -> TimeInterval {
        if let request = loadExportRequest() {
            return request.measureSeconds
        }
        if let value = ProcessInfo.processInfo.environment["M4_PERF_MEASURE"],
           let seconds = TimeInterval(value) {
            return seconds
        }
        return 15
    }

    private func resolveEvidencePath(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return repoRoot.appendingPathComponent(expanded, isDirectory: true)
    }

    private func evidenceDirectory() -> URL? {
        if let request = loadExportRequest() {
            return resolveEvidencePath(request.evidenceDirectory)
        }
        guard let path = ProcessInfo.processInfo.environment["M4_PERF_EVIDENCE_DIR"], !path.isEmpty else {
            return nil
        }
        return resolveEvidencePath(path)
    }

    func testStressRouteFrameTimesMeetNFR001() {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        PerformanceStressHarness.run(
            scene: scene,
            warmupSeconds: warmupSeconds(),
            measureSeconds: measureSeconds()
        )
        XCTAssertGreaterThan(scene.frameTimeSampler.postWarmupSampleCount, 100)
        guard let p95 = scene.frameTimeSampler.p95Ms, let p99 = scene.frameTimeSampler.p99Ms else {
            XCTFail("No post-warmup frame samples recorded")
            return
        }
        XCTAssertLessThanOrEqual(p95, 16.67, "P95 frame time \(p95)ms")
        XCTAssertLessThanOrEqual(p99, 25.0, "P99 frame time \(p99)ms")
    }

    func testMapTransitionLoadTimesMeetNFR002() {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        scene.runMapTransitionBenchmark(roundTrips: 5)
        XCTAssertEqual(scene.mapTransitionTimer.samplesMs.count, 10)
        guard let p95 = scene.mapTransitionTimer.p95Ms else {
            XCTFail("No map load samples")
            return
        }
        XCTAssertLessThan(p95, 3_000, "Map load P95 \(p95)ms")
        for sample in scene.mapTransitionTimer.samplesMs {
            XCTAssertGreaterThan(sample, 0)
        }
    }

    func testMemorySamplesStayStableDuringStressRoute() {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        PerformanceStressHarness.run(scene: scene, warmupSeconds: 1, measureSeconds: 8)
        let samples = scene.perfMemorySamplesMB
        guard samples.count >= 2, let start = samples.first, let end = samples.last, let peak = samples.max() else {
            XCTFail("Expected RSS samples during stress route")
            return
        }
        XCTAssertLessThan(end - start, 50)
        XCTAssertLessThan(peak - start, 80)
    }

    func testExportPerformanceEvidenceMatchesFarmSceneShape() throws {
        let scene = FarmScene(size: CGSize(width: 1920, height: 1080))
        PerformanceStressHarness.run(
            scene: scene,
            warmupSeconds: warmupSeconds(),
            measureSeconds: measureSeconds()
        )
        scene.runMapTransitionBenchmark(roundTrips: 5, preserveExistingSamples: true)

        let directory = evidenceDirectory()
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("CreekSprout-perf-\(UUID().uuidString)", isDirectory: true)
        XCTAssertTrue(scene.exportPerformanceEvidence(to: directory), "exportPerformanceEvidence failed for \(directory.path)")

        let summaryURL = directory.appendingPathComponent("perf-summary.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: summaryURL.path))
        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: summaryURL)) as? [String: Any]
        XCTAssertNotNil(payload?["sampling_method"])
        XCTAssertNotNil(payload?["frame_times"])
        XCTAssertNotNil(payload?["map_loads"])

        XCTAssertNotNil(payload?["memory_mb"])

        let frameTimes = payload?["frame_times"] as? [String: Any]
        let mapLoads = payload?["map_loads"] as? [String: Any]
        let memory = payload?["memory_mb"] as? [String: Any]
        XCTAssertEqual(frameTimes?["clock_source"] as? String, "mach_absolute_time")
        XCTAssertEqual(mapLoads?["clock_source"] as? String, "mach_absolute_time")
        XCTAssertNotNil(frameTimes?["p95_ms"])
        XCTAssertNotNil(mapLoads?["p95_ms"])
        XCTAssertNotNil(memory?["start"])
        XCTAssertNotNil(memory?["peak"])
        XCTAssertNotNil(memory?["end"])

        let frameSamples = frameTimes?["sample_count"] as? Int ?? 0
        let mapSamples = mapLoads?["transition_count"] as? Int ?? 0
        XCTAssertGreaterThan(frameSamples, 0)
        XCTAssertEqual(mapSamples, 10)

        let frameSamplesURL = directory.appendingPathComponent("frame-samples.json")
        let mapSamplesURL = directory.appendingPathComponent("map-load-samples.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: frameSamplesURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mapSamplesURL.path))

        let serialized = try JSONSerialization.data(withJSONObject: payload ?? [:], options: [])
        let text = String(data: serialized, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("sampled_at_runtime"))
    }
}
