import XCTest
@testable import RunCoachCore

final class CoachDecisionEngineTests: XCTestCase {

    /// Construye un `RunState` con una tendencia de FC controlada
    /// (subiendo o bajando, según `baselineBPM`/`changedBPM`) que termina
    /// exactamente en `endTimestamp` — para poder controlar con precisión
    /// el `elapsedSeconds` que ve `CoachDecisionEngine`, sin depender de
    /// escenarios completos. `trendLookbackSeconds: 10` y
    /// `heartRateWindowSize: 2` mantienen esto compacto: la tendencia
    /// queda establecida en ~20 segundos de datos.
    private func makeState(baselineBPM: Int, changedBPM: Int, endTimestamp: TimeInterval) -> RunState {
        let state = RunState(heartRateWindowSize: 2, trendLookbackSeconds: 10, trendThresholdBPM: 3)
        state.ingest(heartRate: HeartRateSample(bpm: baselineBPM, timestamp: endTimestamp - 20))
        state.ingest(heartRate: HeartRateSample(bpm: baselineBPM, timestamp: endTimestamp - 15))
        state.ingest(heartRate: HeartRateSample(bpm: changedBPM, timestamp: endTimestamp - 5))
        state.ingest(heartRate: HeartRateSample(bpm: changedBPM, timestamp: endTimestamp))
        return state
    }

    private func risingState(at endTimestamp: TimeInterval) -> RunState {
        makeState(baselineBPM: 130, changedBPM: 160, endTimestamp: endTimestamp)
    }

    private func fallingState(at endTimestamp: TimeInterval) -> RunState {
        makeState(baselineBPM: 160, changedBPM: 100, endTimestamp: endTimestamp)
    }

    func testSilenceWhenNoEventDetected() {
        let engine = CoachDecisionEngine()
        let state = RunState()
        XCTAssertEqual(engine.evaluate(runState: state), .silence)
    }

    func testFirstDetectedEventSpeaksImmediately() {
        let engine = CoachDecisionEngine()
        let decision = engine.evaluate(runState: risingState(at: 120))
        XCTAssertEqual(decision, .speak(.effortRising(currentBPM: 160)))
    }

    func testDeduplicatesSameEventWhileSustained() {
        let engine = CoachDecisionEngine()
        _ = engine.evaluate(runState: risingState(at: 120))

        let decision = engine.evaluate(runState: risingState(at: 121))
        XCTAssertEqual(decision, .silence)
    }

    func testCooldownBlocksADifferentEventTooSoon() {
        let engine = CoachDecisionEngine(cooldownSeconds: 20)

        let first = engine.evaluate(runState: risingState(at: 120))
        XCTAssertEqual(first, .speak(.effortRising(currentBPM: 160)))

        // Solo 10s después — por debajo del cooldown de 20s — aunque el
        // evento sea distinto (cayendo, no subiendo).
        let blocked = engine.evaluate(runState: fallingState(at: 130))
        XCTAssertEqual(blocked, .silence)
    }

    func testBlockedEventIsRetriedOnceCooldownExpires() {
        let engine = CoachDecisionEngine(cooldownSeconds: 20)

        _ = engine.evaluate(runState: risingState(at: 120))
        _ = engine.evaluate(runState: fallingState(at: 130)) // bloqueado por cooldown

        // 25s después del último evento hablado (120) — ya pasó el cooldown.
        let retried = engine.evaluate(runState: fallingState(at: 145))
        XCTAssertEqual(retried, .speak(.effortFalling(currentBPM: 100)))
    }

    func testRecentSpokenEventsTracksBoundedHistory() {
        let engine = CoachDecisionEngine(cooldownSeconds: 0, recentEventsLimit: 2)

        _ = engine.evaluate(runState: risingState(at: 100))
        _ = engine.evaluate(runState: fallingState(at: 200))
        _ = engine.evaluate(runState: risingState(at: 300))

        XCTAssertEqual(engine.recentSpokenEvents, [
            .effortFalling(currentBPM: 100),
            .effortRising(currentBPM: 160)
        ])
    }
}
