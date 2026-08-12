import XCTest
@testable import RunCoachCore

final class ScenarioSimulatorTests: XCTestCase {

    // MARK: - Frecuencia cardíaca

    func testHeartRateSamplesCoverSegmentAtGivenInterval() {
        let scenario = Scenario(segments: [
            ScenarioSegment(
                name: "test",
                duration: 10,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140
            )
        ])

        let samples = ScenarioSimulator.generateHeartRateSamples(for: scenario, sampleIntervalSeconds: 1)

        XCTAssertEqual(samples.count, 10)
        XCTAssertEqual(samples.first?.timestamp, 0)
        XCTAssertEqual(samples.last?.timestamp, 9)
        XCTAssertTrue(samples.allSatisfy { $0.bpm == 140 })
    }

    func testHeartRateSignalLostProducesNoSamplesForThatSegment() {
        let scenario = Scenario(segments: [
            ScenarioSegment(
                name: "perdida",
                duration: 5,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140,
                heartRateSignalLost: true
            ),
            ScenarioSegment(
                name: "normal",
                duration: 5,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 150,
                endHeartRateBPM: 150
            )
        ])

        let samples = ScenarioSimulator.generateHeartRateSamples(for: scenario, sampleIntervalSeconds: 1)

        XCTAssertEqual(samples.count, 5)
        XCTAssertTrue(samples.allSatisfy { $0.timestamp >= 5 })
        XCTAssertTrue(samples.allSatisfy { $0.bpm == 150 })
    }

    func testAnomalyAppliesOnlyToNearestSample() {
        let scenario = Scenario(segments: [
            ScenarioSegment(
                name: "glitch",
                duration: 10,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140,
                anomalies: [ScenarioAnomaly(atRelativeTime: 5, heartRateBPMDelta: 30)]
            )
        ])

        let samples = ScenarioSimulator.generateHeartRateSamples(for: scenario, sampleIntervalSeconds: 1)

        let affected = samples.filter { $0.timestamp == 5 }
        XCTAssertEqual(affected.first?.bpm, 170)

        let unaffected = samples.filter { $0.timestamp != 5 }
        XCTAssertTrue(unaffected.allSatisfy { $0.bpm == 140 })
    }

    // MARK: - GPS

    func testLocationDistanceMatchesConstantPaceOverTime() {
        // Ritmo constante de 300 seg/km => 3.3333 m/s.
        let scenario = Scenario(segments: [
            ScenarioSegment(
                name: "constante",
                duration: 30,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140
            )
        ])

        let samples = ScenarioSimulator.generateLocationSamples(
            for: scenario,
            sampleIntervalSeconds: 3,
            startLatitude: 40.0,
            startLongitude: -73.0
        )

        XCTAssertFalse(samples.isEmpty)
        // Los timestamps deben ser estrictamente crecientes.
        for (a, b) in zip(samples, samples.dropFirst()) {
            XCTAssertLessThan(a.timestamp, b.timestamp)
        }

        let first = samples.first!
        let last = samples.last!
        let elapsedBetween = last.timestamp - first.timestamp
        let expectedDistance = (1000.0 / 300.0) * elapsedBetween

        XCTAssertEqual(GeoDistance.metersBetween(first, last), expectedDistance, accuracy: 0.5)
    }

    func testLocationSignalLostSkipsEmissionButPositionKeepsIntegrating() {
        let scenario = Scenario(segments: [
            ScenarioSegment(
                name: "perdida",
                duration: 9,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140,
                locationSignalLost: true
            ),
            ScenarioSegment(
                name: "normal",
                duration: 9,
                startPaceSecondsPerKm: 300,
                endPaceSecondsPerKm: 300,
                startHeartRateBPM: 140,
                endHeartRateBPM: 140
            )
        ])

        let samples = ScenarioSimulator.generateLocationSamples(for: scenario, sampleIntervalSeconds: 3)

        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { $0.timestamp >= 9 })
    }
}
