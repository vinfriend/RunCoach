import Foundation

/// Un segmento de carrera completado (por defecto, cada 1000m), con sus
/// métricas promedio. `RunState` genera uno cada vez que se cruza el umbral
/// de distancia configurado.
public struct Split: Equatable, Sendable, Codable {
    public let index: Int
    public let distanceMeters: Double
    public let durationSeconds: TimeInterval
    public let averageHeartRateBPM: Double?

    public init(
        index: Int,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        averageHeartRateBPM: Double?
    ) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.averageHeartRateBPM = averageHeartRateBPM
    }

    /// Ritmo promedio del split, en segundos por kilómetro.
    public var averagePaceSecondsPerKm: Double? {
        guard distanceMeters > 0 else { return nil }
        return durationSeconds / (distanceMeters / 1000)
    }
}
