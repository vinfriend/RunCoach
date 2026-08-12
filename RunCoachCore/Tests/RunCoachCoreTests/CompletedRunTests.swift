import XCTest
@testable import RunCoachCore

final class CompletedRunTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let run = CompletedRun(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 1234,
            totalDistanceMeters: 5000,
            averageHeartRateBPM: 145.5,
            splits: [
                Split(index: 0, distanceMeters: 1000, durationSeconds: 300, averageHeartRateBPM: 140)
            ],
            mode: "simulated"
        )

        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(CompletedRun.self, from: data)

        XCTAssertEqual(decoded, run)
    }

    func testMakeBuildsFromRunState() {
        let state = RunState(splitDistanceMeters: 1000)
        let step = 0.0009
        state.ingest(heartRate: HeartRateSample(bpm: 140, timestamp: 0))
        state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: 200))
        for i in 0...10 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let run = CompletedRun.make(mode: "real", startedAt: startedAt, runState: state)

        XCTAssertEqual(run.startedAt, startedAt)
        XCTAssertEqual(run.durationSeconds, state.elapsedSeconds)
        XCTAssertEqual(run.totalDistanceMeters, state.totalDistanceMeters)
        XCTAssertEqual(run.averageHeartRateBPM, 150) // (140+160)/2
        XCTAssertEqual(run.splits.count, 1)
        XCTAssertEqual(run.mode, "real")
    }
}
