import Foundation

enum CropCoverageSource: String, Equatable, Codable, Sendable {
    case manual
    case rain
    case temporaryCanal = "temporary_canal"
    case formalCanal = "formal_canal"
    case communityCare = "community_care"
}

struct CropCoverageRecord: Equatable, Codable, Sendable {
    var position: GridPosition
    var source: CropCoverageSource
}

struct CropCoverageSummary: Equatable, Codable, Sendable {
    var day: Int
    var records: [CropCoverageRecord]

    static func empty(day: Int) -> CropCoverageSummary {
        CropCoverageSummary(day: day, records: [])
    }

    var positions: [GridPosition] {
        records.map(\.position)
    }

    var count: Int {
        records.count
    }

    func merged(with other: CropCoverageSummary) -> CropCoverageSummary {
        guard day == other.day else { return self }
        var recordByPosition: [GridPosition: CropCoverageRecord] = [:]
        for record in records + other.records {
            if recordByPosition[record.position] == nil {
                recordByPosition[record.position] = record
            }
        }
        return CropCoverageSummary(
            day: day,
            records: recordByPosition.values.sorted(by: Self.positionOrder)
        )
    }

    nonisolated static func positionOrder(
        _ lhs: CropCoverageRecord,
        _ rhs: CropCoverageRecord
    ) -> Bool {
        CropCareService.positionOrder(lhs.position, rhs.position)
    }
}

struct CropPressureRiskRecord: Equatable, Sendable {
    var position: GridPosition
    var cropID: String
    var currentDryStreak: Int
    var predictedCondition: CropCondition
}

struct CropPressureRiskSummary: Equatable, Sendable {
    var day: Int
    var records: [CropPressureRiskRecord]

    var positions: [GridPosition] {
        records.map(\.position)
    }

    var count: Int {
        records.count
    }
}

struct CropCareSettlementSummary: Equatable, Sendable {
    var day: Int
    var grownPositions: [GridPosition]
    var pausedPositions: [GridPosition]
    var wiltedPositions: [GridPosition]
    var witheredPositions: [GridPosition]
    var matureImmunePositions: [GridPosition]
}

/// Stable finite identity used by Q08's mission snapshot. It deliberately
/// describes only a farm coordinate, never a FarmCell or GameState payload.
enum FarmCellIdentity {
    nonisolated static func id(for position: GridPosition) -> String {
        "brookseed.farm_cell.x_\(position.x).y_\(position.y)"
    }

    nonisolated static func position(for id: String) -> GridPosition? {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              String(parts[0]) == "brookseed",
              String(parts[1]) == "farm_cell",
              parts[2].hasPrefix("x_"),
              parts[3].hasPrefix("y_"),
              let x = Int(parts[2].dropFirst(2)),
              let y = Int(parts[3].dropFirst(2)) else {
            return nil
        }
        let position = GridPosition(x: x, y: y)
        let isLegacyField = (0..<10).contains(x) && (0..<6).contains(y)
        let isRearField = (x == 7 || x == 8) && (y == 12 || y == 13)
        return isLegacyField || isRearField ? position : nil
    }
}

enum CropCareService {
    nonisolated static func positionOrder(_ lhs: GridPosition, _ rhs: GridPosition) -> Bool {
        lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
    }

    /// Crops that will wither if the player confirms sleep without any of the
    /// displayed coverage sources. Mature and already-covered crops are safe.
    static func sleepRisk(in state: GameState) -> CropPressureRiskSummary {
        let records = state.farmCells
            .filter { _, cell in
                cell.isGrowingCrop && !cell.wateredToday && cell.dryStreak >= 2
            }
            .map { position, cell in
                CropPressureRiskRecord(
                    position: position,
                    cropID: cell.cropID,
                    currentDryStreak: cell.dryStreak,
                    predictedCondition: .withered
                )
            }
            .sorted { positionOrder($0.position, $1.position) }
        return CropPressureRiskSummary(day: state.clock.day, records: records)
    }

    /// Returns the finite set promised by an active Q08 community-care
    /// snapshot. Invalid/stale IDs, mature crops and already-watered crops are
    /// ignored rather than manufacturing coverage.
    static func previewCommunityCoverage(
        in state: GameState,
        catalog: ContentCatalog
    ) -> CropCoverageSummary {
        guard let mission = state.storyCampaign.mission,
              mission.status != .completed else {
            return .empty(day: state.clock.day)
        }
        let positions = mission.coveredCropCellIDs
            .compactMap(FarmCellIdentity.position(for:))
            .filter { position in
                guard let cell = state.farmCells[position] else { return false }
                return cell.isGrowingCrop
                    && !cell.wateredToday
                    && catalog.crop(id: cell.cropID) != nil
            }
            .sorted(by: positionOrder)
        return CropCoverageSummary(
            day: state.clock.day,
            records: positions.map {
                CropCoverageRecord(position: $0, source: .communityCare)
            }
        )
    }

