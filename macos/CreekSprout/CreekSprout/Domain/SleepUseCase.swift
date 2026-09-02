struct SleepUseCase: Sendable {
    private let dayCycle = DayCycleService()

    /// Builds the post-sleep candidate first, writes autosave, then commits.
    /// Save failure restores `GameState` and `ClockSystem` to the pre-sleep snapshot.
    @discardableResult
    func sleep(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog,
        store: SaveStore? = nil,
        persist: (@Sendable (GameState) throws -> Void)? = nil,
        stageObserver: ((SleepPipelineStage, GameState) throws -> Void)? = nil
    ) throws -> DayEndSummary {
        let previousState = state
        let previousClock = clock.snapshot()
        var candidate = state
        do {
            let summary = try dayCycle.settleTransaction(
                state: &candidate,
                clock: clock,
                catalog: catalog,
                stageObserver: stageObserver
            )
            try SaveValidation.validate(candidate, catalog: catalog)
            try stageObserver?(.validated, candidate)
            if let persist {
                try persist(candidate)
            } else if let store {
                try store.save(candidate)
            }
            try stageObserver?(.saved, candidate)
            state = candidate
            return summary
        } catch {
            state = previousState
            clock.restore(previousClock)
            throw error
        }
    }
}
