import Foundation

/// Un escenario completo de carrera simulada: una secuencia de segmentos
/// que, encadenados, describen cómo evolucionan el ritmo y la FC a lo
/// largo del tiempo. Sirve tanto para tests deterministas de
/// `RunCoachCore` como, más adelante, para probar el Coach Decision
/// Engine (Fase 10) sin necesidad de hardware ni de salir a correr.
public struct Scenario: Sendable {
    public let segments: [ScenarioSegment]

    public init(segments: [ScenarioSegment]) {
        precondition(!segments.isEmpty, "un escenario necesita al menos un segmento")
        self.segments = segments
    }

    public var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// El escenario de referencia de 20 minutos descrito en
    /// docs/testing.md: calentamiento estable, aumento de ritmo con FC
    /// subiendo, esfuerzo sostenido con deriva cardíaca (la FC sigue
    /// subiendo aunque el ritmo ya no cambia — el "evento importante" es
    /// justamente esa deriva sostenida, no un glitch puntual), y
    /// recuperación.
    public static let referenceRun = Scenario(segments: [
        ScenarioSegment(
            name: "calentamiento",
            duration: 300,
            startPaceSecondsPerKm: 390, // 6:30 min/km
            endPaceSecondsPerKm: 390,
            startHeartRateBPM: 118,
            endHeartRateBPM: 128
        ),
        ScenarioSegment(
            name: "aumento_de_ritmo",
            duration: 300,
            startPaceSecondsPerKm: 390,
            endPaceSecondsPerKm: 300, // 5:00 min/km
            startHeartRateBPM: 128,
            endHeartRateBPM: 155
        ),
        ScenarioSegment(
            name: "esfuerzo_sostenido",
            duration: 300,
            startPaceSecondsPerKm: 300,
            endPaceSecondsPerKm: 300,
            startHeartRateBPM: 155,
            endHeartRateBPM: 172
        ),
        ScenarioSegment(
            name: "recuperacion",
            duration: 300,
            startPaceSecondsPerKm: 300,
            endPaceSecondsPerKm: 420, // 7:00 min/km
            startHeartRateBPM: 172,
            endHeartRateBPM: 138
        )
    ])

    /// Escenario corto para ejercitar resiliencia: pérdida de señal (GPS y
    /// FC) seguida de un glitch puntual de sensor. No es el "golden path"
    /// — es para tests específicos de robustez de `RunState` ante datos
    /// incompletos o ruidosos.
    public static let signalLossAndAnomalyDemo = Scenario(segments: [
        ScenarioSegment(
            name: "perdida_de_señal",
            duration: 120,
            startPaceSecondsPerKm: 330,
            endPaceSecondsPerKm: 330,
            startHeartRateBPM: 140,
            endHeartRateBPM: 140,
            heartRateSignalLost: true,
            locationSignalLost: true
        ),
        ScenarioSegment(
            name: "glitch_de_sensor",
            duration: 60,
            startPaceSecondsPerKm: 330,
            endPaceSecondsPerKm: 330,
            startHeartRateBPM: 140,
            endHeartRateBPM: 142,
            anomalies: [ScenarioAnomaly(atRelativeTime: 30, heartRateBPMDelta: 40)]
        )
    ])
}
