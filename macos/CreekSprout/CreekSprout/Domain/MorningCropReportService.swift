import Foundation

struct MorningCropReportCellSnapshot: Equatable, Identifiable, Sendable {
    var position: GridPosition
    var cropID: String
    var cropName: String
    var dryStreak: Int
    var condition: CropCondition
    var coverageSources: [CropCoverageSource]

    var id: String {
        "brookseed.morning_report.cell_\(position.x)_\(position.y)"
    }

    var coordinateText: String {
        "(\(position.x), \(position.y))"
    }

    var coverageText: String {
        coverageSources
            .map(MorningCropReportService.coverageDisplayName)
            .joined(separator: "、")
    }
}

struct MorningCropReportSnapshot: Equatable, Sendable {
    var day: Int
    var weather: WeatherKind
    var requiredCells: [MorningCropReportCellSnapshot]
    var recommendedCells: [MorningCropReportCellSnapshot]
    var matureCells: [MorningCropReportCellSnapshot]
    var coveredCells: [MorningCropReportCellSnapshot]
    var estimatedMinimumStamina: Int
    var estimatedFullCareStamina: Int
    var safetyMessage: String

    var allDangerousCropsSafe: Bool {
        requiredCells.isEmpty
    }

    var accessibilitySummary: String {
        [
            "第 \(day) 天，天气\(weather.displayName)。",
            "必须处理 \(requiredCells.count) 格，建议处理 \(recommendedCells.count) 格，已成熟 \(matureCells.count) 格，已有覆盖 \(coveredCells.count) 格。",
            "保住危险作物预计至少需要 \(estimatedMinimumStamina) 点体力。",
            safetyMessage,
        ].joined(separator: " ")
    }
}

enum MorningCropReportPresentationTransition: Equatable, Sendable {
    case openedAutomatically(day: Int)
    case openedManually(day: Int)
    case closed(day: Int)
    case unchanged
}

/// This small value may live in a save or only in the current presentation
/// session. Persisting it prevents the same morning report from reopening
/// automatically after a same-day reload, while `reopen` remains available.
struct MorningCropReportSessionState: Equatable, Codable, Sendable {
    private(set) var lastAutomaticallyPresentedDay: Int?
    private(set) var visibleDay: Int?

    init(
        lastAutomaticallyPresentedDay: Int? = nil,
        visibleDay: Int? = nil
    ) {
        self.lastAutomaticallyPresentedDay = lastAutomaticallyPresentedDay
        self.visibleDay = visibleDay
    }

    var isPresented: Bool {
        visibleDay != nil
    }

    @discardableResult
    mutating func enterFarm(day: Int) -> MorningCropReportPresentationTransition {
        guard day > 0, lastAutomaticallyPresentedDay != day else {
            return .unchanged
        }
        lastAutomaticallyPresentedDay = day
        visibleDay = day
        return .openedAutomatically(day: day)
    }

    @discardableResult
    mutating func close(day: Int) -> MorningCropReportPresentationTransition {
        guard day > 0, visibleDay == day else {
            return .unchanged
        }
        visibleDay = nil
        return .closed(day: day)
    }

    @discardableResult
    mutating func reopen(day: Int) -> MorningCropReportPresentationTransition {
        guard day > 0, visibleDay != day else {
            return .unchanged
        }
        // A manual open satisfies today's first-entry presentation as well, so
        // entering the farm later that day does not show a duplicate modal.
        lastAutomaticallyPresentedDay = day
        visibleDay = day
        return .openedManually(day: day)
    }
}

struct CropSleepRiskToken: Equatable, Hashable, Codable, Identifiable, Sendable {
    let id: String
    fileprivate let generation: Int
    fileprivate let stateSignature: String
}

struct CropSleepRiskRequest: Equatable, Identifiable, Sendable {
    var token: CropSleepRiskToken
    var day: Int
    var cells: [MorningCropReportCellSnapshot]
    var consequence: String

    var id: String { token.id }

    var count: Int { cells.count }

    var positions: [GridPosition] { cells.map(\.position) }

