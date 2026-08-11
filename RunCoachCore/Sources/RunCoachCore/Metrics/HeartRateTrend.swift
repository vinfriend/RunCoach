import Foundation

/// Clasificación simple de hacia dónde se mueve la frecuencia cardíaca.
/// No es un evento del Coach Decision Engine (eso es Fase 10) — es solo el
/// dato de tendencia que ese motor va a consumir más adelante.
public enum HeartRateTrend: Equatable, Sendable {
    case rising
    case falling
    case stable

    /// Compara la media móvil reciente contra una media móvil previa y
    /// clasifica la tendencia según un umbral en BPM. Con `thresholdBPM` se
    /// evita que fluctuaciones menores (ruido del sensor) se marquen como
    /// tendencia.
    public static func classify(
        recentAverage: Double,
        previousAverage: Double,
        thresholdBPM: Double = 3
    ) -> HeartRateTrend {
        let delta = recentAverage - previousAverage
        if delta > thresholdBPM {
            return .rising
        } else if delta < -thresholdBPM {
            return .falling
        } else {
            return .stable
        }
    }
}
