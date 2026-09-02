import Foundation

// MARK: - Blocking scene kind (world-grid vs journey-local)

enum BlockingSceneKind: Equatable, Sendable {
    case worldGrid(mapID: String)
    case journeyLocal(sceneID: String)

    var label: String {
        switch self {
        case let .worldGrid(mapID): return "world_grid:\(mapID)"
        case let .journeyLocal(sceneID): return "journey_local:\(sceneID)"
        }
    }
}

struct ResolvedBlockingAnchor: Equatable, Sendable {
    var anchorID: String
    var definition: StoryAnchorDefinition
    var sceneID: String?

    static func resolve(
        _ anchorID: String,
        catalog: StoryContentCatalog
    ) -> ResolvedBlockingAnchor? {
        guard let definition = catalog.anchor(id: anchorID) else { return nil }
        return ResolvedBlockingAnchor(
            anchorID: anchorID,
            definition: definition,
            sceneID: definition.sceneID
        )
    }
}

/// Machine-readable per-anchor check result used by path-clearance evidence.
struct StoryAnchorCheck: Equatable, Sendable {
    var anchorID: String
    var kind: String
    var resolved: Bool
    var walkable: Bool?
    var inBounds: Bool?
    var collisionFree: Bool?
    var pairedOK: Bool?
    var issues: [String]
}

struct StoryBlockingClearance: Equatable, Sendable {
    enum Verdict: String, Equatable, Sendable {
        case pass = "pass"
        case blocked = "blocked"
    }

    var verdict: Verdict
    var issues: [String]
    var anchorChecks: [StoryAnchorCheck]

    static let pass = StoryBlockingClearance(verdict: .pass, issues: [], anchorChecks: [])
}

/// A cue resolved into an executable plan. World-grid cues use N-015 map
/// topology; journey-local cues use scene-local normalized coordinates.
struct StoryBlockingPlan: Equatable, Sendable {
    var cue: StoryBlockingCueDefinition
    var sceneKind: BlockingSceneKind
    var entry: ResolvedBlockingAnchor
    var npcStarts: [String: ResolvedBlockingAnchor]
    var playerWaypoints: [ResolvedBlockingAnchor]
    var interaction: ResolvedBlockingAnchor
    var crossingOrInterrupt: StoryCrossingOrInterruptDefinition
    var branchMovements: [String: [ResolvedBlockingAnchor]]
    var npcExits: [String: ResolvedBlockingAnchor]
    var temporarilyBlockedCells: [StoryTemporaryBlockedCell]
    var revealCameraOrProp: StoryRevealCameraOrPropDefinition
    var speakerCount: Int
    var clearance: StoryBlockingClearance
}

enum StoryBlockingResolutionError: Equatable, Error, Sendable {
    case unknownCue(String)
    case anchorNotFound(String)
    case sceneMismatch(String)
    case worldJourneyConflict(String)
    case missingEntry(String)
    case missingInteraction(String)
    case emptyWaypoints(String)
    case emptyNPCPlacement(String)
    case journeySceneUnknown(String)
}

/// Resolves blocking cues into plans with split world-grid / journey-local
/// validation. Pure and deterministic; used by both the runtime and the
/// path-clearance evidence generator.
enum StoryBlockingResolver {
    static func resolveAll(
        catalog: StoryContentCatalog = .shared,
        maps: [String: MapDefinition] = WorldCatalog.maps
    ) -> [StoryBlockingPlan] {
        catalog.blockingCues.compactMap { cue in
            try? resolve(cueID: cue.id, catalog: catalog, maps: maps).get()
        }
    }

