import Foundation

struct WaterBorderVisual: Equatable, Sendable {
    var edgeKeys: [RuntimeArtKey]
    var cornerKeys: [RuntimeArtKey]
}

/// Deterministic presentation choices layered over the authoritative map.
/// These sets never participate in collision, spawning, exits, or save data.
enum WorldVisualCatalog {
    /// The product-owner demo crate is visually staged outside the legacy
    /// 10 x 6 placement grid. Keep its authoritative saved origin intact and
    /// move only this exact fixture's rendered node; user-placed crates keep
    /// rendering on their own saved cells.
    static let demoCrateDisplayCell = GridPosition(x: 10, y: 5)

    static func placedObjectDisplayCell(
        for placed: PlacedObjectState,
        mapID: String
    ) -> GridPosition {
        let isDemoCrate = mapID == ContentID.farmHomestead
            && placed.definitionID == ContentID.woodenCrateObject
            && placed.instanceID == "brookseed.placed.wooden_crate#7,4#down#n019-r8"
            && placed.origin == GridPosition(x: 7, y: 4)
        return isDemoCrate ? demoCrateDisplayCell : placed.origin
    }

    /// Presentation-only outlet where the market wharf meets the north edge
    /// of the creek. Authoritative water and collision cells stay intact.
    static let marketSluiceMouth = GridPosition(x: 3, y: 2)
    static let marketSluiceApron = GridPosition(x: 3, y: 3)

    /// Presentation-only channel tile beneath the transparent mouth of the
    /// farm waterworks. It visually bridges authoritative canal `(13,7)` into
    /// the building footprint without changing collision or saved topology.
    static let farmSluiceApron = GridPosition(x: 13, y: 8)

    /// One-cell-wide continuation from the authoritative east-west road to
    /// the newly opened rear field gate. It uses the same approved stone-path
    /// tile as the rest of the farm and changes no save schema.
    static let farmRearApproachPathCells: Set<GridPosition> = [
        GridPosition(x: 7, y: 8),
        GridPosition(x: 7, y: 9),
        GridPosition(x: 7, y: 10),
        GridPosition(x: 7, y: 11),
    ]

    /// Presentation-only service lanes on the farm. They turn the isolated
    /// creek-wood pickup and the 3x2 work yard into deliberate destinations
    /// connected to the existing east-west road. None of these cells affect
    /// collision, placement rules, exits, or saved map topology.
    static let farmServicePathCells: Set<GridPosition> = Set([
        GridPosition(x: 1, y: 6),
        GridPosition(x: 2, y: 6),
        GridPosition(x: 3, y: 6),
        GridPosition(x: 7, y: 4),
        GridPosition(x: 8, y: 4),
        GridPosition(x: 9, y: 4),
        GridPosition(x: 7, y: 5),
        GridPosition(x: 8, y: 5),
        GridPosition(x: 9, y: 5),
        GridPosition(x: 9, y: 6),
    ]).union(farmRearApproachPathCells)

    /// Starts neighbouring water cells on different source frames. This keeps
    /// the creek animated while avoiding an obvious repeated 24px highlight
    /// grid across a large body of water.
    static func waterAnimationKeys(at position: GridPosition) -> [RuntimeArtKey] {
        let frames = RuntimeArtCatalog.waterFrames
        guard !frames.isEmpty else { return [] }
        let phase = abs(position.x * 13 + position.y * 7) % frames.count
        return Array(frames[phase...]) + Array(frames[..<phase])
    }

    /// Offsets adjacent channel cells onto different first frames. The four
    /// approved frames already travel south; staggering them prevents a row
    /// of identical highlights from reading as repeated static stickers.
    static func canalAnimationKeys(at position: GridPosition) -> [RuntimeArtKey] {
        let frames = RuntimeArtCatalog.canalFlowFrames
        guard !frames.isEmpty else { return [] }
        let phase = ((position.y % frames.count) + frames.count) % frames.count
        return Array(frames[phase...]) + Array(frames[..<phase])
    }

    static func restoredWaterCells(mapID: String, restored: Bool) -> Set<GridPosition> {
        guard let map = WorldCatalog.maps[mapID] else { return [] }
        return Set(map.waterCells.map(\.cell))
    }

    /// The visible road includes the authoritative road, each building's
    /// threshold, and the farm service lanes above. Door thresholds are drawn
    /// underneath building art so transparent doorway pixels meet the road
    /// instead of revealing an unrelated grass square.
    static func presentationPathCells(mapID: String) -> Set<GridPosition> {
        guard let map = WorldCatalog.maps[mapID] else { return [] }
        var cells = map.pathCells
        cells.formUnion(map.buildings.map(\.door))
        if mapID == ContentID.farmHomestead {
            cells.formUnion(farmServicePathCells)
        }
        return cells
    }

