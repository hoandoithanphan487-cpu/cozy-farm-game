import Foundation

struct StoryContentValidationError: Error, Equatable, CustomStringConvertible {
    var reason: String
    var description: String { reason }
}

enum StoryContentValidator {
    static let expectedManuscriptSHA256 = "7986d4247e2ad2d23e0af3195788257a1c4d166582911f3e4ca280e6e80d3d52"

    static func validate(
        _ catalog: StoryContentCatalog = .shared,
        worldMaps: [String: MapDefinition] = WorldCatalog.maps
    ) throws {
        try validateCountsAndReferences(catalog)
        try validateStoryGraphs(catalog)
        try validateBranches(catalog)
        try validateTokens(catalog)
        try validateConspiratorRoster(catalog)
        try validateAnchors(catalog, worldMaps: worldMaps)
        try validateBlockingCues(catalog, worldMaps: worldMaps)
        try validateRevealVisibility(catalog)
    }

    private static func validateCountsAndReferences(_ catalog: StoryContentCatalog) throws {
        guard StoryGeneratedContent.frozenManuscriptSHA256 == expectedManuscriptSHA256 else {
            throw error("生成目录的冻结稿 SHA-256 不匹配")
        }
        guard catalog.stories.count == 10,
              Set(catalog.stories.map(\.id)) == Set(StoryArcID.allCases) else {
            throw error("主剧情必须完整包含 Q01...Q10")
        }

        let manuscript = catalog.allDialogueLines.filter { $0.origin == .manuscript }
        let inline = catalog.allDialogueLines.filter { $0.origin == .inlineChoiceResponse }
        guard manuscript.count == 236 else {
            throw error("稿件对白数量必须为 236，当前为 \(manuscript.count)")
        }
        guard inline.count == 20 else {
            throw error("内联选择回应数量必须为 20，当前为 \(inline.count)")
        }
        guard catalog.blockingCues.count == 50 else {
            throw error("人物动线数量必须为 50，当前为 \(catalog.blockingCues.count)")
        }

        try requireUnique(catalog.stories.map { $0.id.rawValue }, kind: "剧情")
        try requireUnique(catalog.actors.map(\.id), kind: "剧情角色")
        try requireUnique(catalog.allDialogueLines.map(\.id), kind: "运行时对白")
        try requireUnique(manuscript.compactMap(\.sourceID), kind: "稿件对白 sourceID")
        try requireUnique(catalog.blockingCues.map(\.id), kind: "运行时动线")
        try requireUnique(catalog.blockingCues.map(\.sourceBlockingID), kind: "稿件动线 sourceBlockingID")
        try requireUnique(catalog.anchors.map(\.id), kind: "剧情锚点")
        try requireUnique(catalog.journeyScenes.map(\.id), kind: "旅程场景")

        let actorIDs = Set(catalog.actors.map(\.id))
        let cueIDs = Set(catalog.blockingCues.map(\.id))
        for story in catalog.stories {
            guard !story.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw error("剧情标题为空：\(story.id.rawValue)")
            }
            for line in story.stages.flatMap(\.lines) {
                guard ContentID.isValid(line.id) else {
                    throw error("非法运行时对白 ID：\(line.id)")
                }
                guard actorIDs.contains(line.speakerID) else {
                    throw error("对白引用缺失 speaker：\(line.id) -> \(line.speakerID)")
                }
                if let attributed = line.attributedActorID,
                   !actorIDs.contains(attributed) {
                    throw error("对白引用缺失署名角色：\(line.id) -> \(attributed)")
                }
                if let portrait = line.portraitID,
                   !actorIDs.contains(portrait) {
                    throw error("对白引用缺失 portrait：\(line.id) -> \(portrait)")
                }
                guard let cueID = line.blockingCueID, cueIDs.contains(cueID) else {
                    throw error("对白引用缺失人物动线：\(line.id)")
                }
                switch line.origin {
                case .manuscript:
                    guard let sourceID = line.sourceID,
                          sourceID.hasPrefix("Q\(twoDigits(story.id.sequence))_") else {
                        throw error("稿件对白 sourceID 与剧情不一致：\(line.id)")
                    }
                case .inlineChoiceResponse:
                    guard line.sourceID == nil else {
                        throw error("内联选择回应不得冒充 236 稿件 sourceID：\(line.id)")
                    }
                }
            }
        }