    static func resolve(
        cueID: String,
        catalog: StoryContentCatalog = .shared,
        maps: [String: MapDefinition] = WorldCatalog.maps
    ) -> Result<StoryBlockingPlan, StoryBlockingResolutionError> {
        guard let cue = catalog.blockingCue(id: cueID) else {
            return .failure(.unknownCue(cueID))
        }
        let sceneKind: BlockingSceneKind
        if catalog.journeyScene(id: cue.sceneID) != nil {
            sceneKind = .journeyLocal(sceneID: cue.sceneID)
        } else if maps[cue.sceneID] != nil {
            sceneKind = .worldGrid(mapID: cue.sceneID)
        } else {
            return .failure(.sceneMismatch(cue.sceneID))
        }

        var checks: [StoryAnchorCheck] = []
        var issues: [String] = []

        /// `strictSceneMatch` applies to anchors that must live in the cue's
        /// own scene (entry, interaction, main waypoints, NPC placement).
        /// Branch waypoints are route checkpoints: they are validated in
        /// their own map/scene but may cross scenes (Q08 routes, Q10 leave).
        func resolveOne(
            _ anchorID: String,
            purpose: StoryAnchorPurpose,
            strictSceneMatch: Bool
        ) -> Result<ResolvedBlockingAnchor, StoryBlockingResolutionError> {
            guard let anchor = ResolvedBlockingAnchor.resolve(anchorID, catalog: catalog) else {
                return .failure(.anchorNotFound(anchorID))
            }
            let check = checkAnchor(
                anchor: anchor,
                sceneKind: sceneKind,
                purpose: purpose,
                strictSceneMatch: strictSceneMatch,
                catalog: catalog,
                maps: maps
            )
            checks.append(check)
            if !check.resolved || !check.issues.isEmpty {
                issues.append("\(anchorID): \(check.issues.joined(separator: "；"))")
            }
            return .success(anchor)
        }

        let entry: ResolvedBlockingAnchor
        switch resolveOne(cue.entryAnchor, purpose: .entry, strictSceneMatch: true) {
        case .success(let anchor): entry = anchor
        case .failure(let error): return .failure(error)
        }

        var npcStarts: [String: ResolvedBlockingAnchor] = [:]
        for (npcID, anchorID) in cue.npcStartAnchors {
            switch resolveOne(anchorID, purpose: .npcStart, strictSceneMatch: true) {
            case .success(let anchor): npcStarts[npcID] = anchor
            case .failure(let error): return .failure(error)
            }
        }
        guard !npcStarts.isEmpty else {
            return .failure(.emptyNPCPlacement(cueID))
        }

        var waypoints: [ResolvedBlockingAnchor] = []
        for anchorID in cue.playerWaypoints {
            switch resolveOne(anchorID, purpose: .playerWaypoint, strictSceneMatch: true) {
            case .success(let anchor): waypoints.append(anchor)
            case .failure(let error): return .failure(error)
            }
        }
        guard !waypoints.isEmpty else {
            return .failure(.emptyWaypoints(cueID))
        }

        let interaction: ResolvedBlockingAnchor
        switch resolveOne(cue.interactionAnchor, purpose: .interaction, strictSceneMatch: true) {
        case .success(let anchor): interaction = anchor
        case .failure(let error): return .failure(error)
        }

        var branchMovements: [String: [ResolvedBlockingAnchor]] = [:]
        for (branchID, anchorIDs) in cue.branchMovement {
            var resolved: [ResolvedBlockingAnchor] = []
            for anchorID in anchorIDs {
                switch resolveOne(anchorID, purpose: .playerWaypoint, strictSceneMatch: false) {
                case .success(let anchor): resolved.append(anchor)
                case .failure(let error): return .failure(error)
                }
            }
            branchMovements[branchID] = resolved
        }

        var npcExits: [String: ResolvedBlockingAnchor] = [:]
        for (npcID, anchorID) in cue.npcExitAnchors {
            switch resolveOne(anchorID, purpose: .npcExit, strictSceneMatch: true) {
            case .success(let anchor): npcExits[npcID] = anchor
            case .failure(let error): return .failure(error)
            }
        }
        if Set(npcStarts.keys) != Set(npcExits.keys) {
            issues.append("NPC 入退场集合不一致")
        }

        if case .journeyLocal = sceneKind {
            if let crossing = cue.crossingOrInterrupt.destinationSceneID,
               catalog.journeyScene(id: crossing) == nil {
                issues.append("穿越目标场景不存在：\(crossing)")
            }
        }
        if case let .worldGrid(mapID) = sceneKind {
            let map = maps[mapID] ?? MapDefinition(
                id: mapID,
                nameKey: mapID,
                displayName: mapID,
                columns: 0,
                rows: 0,
                blockedCells: [],
                landmarks: [],
                spawns: [],
                exits: []
            )
            for blocked in cue.temporarilyBlockedCells {
                if blocked.mapID != mapID {
                    issues.append("临时阻挡格地图不匹配：\(blocked.mapID)")
                    continue
                }
                if !map.contains(blocked.cell) {
                    issues.append("临时阻挡格越界：\(blocked.cell)")
                    continue
                }
                if map.pathCells.contains(blocked.cell) {
                    issues.append("临时阻挡格占用主路：\(blocked.cell)")
                }
                if map.buildings.contains(where: {
                    $0.door == blocked.cell
                        || $0.interactionCells.contains(blocked.cell)
                }) {
                    issues.append("临时阻挡格占用门/交互位：\(blocked.cell)")
                }
                if map.exits.contains(where: { $0.cell == blocked.cell }) {
                    issues.append("临时阻挡格占用出口：\(blocked.cell)")
                }
            }
        }

        let speakerCount = speakerCount(for: cue, catalog: catalog)
        let clearance = StoryBlockingClearance(
            verdict: issues.isEmpty ? .pass : .blocked,
            issues: Array(Set(issues)).sorted(),
            anchorChecks: checks
        )
        return .success(StoryBlockingPlan(
            cue: cue,
            sceneKind: sceneKind,
            entry: entry,
            npcStarts: npcStarts,
            playerWaypoints: waypoints,
            interaction: interaction,
            crossingOrInterrupt: cue.crossingOrInterrupt,
            branchMovements: branchMovements,
            npcExits: npcExits,
            temporarilyBlockedCells: cue.temporarilyBlockedCells,
            revealCameraOrProp: cue.revealCameraOrProp,
            speakerCount: speakerCount,
            clearance: clearance
        ))
    }

