import Foundation
import XCTest
@testable import CreekSprout

final class N027StoryBlockingTests: XCTestCase {
    private let catalog = StoryContentCatalog.shared
    private let maps = WorldCatalog.maps

    func testAllFiftyCuesResolveWithWorldGridAndJourneyLocalSplit() throws {
        let plans = StoryBlockingResolver.resolveAll(catalog: catalog, maps: maps)
        XCTAssertEqual(plans.count, 50, "10 arcs × 5 cues")
        let sourceIDs = plans.map(\.cue.sourceBlockingID)
        XCTAssertEqual(Set(sourceIDs).count, 50)

        for plan in plans {
            switch plan.sceneKind {
            case let .worldGrid(mapID):
                XCTAssertEqual(mapID, plan.cue.sceneID, plan.cue.id)
                XCTAssertTrue(maps[mapID] != nil, plan.cue.id)
            case let .journeyLocal(sceneID):
                XCTAssertEqual(sceneID, plan.cue.sceneID, plan.cue.id)
                XCTAssertTrue(catalog.journeyScenes.contains { $0.id == sceneID }, plan.cue.id)
            }
        }
    }

    func testEveryCueResolvesCleanClearanceAcrossAllBranches() throws {
        let plans = StoryBlockingResolver.resolveAll(catalog: catalog, maps: maps)
        XCTAssertEqual(plans.count, 50)
        let blocked = plans.filter { $0.clearance.verdict == .blocked }
        XCTAssertTrue(
            blocked.isEmpty,
            "Blocked cues: \(blocked.map { "\($0.cue.id): \($0.clearance.issues)" })"
        )

        // Every branch movement resolves at least one route waypoint.
        for plan in plans {
            for (branchID, waypoints) in plan.branchMovements {
                XCTAssertFalse(waypoints.isEmpty, "\(plan.cue.id) branch \(branchID)")
                for waypoint in waypoints {
                    XCTAssertNotNil(waypoint.definition, plan.cue.id)
                }
            }
            XCTAssertEqual(
                Set(plan.npcStarts.keys),
                Set(plan.npcExits.keys),
                plan.cue.id
            )
            XCTAssertFalse(plan.playerWaypoints.isEmpty, plan.cue.id)
            XCTAssertNotNil(plan.entry.definition)
            XCTAssertNotNil(plan.interaction.definition)
            // NPC placement (the approved content contract) stays 1–3.
            XCTAssertTrue(
                (1...3).contains(plan.cue.npcStartAnchors.count),
                plan.cue.id
            )
            // Strict anchors (entry/interaction/main waypoints/NPC starts)
            // must match the cue scene.
            let strictAnchors = [plan.entry.anchorID, plan.interaction.anchorID]
                + plan.playerWaypoints.map(\.anchorID)
                + plan.npcStarts.values.map(\.anchorID)
                + plan.npcExits.values.map(\.anchorID)
            for anchorID in strictAnchors {
                guard let definition = catalog.anchor(id: anchorID) else {
                    XCTFail("missing anchor \(anchorID)")
                    continue
                }
                switch definition {
                case let .worldGrid(world):
                    XCTAssertEqual(world.mapID, plan.cue.sceneID, anchorID)
                case let .journeyLocal(local):
                    XCTAssertEqual(local.sceneID, plan.cue.sceneID, anchorID)
                }
            }
        }
    }

    func testWorldGridAnchorsRespectN015Topology() throws {
        let farm = try XCTUnwrap(maps[ContentID.farmHomestead])
        let market = try XCTUnwrap(maps[ContentID.creekMarket])

        for anchor in StoryAnchorCatalog.worldGridAnchors {
            let map = anchor.mapID == farm.id ? farm : market
            if anchor.requiresWalkableCell {
                XCTAssertFalse(map.isBlocked(anchor.cell), anchor.id)
            }
            if anchor.requiresInteractionCell {
                let isInteraction = map.buildings.contains { building in
                    building.interactionCells.contains(anchor.cell)
                } || map.landmarks.contains { $0.position == anchor.cell }
                XCTAssertTrue(isInteraction, anchor.id)
            }
        }
        // Landmarks, doors, the farm main road and map exits stay walkable:
        // the frozen cue set must not permanently block them.
        for plan in StoryBlockingResolver.resolveAll(catalog: catalog, maps: maps) {
            for blocked in plan.temporarilyBlockedCells {
                guard let map = maps[blocked.mapID] else {
                    XCTFail("blocked cell map missing \(blocked.mapID)")
                    continue
                }
                XCTAssertFalse(map.pathCells.contains(blocked.cell), blocked.mapID)
                XCTAssertFalse(map.buildings.contains {
                    $0.door == blocked.cell || $0.interactionCells.contains(blocked.cell)
                }, blocked.mapID)
                XCTAssertFalse(map.exits.contains { $0.cell == blocked.cell }, blocked.mapID)
            }
        }
    }

