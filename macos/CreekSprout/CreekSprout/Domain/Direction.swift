enum Direction: String, Equatable, Codable, Sendable {
    case left
    case right
    case up
    case down

    var deltaX: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var deltaY: Int {
        switch self {
        case .up: return 1
        case .down: return -1
        case .left, .right: return 0
        }
    }
}
