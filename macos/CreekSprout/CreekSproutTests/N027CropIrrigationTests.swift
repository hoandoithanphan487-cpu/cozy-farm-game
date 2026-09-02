import Foundation
import XCTest
@testable import CreekSprout

final class N027CropCareTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let plot = GridPosition(x: 2, y: 3)

    func testFirstSecondAndThirdDrySettlementsPauseWiltThenWither() {
        var state = growingState(at: [plot])

        let first = CropCareService.settleCrops(state: &state, catalog: catalog)
        XCTAssertEqual(first.pausedPositions, [plot])
        XCTAssertEqual(state.cell(at: plot).dryStreak, 1)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .thirsty)
        XCTAssertEqual(state.cell(at: plot).stageProgressDays, 0)

        let second = CropCareService.settleCrops(state: &state, catalog: catalog)
        XCTAssertEqual(second.wiltedPositions, [plot])
        XCTAssertEqual(state.cell(at: plot).dryStreak, 2)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .wilted)
        XCTAssertEqual(CropCareService.sleepRisk(in: state).positions, [plot])

        let third = CropCareService.settleCrops(state: &state, catalog: catalog)
        XCTAssertEqual(third.witheredPositions, [plot])
        XCTAssertEqual(state.cell(at: plot).dryStreak, 3)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .withered)
        XCTAssertTrue(state.cell(at: plot).hasCrop, "A clearable remnant must remain.")
        XCTAssertFalse(state.cell(at: plot).readyToHarvest)
    }

    func testManualWaterClearsPressureAndResumesGrowth() {
        var state = growingState(at: [plot])
        state.farmCells[plot]?.dryStreak = 2
        state.farmCells[plot]?.cropCondition = .wilted

        let result = FarmActionService().apply(
            to: &state,
            target: plot,
            tool: .water,
            catalog: catalog
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(state.cell(at: plot).dryStreak, 0)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .healthy)
        XCTAssertTrue(state.cell(at: plot).wateredToday)

        let settled = CropCareService.settleCrops(state: &state, catalog: catalog)
        XCTAssertEqual(settled.grownPositions, [plot])
        XCTAssertEqual(state.cell(at: plot).stageProgressDays, 1)
        XCTAssertFalse(state.cell(at: plot).wateredToday)
    }

    func testRainAndCommunityCareClearPressureWithoutManufacturingCrops() {
        let empty = GridPosition(x: 3, y: 3)
        var state = growingState(at: [plot])
        state.farmCells[plot]?.dryStreak = 2
        state.farmCells[plot]?.cropCondition = .wilted
        state.farmCells[empty] = FarmCell(prepared: true)

        let rain = CropCoverageSummary(
            day: state.clock.day,
            records: [
                CropCoverageRecord(position: plot, source: .rain),
                CropCoverageRecord(position: empty, source: .rain),
            ]
        )
        let appliedRain = CropCareService.applyCoverage(to: &state, summary: rain)
        XCTAssertEqual(appliedRain.positions, [plot])
        XCTAssertEqual(state.cell(at: plot).dryStreak, 0)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .healthy)
        XCTAssertFalse(state.cell(at: empty).hasCrop)

        state.farmCells[plot]?.wateredToday = false
        state.farmCells[plot]?.dryStreak = 2
        state.farmCells[plot]?.cropCondition = .wilted
        state.storyCampaign.mission = mission(covering: [plot], status: .travelling)
        let community = CropCareService.previewCommunityCoverage(in: state, catalog: catalog)
        XCTAssertEqual(community.records, [CropCoverageRecord(position: plot, source: .communityCare)])
        CropCareService.applyCoverage(to: &state, summary: community)
        XCTAssertEqual(state.cell(at: plot).dryStreak, 0)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .healthy)
    }

    func testMatureCropIsImmuneToDryPressureAndExcludedFromSleepRisk() {
        var state = growingState(at: [plot])
        state.farmCells[plot]?.readyToHarvest = true
        state.farmCells[plot]?.cropStage = 2
        state.farmCells[plot]?.dryStreak = 2
        state.farmCells[plot]?.cropCondition = .wilted

        let settled = CropCareService.settleCrops(state: &state, catalog: catalog)
        XCTAssertEqual(settled.matureImmunePositions, [plot])
        XCTAssertEqual(state.cell(at: plot).dryStreak, 0)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .healthy)
        XCTAssertTrue(state.cell(at: plot).readyToHarvest)
        XCTAssertEqual(CropCareService.sleepRisk(in: state).count, 0)
    }

    func testWitheredRemnantCanBeClearedAndReplanted() {
        var state = growingState(at: [plot])
        state.farmCells[plot]?.dryStreak = 3
        state.farmCells[plot]?.cropCondition = .withered

        let cleared = FarmActionService().apply(
            to: &state,
            target: plot,
            tool: .hoe,
            catalog: catalog
        )
        XCTAssertTrue(cleared.isSuccess)
        XCTAssertEqual(cleared.event, "cleared_withered")
        XCTAssertFalse(state.cell(at: plot).hasCrop)
        XCTAssertTrue(state.cell(at: plot).prepared)
        XCTAssertEqual(state.cell(at: plot).dryStreak, 0)
        XCTAssertEqual(state.cell(at: plot).cropCondition, .healthy)
    }

    func testFarmCellIdentityRoundTripsOnlyCultivableCoordinates() {
        let rear = GridPosition(x: 8, y: 13)
        XCTAssertEqual(FarmCellIdentity.position(for: FarmCellIdentity.id(for: plot)), plot)
        XCTAssertEqual(FarmCellIdentity.position(for: FarmCellIdentity.id(for: rear)), rear)
        XCTAssertNil(FarmCellIdentity.position(for: "brookseed.farm_cell.x_9.y_13"))
        XCTAssertNil(FarmCellIdentity.position(for: "brookseed.farm_cell.bad"))
    }

    private func growingState(at positions: [GridPosition]) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = Dictionary(uniqueKeysWithValues: positions.map { position in
            (
                position,
                FarmCell(
                    prepared: true,
                    cropID: ContentID.mistRadishCrop,
                    cropStage: 0,
                    stageProgressDays: 0,
                    plantedDay: state.clock.day,
                    readyToHarvest: false
                )
            )
        })
        return state
    }

    private func mission(
        covering positions: [GridPosition],
        status: StoryMissionStatus
    ) -> StoryMissionSnapshot {
        StoryMissionSnapshot(
            campaignID: "brookseed.campaign.crop_care_test",
            missionInstanceID: "brookseed.story.mission.crop_care_test",
            startDay: 1,
            status: status,
            coveredCropCellIDs: positions.map(FarmCellIdentity.id(for:)).sorted(),
            protectedAnimalIDs: [],
            frozenOrderIDs: [],
            frozenDeadlineIDs: [],
            frozenOfferIDs: [],
            shippingEntries: [],
            checkpoint: .oldWaterway,
            settlementReceiptID: "brookseed.story.receipt.crop_care_test",
            canAbandonToProtection: true
        )
    }
}

