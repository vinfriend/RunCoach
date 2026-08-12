import XCTest
@testable import RunCoachCore

final class RunStateTests: XCTestCase {

    // MARK: - Frecuencia cardíaca

    func testSmoothedHeartRateIsNilBeforeAnySample() {
        let state = RunState()
        XCTAssertNil(state.smoothedHeartRateBPM)
    }

    func testSmoothedHeartRateAveragesRecentSamples() {
        let state = RunState(heartRateWindowSize: 3)
        state.ingest(heartRate: HeartRateSample(bpm: 140, timestamp: 0))
        state.ingest(heartRate: HeartRateSample(bpm: 150, timestamp: 10))
        state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: 20))
        XCTAssertEqual(state.smoothedHeartRateBPM, 150)
    }

    func testAverageHeartRateIsNilBeforeAnySample() {
        let state = RunState()
        XCTAssertNil(state.averageHeartRateBPM)
    }

    func testAverageHeartRateCoversWholeRunNotJustRecentWindow() {
        // A diferencia de smoothedHeartRateBPM (ventana chica), esto
        // promedia TODAS las muestras, aunque la ventana de suavizado
        // sea mucho más chica que la cantidad de muestras ingeridas.
        let state = RunState(heartRateWindowSize: 2)
        state.ingest(heartRate: HeartRateSample(bpm: 100, timestamp: 0))
        state.ingest(heartRate: HeartRateSample(bpm: 200, timestamp: 10))
        state.ingest(heartRate: HeartRateSample(bpm: 150, timestamp: 20))
        // Promedio de las 3: (100+200+150)/3 = 150. La ventana suavizada
        // (últimas 2) daría (200+150)/2 = 175 — distinto a propósito.
        XCTAssertEqual(state.averageHeartRateBPM, 150)
        XCTAssertEqual(state.smoothedHeartRateBPM, 175)
    }

    func testHeartRateTrendIsStableWithoutEnoughHistory() {
        let state = RunState()
        state.ingest(heartRate: HeartRateSample(bpm: 140, timestamp: 0))
        XCTAssertEqual(state.heartRateTrend, .stable)
    }

    func testHeartRateTrendDetectsRisingEffort() {
        let state = RunState(heartRateWindowSize: 3, trendLookbackSeconds: 60, trendThresholdBPM: 3)

        // Fase estable: ~130 bpm.
        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }

        // Fase de esfuerzo: sube a 160 bpm, más de 60s después de la fase estable.
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }

        XCTAssertEqual(state.heartRateTrend, .rising)
    }

    func testHeartRateTrendReturnsToStableAfterSustainedEffort() {
        let state = RunState(heartRateWindowSize: 3, trendLookbackSeconds: 60, trendThresholdBPM: 3)

        for t in stride(from: 0.0, through: 30, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 130, timestamp: t))
        }
        for t in stride(from: 90.0, through: 120, by: 10) {
            state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: t))
        }
        // Se sostiene el esfuerzo: 60s+ después ya no hay "subida" reciente.
        state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: 200))

        XCTAssertEqual(state.heartRateTrend, .stable)
    }

    // MARK: - Distancia y ritmo

    func testDistanceAccumulatesAcrossLocationSamples() {
        let state = RunState()
        // ~0.0009 grados de latitud ≈ 100m.
        let start = 40.0
        let step = 0.0009

        for i in 0..<5 {
            state.ingest(location: LocationSample(
                latitude: start - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        XCTAssertEqual(state.totalDistanceMeters, 400, accuracy: 2)
    }

    func testCurrentPaceReflectsConstantSpeed() {
        let state = RunState(paceWindowSize: 5)
        let step = 0.0009 // ~100m
        // 100m cada 30s => 300 seg/km de ritmo constante.
        for i in 0..<5 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        XCTAssertEqual(state.currentPaceSecondsPerKm ?? -1, 300, accuracy: 1)
    }

    func testIgnoresLocationSamplesWithNoTimeProgress() {
        let state = RunState()
        state.ingest(location: LocationSample(latitude: 40.0, longitude: -73.0, timestamp: 0))
        // Muestra duplicada/desordenada: mismo timestamp.
        state.ingest(location: LocationSample(latitude: 40.001, longitude: -73.0, timestamp: 0))

        XCTAssertNil(state.currentPaceSecondsPerKm)
    }

    // MARK: - Splits

    func testNoSplitBeforeReachingThreshold() {
        let state = RunState(splitDistanceMeters: 1000)
        let step = 0.0009 // ~100m
        for i in 0..<5 { // 400m acumulados
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }
        XCTAssertTrue(state.splits.isEmpty)
    }

    func testSplitGeneratedWhenCrossingThreshold() {
        let state = RunState(splitDistanceMeters: 1000)
        let step = 0.0009 // ~100m
        // 10 muestras de 100m cada 30s = 1000m en 300s (ritmo 5:00/km).
        for i in 0...10 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        XCTAssertEqual(state.splits.count, 1)
        let split = state.splits[0]
        XCTAssertEqual(split.index, 0)
        XCTAssertEqual(split.distanceMeters, 1000, accuracy: 5)
        XCTAssertEqual(split.durationSeconds, 300, accuracy: 1)
        XCTAssertEqual(split.averagePaceSecondsPerKm ?? -1, 300, accuracy: 2)
    }

    func testSplitIncludesAverageHeartRateSinceLastSplit() {
        let state = RunState(splitDistanceMeters: 1000, heartRateWindowSize: 20)
        let step = 0.0009

        state.ingest(heartRate: HeartRateSample(bpm: 140, timestamp: 0))
        state.ingest(heartRate: HeartRateSample(bpm: 150, timestamp: 150))
        state.ingest(heartRate: HeartRateSample(bpm: 160, timestamp: 300))

        for i in 0...10 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        XCTAssertEqual(state.splits.count, 1)
        XCTAssertEqual(state.splits[0].averageHeartRateBPM, 150) // (140+150+160)/3
    }

    func testMultipleSplitsGeneratedOverLongerRun() {
        let state = RunState(splitDistanceMeters: 1000)
        let step = 0.0009 // ~100m
        // 22 pasos de ~100m => ~2200m, con margen suficiente por encima de
        // 2000m (y por debajo de 3000m) para no depender de redondeos del
        // cálculo de Haversine.
        for i in 0...22 {
            state.ingest(location: LocationSample(
                latitude: 40.0 - Double(i) * step,
                longitude: -73.0,
                timestamp: Double(i) * 30
            ))
        }

        XCTAssertEqual(state.splits.count, 2)
        XCTAssertEqual(state.splits[0].index, 0)
        XCTAssertEqual(state.splits[1].index, 1)
    }
}
