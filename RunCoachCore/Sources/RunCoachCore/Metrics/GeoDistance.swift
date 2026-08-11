import Foundation

/// Cálculo de distancia entre coordenadas GPS usando la fórmula de
/// Haversine. Suficientemente precisa para distancias de running (error
/// despreciable frente al ruido normal del GPS de un iPhone).
public enum GeoDistance {
    private static let earthRadiusMeters = 6_371_000.0

    public static func metersBetween(_ a: LocationSample, _ b: LocationSample) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180

        let sinDeltaLat = sin(deltaLat / 2)
        let sinDeltaLon = sin(deltaLon / 2)

        let h = sinDeltaLat * sinDeltaLat
            + cos(lat1) * cos(lat2) * sinDeltaLon * sinDeltaLon
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))

        return earthRadiusMeters * c
    }
}
