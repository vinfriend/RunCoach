import XCTest
@testable import RunCoachCore

final class HeartRateTrendTests: XCTestCase {
    func testRisingAboveThreshold() {
        let trend = HeartRateTrend.classify(recentAverage: 150, previousAverage: 140, thresholdBPM: 3)
        XCTAssertEqual(trend, .rising)
    }

    func testFallingBelowThreshold() {
        let trend = HeartRateTrend.classify(recentAverage: 130, previousAverage: 140, thresholdBPM: 3)
        XCTAssertEqual(trend, .falling)
    }

    func testStableWithinThreshold() {
        let trend = HeartRateTrend.classify(recentAverage: 141, previousAverage: 140, thresholdBPM: 3)
        XCTAssertEqual(trend, .stable)
    }

    func testExactlyAtThresholdIsStable() {
        let trend = HeartRateTrend.classify(recentAverage: 143, previousAverage: 140, thresholdBPM: 3)
        XCTAssertEqual(trend, .stable)
    }
}