    func testJourneyLocalAnchorsValidateScenesPairsAndCollision() throws {
        let scenesByID = Dictionary(
            uniqueKeysWithValues: catalog.journeyScenes.map { ($0.id, $0) }
        )
        for anchor in StoryAnchorCatalog.journeyLocalAnchors {
            let scene = try XCTUnwrap(
                scenesByID[anchor.sceneID],
                anchor.id
            )
            XCTAssertTrue((0...1).contains(anchor.point.x), anchor.id)
            XCTAssertTrue((0...1).contains(anchor.point.y), anchor.id)
            if anchor.purpose != .camera {
                XCTAssertFalse(
                    scene.localCollision.contains { $0.contains(anchor.point) },
                    anchor.id
                )
            }
            if let paired = anchor.pairedAnchorID {
                guard case let .journeyLocal(partner)? = catalog.anchor(id: paired) else {
                    XCTFail("pair missing \(anchor.id) -> \(paired)")
                    continue
                }
                XCTAssertEqual(partner.sceneID, anchor.sceneID, anchor.id)
                XCTAssertEqual(partner.pairedAnchorID, anchor.id, anchor.id)
            }
        }
        // Entry/exit anchors match the scene contract.
        for scene in catalog.journeyScenes {
            guard case let .journeyLocal(entry)? = catalog.anchor(id: scene.entryAnchorID) else {
                XCTFail("entry missing \(scene.id)")
                continue
            }
            XCTAssertEqual(entry.purpose, .entry, scene.id)
            guard case let .journeyLocal(exit)? = catalog.anchor(id: scene.exitAnchorID) else {
                XCTFail("exit missing \(scene.id)")
                continue
            }
            XCTAssertEqual(exit.purpose, .exit, scene.id)
        }
    }

    func testEndingDepartureResolvesToMarketWharfWorldGridAnchor() throws {
        // The finale cue itself resolves cleanly (its scene is the farm for
        // the last watering lines).
        let finalePlan = try StoryBlockingResolver.resolve(
            cueID: "brookseed.story.q10.cue.blk_05",
            catalog: catalog,
            maps: maps
        ).get()
        XCTAssertEqual(finalePlan.cue.sourceBlockingID, "Q10_BLK_05")
        XCTAssertEqual(finalePlan.clearance.verdict, .pass)
        // The departure interaction lives at the existing market wharf.
        let anchor = try XCTUnwrap(
            catalog.anchor(id: StoryAnchorCatalog.endingDepartureAnchorID)
        )
        guard case let .worldGrid(world) = anchor else {
            return XCTFail("ending_departure must be world-grid")
        }
        XCTAssertEqual(world.mapID, ContentID.creekMarket)
        XCTAssertEqual(world.landmarkID, "brookseed.landmark.market_wharf")
        XCTAssertEqual(world.purpose, .interaction)
        XCTAssertTrue(world.requiresWalkableCell)
        XCTAssertTrue(world.requiresInteractionCell)
        XCTAssertFalse(catalog.anchorsByID[StoryAnchorCatalog.endingDepartureAnchorID] == nil)
    }

    func testRevealCuesStayFinaleOnly() throws {
        for arcID in StoryArcID.allCases where arcID.sequence <= 8 {
            let revealCue = try XCTUnwrap(
                catalog.blockingCues.first {
                    $0.arcID == arcID && $0.sourceBlockingID.hasSuffix("_05")
                }
            )
            XCTAssertNil(
                catalog.visibleBlockingCue(id: revealCue.id, finaleUnlocked: false),
                arcID.rawValue
            )
            XCTAssertNotNil(
                catalog.visibleBlockingCue(id: revealCue.id, finaleUnlocked: true),
                arcID.rawValue
            )
        }
    }

    func testRevealCameraOrPropIsRegisteredOnEveryFinaleCue() throws {
        for arcID in StoryArcID.allCases where arcID.sequence <= 8 {
            let revealCue = try XCTUnwrap(
                catalog.blockingCues.first {
                    $0.arcID == arcID && $0.sourceBlockingID.hasSuffix("_05")
                }
            )
            XCTAssertEqual(revealCue.revealCameraOrProp.policy, .finaleOnly, arcID.rawValue)
            XCTAssertNotNil(
                revealCue.revealCameraOrProp.cameraAnchorID ?? revealCue.revealCameraOrProp.propID,
                arcID.rawValue
            )
        }
    }

    /// Machine-readable path clearance over all 50 cues and every branch.
    func testPathClearanceEvidenceEmission() throws {
        let plans = StoryBlockingResolver.resolveAll(catalog: catalog, maps: maps)
        let payload: [String: Any] = [
            "generator": "N027StoryBlockingTests",
            "cue_count": plans.count,
            "verdicts": plans.map { plan in
                [
                    "cue_id": plan.cue.id,
                    "source_blocking_id": plan.cue.sourceBlockingID,
                    "arc": plan.cue.arcID.rawValue,
                    "scene_kind": plan.sceneKind.label,
                    "entry_anchor": plan.entry.anchorID,
                    "npc_start_count": plan.npcStarts.count,
                    "npc_exit_count": plan.npcExits.count,
                    "waypoint_count": plan.playerWaypoints.count,
                    "interaction_anchor": plan.interaction.anchorID,
                    "branch_movement_count": plan.branchMovements.count,
                    "branch_waypoint_counts": plan.branchMovements.mapValues(\.count),
                    "speaker_count": plan.speakerCount,
                    "verdict": plan.clearance.verdict.rawValue,
                    "issues": plan.clearance.issues,
                    "anchor_checks": plan.clearance.anchorChecks.map { check in
                        [
                            "anchor_id": check.anchorID,
                            "kind": check.kind,
                            "resolved": check.resolved,
                            "walkable": check.walkable ?? false,
                            "in_bounds": check.inBounds ?? false,
                            "collision_free": check.collisionFree ?? false,
                            "paired_ok": check.pairedOK ?? false,
                            "issues": check.issues,
                        ] as [String: Any]
                    },
                ] as [String: Any]
            },
        ]
        try N027EvidenceWriter.writeJSON(payload, to: "path-clearance.json")
        XCTAssertEqual(plans.filter { $0.clearance.verdict == .pass }.count, 50)
    }
}
