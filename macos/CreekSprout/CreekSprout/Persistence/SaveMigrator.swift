import Foundation

enum SaveMigrator {
    static func migrate(
        _ data: Data,
        context: SaveMigrationContext = .unspecified
    ) throws -> SaveGameDTO {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard var json = jsonObject as? [String: Any] else {
            throw SaveStoreError.invalidContents
        }
        let version = try schemaVersion(from: json)
        var from = version
        while from < SaveSchema.currentVersion {
            json = try migrateOnce(from: from, json: json, originalData: data, context: context)
            from += 1
        }
        json["schema_version"] = SaveSchema.currentVersion
        let migrated = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(SaveGameDTO.self, from: migrated)
    }

    private static func migrateOnce(
        from version: Int,
        json: [String: Any],
        originalData: Data,
        context: SaveMigrationContext
    ) throws -> [String: Any] {
        switch version {
        case 0:
            return try migrateV0ToV1(json)
        case 1:
            return try migrateV1ToV2(json)
        case 2:
            return try migrateV2ToV3(json)
        case 3:
            return try migrateV3ToV4(json)
        case 4:
            return try migrateV4ToV5(json)
        case 5:
            return try migrateV5ToV6(json)
        case 6:
            return try migrateV6ToV7(json)
        case 7:
            return try migrateV7ToV8(json)
        case 8:
            return try migrateV8ToV9(json)
        case 9:
            return try migrateV9ToV10(json, originalData: originalData, context: context)
        default:
            throw SaveStoreError.unsupportedSchema
        }
    }

    /// Unversioned Swift spike / first M1-002 documents. Godot saves are not migrated.
    private static func migrateV0ToV1(_ json: [String: Any]) throws -> [String: Any] {
        guard json["position"] is [String: Any], json["clock"] is [String: Any] else {
            throw SaveStoreError.invalidContents
        }
        var next = json
        next["facing"] = json["facing"] ?? Direction.down.rawValue
        next["stamina"] = try jsonInteger(in: json, key: "stamina", default: 100)
        next["inventoryCapacity"] = try jsonInteger(in: json, key: "inventoryCapacity", default: 16)
        next["inventory"] = try migrateInventory(json["inventory"])
        next["farmCells"] = json["farmCells"] ?? []
        next["schema_version"] = 1
        return next
    }

    /// M1-002 v1 saves have no economy. Inject VS-0 starting funds and an auditable grant.
    private static func migrateV1ToV2(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["scenario_id"] == nil {
            next["scenario_id"] = ContentID.vs0Scenario
        }
        if next["placed_objects"] == nil {
            next["placed_objects"] = []
        }
        if next["economy"] == nil {
            let day = try clockDay(from: json)
            next["economy"] = [
                "balance": 720,
                "shipping": [
                    "pending_entries": [],
                ],
                "settlement_history": [],
                "ledger": [
                    [
                        "reason_id": ContentID.migrationGrantReason,
                        "amount": 720,
                        "source_ref": "save.migrator.v1_to_v2",
                        "day_index": day,
                    ],
                ],
            ]
        }
        next["schema_version"] = 2
        return next
    }

    /// M2-001 v2 saves have no tutorial. Start at the first teaching step.
    private static func migrateV2ToV3(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["tutorial"] == nil {
            next["tutorial"] = [
                "current_step_id": ContentID.tutorialHarvest,
                "completed_step_ids": [],
                "harvest_count": 0,
                "talked_to_water_apprentice": false,
                "did_manual_save": false,
            ]
        }
        next["schema_version"] = 3
        return next
    }

    /// M2-002 v3 saves have no map. Default to the farm homestead.
    private static func migrateV3ToV4(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["current_map_id"] == nil {
            next["current_map_id"] = ContentID.farmHomestead
        }
        next["schema_version"] = 4
        return next
    }

    /// M3-001 v4 saves have no watershed, quest log, or harvested gather nodes.
    private static func migrateV4ToV5(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["watershed"] == nil {
            next["watershed"] = [
                "restoration_points": 0,
                "unlocked_nodes": [],
                "completed_projects": [],
                "applied_contribution_ids": [],
            ]
        }
        if next["quest_log"] == nil {
            next["quest_log"] = [
                "entries": [],
            ]
        }
        if next["harvested_gather_node_ids"] == nil {
            next["harvested_gather_node_ids"] = []
        }
        next["schema_version"] = 5
        return next
    }