        let expectedCueSources = Set(StoryArcID.allCases.flatMap { arcID in
            (1...5).map { "Q\(twoDigits(arcID.sequence))_BLK_\(twoDigits($0))" }
        })
        guard Set(catalog.blockingCues.map(\.sourceBlockingID)) == expectedCueSources else {
            throw error("50 个 Qxx_BLK_nn 未一一映射")
        }
    }

    private static func validateStoryGraphs(_ catalog: StoryContentCatalog) throws {
        for story in catalog.stories {
            let stageIDs = story.stages.map(\.id)
            try requireUnique(stageIDs, kind: "\(story.id.shortCode) stage")
            let byID = Dictionary(uniqueKeysWithValues: story.stages.map { ($0.id, $0) })
            for stage in story.stages {
                guard ContentID.isValid(stage.id),
                      stage.id == "\(story.id.rawValue).stage.\(stage.kind.rawValue)" else {
                    throw error("剧情 stage ID 非法或不稳定：\(stage.id)")
                }
                for nextID in stage.nextStageIDs where byID[nextID] == nil {
                    throw error("剧情 stage 引用缺失：\(stage.id) -> \(nextID)")
                }
            }

            var visiting = Set<String>()
            var visited = Set<String>()
            func visit(_ id: String) throws {
                if visiting.contains(id) {
                    throw error("剧情 stage 图含循环：\(story.id.shortCode) -> \(id)")
                }
                if visited.contains(id) { return }
                visiting.insert(id)
                for nextID in byID[id]?.nextStageIDs ?? [] {
                    try visit(nextID)
                }
                visiting.remove(id)
                visited.insert(id)
            }
            for id in stageIDs { try visit(id) }

            guard let first = story.stages.first else {
                throw error("剧情缺少 stage：\(story.id.shortCode)")
            }
            var reachable = Set<String>()
            var frontier = [first.id]
            while let id = frontier.popLast(), reachable.insert(id).inserted {
                frontier.append(contentsOf: byID[id]?.nextStageIDs ?? [])
            }
            let requiredReachable = Set(
                story.stages
                    .filter { $0.visibility == .ordinary }
                    .map(\.id)
            )
            guard requiredReachable.isSubset(of: reachable) else {
                let missing = requiredReachable.subtracting(reachable).sorted()
                throw error("剧情存在不可达普通 stage：\(missing.joined(separator: ", "))")
            }

            let actualKinds = Set(story.stages.map(\.kind))
            let expectedKinds: Set<StoryStageID>
            switch story.id {
            case .q01, .q02, .q03, .q04, .q05, .q06, .q07:
                expectedKinds = [.benefit, .warningOne, .warningTwo, .eruption, .aftermath, .revealCallback]
            case .q08:
                expectedKinds = [.benefit, .warningOne, .warningTwo, .eruption, .departureConfirmation, .climax, .aftermath, .revealCallback]
            case .q09:
                expectedKinds = [.discovery, .interrupt, .playerIntent, .turningPoint]
            case .q10:
                expectedKinds = [.confrontationOpen, .playerIntent, .allEvil, .lastFarmAction, .graduation]
            }
            guard actualKinds == expectedKinds else {
                throw error("剧情阶段集合不完整：\(story.id.shortCode)")
            }
        }
    }

    private static func validateBranches(_ catalog: StoryContentCatalog) throws {
        let cueByArc = Dictionary(grouping: catalog.blockingCues, by: \.arcID)
        for story in catalog.stories {
            let expected = StoryChoiceID.choices(for: story.id)
            guard story.branchChoices == expected else {
                throw error("分支枚举与冻结合同不一致：\(story.id.shortCode)")
            }
            let expectedStableIDs = Set(expected.map { $0.stableID(in: story.id) })
            guard expectedStableIDs.count == expected.count else {
                throw error("分支稳定 ID 重复：\(story.id.shortCode)")
            }

            let stageChoices = Set(
                story.stages.flatMap(\.choices).map { $0.stableID(in: story.id) }
            )
            guard stageChoices == expectedStableIDs else {
                let missing = expectedStableIDs.subtracting(stageChoices).sorted()
                throw error("剧情存在不可达分支：\(story.id.shortCode) \(missing)")
            }

            let movementChoices = Set(
                (cueByArc[story.id] ?? []).flatMap { $0.branchMovement.keys }
            )
            guard expectedStableIDs.isSubset(of: movementChoices) else {
                let missing = expectedStableIDs.subtracting(movementChoices).sorted()
                throw error("分支缺少人物移动：\(story.id.shortCode) \(missing)")
            }

            for line in story.stages.flatMap(\.lines) {
                switch line.condition {
                case let .selectedChoice(choice, arcID):
                    guard arcID == story.id,
                          expected.contains(choice) else {
                        throw error("对白分支引用跨剧情或缺失：\(line.id)")
                    }
                case let .q05Resolution(choice):
                    guard story.id == .q05,
                          [.publicOrder, .coop, .delay].contains(choice) else {
                        throw error("q05_resolution 条件非法：\(line.id)")
                    }
                case .always, .selectedAction, .romanceTender:
                    break
                }
            }
        }
    }

    private static func validateTokens(_ catalog: StoryContentCatalog) throws {
        for story in catalog.stories {
            for line in story.stages.flatMap(\.lines) {
                let tokens = StoryDialogueInterpolator.tokens(in: line.text)
                if let unknown = tokens.first(where: { !StoryDialogueInterpolator.allowedTokens.contains($0) }) {
                    throw error("对白含未知 token：\(line.id) -> \(unknown)")
                }
                if line.text.contains("{{"), tokens.isEmpty {
                    throw error("对白含无法识别的 token 语法：\(line.id)")
                }
                if tokens.contains("q05_resolution"), story.id != .q05 {
                    throw error("q05_resolution 只能出现在 Q05：\(line.id)")
                }
                do {
                    let resolved = try StoryDialogueInterpolator.interpolate(
                        line.text,
                        standing: 73,
                        q05Resolution: .publicOrder
                    )
                    guard !resolved.contains("{{") else {
                        throw error("插值后仍残留 token：\(line.id)")
                    }
                } catch let validation as StoryContentValidationError {
                    throw validation
                } catch {
                    throw self.error("对白插值失败：\(line.id) -> \(error)")
                }
            }
        }
    }

    private static func validateConspiratorRoster(_ catalog: StoryContentCatalog) throws {
        let expected: Set<String> = [
            StoryActorID.waterApprentice,
            StoryActorID.seedSteward,
            StoryActorID.creekWarden,
            StoryActorID.neighborHearsay,
            StoryActorID.neighborStoryteller,
            StoryActorID.neighborEvidence,
            StoryActorID.neighborConsensus,
            StoryActorID.catShopBlack,
            StoryActorID.catShopCalico,
            StoryActorID.catShopRagdoll,
            StoryActorID.bellPrincess,
            StoryActorID.greygateRepresentative,
            StoryActorID.greygateFarmer,
        ]
        let declared = Set(StoryActorCatalog.conspiratorRoster)
        let actorFlags = Set(catalog.actors.filter(\.isConspirator).map(\.id))
        guard declared == expected, actorFlags == expected else {
            throw error("终局共谋名册必须完整包含 7 NPC、3 猫、绒铃、灰栅代表与灰栅农场主")
        }
        guard StoryActorID.greygateRepresentative != StoryActorID.greygateFarmer else {
            throw error("灰栅代表与灰栅农场主不得共用 ID")
        }
        let mentionedActors = Set(catalog.allDialogueLines.flatMap { line in
            [line.speakerID, line.attributedActorID].compactMap { $0 }
        })
        guard expected.isSubset(of: mentionedActors) else {
            throw error("共谋名册存在从主剧情完全缺席的角色")
        }
    }

    private static func validateAnchors(
        _ catalog: StoryContentCatalog,
        worldMaps: [String: MapDefinition]
    ) throws {
        let anchorByID = catalog.anchorsByID
        let scenesByID = catalog.journeyScenesByID
        for anchor in catalog.anchors {
            guard ContentID.isValid(anchor.id) else {
                throw error("非法剧情锚点 ID：\(anchor.id)")
            }
            switch anchor {
            case let .worldGrid(world):
                guard let map = worldMaps[world.mapID] else {
                    throw error("world-grid 锚点引用缺失地图：\(world.id)")
                }
                guard map.contains(world.cell) else {
                    throw error("world-grid 锚点越界：\(world.id)")
                }
                if world.requiresWalkableCell, map.isBlocked(world.cell) {
                    throw error("world-grid 锚点不可走：\(world.id)")
                }
                if let landmarkID = world.landmarkID {
                    guard map.landmarks.contains(where: { $0.id == landmarkID }) else {
                        throw error("锚点引用缺失 landmark：\(world.id) -> \(landmarkID)")
                    }
                    if world.requiresInteractionCell {
                        guard let building = map.building(id: landmarkID),
                              building.interactionCells.contains(world.cell) else {
                            throw error("锚点不是 landmark 的可达 interaction cell：\(world.id)")
                        }
                    }
                } else if world.requiresInteractionCell {
                    throw error("要求 interaction cell 的锚点缺少 landmark：\(world.id)")
                }
            case let .journeyLocal(local):
                guard let scene = scenesByID[local.sceneID] else {
                    throw error("journey-local 锚点引用缺失场景：\(local.id)")
                }
                guard (0...1).contains(local.point.x), (0...1).contains(local.point.y) else {
                    throw error("journey-local 锚点坐标必须归一化：\(local.id)")
                }
                guard !scene.localCollision.contains(where: { $0.contains(local.point) }) else {
                    throw error("journey-local 锚点落入局部碰撞：\(local.id)")
                }
                if let pairedID = local.pairedAnchorID {
                    guard case let .journeyLocal(paired)? = anchorByID[pairedID],
                          paired.sceneID == local.sceneID,
                          paired.pairedAnchorID == local.id else {
                        throw error("journey-local 入口／出口配对无效：\(local.id)")
                    }
                }
            }
        }

        for scene in catalog.journeyScenes {
            guard ContentID.isValid(scene.id) else {
                throw error("非法旅程场景 ID：\(scene.id)")
            }
            guard case let .journeyLocal(entry)? = anchorByID[scene.entryAnchorID],
                  entry.sceneID == scene.id,
                  entry.purpose == .entry else {
                throw error("旅程场景入口锚点无效：\(scene.id)")
            }
            guard case let .journeyLocal(exit)? = anchorByID[scene.exitAnchorID],
                  exit.sceneID == scene.id,
                  exit.purpose == .exit else {
                throw error("旅程场景出口锚点无效：\(scene.id)")
            }
            guard canReachJourney(entry.point, exit.point, collision: scene.localCollision) else {
                throw error("旅程场景入口无法到达出口：\(scene.id)")
            }
        }

        guard case let .worldGrid(departure)? = anchorByID[StoryAnchorCatalog.endingDepartureAnchorID],
              departure.mapID == ContentID.creekMarket,
              departure.landmarkID == "brookseed.landmark.market_wharf",
              departure.cell == GridPosition(x: 3, y: 5),
              departure.requiresInteractionCell else {
            throw error("ending_departure 必须解析到 market_wharf interaction (3,5)")
        }
    }

    private static func validateBlockingCues(
        _ catalog: StoryContentCatalog,
        worldMaps: [String: MapDefinition]
    ) throws {
        let anchors = catalog.anchorsByID
        let actors = catalog.actorsByID
        let journeyScenes = catalog.journeyScenesByID
        for cue in catalog.blockingCues {
            guard ContentID.isValid(cue.id),
                  cue.id == "\(cue.arcID.rawValue).cue.blk_\(cue.sourceBlockingID.suffix(2))" else {
                throw error("动线运行时 ID 与 sourceBlockingID 不一致：\(cue.sourceBlockingID)")
            }
            guard !cue.playerWaypoints.isEmpty else {
                throw error("动线缺少玩家检查／操作节点：\(cue.sourceBlockingID)")
            }
            guard (1...3).contains(cue.npcStartAnchors.count) else {
                throw error("近景主要说话者必须为 1...3 人：\(cue.sourceBlockingID)")
            }
            guard Set(cue.npcStartAnchors.keys) == Set(cue.npcExitAnchors.keys) else {
                throw error("NPC 入退场角色集合不一致：\(cue.sourceBlockingID)")
            }
            for actorID in cue.npcStartAnchors.keys where actors[actorID] == nil {
                throw error("动线引用缺失角色：\(cue.sourceBlockingID) -> \(actorID)")
            }

            var referenced = [cue.entryAnchor, cue.interactionAnchor]
            referenced.append(contentsOf: cue.playerWaypoints)
            referenced.append(contentsOf: cue.npcStartAnchors.values)
            referenced.append(contentsOf: cue.npcExitAnchors.values)
            referenced.append(contentsOf: cue.branchMovement.values.flatMap { $0 })
            if let atAnchor = cue.crossingOrInterrupt.atAnchorID { referenced.append(atAnchor) }
            if let camera = cue.revealCameraOrProp.cameraAnchorID { referenced.append(camera) }
            for anchorID in referenced where anchors[anchorID] == nil {
                throw error("动线引用缺失锚点：\(cue.sourceBlockingID) -> \(anchorID)")
            }

            if worldMaps[cue.sceneID] != nil {
                guard case let .worldGrid(entry)? = anchors[cue.entryAnchor],
                      entry.mapID == cue.sceneID,
                      case let .worldGrid(interaction)? = anchors[cue.interactionAnchor],
                      interaction.mapID == cue.sceneID else {
                    throw error("world-grid cue 混用 journey-local 主锚点：\(cue.sourceBlockingID)")
                }
            } else if journeyScenes[cue.sceneID] != nil {
                guard case let .journeyLocal(entry)? = anchors[cue.entryAnchor],
                      entry.sceneID == cue.sceneID,
                      case let .journeyLocal(interaction)? = anchors[cue.interactionAnchor],
                      interaction.sceneID == cue.sceneID else {
                    throw error("journey-local cue 混用 world-grid 主锚点：\(cue.sourceBlockingID)")
                }
            } else {
                throw error("动线引用未知 scene：\(cue.sourceBlockingID) -> \(cue.sceneID)")
            }

            let allowedBranches = Set(
                StoryChoiceID.choices(for: cue.arcID).map { $0.stableID(in: cue.arcID) }
            )
            for branchID in cue.branchMovement.keys where !allowedBranches.contains(branchID) {
                throw error("动线引用未知分支：\(cue.sourceBlockingID) -> \(branchID)")
            }

            try validateTemporaryBlocks(cue, anchors: anchors, worldMaps: worldMaps)
            try validateCueReachability(cue, anchors: anchors, catalog: catalog, worldMaps: worldMaps)
        }
    }

    private static func validateRevealVisibility(_ catalog: StoryContentCatalog) throws {
        for arcID in StoryArcID.allCases where arcID.sequence <= 8 {
            guard let reveal = catalog.stage(arcID: arcID, kind: .revealCallback),
                  reveal.visibility == .finaleOnly,
                  !reveal.lines.isEmpty,
                  reveal.lines.allSatisfy({ $0.visibility == .finaleOnly }) else {
                throw error("Q01...Q08 reveal_callback 必须只在终局可见：\(arcID.shortCode)")
            }
            guard catalog.visibleLines(
                arcID: arcID,
                stage: .revealCallback,
                finaleUnlocked: false
            ).isEmpty else {
                throw error("Q09 前泄露 reveal_callback：\(arcID.shortCode)")
            }
        }
        for cue in catalog.blockingCues where cue.arcID.sequence <= 8 {
            let isRevealCue = cue.sourceBlockingID.hasSuffix("_05")
            if isRevealCue, cue.revealCameraOrProp.policy != .finaleOnly {
                throw error("揭露动线缺少 finale-only 保护：\(cue.sourceBlockingID)")
            }
            if !isRevealCue, cue.revealCameraOrProp.policy == .finaleOnly {
                throw error("普通动线意外携带揭露机位：\(cue.sourceBlockingID)")
            }
        }
    }

    private static func validateTemporaryBlocks(
        _ cue: StoryBlockingCueDefinition,
        anchors: [String: StoryAnchorDefinition],
        worldMaps: [String: MapDefinition]
    ) throws {
        for blocked in cue.temporarilyBlockedCells {
            guard let map = worldMaps[blocked.mapID], map.contains(blocked.cell) else {
                throw error("临时阻挡格越界：\(cue.sourceBlockingID)")
            }
            let protected = map.pathCells.contains(blocked.cell)
                || map.exits.contains(where: { $0.cell == blocked.cell })
                || map.buildings.contains(where: {
                    $0.door == blocked.cell || $0.interactionCells.contains(blocked.cell)
                })
            guard !protected else {
                throw error("临时阻挡占用主路／门／出口／交互位：\(cue.sourceBlockingID)")
            }
        }
    }

    private static func validateCueReachability(
        _ cue: StoryBlockingCueDefinition,
        anchors: [String: StoryAnchorDefinition],
        catalog: StoryContentCatalog,
        worldMaps: [String: MapDefinition]
    ) throws {
        var referenced = [cue.entryAnchor, cue.interactionAnchor]
        referenced.append(contentsOf: cue.playerWaypoints)
        referenced.append(contentsOf: cue.npcStartAnchors.values)
        referenced.append(contentsOf: cue.npcExitAnchors.values)
        referenced.append(contentsOf: cue.branchMovement.values.flatMap { $0 })

        let worldAnchors = referenced.compactMap { anchorID -> WorldGridStoryAnchor? in
            guard case let .worldGrid(anchor)? = anchors[anchorID] else { return nil }
            return anchor
        }
        for (mapID, group) in Dictionary(grouping: worldAnchors, by: \.mapID) {
            guard let map = worldMaps[mapID] else { continue }
            let temporary = Set(
                cue.temporarilyBlockedCells
                    .filter { $0.mapID == mapID }
                    .map(\.cell)
            )
            let start: GridPosition
            if let primary = group.first(where: { $0.id == cue.entryAnchor }) {
                start = primary.cell
            } else if let spawn = map.spawns.first {
                start = spawn.position
            } else if let first = group.first {
                start = first.cell
            } else {
                continue
            }
            for target in group where !canReachWorld(start, target.cell, map: map, extraBlocked: temporary) {
                throw error("动线 world-grid 路径不通：\(cue.sourceBlockingID) -> \(target.id)")
            }
        }

        let localAnchors = referenced.compactMap { anchorID -> JourneyLocalStoryAnchor? in
            guard case let .journeyLocal(anchor)? = anchors[anchorID] else { return nil }
            return anchor
        }
        for (sceneID, group) in Dictionary(grouping: localAnchors, by: \.sceneID) {
            guard let scene = catalog.journeyScenesByID[sceneID],
                  case let .journeyLocal(sceneEntry)? = anchors[scene.entryAnchorID] else {
                throw error("动线 journey-local 场景缺失：\(cue.sourceBlockingID)")
            }
            let start = group.first(where: { $0.id == cue.entryAnchor })?.point ?? sceneEntry.point
            for target in group where !canReachJourney(start, target.point, collision: scene.localCollision) {
                throw error("动线 journey-local 路径不通：\(cue.sourceBlockingID) -> \(target.id)")
            }
        }
    }

    private static func canReachWorld(
        _ start: GridPosition,
        _ target: GridPosition,
        map: MapDefinition,
        extraBlocked: Set<GridPosition>
    ) -> Bool {
        if start == target { return true }
        guard map.contains(start), map.contains(target),
              !map.isBlocked(start), !map.isBlocked(target),
              !extraBlocked.contains(start), !extraBlocked.contains(target) else {
            return false
        }
        var visited: Set<GridPosition> = [start]
        var queue = [start]
        var cursor = 0
        let deltas = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            for (dx, dy) in deltas {
                let next = GridPosition(x: current.x + dx, y: current.y + dy)
                guard map.contains(next),
                      !map.isBlocked(next),
                      !extraBlocked.contains(next),
                      visited.insert(next).inserted else { continue }
                if next == target { return true }
                queue.append(next)
            }
        }
        return false
    }

    private static func canReachJourney(
        _ start: StoryNormalizedPoint,
        _ target: StoryNormalizedPoint,
        collision: [StoryCollisionRect]
    ) -> Bool {
        let resolution = 30
        func cell(_ point: StoryNormalizedPoint) -> GridPosition {
            GridPosition(
                x: min(resolution, max(0, Int((point.x * Double(resolution)).rounded()))),
                y: min(resolution, max(0, Int((point.y * Double(resolution)).rounded())))
            )
        }
        func point(_ cell: GridPosition) -> StoryNormalizedPoint {
            StoryNormalizedPoint(
                x: Double(cell.x) / Double(resolution),
                y: Double(cell.y) / Double(resolution)
            )
        }
        func isBlocked(_ cell: GridPosition) -> Bool {
            collision.contains { $0.contains(point(cell)) }
        }

        let from = cell(start)
        let to = cell(target)
        guard !isBlocked(from), !isBlocked(to) else { return false }
        if from == to { return true }
        var visited: Set<GridPosition> = [from]
        var queue = [from]
        var cursor = 0
        let deltas = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            for (dx, dy) in deltas {
                let next = GridPosition(x: current.x + dx, y: current.y + dy)
                guard (0...resolution).contains(next.x),
                      (0...resolution).contains(next.y),
                      !isBlocked(next),
                      visited.insert(next).inserted else { continue }
                if next == to { return true }
                queue.append(next)
            }
        }
        return false
    }

    private static func requireUnique(_ ids: [String], kind: String) throws {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw error("重复\(kind) ID：\(id)")
        }
    }

    private static func error(_ reason: String) -> StoryContentValidationError {
        StoryContentValidationError(reason: reason)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }
}
