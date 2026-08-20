struct ClockSnapshot: Equatable, Sendable {
    var accumulatedMinutes: Double
    var pauseReasons: Set<PauseReason>
}

final class ClockSystem {
    private var accumulatedMinutes = 0.0
    private var pauseReasons: Set<PauseReason> = []

    func snapshot() -> ClockSnapshot {
        ClockSnapshot(accumulatedMinutes: accumulatedMinutes, pauseReasons: pauseReasons)
    }

    func restore(_ snapshot: ClockSnapshot) {
        accumulatedMinutes = snapshot.accumulatedMinutes
        pauseReasons = snapshot.pauseReasons
    }

    var isPaused: Bool {
        !pauseReasons.isEmpty
    }

    func addPauseReason(_ reason: PauseReason) {
        pauseReasons.insert(reason)
    }

    func removePauseReason(_ reason: PauseReason) {
        pauseReasons.remove(reason)
    }

    func containsPauseReason(_ reason: PauseReason) -> Bool {
        pauseReasons.contains(reason)
    }

    @discardableResult
    func advance(state: inout GameState, deltaSeconds: Double) -> Int {
        guard !isPaused, deltaSeconds > 0 else {
            return 0
        }
        accumulatedMinutes += deltaSeconds * GameClock.gameMinutesPerRealSecond
        let wholeMinutes = Int(accumulatedMinutes.rounded(.down))
        guard wholeMinutes > 0 else {
            return 0
        }
        accumulatedMinutes -= Double(wholeMinutes)
        let currentMinute = state.clock.minute
        let advanced = min(wholeMinutes, GameClock.dayEndMinute - currentMinute)
        state.clock.minute = currentMinute + max(advanced, 0)
        return max(advanced, 0)
    }

    func beginNextDay(state: inout GameState) {
        state.clock.day += 1
        state.clock.minute = GameClock.dayStartMinute
        accumulatedMinutes = 0
    }
}