    static func isStonePath(_ position: GridPosition, mapID: String) -> Bool {
        presentationPathCells(mapID: mapID).contains(position)
    }

    static func canalKey(at position: GridPosition, mapID: String, restored: Bool) -> RuntimeArtKey? {
        canalKeys(at: position, mapID: mapID, restored: restored).first
    }

    /// Presentation-only canal tiles. An NS canal that meets a stone path also
    /// draws the EW join so both orientations appear on the player path.
    static func canalKeys(at position: GridPosition, mapID: String, restored: Bool) -> [RuntimeArtKey] {
        guard let canal = WorldCatalog.maps[mapID]?.canalCells.first(where: { $0.cell == position }) else {
            return []
        }
        var keys: [RuntimeArtKey] = [canal.isNorthSouth ? .tileCanalNS : .tileCanalEW]
        if canal.isNorthSouth {
            let east = GridPosition(x: position.x + 1, y: position.y)
            let west = GridPosition(x: position.x - 1, y: position.y)
            if isStonePath(east, mapID: mapID) || isStonePath(west, mapID: mapID) {
                keys.append(.tileCanalEW)
            }
        }
        return keys
    }

    static func waterBorder(at position: GridPosition, mapID: String) -> WaterBorderVisual {
        guard let semantic = WorldCatalog.maps[mapID]?.waterCells.first(where: { $0.cell == position })?.semantic else {
            return WaterBorderVisual(edgeKeys: [], cornerKeys: [])
        }
        switch semantic {
        case .base: return WaterBorderVisual(edgeKeys: [], cornerKeys: [])
        case .edgeN: return WaterBorderVisual(edgeKeys: [.tileWaterEdgeN], cornerKeys: [])
        case .edgeE: return WaterBorderVisual(edgeKeys: [.tileWaterEdgeE], cornerKeys: [])
        case .edgeS: return WaterBorderVisual(edgeKeys: [.tileWaterEdgeS], cornerKeys: [])
        case .edgeW: return WaterBorderVisual(edgeKeys: [.tileWaterEdgeW], cornerKeys: [])
        case .cornerNE: return WaterBorderVisual(edgeKeys: [], cornerKeys: [.tileWaterCornerNE])
        case .cornerSE: return WaterBorderVisual(edgeKeys: [], cornerKeys: [.tileWaterCornerSE])
        case .cornerSW: return WaterBorderVisual(edgeKeys: [], cornerKeys: [.tileWaterCornerSW])
        case .cornerNW: return WaterBorderVisual(edgeKeys: [], cornerKeys: [.tileWaterCornerNW])
        }
    }

    static func sluiceConnectionKeys(at position: GridPosition, mapID: String) -> [RuntimeArtKey] {
        guard mapID == ContentID.creekMarket, position == marketSluiceMouth else { return [] }
        return [.tileCanalNS]
    }

    static func farmSluiceConnectionKeys(at position: GridPosition, mapID: String) -> [RuntimeArtKey] {
        guard mapID == ContentID.farmHomestead, position == farmSluiceApron else { return [] }
        return [.tileCanalNS]
    }

    /// Compatibility helper retained for deterministic presenter unit tests.
    static func waterBorder(at position: GridPosition, waterCells: Set<GridPosition>) -> WaterBorderVisual {
        guard waterCells.contains(position) else { return WaterBorderVisual(edgeKeys: [], cornerKeys: []) }
        let north = waterCells.contains(GridPosition(x: position.x, y: position.y + 1))
        let east = waterCells.contains(GridPosition(x: position.x + 1, y: position.y))
        let south = waterCells.contains(GridPosition(x: position.x, y: position.y - 1))
        let west = waterCells.contains(GridPosition(x: position.x - 1, y: position.y))
        let edges: [RuntimeArtKey] = [
            north ? nil : .tileWaterEdgeN,
            east ? nil : .tileWaterEdgeE,
            south ? nil : .tileWaterEdgeS,
            west ? nil : .tileWaterEdgeW,
        ].compactMap { $0 }
        let corners: [RuntimeArtKey] = [
            (!north && !east) ? .tileWaterCornerNE : nil,
            (!south && !east) ? .tileWaterCornerSE : nil,
            (!south && !west) ? .tileWaterCornerSW : nil,
            (!north && !west) ? .tileWaterCornerNW : nil,
        ].compactMap { $0 }
        return WaterBorderVisual(edgeKeys: edges, cornerKeys: corners)
    }
}
