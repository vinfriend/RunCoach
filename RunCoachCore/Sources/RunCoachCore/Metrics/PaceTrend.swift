import Foundation

/// Clasificación simple de hacia dónde se mueve el ritmo — mismo patrón
/// que `HeartRateTrend`. `improving` significa más rápido (menos
/// segundos por km); `worsening`, más lento.
public enum PaceTrend: Equatable, Sendable {
    case improving
    case worsening
    case stable

    /// Compara el ritmo suavizado reciente contra uno previo y clasifica
    /// según un umbral en segundos/km, para que fluctuaciones menores no
    /// se marquen como tendencia — mismo criterio que
    /// `HeartRateTrend.classify`.
    public static func classify(
        recentAverage: Double,
        previousAverage: Double,
        thresholdSecondsPerKm: Double = 10
    ) -> PaceTrend {
        let delta = recentAverage - previousAverage
        if delta > thresholdSecondsPerKm {
            return .worsening
        } else if delta < -thresholdSecondsPerKm {
            return .improving
        } else {
            return .stable
        }
    }
}
