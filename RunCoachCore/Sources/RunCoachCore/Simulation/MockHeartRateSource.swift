import Foundation

/// Fuente de FC simulada: reproduce una secuencia de muestras
/// pre-generadas (típicamente por `ScenarioSimulator`) llamando a
/// `onSample` en orden. Implementa `HeartRateSource` para que `RunState`
/// no distinga esta fuente de una real (`BLEHeartRateSource`, Fase 6).
///
/// La reproducción es síncrona e inmediata (sin temporizador real): es lo
/// que necesita el Simulation Mode para tests deterministas en Windows. El
/// ritmo de reproducción en tiempo real para pruebas interactivas en la
/// app (Fase 9+) es una necesidad de una fase posterior y se puede agregar
/// sin cambiar el protocolo `HeartRateSource`.
public final class MockHeartRateSource: HeartRateSource {
    public var onSample: ((HeartRateSample) -> Void)?
    private let samples: [HeartRateSample]
    public private(set) var isRunning = false

    public init(samples: [HeartRateSample]) {
        self.samples = samples
    }

    public func start() {
        isRunning = true
        for sample in samples {
            guard isRunning else { break }
            onSample?(sample)
        }
        isRunning = false
    }

    public func stop() {
        isRunning = false
    }
}
