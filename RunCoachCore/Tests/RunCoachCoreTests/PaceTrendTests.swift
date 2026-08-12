import XCTest
@testable import RunCoachCore

final class PaceTrendTests: XCTestCase {
    func testWorseningAboveThreshold() {
        // Más segundos por km = más lento = empeorando.
        let trend = PaceTrend.classify(recentAverage: 320, previousAverage: 300, thresholdSecondsPerKm: 10)
        XCTAssertEqual(trend, .worsening)
    }

    func testImprovingBelowThreshold() {
        let trend = PaceTrend.classify(recentAverage: 280, previousAverage: 300, thresholdSecondsPerKm: 10)
        XCTAssertEqual(trend, .improving)
    }

    func testStableWithinThreshold() {
        let trend = PaceTrend.classify(recentAverage: 305, previousAverage: 300, thresholdSecondsPerKm: 10)
        XCTAssertEqual(trend, .stable)
    }

    func testExactlyAtThresholdIsStable() {
        let trend = PaceTrend.classify(recentAverage: 310, previousAverage: 300, thresholdSecondsPerKm: 10)
        XCTAssertEqual(trend, .stable)
    }
}
