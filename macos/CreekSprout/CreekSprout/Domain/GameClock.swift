struct GameClock: Equatable, Codable, Sendable {
    static let dayStartMinute = 390
    static let dayEndMinute = 1410
    static let gameMinutesPerRealSecond = 1.3

    var day: Int
    var minute: Int

    static let spikeDefault = GameClock(day: 1, minute: dayStartMinute)
}