final class N027IrrigationTests: XCTestCase {
    private let catalog = ContentCatalog.vs0
    private let service = IrrigationService()

    func testTemporaryCanalSelectsRealUnwateredGrowingCellsInStableXThenYOrder() {
        let eligible = [
            GridPosition(x: 4, y: 2),
            GridPosition(x: 1, y: 4),
            GridPosition(x: 1, y: 2),
            GridPosition(x: 3, y: 1),
            GridPosition(x: 2, y: 5),
        ]
        var state = restoredCanalState(growingAt: eligible)
        let alreadyWatered = GridPosition(x: 0, y: 1)
        let mature = GridPosition(x: 0, y: 2)
        state.farmCells[alreadyWatered] = growingCell(watered: true)
        state.farmCells[mature] = growingCell(ready: true)

        let preview = service.previewOvernightCoverage(state: state, catalog: catalog)
        XCTAssertEqual(service.activeTier(in: state), .temporary)
        XCTAssertEqual(
            preview.positions,
            [
                GridPosition(x: 1, y: 2),
                GridPosition(x: 1, y: 4),
                GridPosition(x: 2, y: 5),
                GridPosition(x: 3, y: 1),
            ]
        )
        XCTAssertTrue(preview.records.allSatisfy { $0.source == .temporaryCanal })

        let applied = service.applyOvernightCoverage(state: &state, catalog: catalog)
        XCTAssertEqual(applied, preview)
        XCTAssertEqual(state.storyMetrics.automaticWaterCellDays, 4)
        XCTAssertEqual(state.storyMetrics.temporaryCanalBenefitDays, [1])
        XCTAssertEqual(state.storyMetrics.automaticWaterSleepDays, [1])
        XCTAssertTrue(preview.positions.allSatisfy { state.cell(at: $0).wateredToday })
        XCTAssertFalse(state.cell(at: GridPosition(x: 4, y: 2)).wateredToday)
    }

