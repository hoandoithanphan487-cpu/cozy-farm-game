enum ItemQuality: String, Equatable, Codable, Sendable {
    case normal
    case good
    case excellent

    /// Quality multiplier in basis points (normal 100 = 1.00×).
    var multiplierBp: Int {
        switch self {
        case .normal: return 100
        case .good: return 118
        case .excellent: return 142
        }
    }
}
