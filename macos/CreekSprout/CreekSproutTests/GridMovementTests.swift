import XCTest
@testable import CreekSprout

final class GridMovementTests: XCTestCase {
    func testPlayerCannotLeaveTenBySixBounds() {
        var origin = GameState.spikeDefault
        origin.position = GridPosition(x: 0, y: 0)
        XCTAssertFalse(origin.move(.left))
        XCTAssertFalse(origin.move(.down))
        XCTAssertEqual(origin.position, GridPosition(x: 0, y: 0))
        XCTAssertTrue(origin.move(.right))
        XCTAssertEqual(origin.position, GridPosition(x: 1, y: 0))
        XCTAssertTrue(origin.move(.up))
        XCTAssertEqual(origin.position, GridPosition(x: 1, y: 1))

        var farCorner = GameState.spikeDefault
        farCorner.position = GridPosition(x: 9, y: 5)
        XCTAssertFalse(farCorner.move(.right))
        XCTAssertFalse(farCorner.move(.up))
        XCTAssertEqual(farCorner.position, GridPosition(x: 9, y: 5))
        XCTAssertTrue(farCorner.move(.left))
        XCTAssertEqual(farCorner.position, GridPosition(x: 8, y: 5))
        XCTAssertTrue(farCorner.move(.down))
        XCTAssertEqual(farCorner.position, GridPosition(x: 8, y: 4))
    }

    func testMovedPositionIsNilOutsideFarm() {
        XCTAssertNil(GridPosition(x: 0, y: 3).moved(in: .left))
        XCTAssertNil(GridPosition(x: 9, y: 3).moved(in: .right))
        XCTAssertNil(GridPosition(x: 4, y: 0).moved(in: .down))
        XCTAssertNil(GridPosition(x: 4, y: 5).moved(in: .up))
        XCTAssertEqual(GridPosition(x: 4, y: 2).moved(in: .up), GridPosition(x: 4, y: 3))
    }

    func testTenBySixRejectsTheContractedOutsideCoordinates() {
        let invalid = [
            GridPosition(x: 10, y: 0),
            GridPosition(x: 0, y: 6),
            GridPosition(x: -1, y: 0),
            GridPosition(x: 0, y: -1),
        ]
        for coordinate in invalid {
            XCTAssertFalse(coordinate.isInsideFarm, "\(coordinate.x),\(coordinate.y) must be outside the 10×6 farm")
        }
        XCTAssertTrue(GridPosition(x: 0, y: 0).isInsideFarm)
        XCTAssertTrue(GridPosition(x: 9, y: 5).isInsideFarm)
    }

    func testFacingUpdatesAndTargetCellStaysInsideFarm() {
        var state = GameState.spikeDefault
        state.position = GridPosition(x: 0, y: 0)
        XCTAssertFalse(state.move(.left))
        XCTAssertEqual(state.facing, .left)
        XCTAssertEqual(state.targetCell, GridPosition(x: 0, y: 0))
        XCTAssertTrue(state.move(.right))
        XCTAssertEqual(state.facing, .right)
        XCTAssertEqual(state.targetCell, GridPosition(x: 2, y: 0))
    }
}