    var positionText: String {
        positions.map { "(\($0.x), \($0.y))" }.joined(separator: "、")
    }

    var accessibilitySummary: String {
        "睡前风险确认。\(count) 格作物，格位 \(positionText)。\(consequence)"
    }
}

enum CropSleepRiskConfirmationResult: Equatable, Sendable {
    case authorized(CropSleepRiskRequest)
    case cancelled
    case stale
    case notPending
}

/// Owns one outstanding confirmation token. It never receives an `inout`
/// GameState or ClockSystem, so cancellation cannot advance time or mutate the
/// farm. Callers may invoke SleepUseCase only after `.authorized`.
struct CropSleepRiskConfirmationCoordinator: Equatable, Sendable {
    private(set) var activeRequest: CropSleepRiskRequest?
    private var generation: Int = 0

    @discardableResult
    mutating func issue(
        state: GameState,
        catalog: ContentCatalog,
        plannedCoverage: [CropCoverageSummary] = []
    ) -> CropSleepRiskRequest? {
        generation = generation == Int.max ? 1 : generation + 1
        let snapshot = MorningCropReportService.snapshot(
            state: state,
            catalog: catalog,
            plannedCoverage: plannedCoverage
        )
        activeRequest = MorningCropReportService.sleepRiskRequest(
            snapshot: snapshot,
            generation: generation
        )
        return activeRequest
    }

    @discardableResult
    mutating func cancel(token: CropSleepRiskToken) -> CropSleepRiskConfirmationResult {
        guard let activeRequest else {
            return .notPending
        }
        guard activeRequest.token == token else {
            return .stale
        }
        self.activeRequest = nil
        return .cancelled
    }

    @discardableResult
    mutating func confirm(
        token: CropSleepRiskToken,
        state: GameState,
        catalog: ContentCatalog,
        plannedCoverage: [CropCoverageSummary] = []
    ) -> CropSleepRiskConfirmationResult {
        guard let activeRequest else {
            return .notPending
        }
        guard activeRequest.token == token else {
            return .stale
        }

        let currentSnapshot = MorningCropReportService.snapshot(
            state: state,
            catalog: catalog,
            plannedCoverage: plannedCoverage
        )
        guard let currentRequest = MorningCropReportService.sleepRiskRequest(
            snapshot: currentSnapshot,
            generation: activeRequest.token.generation
        ), currentRequest == activeRequest else {
            self.activeRequest = nil
            return .stale
        }

        self.activeRequest = nil
        return .authorized(activeRequest)
    }
}

enum MorningCropReportService {
    static let safeMessage = "田里的作物都稳住了。"

    static func snapshot(
        state: GameState,
        catalog: ContentCatalog,
        plannedCoverage: [CropCoverageSummary] = []
    ) -> MorningCropReportSnapshot {
        let day = state.clock.day
        let weather = catalog.scenario.weather(on: day)
        let plannedSources = plannedSourcesByPosition(
            day: day,
            summaries: plannedCoverage
        )

        var required: [MorningCropReportCellSnapshot] = []
        var recommended: [MorningCropReportCellSnapshot] = []
        var mature: [MorningCropReportCellSnapshot] = []
        var covered: [MorningCropReportCellSnapshot] = []

        for position in state.farmCells.keys.sorted(by: positionComesBefore) {
            guard let cell = state.farmCells[position], cell.hasCrop else {
                continue
            }

            var sources = plannedSources[position] ?? []
            if weather == .rain, cell.isGrowingCrop {
                sources.append(.rain)
            }
            if cell.wateredToday, cell.isGrowingCrop, sources.isEmpty {
                sources.append(.manual)
            }
            sources = sortedUniqueSources(sources)

            let entry = MorningCropReportCellSnapshot(
                position: position,
                cropID: cell.cropID,
                cropName: cropName(cell.cropID, catalog: catalog),
                dryStreak: cell.dryStreak,
                condition: cell.cropCondition,
                coverageSources: sources
            )

            if cell.readyToHarvest, cell.cropCondition != .withered {
                mature.append(entry)
                continue
            }
            guard cell.isGrowingCrop else {
                continue
            }

            let isSafeTonight = cell.wateredToday || !sources.isEmpty
            if isSafeTonight {
                covered.append(entry)
            } else if cell.dryStreak == 2 {
                required.append(entry)
            } else {
                recommended.append(entry)
            }
        }

        let minimumStamina = staminaCost(forCellCount: required.count)
        let fullCareStamina = staminaCost(forCellCount: required.count + recommended.count)
        let safetyMessage = required.isEmpty
            ? safeMessage
            : "还有 \(required.count) 格作物今晚必须照料，否则会枯萎。"

        return MorningCropReportSnapshot(
            day: day,
            weather: weather,
            requiredCells: required,
            recommendedCells: recommended,
            matureCells: mature,
            coveredCells: covered,
            estimatedMinimumStamina: minimumStamina,
            estimatedFullCareStamina: fullCareStamina,
            safetyMessage: safetyMessage
        )
    }

