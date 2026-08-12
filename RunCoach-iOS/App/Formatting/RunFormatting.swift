import Foundation

/// Formateo de métricas de carrera para mostrar en pantalla — compartido
/// entre `RunView`, `HistoryView` y `RunDetailView` para no repetir la
/// misma lógica tres veces (y el mismo tipo de bug: antes de esto,
/// `RunView` truncaba el ritmo y `RunDetailView` lo redondeaba — el mismo
/// formato dando resultados levemente distintos según la pantalla).
enum RunFormatting {
    static func duration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    static func distance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    static func pace(_ secondsPerKm: Double?, whenMissing: String = "sin datos") -> String {
        guard let secondsPerKm, secondsPerKm.isFinite else { return whenMissing }
        let totalSeconds = Int(secondsPerKm.rounded())
        return String(format: "%d:%02d /km", totalSeconds / 60, totalSeconds % 60)
    }
}
