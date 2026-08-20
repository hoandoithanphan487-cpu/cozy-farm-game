import XCTest
@testable import CreekSprout

final class MapContentTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testTwoMapsHaveStableIDsNamesBoundsSpawnsAndBidirectionalExits() throws {
        try ContentValidator.validate(catalog)

        XCTAssertEqual(catalog.maps.count, 2)
        let farm = try XCTUnwrap(catalog.map(id: ContentID.farmHomestead))
        let market = try XCTUnwrap(catalog.map(id: ContentID.creekMarket))

        XCTAssertEqual(farm.displayName, "农场与农舍")
        XCTAssertEqual(farm.columns, 10)
        XCTAssertEqual(farm.rows, 6)
        XCTAssertEqual(farm.spawns.count, 2)
        XCTAssertEqual(farm.exits.count, 1)
        XCTAssertFalse(farm.landmarks.isEmpty)
        XCTAssertFalse(farm.blockedCells.isEmpty)

        XCTAssertEqual(market.displayName, "溪岸集市")
        XCTAssertEqual(market.columns, 10)
        XCTAssertEqual(market.rows, 8)
        XCTAssertEqual(market.spawns.count, 1)
        XCTAssertEqual(market.exits.count, 1)
        XCTAssertGreaterThanOrEqual(market.landmarks.count, 4)
        XCTAssertFalse(market.blockedCells.isEmpty)

        let farmExit = try XCTUnwrap(farm.exit(id: ContentID.farmToMarketExit))
        XCTAssertEqual(farmExit.destinationMapID, ContentID.creekMarket)
        XCTAssertNotNil(market.spawn(id: farmExit.destinationSpawnID))

        let marketExit = try XCTUnwrap(market.exit(id: ContentID.marketToFarmExit))
        XCTAssertEqual(marketExit.destinationMapID, ContentID.farmHomestead)
        XCTAssertNotNil(farm.spawn(id: marketExit.destinationSpawnID))
    }

    func testSevenNpcsHaveRequiredDialogueCountsAndPersonalities() throws {
        XCTAssertEqual(catalog.npcs.count, 7)

        let functionIDs = [
            ContentID.waterApprentice,
            ContentID.seedSteward,
            ContentID.creekWarden,
        ]
        let neighborIDs = [
            ContentID.neighborHearsay,
            ContentID.neighborStoryteller,
            ContentID.neighborEvidence,
            ContentID.neighborConsensus,
        ]
        XCTAssertEqual(
            Set(catalog.npcs.values.filter { $0.role == .questGiver }.map(\.id)),
            Set(functionIDs)
        )
        XCTAssertEqual(
            Set(catalog.npcs.values.filter { $0.role == .neighbor }.map(\.id)),
            Set(neighborIDs)
        )

        XCTAssertEqual(catalog.npc(id: ContentID.waterApprentice)?.displayName, "水工学徒")
        XCTAssertEqual(catalog.npc(id: ContentID.seedSteward)?.displayName, "种源管理员")
        XCTAssertEqual(catalog.npc(id: ContentID.creekWarden)?.displayName, "溪岸巡护员")
        XCTAssertEqual(catalog.npc(id: ContentID.neighborHearsay)?.displayName, "涧麦婶")
        XCTAssertEqual(catalog.npc(id: ContentID.neighborStoryteller)?.displayName, "石灯")
        XCTAssertEqual(catalog.npc(id: ContentID.neighborEvidence)?.displayName, "青砚")
        XCTAssertEqual(catalog.npc(id: ContentID.neighborConsensus)?.displayName, "絮宁")

        XCTAssertEqual(catalog.npc(id: ContentID.neighborHearsay)?.personalityArchetype, .helpfulHearsay)
        XCTAssertEqual(catalog.npc(id: ContentID.neighborStoryteller)?.personalityArchetype, .dramaticStoryteller)
        XCTAssertEqual(catalog.npc(id: ContentID.neighborEvidence)?.personalityArchetype, .evidenceMinded)
        XCTAssertEqual(catalog.npc(id: ContentID.neighborConsensus)?.personalityArchetype, .consensusFollower)

        for npcID in functionIDs {
            let npc = try XCTUnwrap(catalog.npc(id: npcID))
            XCTAssertEqual(npc.mapID, ContentID.creekMarket)
            let dialogue = try XCTUnwrap(catalog.dialogue(id: npc.dialoguePoolID))
            XCTAssertGreaterThanOrEqual(dialogue.lines.count, 3)
            XCTAssertLessThanOrEqual(dialogue.lines.count, 5)
        }
        for npcID in neighborIDs {
            let npc = try XCTUnwrap(catalog.npc(id: npcID))
            XCTAssertEqual(npc.mapID, ContentID.creekMarket)
            let dialogue = try XCTUnwrap(catalog.dialogue(id: npc.dialoguePoolID))
            XCTAssertGreaterThanOrEqual(dialogue.lines.count, 4)
            XCTAssertLessThanOrEqual(dialogue.lines.count, 6)
        }

        let teaching = try XCTUnwrap(catalog.dialogue(id: ContentID.waterApprenticeVs0Dialogue))
        XCTAssertEqual(teaching.lines.count, 3)
    }

    func testAllMapNpcAndDialogueReferencesResolve() throws {
        XCTAssertNoThrow(try ContentValidator.validate(catalog))
        for npc in catalog.npcs.values {
            XCTAssertNotNil(catalog.map(id: npc.mapID), npc.id)
            XCTAssertNotNil(catalog.dialogue(id: npc.dialoguePoolID), npc.id)
            XCTAssertTrue(ContentID.isValid(npc.id))
        }
        for map in catalog.maps.values {
            for exit in map.exits {
                XCTAssertNotNil(catalog.map(id: exit.destinationMapID), exit.id)
                XCTAssertNotNil(catalog.map(id: exit.destinationMapID)?.spawn(id: exit.destinationSpawnID), exit.id)
            }
        }
    }
}

