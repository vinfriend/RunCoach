import Foundation

/// Una lectura puntual de posición GPS.
///
/// `timestamp` es el tiempo transcurrido en segundos desde el inicio de la
/// carrera, igual que en `HeartRateSample` — ver esa nota para el motivo.
public struct LocationSample: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: TimeInterval
    public let horizontalAccuracyMeters: Double?

    public init(
        latitude: Double,
        longitude: Double,
        timestamp: TimeInterval,
        horizontalAccuracyMeters: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}