    // MARK: - Per-anchor checks

    static func checkAnchor(
        anchor: ResolvedBlockingAnchor,
        sceneKind: BlockingSceneKind,
        purpose: StoryAnchorPurpose,
        strictSceneMatch: Bool,
        catalog: StoryContentCatalog,
        maps: [String: MapDefinition]
    ) -> StoryAnchorCheck {
        switch anchor.definition {
        case let .worldGrid(world):
            guard case let .worldGrid(mapID) = sceneKind else {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "world_grid",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["world-grid 锚点用于 journey-local cue"]
                )
            }
            if strictSceneMatch, world.mapID != mapID {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "world_grid",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["锚点地图 \(world.mapID) 与 cue 场景 \(mapID) 不一致"]
                )
            }
            // Lenient branch/route waypoints validate against their own map.
            let validationMapID = strictSceneMatch ? mapID : world.mapID
            guard let map = maps[validationMapID] else {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "world_grid",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["地图不存在：\(validationMapID)"]
                )
            }
            var issues: [String] = []
            let inBounds = map.contains(world.cell)
            if !inBounds {
                issues.append("越界 \(world.cell)")
            }
            var walkable: Bool?
            if world.requiresWalkableCell {
                walkable = inBounds && !map.isBlocked(world.cell)
                if walkable == false {
                    issues.append("不可走 \(world.cell)")
                }
            }
            if world.requiresInteractionCell {
                let isInteraction = map.buildings.contains { building in
                    building.interactionCells.contains(world.cell)
                } || map.landmarks.contains { $0.position == world.cell }
                if !isInteraction {
                    issues.append("非交互位 \(world.cell)")
                }
            }
            if purpose == .exit, map.exit(at: world.cell) == nil {
                issues.append("非地图出口 \(world.cell)")
            }
            if purpose == .camera, world.requiresWalkableCell {
                issues.append("机位锚点不应要求可走")
            }
            return StoryAnchorCheck(
                anchorID: anchor.anchorID,
                kind: "world_grid",
                resolved: issues.isEmpty,
                walkable: walkable,
                inBounds: inBounds,
                collisionFree: walkable,
                pairedOK: nil,
                issues: issues
            )

        case let .journeyLocal(local):
            guard case let .journeyLocal(sceneID) = sceneKind else {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "journey_local",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["journey-local 锚点用于 world-grid cue"]
                )
            }
            if strictSceneMatch, local.sceneID != sceneID {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "journey_local",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["锚点场景 \(local.sceneID) 与 cue 场景 \(sceneID) 不一致"]
                )
            }
            // Lenient branch/route waypoints validate against their own scene.
            let validationSceneID = strictSceneMatch ? sceneID : local.sceneID
            guard let scene = catalog.journeyScene(id: validationSceneID) else {
                return StoryAnchorCheck(
                    anchorID: anchor.anchorID,
                    kind: "journey_local",
                    resolved: false,
                    walkable: nil,
                    inBounds: nil,
                    collisionFree: nil,
                    pairedOK: nil,
                    issues: ["旅程场景不存在：\(validationSceneID)"]
                )
            }
            var issues: [String] = []
            let inBounds = (0...1).contains(local.point.x) && (0...1).contains(local.point.y)
            if !inBounds {
                issues.append("归一化坐标越界 (\(local.point.x), \(local.point.y))")
            }
            var collisionFree: Bool?
            if purpose != .camera {
                collisionFree = inBounds
                    && !scene.localCollision.contains { $0.contains(local.point) }
                if collisionFree == false {
                    issues.append("落在局部碰撞区内")
                }
            }
            var pairedOK: Bool?
            if let paired = local.pairedAnchorID {
                if let partner = catalog.anchor(id: paired) {
                    if case let .journeyLocal(partnerLocal) = partner {
                        if partnerLocal.sceneID != local.sceneID {
                            issues.append("配对锚点场景不一致")
                        }
                        if partnerLocal.pairedAnchorID != local.id {
                            issues.append("配对关系未互相指向")
                        }
                    } else {
                        issues.append("配对锚点类型错误")
                    }
                } else {
                    issues.append("配对锚点不存在：\(paired)")
                }
                pairedOK = issues.isEmpty
            }
            if purpose == .entry || purpose == .exit {
                let expectedPair: String
                if purpose == .entry {
                    expectedPair = scene.entryAnchorID
                } else {
                    expectedPair = scene.exitAnchorID
                }
                if local.id != expectedPair {
                    issues.append("场景\(purpose == .entry ? "入口" : "出口")锚点不匹配：\(local.id)")
                }
            }
            return StoryAnchorCheck(
                anchorID: anchor.anchorID,
                kind: "journey_local",
                resolved: issues.isEmpty,
                walkable: nil,
                inBounds: inBounds,
                collisionFree: collisionFree,
                pairedOK: pairedOK,
                issues: issues
            )
        }
    }

    // MARK: - Speakers bound to a cue

    /// Main speakers physically placed in this close-up. The manuscript
    /// staggers arrivals ("分三批到"、"错时赶到") and lets background characters
    /// pass without joining the shot, so the close-up limit applies to the
    /// cue's placed actors — never to the union of every line bound to the
    /// cue. `system` and `ledger` are presentation voices, not on-screen
    /// people.
    static func speakerCount(
        for cue: StoryBlockingCueDefinition,
        catalog: StoryContentCatalog
    ) -> Int {
        cue.npcStartAnchors.keys.filter { actorID in
            actorID != StoryActorID.system && actorID != StoryActorID.ledger
        }.count
    }
}

extension StoryContentCatalog {
    func journeyScene(id: String) -> StoryJourneySceneDefinition? {
        journeyScenes.first { $0.id == id }
    }
}