final class MapTravelTests: XCTestCase {
    private let catalog = ContentCatalog.vs0

    func testPlayerCanTravelFarmToMarketAndBack() {
        var state = GameState.vs0NewGame(catalog: catalog)
        XCTAssertEqual(state.currentMapID, ContentID.farmHomestead)
        state.position = GridPosition(x: 5, y: 1)
        state.facing = .down
        let stepToExit = MapTravelService.tryMove(state: &state, direction: .down, catalog: catalog)
        XCTAssertTrue(stepToExit.didMove)
        XCTAssertFalse(stepToExit.didTravel)
        let toMarket = MapTravelService.interactWithExit(state: &state, catalog: catalog)
        XCTAssertTrue(toMarket?.didTravel == true)
        XCTAssertEqual(state.currentMapID, ContentID.creekMarket)
        XCTAssertEqual(state.position, GridPosition(x: 5, y: 1))
        XCTAssertTrue(WorldCatalog.creekMarket.contains(state.position))

        state.facing = .down
        let stepToReturn = MapTravelService.tryMove(state: &state, direction: .down, catalog: catalog)
        XCTAssertTrue(stepToReturn.didMove)
        let toFarm = MapTravelService.interactWithExit(state: &state, catalog: catalog)
        XCTAssertTrue(toFarm?.didTravel == true)
        XCTAssertEqual(state.currentMapID, ContentID.farmHomestead)
        XCTAssertEqual(state.position, GridPosition(x: 5, y: 2))
    }

    func testBlockedCellsRejectMovementAndSevenMarketNpcsAreApproachable() {
        var state = GameState.vs0NewGame(catalog: catalog)
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 5, y: 1)

        let blocked = MapTravelService.tryMove(state: &state, direction: .left, catalog: catalog)
        _ = blocked
        state.position = GridPosition(x: 1, y: 1)
        let intoWharf = MapTravelService.tryMove(state: &state, direction: .down, catalog: catalog)
        XCTAssertFalse(intoWharf.didMove)
        XCTAssertEqual(state.position, GridPosition(x: 1, y: 1))

        let npcs = MapTravelService.visibleNpcs(state: state, catalog: catalog)
        XCTAssertEqual(npcs.count, 7)
        XCTAssertEqual(Set(npcs.map(\.npcID)), Set(catalog.npcs.keys))

        for npc in npcs {
            state.position = GridPosition(x: npc.position.x, y: npc.position.y)
            XCTAssertEqual(MapTravelService.npc(atOrFacing: state, catalog: catalog)?.npcID, npc.npcID)
        }
    }

    func testMarketDialoguePausesClockWithoutChangingAuthoritativeState() {
        var state = GameState.vs0NewGame(catalog: catalog)
        let before = state
        let clock = ClockSystem()
        let npc = catalog.npc(id: ContentID.neighborHearsay)!
        let session = DialogueService.start(
            dialogueID: npc.dialoguePoolID,
            catalog: catalog,
            alreadyCompleted: false,
            clock: clock
        )
        XCTAssertEqual(session?.lines.count, 5)
        XCTAssertTrue(clock.containsPauseReason(.dialogue))
        XCTAssertEqual(clock.advance(state: &state, deltaSeconds: 10), 0)
        DialogueService.end(clock: clock)
        XCTAssertFalse(clock.containsPauseReason(.dialogue))
        XCTAssertEqual(state.tutorial, before.tutorial)
        XCTAssertEqual(state.economy, before.economy)
        XCTAssertGreaterThan(clock.advance(state: &state, deltaSeconds: 3), 0)
    }

    func testRepeatMarketTalkDoesNotAdvanceTutorial() {
        let state = GameState.vs0NewGame(catalog: catalog)
        let clock = ClockSystem()
        let npc = catalog.npc(id: ContentID.seedSteward)!
        XCTAssertNotNil(
            DialogueService.start(
                dialogueID: npc.dialoguePoolID,
                catalog: catalog,
                alreadyCompleted: false,
                clock: clock
            )
        )
        DialogueService.end(clock: clock)
        XCTAssertFalse(state.tutorial.talkedToWaterApprentice)
        XCTAssertEqual(state.tutorial.currentStepID, ContentID.tutorialHarvest)
        XCTAssertNotNil(
            DialogueService.start(
                dialogueID: npc.dialoguePoolID,
                catalog: catalog,
                alreadyCompleted: true,
                clock: clock
            )
        )
        DialogueService.end(clock: clock)
        XCTAssertFalse(state.tutorial.talkedToWaterApprentice)
        XCTAssertEqual(state.economy.balance, 720)
    }
}

