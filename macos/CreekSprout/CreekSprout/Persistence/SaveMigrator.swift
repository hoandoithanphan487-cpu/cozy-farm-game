import Foundation

enum SaveMigrator {
    static func migrate(_ data: Data) throws -> SaveGameDTO {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard var json = jsonObject as? [String: Any] else {
            throw SaveStoreError.invalidContents
        }
        let version = integer(json["schema_version"]) ?? 0
        guard version <= SaveSchema.currentVersion else {
            throw SaveStoreError.unsupportedSchema
        }
        guard version >= 0 else {
            throw SaveStoreError.invalidContents
        }
        var from = version
        while from < SaveSchema.currentVersion {
            json = try migrateOnce(from: from, json: json)
            from += 1
        }
        json["schema_version"] = SaveSchema.currentVersion
        let migrated = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(SaveGameDTO.self, from: migrated)
    }

    private static func migrateOnce(from version: Int, json: [String: Any]) throws -> [String: Any] {
        switch version {
        case 0:
            return try migrateV0ToV1(json)
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
        next["stamina"] = integer(json["stamina"]) ?? 100
        next["inventoryCapacity"] = integer(json["inventoryCapacity"]) ?? 16
        next["inventory"] = try migrateInventory(json["inventory"])
        next["farmCells"] = json["farmCells"] ?? []
        next["schema_version"] = 1
        return next
    }

    private static func migrateInventory(_ value: Any?) throws -> [[String: Any]] {
        if let stacks = value as? [[String: Any]] {
            return stacks.map(remapSpikeItemID)
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

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? Int {
            return number
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}

enum SaveCodec {
    static func encode(_ state: GameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(SaveGameDTO(state: state))
    }

    static func decode(_ data: Data) throws -> GameState {
        try SaveMigrator.migrate(data).makeState()
    }
}
