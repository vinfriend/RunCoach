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

    func testDetectsDeteriorationWhenEffortRisesAndPaceWorsensTogether() {
        let state = RunState(
            heartRateWindowSize: 3,
            paceWindowSize: 2,
            trendLookbackSeconds: 60,
            trendThresholdBPM: 3,
            paceTrendThresholdSecondsPerKm: 10
        )
        let step = 0.0009 // ~100m

        // FC subiendo (mismo patrón que testDetectsRisingEffort).
        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }

        // Ritmo empeorando al mismo tiempo (mismo patrón que
        // RunStateTests.testPaceTrendDetectsWorsening).
        for i in 0...2 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 20
            ))
        }
        state.ingest(location: LocationSample(latitude: 40.0 - 3 * step, longitude: -73.0, timestamp: 80))
        state.ingest(location: LocationSample(latitude: 40.0 - 4 * step, longitude: -73.0, timestamp: 120))

        guard case .deteriorating(let bpm, let pace) = CoachEventDetector.detect(runState: state) else {
            return XCTFail("se esperaba .deteriorating")
        }
        XCTAssertEqual(bpm, 160)
        XCTAssertEqual(pace, 400, accuracy: 1)
    }

    func testEffortRisingWithoutPaceDataIsNotMistakenForDeterioration() {
        // FC subiendo, sin ninguna muestra de ubicación: paceTrend es
        // .stable por falta de datos, no .worsening — no debería
        // confundirse con deterioro.
        let state = RunState(heartRateWindowSize: 3, trendLookbackSeconds: 60, trendThresholdBPM: 3)
        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }

        guard case .effortRising = CoachEventDetector.detect(runState: state) else {
            return XCTFail("se esperaba .effortRising, no .deteriorating")
        }
    }
}
