import XCTest
@testable import RunCoachCore

final class MovingAverageTests: XCTestCase {
    func testEmptyAverageIsNil() {
        let average = MovingAverage(capacity: 3)
        XCTAssertNil(average.value)
        XCTAssertTrue(average.isEmpty)
    }

    func testAverageWithinCapacity() {
        var average = MovingAverage(capacity: 5)
        average.add(10)
        average.add(20)
        average.add(30)
        XCTAssertEqual(average.value, 20)
        XCTAssertEqual(average.sampleCount, 3)
    }

    func testAverageDropsOldestBeyondCapacity() {
        var average = MovingAverage(capacity: 3)
        average.add(10)
        average.add(20)
        average.add(30)
        average.add(100) // debería descartar el 10
        XCTAssertEqual(average.value, 50) // (20 + 30 + 100) / 3
        XCTAssertEqual(average.sampleCount, 3)
    }
}
