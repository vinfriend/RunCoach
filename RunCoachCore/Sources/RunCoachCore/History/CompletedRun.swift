import Foundation

/// El resumen de una carrera ya terminada — lo que se guarda en el
/// historial (Fase 19) para poder mostrarlo después. A diferencia de
/// `HeartRateSample`/`LocationSample` (timestamps relativos, pensados
/// para determinismo en tests/simulación), `startedAt` sí es un `Date`
/// real: acá lo que importa es "cuándo pasó esto de verdad", no
/// reproducibilidad.
public struct CompletedRun: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let durationSeconds: TimeInterval
    public let totalDistanceMeters: Double
    public let averageHeartRateBPM: Double?
    public let splits: [Split]
    /// `"simulated"` o `"real"` — una etiqueta simple, no el `RunMode` de
    /// `RunCoach-iOS` (que vive en la capa de UI). Evita acoplar
    /// `RunCoachCore` a un tipo que no le pertenece.
    public let mode: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        durationSeconds: TimeInterval,
        totalDistanceMeters: Double,
        averageHeartRateBPM: Double?,
        splits: [Split],
        mode: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.totalDistanceMeters = totalDistanceMeters
        self.averageHeartRateBPM = averageHeartRateBPM
        self.splits = splits
        self.mode = mode
    }

    /// Construye el resumen a partir de un `RunState` ya terminado.
    public static func make(mode: String, startedAt: Date, runState: RunState) -> CompletedRun {
        CompletedRun(
            startedAt: startedAt,
            durationSeconds: runState.elapsedSeconds,
            totalDistanceMeters: runState.totalDistanceMeters,
            averageHeartRateBPM: runState.averageHeartRateBPM,
            splits: runState.splits,
            mode: mode
        )
    }
}