    /// M3-003 v5 saves predate the community event system. They get the legal
    /// new-game defaults: neutral standing from content, no neighbour records,
    /// no gossip events and no trust. The day-start pass then offers the
    /// scripted event normally, so an old save is never soft-locked.
    private static func migrateV5ToV6(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["community"] == nil {
            next["community"] = [
                "standing": CommunityCatalog.balance.newGameStanding,
                "neighbor_states": [],
                "active_events": [],
                "event_history": [],
            ]
        }
        if next["relationships"] == nil {
            next["relationships"] = [
                "trust": [],
                "effects": [],
            ]
        }
        next["schema_version"] = 6
        return next
    }

    /// D0-002 v6 saves have no settings snapshot. Inject legal defaults.
    private static func migrateV6ToV7(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["settings"] == nil {
            next["settings"] = defaultSettingsJSON()
        }
        next["schema_version"] = 7
        return next
    }

    /// M4-001 v7 saves have no crafting selection. Default to first available at load time.
    private static func migrateV7ToV8(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        if next["selected_recipe_id"] == nil {
            next["selected_recipe_id"] = NSNull()
        }
        next["schema_version"] = 8
        return next
    }

    /// N-022 v8 saves have no livestock roster or cat-shop transaction state.
    /// Every legacy save receives the same small starter herd; no currency is
    /// granted and the cat-shop receipt history starts empty.
    private static func migrateV8ToV9(_ json: [String: Any]) throws -> [String: Any] {
        var next = json
        let day = try clockDay(from: json)
        if next["livestock"] == nil {
            next["livestock"] = try encodableJSONObject(
                LivestockCatalog.starterHerd(startDay: day)
            )
        }
        if next["cat_shop"] == nil {
            next["cat_shop"] = try encodableJSONObject(CatShopState.empty)
        }
        next["schema_version"] = 9
        return next
    }

    /// N-027 v9 saves have no campaign ownership, story history, or crop-care
    /// pressure. Migration is intentionally neutral: it never infers story
    /// progress from inventory, receipts, relationships, or current crops.
    private static func migrateV9ToV10(
        _ json: [String: Any],
        originalData: Data,
        context: SaveMigrationContext
    ) throws -> [String: Any] {
        var next = json
        let campaignID = CampaignIdentity.legacy(data: originalData, context: context)
        next["campaign_id"] = campaignID
        next["generation_metadata"] = try encodableJSONObject(
            SaveGenerationMetadata.neutral(
                campaignID: campaignID,
                sourceSlotName: context.sourceSlotName
            )
        )
        next["story_campaign"] = try encodableJSONObject(StoryCampaignState.newGame)
        next["story_metrics"] = try encodableJSONObject(StoryMetricsState.empty)
        if var records = next["farmCells"] as? [[String: Any]] {
            for index in records.indices {
                records[index]["dryStreak"] = 0
                records[index]["cropCondition"] = CropCondition.healthy.rawValue
            }
            next["farmCells"] = records
        }
        next["schema_version"] = 10
        return next
    }

