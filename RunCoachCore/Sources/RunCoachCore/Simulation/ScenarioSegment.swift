import Foundation

/// Un tramo de un escenario simulado: ritmo y frecuencia cardíaca
/// interpolan linealmente entre un valor inicial y uno final a lo largo de
/// `duration`. Encadenando varios segmentos se arman escenarios completos
/// (calentamiento, aumento de ritmo, esfuerzo sostenido, recuperación,
/// etc.) — ver `Scenario`.
public struct ScenarioSegment: Sendable {
    public let name: String
    public let duration: TimeInterval
    public let startPaceSecondsPerKm: Double
    public let endPaceSecondsPerKm: Double
    public let startHeartRateBPM: Int
    public let endHeartRateBPM: Int
    /// Si es `true`, `ScenarioSimulator` no genera ninguna muestra de FC
    /// durante este segmento (simula, por ejemplo, que la pulsera se
    /// desconectó).
    public let heartRateSignalLost: Bool
    /// Igual que `heartRateSignalLost` pero para GPS. La posición real
    /// sigue integrándose internamente — al recuperar señal, la siguiente
    /// muestra refleja un salto de distancia, tal como pasaría con GPS
    /// real reconectando.
    public let locationSignalLost: Bool
    public let anomalies: [ScenarioAnomaly]

    public init(
        name: String,
        duration: TimeInterval,
        startPaceSecondsPerKm: Double,
        endPaceSecondsPerKm: Double,
        startHeartRateBPM: Int,
        endHeartRateBPM: Int,
        heartRateSignalLost: Bool = false,
        locationSignalLost: Bool = false,
        anomalies: [ScenarioAnomaly] = []
    ) {
        precondition(duration > 0, "duration debe ser mayor a 0")
        self.name = name
        self.duration = duration
        self.startPaceSecondsPerKm = startPaceSecondsPerKm
        self.endPaceSecondsPerKm = endPaceSecondsPerKm
        self.startHeartRateBPM = startHeartRateBPM
        self.endHeartRateBPM = endHeartRateBPM
        self.heartRateSignalLost = heartRateSignalLost
        self.locationSignalLost = locationSignalLost
        self.anomalies = anomalies
    }

    /// Ritmo interpolado linealmente en el instante `t` (segundos desde el
    /// inicio de este segmento).
    func paceSecondsPerKm(at t: TimeInterval) -> Double {
        let fraction = min(max(t / duration, 0), 1)
        return startPaceSecondsPerKm + (endPaceSecondsPerKm - startPaceSecondsPerKm) * fraction
    }

    /// FC interpolada linealmente en el instante `t` (sin contar
    /// anomalías, que se aplican aparte en `ScenarioSimulator`).
    func heartRateBPM(at t: TimeInterval) -> Int {
        let fraction = min(max(t / duration, 0), 1)
        let base = Double(startHeartRateBPM) + Double(endHeartRateBPM - startHeartRateBPM) * fraction
        return Int(base.rounded())
    }
}
