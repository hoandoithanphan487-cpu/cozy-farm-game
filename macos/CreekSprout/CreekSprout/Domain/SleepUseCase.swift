struct SleepUseCase: Sendable {
    private let dayCycle = DayCycleService()

    /// Builds the post-sleep candidate first, writes autosave, then commits.
    /// Save failure restores `GameState` and `ClockSystem` to the pre-sleep snapshot.
    @discardableResult
    func sleep(
        state: inout GameState,
        clock: ClockSystem,
        catalog: ContentCatalog,
        store: SaveStore? = nil
    ) throws -> DayEndSummary {
        let previousState = state
        let previousClock = clock.snapshot()
        var candidate = state
        let summary = dayCycle.settle(state: &candidate, clock: clock, catalog: catalog)
        do {
            if let store {
                try store.save(candidate)
            }
            state = candidate
            return summary
        } catch {
            state = previousState
            clock.restore(previousClock)
            throw error
        }
    }
}