    private static func encodableJSONObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func defaultSettingsJSON() -> [String: Any] {
        let defaults = SettingsState.defaults
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(defaults),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func clockDay(from json: [String: Any]) throws -> Int {
        guard let clock = json["clock"] as? [String: Any] else {
            throw SaveStoreError.invalidContents
        }
        return try jsonInteger(in: clock, key: "day", default: 1)
    }

    private static func migrateInventory(_ value: Any?) throws -> [[String: Any]] {
        if let stacks = value as? [[String: Any]] {
            return stacks.map { stack in
                remapSpikeItemID(stack)
            }
        }
        if let stack = value as? [String: Any] {
            return [remapSpikeItemID(stack)]
        }
        throw SaveStoreError.invalidContents
    }

    private static func remapSpikeItemID(_ stack: [String: Any]) -> [String: Any] {
        var next = stack
        if let itemID = stack["itemID"] as? String {
            next["itemID"] = Self.spikeItemIDs[itemID] ?? itemID
        }
        return next
    }

    private static let spikeItemIDs = [
        "mist_radish_seed": ContentID.mistRadishSeed,
        "mist_radish": ContentID.mistRadishItem,
    ]

    private static func schemaVersion(from json: [String: Any]) throws -> Int {
        guard let raw = json["schema_version"] else {
            return 0
        }
        let version = try losslessJSONInteger(raw)
        guard version >= 0 else {
            throw SaveStoreError.invalidContents
        }
        guard version <= SaveSchema.currentVersion else {
            throw SaveStoreError.unsupportedSchema
        }
        return version
    }

    private static func jsonInteger(in json: [String: Any], key: String, default defaultValue: Int) throws -> Int {
        guard let raw = json[key] else {
            return defaultValue
        }
        return try losslessJSONInteger(raw)
    }

    /// JSONSerialization boxes JSON numbers and bools as NSNumber. Only finite,
    /// fractionless values in the Int range are accepted; CFBoolean is rejected.
    private static func losslessJSONInteger(_ value: Any) throws -> Int {
        guard let number = value as? NSNumber else {
            throw SaveStoreError.invalidContents
        }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
            throw SaveStoreError.invalidContents
        }
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite, doubleValue.rounded(.towardZero) == doubleValue else {
            throw SaveStoreError.invalidContents
        }
        guard let intValue = Int(exactly: doubleValue) else {
            throw SaveStoreError.invalidContents
        }
        return intValue
    }
}

enum SaveCodec {
    static func encode(
        _ state: GameState,
        generationMetadata: SaveGenerationMetadata? = nil
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(
            SaveGameDTO(state: state, generationMetadata: generationMetadata)
        )
    }

    static func decode(
        _ data: Data,
        catalog: ContentCatalog = .vs0,
        context: SaveMigrationContext = .unspecified
    ) throws -> GameState {
        try decodeGeneration(data, catalog: catalog, context: context).state
    }

    static func decodeGeneration(
        _ data: Data,
        catalog: ContentCatalog = .vs0,
        context: SaveMigrationContext = .unspecified
    ) throws -> SaveGeneration {
        let dto = try SaveMigrator.migrate(data, context: context)
        var state = try dto.makeState()
        try SavePositionRelocator.relocateIfNeeded(state: &state, catalog: catalog)
        return SaveGeneration(state: state, metadata: dto.generationMetadata)
    }
}

/// N-015 keeps schema v8 and repairs only the decoded world position. The
/// ordering is deliberately stable so the same legacy save always chooses the
/// same nearest safe cell: Manhattan distance, then y, then x.
enum SavePositionRelocator {
    static func relocateIfNeeded(state: inout GameState, catalog: ContentCatalog) throws {
        guard let map = catalog.map(id: state.currentMapID) else {
            throw SaveStoreError.invalidContents
        }
        let occupiedByNPC = npcOccupiedCells(mapID: map.id, catalog: catalog)
        if isSafe(state.position, in: map, occupiedByNPC: occupiedByNPC) {
            return
        }

        let origin = state.position
        let candidates = (0..<map.rows).flatMap { row in
            (0..<map.columns).map { column in GridPosition(x: column, y: row) }
        }.filter { isSafe($0, in: map, occupiedByNPC: occupiedByNPC) }
        guard let nearest = candidates.min(by: { lhs, rhs in
            let leftDistance = abs(lhs.x - origin.x) + abs(lhs.y - origin.y)
            let rightDistance = abs(rhs.x - origin.x) + abs(rhs.y - origin.y)
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }) else {
            throw SaveStoreError.invalidContents
        }
        state.position = nearest
    }

    private static func isSafe(
        _ position: GridPosition,
        in map: MapDefinition,
        occupiedByNPC: Set<GridPosition>
    ) -> Bool {
        map.contains(position)
            && !map.isBlocked(position)
            && !occupiedByNPC.contains(position)
    }

    private static func npcOccupiedCells(mapID: String, catalog: ContentCatalog) -> Set<GridPosition> {
        if mapID == ContentID.farmHomestead {
            return Set(catalog.scenario.startingNpcSpawns.map(\.position))
        }
        return Set(WorldCatalog.npcList.filter { $0.mapID == mapID }.map(\.position))
    }
}
