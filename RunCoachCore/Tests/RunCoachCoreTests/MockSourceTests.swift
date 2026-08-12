import XCTest
@testable import RunCoachCore

final class MockSourceTests: XCTestCase {
    func testMockHeartRateSourceReplaysAllSamplesInOrder() {
        let samples = [
            HeartRateSample(bpm: 120, timestamp: 0),
            HeartRateSample(bpm: 130, timestamp: 1),
            HeartRateSample(bpm: 140, timestamp: 2)
        ]
        let source = MockHeartRateSource(samples: samples)
        var received: [HeartRateSample] = []
        source.onSample = { received.append($0) }

        source.start()

        XCTAssertEqual(received, samples)
        XCTAssertFalse(source.isRunning)
    }

    func testMockLocationSourceReplaysAllSamplesInOrder() {
        let samples = [
            LocationSample(latitude: 40.0, longitude: -73.0, timestamp: 0),
            LocationSample(latitude: 40.001, longitude: -73.0, timestamp: 3)
        ]
        let source = MockLocationSource(samples: samples)
        var received: [LocationSample] = []
        source.onSample = { received.append($0) }

        source.start()

        XCTAssertEqual(received, samples)
        XCTAssertFalse(source.isRunning)
    }

    func testMockHeartRateSourceStopsEarlyWhenStoppedDuringReplay() {
        let samples = (0..<5).map { HeartRateSample(bpm: 120 + $0, timestamp: TimeInterval($0)) }
        let source = MockHeartRateSource(samples: samples)
        var received: [HeartRateSample] = []
        source.onSample = { sample in
            received.append(sample)
            if sample.timestamp == 2 {
                source.stop()
            }
        }

        source.start()

        XCTAssertEqual(received.count, 3) // timestamps 0, 1, 2
    }

    func testMockSourcesFeedRunStateDirectly() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .signalLossAndAnomalyDemo)
        let locationSamples = ScenarioSimulator.generateLocationSamples(for: .signalLossAndAnomalyDemo)

        let state = RunState()
        let hrSource = MockHeartRateSource(samples: heartRateSamples)
        let locationSource = MockLocationSource(samples: locationSamples)
        hrSource.onSample = { [weak state] in state?.ingest(heartRate: $0) }
        locationSource.onSample = { [weak state] in state?.ingest(location: $0) }

        hrSource.start()
        locationSource.start()

        // El escenario de pérdida de señal + glitch no debería romper nada;
        // al menos debería haberse ingerido el tramo con datos.
        XCTAssertFalse(state.heartRateSamples.isEmpty)
        XCTAssertGreaterThanOrEqual(state.elapsedSeconds, 150) // duración total del escenario
    }
}