    nonisolated static func coverageDisplayName(_ source: CropCoverageSource) -> String {
        switch source {
        case .manual:
            return "手工浇水"
        case .rain:
            return "雨水"
        case .temporaryCanal:
            return "临时水渠"
        case .formalCanal:
            return "正式水渠"
        case .communityCare:
            return "社区托管"
        }
    }

    fileprivate static func sleepRiskRequest(
        snapshot: MorningCropReportSnapshot,
        generation: Int
    ) -> CropSleepRiskRequest? {
        guard !snapshot.requiredCells.isEmpty else {
            return nil
        }
        let signature = riskSignature(snapshot)
        let digest = stableDigest(signature)
        let token = CropSleepRiskToken(
            id: "brookseed.sleep_risk.day_\(snapshot.day).request_\(generation).\(digest)",
            generation: generation,
            stateSignature: signature
        )
        return CropSleepRiskRequest(
            token: token,
            day: snapshot.day,
            cells: snapshot.requiredCells,
            consequence: "确认睡眠后，这些作物会在本次日结枯萎，并留下可清理的残株。"
        )
    }

    private static func plannedSourcesByPosition(
        day: Int,
        summaries: [CropCoverageSummary]
    ) -> [GridPosition: [CropCoverageSource]] {
        var result: [GridPosition: [CropCoverageSource]] = [:]
        for summary in summaries where summary.day == day {
            for record in summary.records {
                result[record.position, default: []].append(record.source)
            }
        }
        return result
    }

    private static func cropName(_ cropID: String, catalog: ContentCatalog) -> String {
        guard let crop = catalog.crop(id: cropID) else {
            return cropID
        }
        return catalog.displayName(forItemID: crop.harvestItemID)
    }

    nonisolated private static func positionComesBefore(_ lhs: GridPosition, _ rhs: GridPosition) -> Bool {
        lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
    }

    private static func sortedUniqueSources(
        _ sources: [CropCoverageSource]
    ) -> [CropCoverageSource] {
        var unique: [CropCoverageSource] = []
        for source in sources where !unique.contains(source) {
            unique.append(source)
        }
        return unique.sorted { sourceOrder($0) < sourceOrder($1) }
    }

    private static func sourceOrder(_ source: CropCoverageSource) -> Int {
        switch source {
        case .manual: return 0
        case .rain: return 1
        case .temporaryCanal: return 2
        case .formalCanal: return 3
        case .communityCare: return 4
        }
    }

    private static func staminaCost(forCellCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        let unit = FarmTool.water.staminaCost
        guard count <= Int.max / unit else { return Int.max }
        return count * unit
    }

    private static func riskSignature(_ snapshot: MorningCropReportSnapshot) -> String {
        let entries = snapshot.requiredCells.map { entry in
            "\(entry.position.x),\(entry.position.y),\(entry.cropID),\(entry.dryStreak),\(entry.condition.rawValue)"
        }
        return (["day=\(snapshot.day)"] + entries).joined(separator: "|")
    }

    private static func stableDigest(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16, uppercase: false)
    }
}
