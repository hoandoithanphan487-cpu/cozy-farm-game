enum SaveValidation {
    static let maxQuantity = 99
    static let maxCapacity = 999
    static let maxStamina = 100
    static let maxMinute = 1439
    static let maxShippingQuantity = 999
    static let maxUnitPriceSnapshot = 1_000_000
    static let maxLineAmount = 10_000_000
    static let maxSettlementTotal = 10_000_000

    static func validate(_ state: GameState, catalog: ContentCatalog) throws {
        guard ContentID.isValid(state.currentMapID), catalog.knowsMapID(state.currentMapID) else {
            throw SaveStoreError.invalidContents
        }
        guard let map = catalog.map(id: state.currentMapID), map.contains(state.position) else {
            throw SaveStoreError.invalidContents
        }
        guard (0...Self.maxStamina).contains(state.stamina) else {
            throw SaveStoreError.invalidContents
        }
        guard (1...Self.maxCapacity).contains(state.inventoryCapacity) else {
            throw SaveStoreError.invalidContents
        }
        guard state.clock.day >= 1, (0...Self.maxMinute).contains(state.clock.minute) else {
            throw SaveStoreError.invalidContents
        }
        guard state.inventory.count <= state.inventoryCapacity else {
            throw SaveStoreError.invalidContents
        }
        for stack in state.inventory {
            guard ContentID.isValid(stack.itemID), catalog.knowsItemID(stack.itemID) else {
                throw SaveStoreError.invalidContents
            }
            let stackLimit = catalog.stackLimit(for: stack.itemID)
            guard (1...stackLimit).contains(stack.quantity) else {
                throw SaveStoreError.invalidContents
            }
        }
        for (coordinate, cell) in state.farmCells {
            guard coordinate.isInsideFarm else {
                throw SaveStoreError.invalidContents
            }
            guard cell.fertility >= 0, cell.cropStage >= 0, cell.stageProgressDays >= 0, cell.plantedDay >= 0 else {
                throw SaveStoreError.invalidContents
            }
            if cell.cropID.isEmpty {
                continue
            }
            guard ContentID.isValid(cell.cropID), catalog.knowsCropID(cell.cropID) else {
                throw SaveStoreError.invalidContents
            }
        }
        try validateEconomy(state.economy, scenarioID: state.scenarioID, catalog: catalog)
        try validatePlacedObjects(state, catalog: catalog)
        try validateTutorial(state.tutorial, catalog: catalog)
        try validateWatershed(state, catalog: catalog)
        try validateQuestLog(state, catalog: catalog)
        try validateHarvestedNodes(state, catalog: catalog)
        try validateCommunity(state, catalog: catalog)
        try validateRelationships(state, catalog: catalog)
        try validateSettings(state.settings)
        try validateSelectedRecipe(state.selectedRecipeID, catalog: catalog)
    }

    private static func validateSelectedRecipe(_ recipeID: String?, catalog: ContentCatalog) throws {
        guard let recipeID else { return }
        guard ContentID.isValid(recipeID), catalog.recipe(id: recipeID) != nil else {
            throw SaveStoreError.invalidContents
        }
    }

    static func validateSettings(_ settings: SettingsState) throws {
        do {
            try SettingsValidation.validate(settings)
        } catch {
            throw SaveStoreError.invalidContents
        }
    }

    private static func validateEconomy(
        _ economy: EconomyState,
        scenarioID: String,
        catalog: ContentCatalog
    ) throws {
        guard ContentID.isValid(scenarioID) else {
            throw SaveStoreError.invalidContents
        }
        guard economy.balance >= 0 else {
            throw SaveStoreError.invalidContents
        }

        let pending = economy.shipping.pendingEntries
        let pendingIDs = pending.map(\.entryID)
        guard pendingIDs == pendingIDs.sorted() else {
            throw SaveStoreError.invalidContents
        }
        var entryIDs = Set<String>()
        for entry in pending {
            guard entryIDs.insert(entry.entryID).inserted else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(entry.itemID), catalog.knowsItemID(entry.itemID) else {
                throw SaveStoreError.invalidContents
            }
            let expectedID = ShippingEntry.mergeKey(
                itemID: entry.itemID,
                quality: entry.quality,
                depositedDay: entry.depositedDay
            )
            guard entry.entryID == expectedID else {
                throw SaveStoreError.invalidContents
            }
            guard (1...Self.maxShippingQuantity).contains(entry.quantity) else {
                throw SaveStoreError.invalidContents
            }
            guard (0...Self.maxUnitPriceSnapshot).contains(entry.unitPriceSnapshot) else {
                throw SaveStoreError.invalidContents
            }
            guard entry.depositedDay >= 1 else {
                throw SaveStoreError.invalidContents
            }
            _ = try boundedProduct(
                entry.unitPriceSnapshot,
                entry.quantity,
                max: Self.maxLineAmount
            )
        }

        let history = economy.settlementHistory
        let settlementIDs = history.map(\.settlementID)
        guard settlementIDs == settlementIDs.sorted() else {
            throw SaveStoreError.invalidContents
        }
        var seenSettlementIDs = Set<String>()
        for record in history {
            guard seenSettlementIDs.insert(record.settlementID).inserted else {
                throw SaveStoreError.invalidContents
            }
            let expectedID = SettlementRecord.makeID(scenarioID: record.scenarioID, gameDay: record.gameDay)
            guard record.settlementID == expectedID, record.scenarioID == scenarioID, record.gameDay >= 1 else {
                throw SaveStoreError.invalidContents
            }
            guard (0...Self.maxSettlementTotal).contains(record.total) else {
                throw SaveStoreError.invalidContents
            }
            var lineAmounts: [Int] = []
            for line in record.lines {
                guard ContentID.isValid(line.itemID), catalog.knowsItemID(line.itemID) else {
                    throw SaveStoreError.invalidContents
                }
                guard (1...Self.maxShippingQuantity).contains(line.quantity) else {
                    throw SaveStoreError.invalidContents
                }
                guard (0...Self.maxLineAmount).contains(line.amount) else {
                    throw SaveStoreError.invalidContents
                }
                lineAmounts.append(line.amount)
            }
            let summed = try boundedSum(lineAmounts, max: Self.maxSettlementTotal)
            guard summed == record.total else {
                throw SaveStoreError.invalidContents
            }
        }
        for entry in economy.ledger {
            guard !entry.reasonID.isEmpty, !entry.sourceRef.isEmpty, entry.dayIndex >= 1 else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validatePlacedObjects(_ state: GameState, catalog: ContentCatalog) throws {
        var instanceIDs = Set<String>()
        var occupied = Set<GridPosition>()
        let cropCells = Set(state.farmCells.compactMap { coordinate, cell in
            cell.hasCrop ? coordinate : nil
        })
        let exit = catalog.scenario.exitCell
        let playerOnFarm = state.currentMapID == ContentID.farmHomestead
        for object in state.placedObjects {
            guard instanceIDs.insert(object.instanceID).inserted else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(object.definitionID), catalog.knowsPlacedObjectID(object.definitionID) else {
                throw SaveStoreError.invalidContents
            }
            let footprint = PlacementService.absoluteFootprint(
                definitionID: object.definitionID,
                origin: object.origin,
                facing: object.facing,
                catalog: catalog
            )
            guard !footprint.isEmpty else {
                throw SaveStoreError.invalidContents
            }
            for cell in footprint {
                guard cell.isInsideFarm, occupied.insert(cell).inserted, !cropCells.contains(cell) else {
                    throw SaveStoreError.invalidContents
                }
                if playerOnFarm {
                    guard cell != state.position, cell != exit else {
                        throw SaveStoreError.invalidContents
                    }
                } else {
                    guard cell != exit else {
                        throw SaveStoreError.invalidContents
                    }
                }
            }
        }
        let reachStart = playerOnFarm ? state.position : catalog.scenario.playerStart
        guard PlacementService.canReach(exit, from: reachStart, blocked: occupied) else {
            throw SaveStoreError.invalidContents
        }
    }

    private static func validateTutorial(_ tutorial: TutorialState, catalog: ContentCatalog) throws {
        guard catalog.knowsTutorialStepID(tutorial.currentStepID) else {
            throw SaveStoreError.invalidContents
        }
        guard (0...99).contains(tutorial.harvestCount) else {
            throw SaveStoreError.invalidContents
        }
        let order = ContentID.tutorialStepIDs
        var seen = Set<String>()
        for stepID in tutorial.completedStepIDs {
            guard seen.insert(stepID).inserted, catalog.knowsTutorialStepID(stepID) else {
                throw SaveStoreError.invalidContents
            }
        }
        guard Array(order.prefix(tutorial.completedStepIDs.count)) == tutorial.completedStepIDs else {
            throw SaveStoreError.invalidContents
        }
        let expectedCurrent: String
        if tutorial.completedStepIDs.count < order.count {
            expectedCurrent = order[tutorial.completedStepIDs.count]
        } else {
            expectedCurrent = ContentID.tutorialNextDay
        }
        guard tutorial.currentStepID == expectedCurrent else {
            throw SaveStoreError.invalidContents
        }
        if tutorial.completedStepIDs.contains(ContentID.tutorialHarvest) {
            guard tutorial.harvestCount >= 3 else {
                throw SaveStoreError.invalidContents
            }
        }
        if tutorial.completedStepIDs.contains(ContentID.tutorialTalk) {
            guard tutorial.talkedToWaterApprentice else {
                throw SaveStoreError.invalidContents
            }
        }
        if tutorial.completedStepIDs.contains(ContentID.tutorialSave) {
            guard tutorial.didManualSave else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateWatershed(_ state: GameState, catalog: ContentCatalog) throws {
        let watershed = state.watershed
        guard watershed.restorationPoints >= 0, watershed.restorationPoints <= 999 else {
            throw SaveStoreError.invalidContents
        }
        let applied = watershed.appliedContributionIDs
        guard applied == applied.sorted(), Set(applied).count == applied.count else {
            throw SaveStoreError.invalidContents
        }
        var summed = 0
        for contributionID in applied {
            guard ContentID.isValid(contributionID), let definition = catalog.contribution(id: contributionID) else {
                throw SaveStoreError.invalidContents
            }
            summed += definition.points
        }
        guard summed == watershed.restorationPoints else {
            throw SaveStoreError.invalidContents
        }
        let unlocked = watershed.unlockedNodes
        guard unlocked == unlocked.sorted(), Set(unlocked).count == unlocked.count else {
            throw SaveStoreError.invalidContents
        }
        for unlockID in unlocked {
            guard ContentID.isValid(unlockID) else {
                throw SaveStoreError.invalidContents
            }
        }
        let projects = watershed.completedProjects
        guard projects == projects.sorted(), Set(projects).count == projects.count else {
            throw SaveStoreError.invalidContents
        }
        let restored = watershed.restorationPoints >= ContentID.watershedThreshold
        for unlockID in ContentID.watershedThresholdUnlockIDs {
            if restored {
                guard unlocked.contains(unlockID) else {
                    throw SaveStoreError.invalidContents
                }
            } else {
                guard !unlocked.contains(unlockID) else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
        if restored {
            guard projects.contains(ContentID.canalSegmentProject) else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateQuestLog(_ state: GameState, catalog: ContentCatalog) throws {
        let ids = state.questLog.entries.map(\.questID)
        guard ids == ids.sorted(), Set(ids).count == ids.count else {
            throw SaveStoreError.invalidContents
        }
        for entry in state.questLog.entries {
            guard ContentID.isValid(entry.questID), catalog.quest(id: entry.questID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard entry.status != .notStarted else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateHarvestedNodes(_ state: GameState, catalog: ContentCatalog) throws {
        let harvested = state.harvestedGatherNodeIDs
        guard harvested == harvested.sorted(), Set(harvested).count == harvested.count else {
            throw SaveStoreError.invalidContents
        }
        for nodeID in harvested {
            guard let node = catalog.gatherNode(id: nodeID) else {
                throw SaveStoreError.invalidContents
            }
            if let required = node.requiredUnlockID {
                guard state.watershed.unlockedNodes.contains(required) else {
                    throw SaveStoreError.invalidContents
                }
            }
        }
    }

    private static func validateCommunity(_ state: GameState, catalog: ContentCatalog) throws {
        let community = state.community
        let balance = catalog.communityBalance
        guard (balance.minStanding...balance.maxStanding).contains(community.standing) else {
            throw SaveStoreError.invalidContents
        }

        let neighborIDs = community.neighborStates.map(\.npcID)
        guard neighborIDs == neighborIDs.sorted(), Set(neighborIDs).count == neighborIDs.count else {
            throw SaveStoreError.invalidContents
        }
        for neighbor in community.neighborStates {
            guard ContentID.isValid(neighbor.npcID), catalog.npc(id: neighbor.npcID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard neighbor.gossipCooldownUntilDay >= 0 else {
                throw SaveStoreError.invalidContents
            }
        }

        let activeIDs = community.activeEvents.map(\.instanceID)
        let historyIDs = community.eventHistory.map(\.instanceID)
        guard activeIDs == activeIDs.sorted(), historyIDs == historyIDs.sorted() else {
            throw SaveStoreError.invalidContents
        }
        var seenInstanceIDs = Set<String>()
        for event in community.allEvents {
            guard seenInstanceIDs.insert(event.instanceID).inserted else {
                throw SaveStoreError.invalidContents
            }
            try validateEvent(event, catalog: catalog)
        }
        for event in community.activeEvents {
            guard !event.status.isTerminal else {
                throw SaveStoreError.invalidContents
            }
        }
        for event in community.eventHistory {
            guard event.status.isTerminal, event.resolvedDay != nil else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateEvent(
        _ event: GossipEventState,
        catalog: ContentCatalog
    ) throws {
        guard ContentID.isValid(event.instanceID), ContentID.isValid(event.definitionID) else {
            throw SaveStoreError.invalidContents
        }
        guard let definition = catalog.gossipEvent(id: event.definitionID) else {
            throw SaveStoreError.invalidContents
        }
        guard event.claimID == definition.claimID, catalog.gossipClaim(id: event.claimID) != nil else {
            throw SaveStoreError.invalidContents
        }
        guard event.instanceID == ContentID.gossipInstanceID(
            definitionID: event.definitionID,
            offeredDay: event.offeredDay
        ) else {
            throw SaveStoreError.invalidContents
        }
        guard event.offeredDay >= 1 else {
            throw SaveStoreError.invalidContents
        }
        guard event.deadlineDay >= event.offeredDay,
              (0...Self.maxMinute).contains(event.deadlineMinute),
              event.deadlineDay == event.offeredDay + definition.deadlineOffsetDays,
              event.deadlineMinute == definition.deadlineMinute else {
            throw SaveStoreError.invalidContents
        }
        if let resolvedDay = event.resolvedDay {
            guard resolvedDay >= event.offeredDay else {
                throw SaveStoreError.invalidContents
            }
            guard event.status.isTerminal else {
                throw SaveStoreError.invalidContents
            }
        } else if event.status.isTerminal {
            throw SaveStoreError.invalidContents
        }
        if event.status == .resolvedCorrected || event.status == .verified {
            guard event.truthVerified else {
                throw SaveStoreError.invalidContents
            }
        }

        // Action history must be contiguous 1...n and replay the state machine
        // from `offered`. An empty history is legal and must not build a 1...0
        // range, so the sequence check is written as an enumeration.
        var replayed = GossipEventStatus.offered
        for (index, record) in event.actionHistory.enumerated() {
            guard record.sequence == index + 1 else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(record.actionID),
                  let action = catalog.gossipAction(id: record.actionID),
                  definition.actionIDs.contains(record.actionID) else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(record.npcID), catalog.npc(id: record.npcID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard record.day >= event.offeredDay, (0...Self.maxMinute).contains(record.minute) else {
                throw SaveStoreError.invalidContents
            }
            guard action.requiredStatus == replayed,
                  GossipTransitionTable.isLegal(from: replayed, to: action.nextStatus) else {
                throw SaveStoreError.invalidContents
            }
            replayed = action.nextStatus
        }
        let recordedIDs = event.actionHistory.map(\.actionID)
        guard Set(recordedIDs).count == recordedIDs.count else {
            throw SaveStoreError.invalidContents
        }
        if event.actionHistory.isEmpty {
            // Only expiry can end an untouched event.
            guard event.status == .offered || event.status == .expired else {
                throw SaveStoreError.invalidContents
            }
        } else {
            guard event.status == replayed || event.status == .expired else {
                throw SaveStoreError.invalidContents
            }
        }

        let granted = event.grantedEffectIDs
        guard granted == granted.sorted(), Set(granted).count == granted.count else {
            throw SaveStoreError.invalidContents
        }
        for effectID in granted {
            guard catalog.knownGrantEffectIDs.contains(effectID) else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func validateRelationships(_ state: GameState, catalog: ContentCatalog) throws {
        let balance = catalog.communityBalance
        let relationships = state.relationships
        let trustIDs = relationships.trust.map(\.npcID)
        guard trustIDs == trustIDs.sorted(), Set(trustIDs).count == trustIDs.count else {
            throw SaveStoreError.invalidContents
        }
        for record in relationships.trust {
            guard ContentID.isValid(record.npcID), catalog.npc(id: record.npcID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard (0...balance.maxTrustSubpoints).contains(record.subpoints) else {
                throw SaveStoreError.invalidContents
            }
            guard (0..<balance.fixedPointScale).contains(record.remainder) else {
                throw SaveStoreError.invalidContents
            }
            guard record.lastFirstTalkDay >= 0, record.lastFirstTalkDay <= state.clock.day else {
                throw SaveStoreError.invalidContents
            }
        }

        var seenEffects = Set<String>()
        for effect in relationships.effects {
            guard seenEffects.insert("\(effect.npcID)|\(effect.effectID)|\(effect.startDay)").inserted else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(effect.effectID),
                  catalog.relationshipEffect(id: effect.effectID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard ContentID.isValid(effect.npcID), catalog.npc(id: effect.npcID) != nil else {
                throw SaveStoreError.invalidContents
            }
            guard effect.startDay >= 1, effect.endDay >= effect.startDay else {
                throw SaveStoreError.invalidContents
            }
            guard effect.zeroGrowthDay == 0
                || (effect.zeroGrowthDay >= effect.startDay && effect.zeroGrowthDay <= effect.endDay) else {
                throw SaveStoreError.invalidContents
            }
            guard effect.firstTalkStartDay == 0
                || (effect.firstTalkStartDay >= effect.startDay && effect.firstTalkStartDay <= effect.endDay) else {
                throw SaveStoreError.invalidContents
            }
            guard (0...CommunityBalanceDefinition.maxBasisPoints).contains(effect.firstTalkMultiplierBP) else {
                throw SaveStoreError.invalidContents
            }
        }
    }

    private static func boundedProduct(_ lhs: Int, _ rhs: Int, max: Int) throws -> Int {
        let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow, product >= 0, product <= max else {
            throw SaveStoreError.invalidContents
        }
        return product
    }

    private static func boundedSum(_ values: [Int], max: Int) throws -> Int {
        var total = 0
        for value in values {
            let (next, overflow) = total.addingReportingOverflow(value)
            guard !overflow, next >= 0, next <= max else {
                throw SaveStoreError.invalidContents
            }
            total = next
        }
        return total
    }
}