final class MapSaveTests: XCTestCase {
    private var directory: URL!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-map-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testMarketPositionRoundTripsThroughSaveLoad() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        state.currentMapID = ContentID.creekMarket
        state.position = GridPosition(x: 5, y: 1)
        try store.save(state)

        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as! [String: Any]
        XCTAssertEqual((payload["schema_version"] as? NSNumber)?.intValue, SaveSchema.currentVersion)
        XCTAssertEqual(payload["current_map_id"] as? String, ContentID.creekMarket)

        let loaded = try store.load()
        XCTAssertEqual(loaded.currentMapID, ContentID.creekMarket)
        XCTAssertEqual(loaded.position, GridPosition(x: 5, y: 1))
        XCTAssertTrue(WorldCatalog.creekMarket.contains(loaded.position))
        XCTAssertEqual(loaded.economy.balance, 720)
    }

    func testV3SaveMigratesToFarmMap() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        var state = GameState.vs0NewGame(catalog: catalog)
        state.position = GridPosition(x: 5, y: 4)
        try store.save(state)
        var payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as! [String: Any]
        payload["schema_version"] = 3
        payload.removeValue(forKey: "current_map_id")
        let v3 = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try v3.write(to: store.primaryURL, options: .atomic)

        let migrated = try SaveMigrator.migrate(v3)
        XCTAssertEqual(migrated.schemaVersion, SaveSchema.currentVersion)
        XCTAssertEqual(migrated.currentMapID, ContentID.farmHomestead)
        XCTAssertEqual(migrated.watershed.restorationPoints, 0)
        let loaded = try store.load()
        XCTAssertEqual(loaded.currentMapID, ContentID.farmHomestead)
        XCTAssertTrue(WorldCatalog.farmHomestead.contains(loaded.position))
        XCTAssertEqual(loaded.economy.balance, 720)
        XCTAssertEqual(loaded.watershed.restorationPoints, 0)
        XCTAssertTrue(loaded.harvestedGatherNodeIDs.isEmpty)
    }

    func testUnknownMapIDIsRejected() throws {
        let store = SaveStore(directory: directory, catalog: catalog)
        try store.save(GameState.vs0NewGame(catalog: catalog))
        try? FileManager.default.removeItem(at: store.backupURL)
        var payload = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as! [String: Any]
        payload["current_map_id"] = "brookseed.map.not_real"
        let illegal = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try illegal.write(to: store.primaryURL, options: .atomic)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? SaveStoreError, .noValidSaveGeneration)
        }
    }
}

final class ContentValidationFailureTests: XCTestCase {
    func testDuplicateMapIDIsRejected() {
        var maps = WorldCatalog.mapList
        maps.append(maps[0])
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: maps,
                npcs: WorldCatalog.npcList,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("重复 ID"), reason)
        }
    }

    func testMissingDialogueReferenceIsRejected() {
        var npcs = WorldCatalog.npcList
        npcs[0].dialoguePoolID = "brookseed.dialogue.missing_pool"
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: WorldCatalog.mapList,
                npcs: npcs,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("缺失对白"), reason)
        }
    }

    func testSpawnOutOfBoundsIsRejected() {
        var farm = WorldCatalog.farmHomestead
        farm.spawns = [MapSpawnDefinition(id: ContentID.farmWakeSpawn, position: GridPosition(x: 99, y: 0))]
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: [farm, WorldCatalog.creekMarket],
                npcs: WorldCatalog.npcList,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("越界"), reason)
        }
    }

    func testOverlappingNpcsAreRejected() {
        var npcs = WorldCatalog.npcList
        npcs[1].position = npcs[0].position
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: WorldCatalog.mapList,
                npcs: npcs,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("重叠"), reason)
        }
    }

    func testNpcBlockingUniqueExitIsRejected() {
        var npcs = WorldCatalog.npcList
        npcs[0].position = WorldCatalog.creekMarket.exits[0].cell
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: WorldCatalog.mapList,
                npcs: npcs,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("阻断唯一出口") || reason.contains("出口"), reason)
        }
    }

    func testIllegalIDIsRejected() {
        var farm = WorldCatalog.farmHomestead
        farm.id = "not a valid id"
        XCTAssertThrowsError(
            try ContentValidator.validate(
                maps: [farm, WorldCatalog.creekMarket],
                npcs: WorldCatalog.npcList,
                dialogues: Array(ContentCatalog.vs0.dialogues.values)
            )
        ) { error in
            let reason = (error as? ContentValidationError)?.reason ?? ""
            XCTAssertTrue(reason.contains("非法"), reason)
        }
    }
}