    /// Captures coverage that was already applied by a source such as rain.
    /// This lets day-start weather clear an existing dry streak immediately
    /// while preserving `wateredToday` for the morning report and next sleep.
    static func currentWateredCoverage(
        in state: GameState,
        source: CropCoverageSource,
        catalog: ContentCatalog
    ) -> CropCoverageSummary {
        let positions = state.farmCells
            .filter { _, cell in
                cell.isGrowingCrop
                    && cell.wateredToday
                    && catalog.crop(id: cell.cropID) != nil
            }
            .map(\.key)
            .sorted(by: positionOrder)
        return CropCoverageSummary(
            day: state.clock.day,
            records: positions.map { CropCoverageRecord(position: $0, source: source) }
        )
    }

    /// Marks only real, non-withered crops. Coverage immediately clears the
    /// pressure counter; settlement later consumes `wateredToday` exactly once.
    @discardableResult
    static func applyCoverage(
        to state: inout GameState,
        summary: CropCoverageSummary
    ) -> CropCoverageSummary {
        guard summary.day == state.clock.day else {
            return .empty(day: state.clock.day)
        }
        var applied: [CropCoverageRecord] = []
        var seen = Set<GridPosition>()
        for record in summary.records.sorted(by: CropCoverageSummary.positionOrder) {
            guard seen.insert(record.position).inserted else { continue }
            guard var cell = state.farmCells[record.position],
                  cell.isGrowingCrop else {
                continue
            }
            cell.wateredToday = true
            cell.dryStreak = 0
            cell.cropCondition = .healthy
            state.farmCells[record.position] = cell
            applied.append(record)
        }
        return CropCoverageSummary(day: state.clock.day, records: applied)
    }

    /// Resolves one crop day after all manual, rain, canal and community-care
    /// coverage has been applied to the same candidate GameState.
    @discardableResult
    static func settleCrops(
        state: inout GameState,
        catalog: ContentCatalog
    ) -> CropCareSettlementSummary {
        var grown: [GridPosition] = []
        var paused: [GridPosition] = []
        var wilted: [GridPosition] = []
        var withered: [GridPosition] = []
        var matureImmune: [GridPosition] = []

        for position in state.farmCells.keys.sorted(by: positionOrder) {
            guard var cell = state.farmCells[position] else { continue }
            defer {
                cell.wateredToday = false
                state.farmCells[position] = cell
            }

            guard cell.hasCrop else {
                cell.dryStreak = 0
                cell.cropCondition = .healthy
                continue
            }
            if cell.readyToHarvest {
                cell.dryStreak = 0
                cell.cropCondition = .healthy
                matureImmune.append(position)
                continue
            }
            if cell.cropCondition == .withered {
                cell.dryStreak = 3
                continue
            }
            guard cell.wateredToday else {
                let nextDryStreak: Int
                if cell.dryStreak >= 3 {
                    nextDryStreak = 3
                } else {
                    nextDryStreak = cell.dryStreak + 1
                }
                cell.dryStreak = nextDryStreak
                switch nextDryStreak {
                case 1:
                    cell.cropCondition = .thirsty
                    paused.append(position)
                case 2:
                    cell.cropCondition = .wilted
                    wilted.append(position)
                default:
                    cell.cropCondition = .withered
                    withered.append(position)
                }
                continue
            }

            cell.dryStreak = 0
            cell.cropCondition = .healthy
            guard let crop = catalog.crop(id: cell.cropID) else { continue }
            if cell.stageProgressDays < Int.max {
                cell.stageProgressDays += 1
            }
            cell.cropStage = stage(for: crop, wateredDays: cell.stageProgressDays)
            cell.readyToHarvest = cell.cropStage >= crop.matureStageIndex
            grown.append(position)
        }

        return CropCareSettlementSummary(
            day: state.clock.day,
            grownPositions: grown,
            pausedPositions: paused,
            wiltedPositions: wilted,
            witheredPositions: withered,
            matureImmunePositions: matureImmune
        )
    }

    private static func stage(for crop: CropDefinition, wateredDays: Int) -> Int {
        var stage = 0
        var cumulativeDays = 0
        for (index, days) in crop.stageDays.enumerated() {
            let (next, overflow) = cumulativeDays.addingReportingOverflow(days)
            cumulativeDays = overflow ? Int.max : next
            if wateredDays >= cumulativeDays {
                stage = min(index + 1, crop.matureStageIndex)
            }
        }
        return stage
    }
}