    func testFormalCanalBeginsOnlyAfterQ01ResolvedAndCoversConfiguredEight() {
        let positions = (0..<9).map { GridPosition(x: $0, y: 2) }
        var state = restoredCanalState(growingAt: positions)
        setQ01Phase(.aftermath, in: &state)
        XCTAssertEqual(service.activeTier(in: state), .temporary)

        setQ01Phase(.resolved, in: &state)
        XCTAssertEqual(service.activeTier(in: state), .formal)
        let applied = service.applyOvernightCoverage(state: &state, catalog: catalog)
        XCTAssertEqual(applied.count, 8)
        XCTAssertTrue(applied.records.allSatisfy { $0.source == .formalCanal })
        XCTAssertEqual(state.storyMetrics.automaticWaterCellDays, 8)
        XCTAssertEqual(state.storyMetrics.formalCanalBenefitDays, [1])
        XCTAssertTrue(state.storyMetrics.temporaryCanalBenefitDays.isEmpty)
    }

    func testInactiveOrUnrestoredCanalNeverManufacturesCoverageOrMetrics() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = [GridPosition(x: 2, y: 2): growingCell()]
        let before = state
        XCTAssertEqual(service.previewOvernightCoverage(state: state, catalog: catalog).count, 0)
        XCTAssertEqual(service.applyOvernightCoverage(state: &state, catalog: catalog).count, 0)
        XCTAssertEqual(state, before)
    }

    func testSameDayRetryAndDTOReadbackAreExactlyOnce() throws {
        let positions = (0..<6).map { GridPosition(x: $0, y: 2) }
        var state = restoredCanalState(growingAt: positions)
        let first = service.applyOvernightCoverage(state: &state, catalog: catalog)
        XCTAssertEqual(first.count, 4)
        let afterFirst = state

        XCTAssertEqual(service.applyOvernightCoverage(state: &state, catalog: catalog).count, 0)
        XCTAssertEqual(state, afterFirst)

        let data = try JSONEncoder().encode(SaveGameDTO(state: state))
        var loaded = try JSONDecoder().decode(SaveGameDTO.self, from: data).makeState()
        XCTAssertEqual(service.applyOvernightCoverage(state: &loaded, catalog: catalog).count, 0)
        XCTAssertEqual(loaded.storyMetrics.automaticWaterCellDays, 4)
        XCTAssertEqual(loaded.storyMetrics.temporaryCanalBenefitDays, [1])
    }

    func testSleepPipelineAppliesCoverageBeforePressureAndRollsBackOnFailure() throws {
        let positions = (0..<6).map { GridPosition(x: $0, y: 2) }
        var state = restoredCanalState(growingAt: positions)
        let before = state
        let clock = ClockSystem()
        enum InjectedFailure: Error { case afterCoverage }

        XCTAssertThrowsError(
            try SleepUseCase().sleep(
                state: &state,
                clock: clock,
                catalog: catalog,
                stageObserver: { stage, candidate in
                    if stage == .overnightCoverageApplied {
                        XCTAssertEqual(candidate.storyMetrics.automaticWaterCellDays, 4)
                        XCTAssertEqual(candidate.farmCells.values.filter(\.wateredToday).count, 4)
                        throw InjectedFailure.afterCoverage
                    }
                }
            )
        )
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.clock.day, 1)
        XCTAssertFalse(clock.isPaused)
        XCTAssertEqual(state.storyMetrics.automaticWaterCellDays, 0)
        XCTAssertTrue(state.farmCells.values.allSatisfy { !$0.wateredToday })
    }

    func testSuccessfulSleepCountsOnlyActualCanalCellsAndLeavesManualFallback() throws {
        let positions = (0..<6).map { GridPosition(x: $0, y: 2) }
        var state = restoredCanalState(growingAt: positions)
        let manual = GridPosition(x: 0, y: 2)
        XCTAssertTrue(
            FarmActionService().apply(
                to: &state,
                target: manual,
                tool: .water,
                catalog: catalog
            ).isSuccess
        )

        var uncoveredBeforeRain = 0
        let summary = try SleepUseCase().sleep(
            state: &state,
            clock: ClockSystem(),
            catalog: catalog,
            stageObserver: { stage, candidate in
                if stage == .cropsAdvanced {
                    uncoveredBeforeRain = candidate.farmCells.values.filter {
                        $0.cropCondition == .thirsty
                    }.count
                }
            }
        )
        XCTAssertEqual(summary.previousDay, 1)
        XCTAssertEqual(state.clock.day, 2)
        XCTAssertEqual(state.storyMetrics.manualWaterCellDays, 1)
        XCTAssertEqual(state.storyMetrics.automaticWaterCellDays, 4)
        XCTAssertEqual(state.storyMetrics.temporaryCanalBenefitDays, [1])
        XCTAssertEqual(state.farmCells.values.filter { $0.stageProgressDays == 1 }.count, 5)
        XCTAssertEqual(uncoveredBeforeRain, 1, "Manual watering remains the fallback for uncovered cells.")
        XCTAssertEqual(state.farmCells.values.filter { $0.cropCondition == .thirsty }.count, 0)
        XCTAssertTrue(
            state.farmCells.values.allSatisfy { $0.dryStreak == 0 },
            "Day-two rain must immediately stabilize all growing crops."
        )
    }

    func testCustomDataDefinitionChangesCapacityWithoutChangingSelectionRules() {
        let positions = (0..<4).map { GridPosition(x: $0, y: 2) }
        var state = restoredCanalState(growingAt: positions)
        let custom = IrrigationService(
            definition: IrrigationDefinition(
                temporary: IrrigationTierDefinition(tier: .temporary, maximumCoveredCells: 2),
                formal: IrrigationTierDefinition(tier: .formal, maximumCoveredCells: 3)
            )
        )
        XCTAssertEqual(custom.applyOvernightCoverage(state: &state, catalog: catalog).count, 2)
        XCTAssertEqual(state.storyMetrics.automaticWaterCellDays, 2)
    }

    private func restoredCanalState(growingAt positions: [GridPosition]) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.farmCells = Dictionary(uniqueKeysWithValues: positions.map { ($0, growingCell()) })
        state.questLog.setStatus(.completed, for: ContentID.restoreOldCanalQuest)
        state.watershed = WatershedState(
            restorationPoints: 20,
            unlockedNodes: ContentID.watershedThresholdUnlockIDs.sorted(),
            completedProjects: [ContentID.canalSegmentProject],
            appliedContributionIDs: [
                ContentID.deliverCanalContribution,
                ContentID.placeCanalContribution,
            ].sorted()
        )
        return state
    }

    private func growingCell(watered: Bool = false, ready: Bool = false) -> FarmCell {
        FarmCell(
            prepared: true,
            wateredToday: watered,
            cropID: ContentID.mistRadishCrop,
            cropStage: ready ? 2 : 0,
            stageProgressDays: ready ? 3 : 0,
            plantedDay: 1,
            readyToHarvest: ready
        )
    }

    private func setQ01Phase(_ phase: StoryPhase, in state: inout GameState) {
        guard var segment = state.storyCampaign.segment(.q01) else {
            XCTFail("Missing Q01 segment")
            return
        }
        segment.phase = phase
        state.storyCampaign.updateSegment(segment)
    }
}
