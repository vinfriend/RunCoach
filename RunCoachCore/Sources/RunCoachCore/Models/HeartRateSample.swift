import Foundation

/// Una lectura puntual de frecuencia cardíaca.
///
/// `timestamp` es el tiempo transcurrido en segundos desde el inicio de la
/// carrera (no una fecha de calendario). Esto hace que `RunState` sea
/// determinista y fácil de testear, y es lo que el Simulation Engine
/// (Fase 3) va a poder controlar directamente sin depender del reloj real.
public struct HeartRateSample: Equatable, Sendable {
    public let bpm: Int
    public let timestamp: TimeInterval

    public init(bpm: Int, timestamp: TimeInterval) {
        self.bpm = bpm
        self.timestamp = timestamp
    }
}
