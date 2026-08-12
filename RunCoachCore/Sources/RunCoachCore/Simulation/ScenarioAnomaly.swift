import Foundation

/// Un evento puntual e inesperado dentro de un segmento del escenario: una
/// lectura de FC anómala en un instante concreto (glitch de sensor, pico
/// de esfuerzo brusco), independiente de la interpolación normal del
/// segmento.
public struct ScenarioAnomaly: Equatable, Sendable {
    /// Instante, en segundos desde el inicio del segmento (no del
    /// escenario completo), en el que ocurre la anomalía.
    public let atRelativeTime: TimeInterval
    public let heartRateBPMDelta: Int

    public init(atRelativeTime: TimeInterval, heartRateBPMDelta: Int) {
        self.atRelativeTime = atRelativeTime
        self.heartRateBPMDelta = heartRateBPMDelta
    }
}
