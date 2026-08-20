import Foundation

#if os(macOS)
import Darwin
#endif

/// Monotonic wall clock for performance evidence (not game/simulation time).
enum PerformanceClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func monotonicSeconds() -> TimeInterval {
        let ticks = mach_absolute_time()
        let nanos = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000_000.0
    }
}

/// Rolling frame-time samples for NFR-001. Each sample is the monotonic wall-clock
/// duration of one paced frame's game work (`update` + stress intents), excluding
/// intentional idle sleep used to hold ~60 fps.
struct FrameTimeSampler: Sendable {
    private(set) var samplesMs: [Double] = []
    private var sessionStart: TimeInterval?
    private var warmupComplete = false
    private let warmupSeconds: TimeInterval

    init(warmupSeconds: TimeInterval = 60) {
        self.warmupSeconds = warmupSeconds
    }

    mutating func reset() {
        samplesMs.removeAll(keepingCapacity: true)
        sessionStart = nil
        warmupComplete = false
    }

    mutating func recordFrameDuration(seconds: TimeInterval) {
        let durationMs = seconds * 1000
        guard durationMs > 0, durationMs < 500 else { return }
        let now = PerformanceClock.monotonicSeconds()
        if sessionStart == nil {
            sessionStart = now
        }
        if !warmupComplete {
            if let start = sessionStart, now - start >= warmupSeconds {
                warmupComplete = true
                samplesMs.removeAll(keepingCapacity: true)
            }
            return
        }
        samplesMs.append(durationMs)
    }

    var postWarmupSampleCount: Int {
        samplesMs.count
    }

    func percentile(_ p: Double) -> Double? {
        guard !samplesMs.isEmpty else { return nil }
        let sorted = samplesMs.sorted()
        let rank = Int(ceil(p / 100.0 * Double(sorted.count))) - 1
        let index = min(max(rank, 0), sorted.count - 1)
        return sorted[index]
    }

    var p95Ms: Double? { percentile(95) }
    var p99Ms: Double? { percentile(99) }

    func summaryJSON(includeSamples: Bool = true) -> [String: Any] {
        var payload: [String: Any] = [
            "clock_source": "mach_absolute_time",
            "sample_count": samplesMs.count,
            "warmup_seconds": warmupSeconds,
            "measurement": "frame_work_ms_excluding_pacing_sleep",
            "p95_ms": p95Ms ?? NSNull(),
            "p99_ms": p99Ms ?? NSNull(),
            "mean_ms": samplesMs.isEmpty ? NSNull() : samplesMs.reduce(0, +) / Double(samplesMs.count),
        ]
        if includeSamples {
            payload["samples_ms"] = samplesMs
        }
        return payload
    }
}

/// Records map transition durations for NFR-002 using monotonic wall clock only.
struct MapLoadTimer: Sendable {
    private(set) var samplesMs: [Double] = []
    private var pendingStart: TimeInterval?

    mutating func reset() {
        samplesMs.removeAll(keepingCapacity: true)
        pendingStart = nil
    }

    mutating func beginLoad() {
        pendingStart = PerformanceClock.monotonicSeconds()
    }

    mutating func finishLoad() {
        guard let start = pendingStart else { return }
        pendingStart = nil
        let elapsed = (PerformanceClock.monotonicSeconds() - start) * 1000
        guard elapsed >= 0, elapsed < 30_000 else { return }
        samplesMs.append(elapsed)
    }

    mutating func cancelLoad() {
        pendingStart = nil
    }

    func percentile(_ p: Double) -> Double? {
        guard !samplesMs.isEmpty else { return nil }
        let sorted = samplesMs.sorted()
        let rank = Int(ceil(p / 100.0 * Double(sorted.count))) - 1
        let index = min(max(rank, 0), sorted.count - 1)
        return sorted[index]
    }

    var p95Ms: Double? { percentile(95) }

