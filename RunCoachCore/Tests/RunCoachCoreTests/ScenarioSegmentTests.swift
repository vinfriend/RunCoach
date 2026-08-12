import XCTest
@testable import RunCoachCore

final class ScenarioSegmentTests: XCTestCase {
    func testPaceInterpolatesLinearly() {
        let segment = ScenarioSegment(
            name: "test",
            duration: 100,
            startPaceSecondsPerKm: 400,
            endPaceSecondsPerKm: 300,
            startHeartRateBPM: 120,
            endHeartRateBPM: 120
        )
        XCTAssertEqual(segment.paceSecondsPerKm(at: 0), 400)
        XCTAssertEqual(segment.paceSecondsPerKm(at: 50), 350)
        XCTAssertEqual(segment.paceSecondsPerKm(at: 100), 300)
    }

    func testHeartRateInterpolatesLinearly() {
        let segment = ScenarioSegment(
            name: "test",
            duration: 100,
            startPaceSecondsPerKm: 300,
            endPaceSecondsPerKm: 300,
            startHeartRateBPM: 120,
            endHeartRateBPM: 160
        )
        XCTAssertEqual(segment.heartRateBPM(at: 0), 120)
        XCTAssertEqual(segment.heartRateBPM(at: 50), 140)
        XCTAssertEqual(segment.heartRateBPM(at: 100), 160)
    }

    func testInterpolationClampsOutsideDuration() {
        let segment = ScenarioSegment(
            name: "test",
            duration: 100,
            startPaceSecondsPerKm: 400,
            endPaceSecondsPerKm: 300,
            startHeartRateBPM: 120,
            endHeartRateBPM: 160
        )
        XCTAssertEqual(segment.paceSecondsPerKm(at: -10), 400)
        XCTAssertEqual(segment.paceSecondsPerKm(at: 200), 300)
        XCTAssertEqual(segment.heartRateBPM(at: -10), 120)
        XCTAssertEqual(segment.heartRateBPM(at: 200), 160)
    }

    func testConstantSegmentStaysFlat() {
        let segment = ScenarioSegment(
            name: "estable",
            duration: 300,
            startPaceSecondsPerKm: 390,
            endPaceSecondsPerKm: 390,
            startHeartRateBPM: 130,
            endHeartRateBPM: 130
        )
        XCTAssertEqual(segment.paceSecondsPerKm(at: 150), 390)
        XCTAssertEqual(segment.heartRateBPM(at: 150), 130)
    }
}
