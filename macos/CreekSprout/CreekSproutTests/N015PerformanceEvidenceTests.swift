import Foundation
import XCTest
@testable import CreekSprout

final class N015PerformanceEvidenceTests: XCTestCase {
    func testExportN015RuntimePerformanceEvidence() throws {
        let scene = FarmScene(size: CGSize(width: 1_920, height: 1_080))
        PerformanceStressHarness.run(scene: scene, warmupSeconds: 2, measureSeconds: 15)
        scene.runMapTransitionBenchmark(roundTrips: 5, preserveExistingSamples: true)

        guard let frameP95 = scene.frameTimeSampler.p95Ms,
              let frameP99 = scene.frameTimeSampler.p99Ms,
              let mapP95 = scene.mapTransitionTimer.p95Ms,
              let memoryStart = scene.perfMemorySamplesMB.first,
              let memoryEnd = scene.perfMemorySamplesMB.last,
              let memoryPeak = scene.perfMemorySamplesMB.max() else {
            return XCTFail("Performance harness did not produce the required measurements")
        }

        XCTAssertLessThanOrEqual(frameP95, 16.67)
        XCTAssertLessThanOrEqual(frameP99, 25.0)
        XCTAssertLessThan(mapP95, 3_000)
        XCTAssertLessThan(memoryEnd - memoryStart, 50)
        XCTAssertLessThan(memoryPeak - memoryStart, 80)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CreekSprout-n015-performance",
            isDirectory: true
        )
        XCTAssertTrue(scene.exportPerformanceEvidence(to: directory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("perf-summary.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("frame-samples.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("map-load-samples.json").path))
        print("[N015PerfExport] \(directory.path)")
    }
}