    func summaryJSON(includeSamples: Bool = true) -> [String: Any] {
        var payload: [String: Any] = [
            "clock_source": "mach_absolute_time",
            "transition_count": samplesMs.count,
            "p95_ms": p95Ms ?? NSNull(),
        ]
        if includeSamples {
            payload["samples_ms"] = samplesMs
        }
        return payload
    }
}

enum MemorySampler {
    static func residentSizeBytes() -> UInt64? {
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.resident_size
        #else
        return nil
        #endif
    }

    static func residentSizeMB() -> Double? {
        guard let bytes = residentSizeBytes() else { return nil }
        return Double(bytes) / (1024 * 1024)
    }
}

enum PerformanceEvidenceWriter {
    @discardableResult
    static func writeJSON(_ object: [String: Any], fileName: String, directory: URL, prettyPrinted: Bool = true) -> Bool {
        guard JSONSerialization.isValidJSONObject(object),
              let data = tryJSONSerializationData(object, prettyPrinted: prettyPrinted) else {
            return false
        }
        return writeData(data, fileName: fileName, directory: directory)
    }

    @discardableResult
    static func writeEncodable<T: Encodable>(_ value: T, fileName: String, directory: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return false
        }
        return writeData(data, fileName: fileName, directory: directory)
    }

    @discardableResult
    private static func writeData(_ data: Data, fileName: String, directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func tryJSONSerializationData(_ object: [String: Any], prettyPrinted: Bool) -> Data? {
        var options: JSONSerialization.WritingOptions = [.sortedKeys]
        if prettyPrinted {
            options.insert(.prettyPrinted)
        }
        return try? JSONSerialization.data(withJSONObject: object, options: options)
    }
}

/// Wall-clock stress driver: paces real `FarmScene.update()` frames and mixed intents.
enum PerformanceStressHarness {
    static func run(
        scene: FarmScene,
        warmupSeconds: TimeInterval,
        measureSeconds: TimeInterval,
        targetFrameInterval: TimeInterval = 1.0 / 60.0
    ) {
        scene.prepareForPerformanceMeasurement(warmupSeconds: warmupSeconds)
        let endTime = PerformanceClock.monotonicSeconds() + warmupSeconds + measureSeconds
        var lastFrameEnd = PerformanceClock.monotonicSeconds()
        var frameIndex = 0
        while PerformanceClock.monotonicSeconds() < endTime {
            let frameStart = PerformanceClock.monotonicSeconds()
            let frameTimestamp = frameStart
            scene.update(frameTimestamp)
            applyStressIntent(scene: scene, frameIndex: frameIndex)
            let frameEnd = PerformanceClock.monotonicSeconds()
            scene.recordPerformanceFrameDuration(frameEnd - frameStart)
            frameIndex += 1
            let nextFrame = lastFrameEnd + targetFrameInterval
            let idle = nextFrame - frameEnd
            if idle > 0 {
                Thread.sleep(forTimeInterval: idle)
            }
            lastFrameEnd = max(frameEnd, nextFrame)
        }
    }

    private static func applyStressIntent(scene: FarmScene, frameIndex: Int) {
        switch frameIndex % 3600 {
        case 3580:
            scene.sleepAndSettle()
        default:
            break
        }
        switch frameIndex % 1200 {
        case 1180:
            scene.stepPerformanceMapTravel()
        default:
            break
        }
        switch frameIndex % 60 {
        case 0: scene.tryMove(.up)
        case 1: scene.tryMove(.down)
        case 2: scene.tryMove(.left)
        case 3: scene.tryMove(.right)
        case 5: scene.selectTool(.hoe)
        case 6: scene.selectTool(.water)
        case 8: scene.selectTool(.harvest)
        case 10: scene.cycleRecipe()
        case 12: scene.craftSelectedRecipe()
        case 15: scene.performAction()
        case 18: scene.talkToNpc()
        case 20: _ = scene.hudText
        case 25: scene.cycleRecipe()
        case 30: scene.performAction()
        case 35: scene.performAction()
        case 40: scene.tryMove(.down)
        case 45: scene.performAction()
        case 50: scene.performAction()
        default: break
        }
    }
}
