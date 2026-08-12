import XCTest
@testable import RunCoachCore

final class CoachEventDetectorTests: XCTestCase {

    func testNilBeforeAnyHeartRateData() {
        let state = RunState()
        XCTAssertNil(CoachEventDetector.detect(runState: state))
    }

    func testNilWhileStable() {
        let state = RunState(heartRateWindowSize: 3)
        state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: 0))
        state.ingest(heartRate: HeartRateSample(bpm: 131, timestamp: 10))
        state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: 20))
        XCTAssertNil(CoachEventDetector.detect(runState: state))
    }

    func testDetectsRisingEffort() {
        let state = RunState(heartRateWindowSize: 3, trendLookbackSeconds: 60, trendThresholdBPM: 3)
        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }

        guard case .effortRising(let bpm) = CoachEventDetector.detect(runState: state) else {
            return XCTFail("se esperaba .effortRising")
        }
        XCTAssertEqual(bpm, 160)
    }

    func testDetectsFallingEffort() {
        let state = RunState(heartRateWindowSize: 3, trendLookbackSeconds: 60, trendThresholdBPM: 3)
        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }

        guard case .effortFalling(let bpm) = CoachEventDetector.detect(runState: state) else {
            return XCTFail("se esperaba .effortFalling")
        }
        XCTAssertEqual(bpm, 130)
    }
}
