import XCTest
@testable import RunCoachCore

/// Tests sobre el escenario de referencia de 20 minutos descrito en
/// docs/testing.md — el "golden path" que ejercita RunState de punta a
/// punta con datos sintéticos reproducibles, sin hardware.
final class ReferenceScenarioTests: XCTestCase {

    func testTotalDurationIsTwentyMinutes() {
        XCTAssertEqual(Scenario.referenceRun.totalDuration, 1200)
    }

    func testFullRunThroughMockSourcesProducesPlausibleMetrics() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .referenceRun)
        let locationSamples = ScenarioSimulator.generateLocationSamples(for: .referenceRun, startLatitude: 40.0)

        let state = RunState()
        let hrSource = MockHeartRateSource(samples: heartRateSamples)
        let locationSource = MockLocationSource(samples: locationSamples)
        hrSource.onSample = { [weak state] in state?.ingest(heartRate: $0) }
        locationSource.onSample = { [weak state] in state?.ingest(location: $0) }

        hrSource.start()
        locationSource.start()

        XCTAssertEqual(state.elapsedSeconds, 1199, accuracy: 1)

        // ~3485m calculados de forma independiente para este escenario
        // (ver docs/decisions.md) — margen generoso porque el muestreo de
        // ubicación cada 3s (vs. la integración interna cada 1s) recorta
        // un poco el principio y el final.
        XCTAssertEqual(state.totalDistanceMeters, 3485, accuracy: 50)

        // A ~3.5km con splits de 1000m, esperamos 3 splits completos.
        XCTAssertEqual(state.splits.count, 3)
    }

    func testHeartRateTrendIsRisingDuringBuildupPhase() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .referenceRun)
        let state = RunState()

        // t=450s: 150s dentro del segmento "aumento_de_ritmo" (300-600s),
        // con margen suficiente para que la ventana de suavizado y el
        // lookback de 60s queden completamente dentro del tramo de subida.
        for sample in heartRateSamples where sample.timestamp <= 450 {
            state.ingest(heartRate: sample)
        }

        XCTAssertEqual(state.heartRateTrend, .rising)
    }

    func testHeartRateTrendIsFallingDuringRecoveryPhase() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .referenceRun)
        let state = RunState()

        // t=1050s: 150s dentro del segmento "recuperacion" (900-1200s).
        for sample in heartRateSamples where sample.timestamp <= 1050 {
            state.ingest(heartRate: sample)
        }

        XCTAssertEqual(state.heartRateTrend, .falling)
    }

    func testHeartRateTrendIsStableDuringWarmup() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .referenceRun)
        let state = RunState()

        // t=200s: dentro del calentamiento (0-300s), que sube muy poco
        // (118 -> 128 en 300s) — no debería disparar "rising" con el
        // umbral por defecto de 3 bpm.
        for sample in heartRateSamples where sample.timestamp <= 200 {
            state.ingest(heartRate: sample)
        }

        XCTAssertEqual(state.heartRateTrend, .stable)
    }

    /// El test más importante de esta fase: corre el escenario de
    /// referencia completo (1200 muestras de FC) a través del Coach
    /// Decision Engine y verifica el criterio de docs/testing.md — la
    /// salida más frecuente debe ser silencio, no una intervención por
    /// muestra.
    func testCoachDecisionEngineSpeaksSparinglyAcrossFullRun() {
        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: .referenceRun)
        let state = RunState()
        let engine = CoachDecisionEngine()

        var spokenEvents: [CoachEvent] = []
        for sample in heartRateSamples {
            state.ingest(heartRate: sample)
            if case .speak(let event) = engine.evaluate(runState: state) {
                spokenEvents.append(event)
            }
        }

        XCTAssertLessThanOrEqual(spokenEvents.count, 3)
        XCTAssertGreaterThanOrEqual(
            spokenEvents.count, 1,
            "el escenario tiene un tramo de subida y uno de recuperación; el motor no debería quedarse mudo del todo"
        )
    }
}
