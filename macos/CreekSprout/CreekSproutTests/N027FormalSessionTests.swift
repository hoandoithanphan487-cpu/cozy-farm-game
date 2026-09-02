import Foundation
import XCTest
@testable import CreekSprout

final class N027FormalSessionTests: XCTestCase {
    private var sandbox: URL!
    private var service: FormalGameSessionService!
    private let catalog = ContentCatalog.vs0

    override func setUpWithError() throws {
        sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CreekSprout-N027-Formal-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sandbox,
            withIntermediateDirectories: true
        )
        service = .debugFixture(sandboxRoot: sandbox, catalog: catalog)
    }

    override func tearDownWithError() throws {
        if let sandbox {
            try? FileManager.default.removeItem(at: sandbox)
        }
        service = nil
        sandbox = nil
    }

    func testListsExactlyThreeManualSlotsWithLatestCampaignSummaryAndUnreadableSafety() throws {
        XCTAssertEqual(
            service.manualSlots().map(\.state),
            [.empty, .empty, .empty]
        )

        let launch = try createCampaign(in: 0)
        var automatic = launch.state
        automatic.clock = GameClock(day: 6, minute: 735)
        automatic.economy.balance = 2_468
        automatic.community.standing = 72
        _ = try coordinator.save(
            automatic,
            kind: .campaignAuto,
            ownerManualSlot: launch.ownerManualSlot
        )

        try FileManager.default.createDirectory(
            at: service.storageRoot,
            withIntermediateDirectories: true
        )
        try Data("not-a-save".utf8).write(
            to: service.storageRoot.appendingPathComponent(
                "\(SaveSlotCatalog.manualSlotNames[1]).json"
            ),
            options: .atomic
        )

        let slots = service.manualSlots()
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.map(\.slotIndex), [0, 1, 2])
        XCTAssertEqual(slots.map(\.ownerManualSlot), SaveSlotCatalog.manualSlotNames)
        XCTAssertEqual(slots[0].campaign?.campaignID, launch.campaignID)
        XCTAssertEqual(slots[0].campaign?.generationKind, .campaignAuto)
        XCTAssertEqual(slots[0].campaign?.day, 6)
        XCTAssertEqual(slots[0].campaign?.minute, 735)
        XCTAssertEqual(slots[0].campaign?.balance, 2_468)
        XCTAssertEqual(slots[0].campaign?.standing, 72)
        XCTAssertEqual(slots[1].state, .unreadable)
        XCTAssertTrue(slots[2].isEmpty)

        let occupied = try service.prepareNewGame(inManualSlot: 0)
        XCTAssertTrue(occupied.requiresOverwriteConfirmation)
        XCTAssertEqual(occupied.replacingCampaign?.campaignID, launch.campaignID)
        let unreadable = try service.prepareNewGame(inManualSlot: 1)
        XCTAssertTrue(unreadable.requiresOverwriteConfirmation)
        XCTAssertTrue(unreadable.replacesUnreadableSave)
        let empty = try service.prepareNewGame(inManualSlot: 2)
        XCTAssertFalse(empty.requiresOverwriteConfirmation)
        XCTAssertNil(empty.replacingCampaign)
    }

    func testPreparingThenCancellingOverwritePerformsZeroWrites() throws {
        let launch = try createCampaign(in: 0)
        var automatic = launch.state
        automatic.clock = GameClock(day: 4, minute: 810)
        _ = try coordinator.save(
            automatic,
            kind: .campaignAuto,
            ownerManualSlot: launch.ownerManualSlot
        )
        let before = try filesystemSnapshot(at: service.storageRoot)

        let request = try service.prepareNewGame(inManualSlot: 0)
        XCTAssertTrue(request.requiresOverwriteConfirmation)
        XCTAssertEqual(request.replacingCampaign?.campaignID, launch.campaignID)
        // UI cancellation is deliberately represented by discarding this
        // read-only request instead of invoking its confirmation token.
        _ = request

        XCTAssertEqual(try filesystemSnapshot(at: service.storageRoot), before)
        XCTAssertEqual(service.manualSlots()[0].campaign?.campaignID, launch.campaignID)
    }

    func testFailedConfirmedCreationIsAtomicAndKeepsExistingCampaignReadable() throws {
        let launch = try createCampaign(in: 0)
        _ = try coordinator.save(
            launch.state,
            kind: .campaignAuto,
            ownerManualSlot: launch.ownerManualSlot
        )
        let request = try service.prepareNewGame(inManualSlot: 0)
        let before = try filesystemSnapshot(at: service.storageRoot)

        XCTAssertThrowsError(
            try service.confirmNewGame(
                using: request.confirmationToken,
                debugStateFactory: { campaignID in
                    var invalid = GameState.vs0NewGame(
                        catalog: self.catalog,
                        campaignID: campaignID
                    )
                    invalid.stamina = -1
                    return invalid
                }
            )
        ) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .persistenceFailure)
        }

        XCTAssertEqual(try filesystemSnapshot(at: service.storageRoot), before)
        let continued = try service.continueGame()
        XCTAssertEqual(continued.campaignID, launch.campaignID)
        XCTAssertEqual(continued.ownerManualSlot, launch.ownerManualSlot)
    }

    func testStaleConfirmationTokenRefusesChangedCampaignWithoutFurtherWrites() throws {
        let launch = try createCampaign(in: 0)
        let request = try service.prepareNewGame(inManualSlot: 0)
        var advanced = launch.state
        advanced.clock = GameClock(day: 2, minute: 900)
        _ = try coordinator.save(
            advanced,
            kind: .campaignAuto,
            ownerManualSlot: launch.ownerManualSlot
        )
        let afterAdvance = try filesystemSnapshot(at: service.storageRoot)

        XCTAssertThrowsError(
            try service.confirmNewGame(using: request.confirmationToken)
        ) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .staleConfirmationToken)
        }
        XCTAssertEqual(
            try filesystemSnapshot(at: service.storageRoot),
            afterAdvance
        )
        XCTAssertEqual(service.manualSlots()[0].campaign?.day, 2)
    }

    func testConfirmedOverwriteOnlyTouchesTargetSlotAndItsOwnedCampaign() throws {
        let original = try (0..<3).map(createCampaign(in:))
        for (index, launch) in original.enumerated() {
            var automatic = launch.state
            automatic.clock = GameClock(day: index + 2, minute: 700 + index)
            automatic.economy.balance = 1_000 + index
            _ = try coordinator.save(
                automatic,
                kind: .campaignAuto,
                ownerManualSlot: launch.ownerManualSlot
            )
        }
        let settingsURL = service.storageRoot.appendingPathComponent("settings.json")
        let settingsData = Data("settings-must-survive".utf8)
        try settingsData.write(to: settingsURL, options: .atomic)
        let before = try filesystemSnapshot(at: service.storageRoot)

        let request = try service.prepareNewGame(inManualSlot: 0)
        XCTAssertTrue(request.requiresOverwriteConfirmation)
        let replacement = try service.confirmNewGame(
            using: request.confirmationToken
        )

        XCTAssertNotEqual(replacement.campaignID, original[0].campaignID)
        XCTAssertEqual(replacement.manualSlotIndex, 0)
        XCTAssertEqual(replacement.ownerManualSlot, SaveSlotCatalog.manualSlotNames[0])
        XCTAssertEqual(replacement.generationKind, .manual)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: coordinator.campaignDirectory(original[0].campaignID).path
        ))
        XCTAssertEqual(try Data(contentsOf: settingsURL), settingsData)

        let slots = service.manualSlots()
        XCTAssertEqual(slots[0].campaign?.campaignID, replacement.campaignID)
        XCTAssertEqual(slots[1].campaign?.campaignID, original[1].campaignID)
        XCTAssertEqual(slots[2].campaign?.campaignID, original[2].campaignID)

        let after = try filesystemSnapshot(at: service.storageRoot)
        let changed = changedPaths(before: before, after: after)
        XCTAssertFalse(changed.isEmpty)
        XCTAssertTrue(changed.allSatisfy { path in
            path.hasPrefix("\(SaveSlotCatalog.manualSlotNames[0]).")
                || path.hasPrefix("campaigns/\(original[0].campaignID)/")
        }, "Unexpected cross-slot mutation: \(changed.sorted())")
    }

    func testDuplicateCampaignOwnershipBlocksOverwriteInsteadOfDeletingSharedCompanions() throws {
        let launch = try createCampaign(in: 0)
        _ = try coordinator.save(
            launch.state,
            kind: .campaignAuto,
            ownerManualSlot: launch.ownerManualSlot
        )
        let secondOwner = SaveSlotCatalog.manualSlotNames[1]
        let duplicateMetadata = SaveGenerationMetadata(
            campaignID: launch.campaignID,
            ownerManualSlot: secondOwner,
            generationKind: .manual,
            saveSequence: 100,
            writtenAtMilliseconds: 100_000
        )
        let duplicateData = try SaveCodec.encode(
            launch.state,
            generationMetadata: duplicateMetadata
        )
        try duplicateData.write(
            to: service.storageRoot.appendingPathComponent("\(secondOwner).json"),
            options: .atomic
        )
        let request = try service.prepareNewGame(inManualSlot: 0)
        let before = try filesystemSnapshot(at: service.storageRoot)

        XCTAssertThrowsError(
            try service.confirmNewGame(using: request.confirmationToken)
        ) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .ambiguousCampaignOwnership)
        }
        XCTAssertEqual(try filesystemSnapshot(at: service.storageRoot), before)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: coordinator.campaignDirectory(launch.campaignID)
                .appendingPathComponent("campaign_auto.json").path
        ))
    }

    func testContinueUsesCoordinatorRankingAndRejectsCrossBoundProtectionKinds() throws {
        let first = try createCampaign(in: 0)
        let second = try createCampaign(in: 1)
        var advancedFirst = first.state
        advancedFirst.clock = GameClock(day: 9, minute: 660)
        advancedFirst.economy.balance = 9_001
        let automatic = try coordinator.save(
            advancedFirst,
            kind: .campaignAuto,
            ownerManualSlot: first.ownerManualSlot
        )
        _ = try coordinator.save(
            second.state,
            kind: .preReveal,
            ownerManualSlot: second.ownerManualSlot
        )

        let forgedMetadata = SaveGenerationMetadata(
            campaignID: second.campaignID,
            ownerManualSlot: second.ownerManualSlot,
            generationKind: .missionCurrent,
            saveSequence: automatic.saveSequence + 1_000,
            writtenAtMilliseconds: automatic.writtenAtMilliseconds + 1_000
        )
        let forgedData = try SaveCodec.encode(
            second.state,
            generationMetadata: forgedMetadata
        )
        let crossedMissionURL = coordinator.campaignDirectory(first.campaignID)
            .appendingPathComponent("mission_current.json")
        try forgedData.write(to: crossedMissionURL, options: .atomic)

        let continued = try service.continueGame()
        XCTAssertEqual(continued.campaignID, first.campaignID)
        XCTAssertEqual(continued.manualSlotIndex, 0)
        XCTAssertEqual(continued.ownerManualSlot, first.ownerManualSlot)
        XCTAssertEqual(continued.generationKind, .campaignAuto)
        XCTAssertEqual(continued.state.clock.day, 9)
        XCTAssertEqual(continued.state.economy.balance, 9_001)
        XCTAssertNotEqual(continued.generationKind, .preReveal)
        XCTAssertNotEqual(continued.generationKind, .missionCurrent)
    }

    func testEmptyContinueAndInvalidSlotFailWithoutCreatingFiles() throws {
        XCTAssertThrowsError(try service.prepareNewGame(inManualSlot: -1)) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .invalidManualSlot)
        }
        XCTAssertThrowsError(try service.prepareNewGame(inManualSlot: 3)) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .invalidManualSlot)
        }
        XCTAssertThrowsError(try service.continueGame()) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .noContinuableCampaign)
        }
        XCTAssertEqual(try filesystemSnapshot(at: service.storageRoot), [:])
    }

    func testDebugFixtureIsExplicitlyIsolatedAndFactoryCannotRunOnProductionScope() throws {
        let productionRoot = sandbox.appendingPathComponent("production", isDirectory: true)
        let production = FormalGameSessionService(
            productionRoot: productionRoot,
            catalog: catalog
        )
        XCTAssertNotEqual(production.storageRoot, service.storageRoot)
        XCTAssertEqual(
            service.storageRoot.lastPathComponent,
            "n027-formal-session-fixture"
        )
        let request = try production.prepareNewGame(inManualSlot: 0)
        XCTAssertThrowsError(
            try production.confirmNewGame(
                using: request.confirmationToken,
                debugStateFactory: { GameState.vs0NewGame(campaignID: $0) }
            )
        ) { error in
            XCTAssertEqual(error as? FormalGameSessionError, .debugFixtureRequired)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: productionRoot.path))
    }

    private var coordinator: CampaignSaveCoordinator {
        CampaignSaveCoordinator(rootDirectory: service.storageRoot, catalog: catalog)
    }

    private func createCampaign(in slotIndex: Int) throws -> FormalSessionLaunch {
        let request = try service.prepareNewGame(inManualSlot: slotIndex)
        return try service.confirmNewGame(using: request.confirmationToken)
    }

    private func filesystemSnapshot(at root: URL) throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [:] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            XCTFail("Unable to enumerate \(root.path)")
            return [:]
        }
        var result: [String: Data] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let relative = String(
                url.standardizedFileURL.path.dropFirst(
                    root.standardizedFileURL.path.count + 1
                )
            )
            if values.isDirectory == true {
                result[relative + "/"] = Data("directory".utf8)
            } else if values.isRegularFile == true {
                result[relative] = try Data(contentsOf: url)
            }
        }
        return result
    }

    private func changedPaths(
        before: [String: Data],
        after: [String: Data]
    ) -> Set<String> {
        Set(before.keys).union(after.keys).filter { before[$0] != after[$0] }
    }
}
