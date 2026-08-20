enum WatershedFailure: Equatable, Error, Sendable {
    case unknownContribution
    case sourceMismatch
    case missingPrerequisite
    case invalidPoints
}

struct WatershedApplyResult: Equatable, Sendable {
    var state: GameState
    var didApply: Bool
    var pointsAwarded: Int
}

enum WatershedService {
    static let restorationThreshold = ContentID.watershedThreshold

    static func apply(
        state: GameState,
        contributionID: String,
        sourceEventID: String,
        catalog: ContentCatalog
    ) -> Result<WatershedApplyResult, WatershedFailure> {
        guard let definition = catalog.contribution(id: contributionID) else {
            return .failure(.unknownContribution)
        }
        guard definition.points >= 0 else {
            return .failure(.invalidPoints)
        }
        guard definition.sourceEventID == sourceEventID else {
            return .failure(.sourceMismatch)
        }

        var next = state
        if definition.oneTime, next.watershed.hasApplied(contributionID) {
            next = reconcile(next)
            return .success(WatershedApplyResult(state: next, didApply: false, pointsAwarded: 0))
        }
        for prerequisite in definition.prerequisiteIDs {
            guard next.watershed.hasApplied(prerequisite) else {
                return .failure(.missingPrerequisite)
            }
        }

        next.watershed.appliedContributionIDs.append(contributionID)
        next.watershed.appliedContributionIDs.sort()
        next.watershed.restorationPoints += definition.points
        next = reconcile(next)
        return .success(
            WatershedApplyResult(state: next, didApply: true, pointsAwarded: definition.points)
        )
    }

    static func reconcile(_ state: GameState) -> GameState {
        var next = state
        next.watershed.appliedContributionIDs = uniqueSorted(next.watershed.appliedContributionIDs)
        next.watershed.unlockedNodes = uniqueSorted(next.watershed.unlockedNodes)
        next.watershed.completedProjects = uniqueSorted(next.watershed.completedProjects)
        next.harvestedGatherNodeIDs = uniqueSorted(next.harvestedGatherNodeIDs)

        guard next.watershed.restorationPoints >= restorationThreshold else {
            return next
        }

        for unlockID in ContentID.watershedThresholdUnlockIDs {
            if !next.watershed.unlockedNodes.contains(unlockID) {
                next.watershed.unlockedNodes.append(unlockID)
            }
        }
        next.watershed.unlockedNodes = uniqueSorted(next.watershed.unlockedNodes)

        if !next.watershed.completedProjects.contains(ContentID.canalSegmentProject) {
            next.watershed.completedProjects.append(ContentID.canalSegmentProject)
            next.watershed.completedProjects = uniqueSorted(next.watershed.completedProjects)
        }
        return next
    }

    private static func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }
}
