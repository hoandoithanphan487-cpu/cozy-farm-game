struct GridPosition: Equatable, Hashable, Codable, Sendable {
    static let columnCount = 10
    static let rowCount = 6

    var x: Int
    var y: Int

    var isInsideFarm: Bool {
        (0..<Self.columnCount).contains(x) && (0..<Self.rowCount).contains(y)
    }

    func moved(in direction: Direction) -> GridPosition? {
        let next = GridPosition(x: x + direction.deltaX, y: y + direction.deltaY)
        return next.isInsideFarm ? next : nil
    }
}
