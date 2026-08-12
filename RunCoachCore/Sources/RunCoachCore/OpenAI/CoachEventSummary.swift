import Foundation

/// Resumen estructurado de la carrera en el momento en que
/// `CoachDecisionEngine` decidió que hay algo que vale la pena decir.
/// Es lo que se le manda a OpenAI — nunca las muestras crudas, y nunca
/// más seguido que lo que el motor de decisión ya filtró (ver
/// docs/openai.md).
public struct CoachEventSummary: Equatable, Sendable {
    public let event: CoachEvent
    public let elapsedSeconds: TimeInterval
    public let totalDistanceMeters: Double
    public let currentPaceSecondsPerKm: Double?
    public let heartRateTrend: HeartRateTrend

    public init(
        event: CoachEvent,
        elapsedSeconds: TimeInterval,
        totalDistanceMeters: Double,
        currentPaceSecondsPerKm: Double?,
        heartRateTrend: HeartRateTrend
    ) {
        self.event = event
        self.elapsedSeconds = elapsedSeconds
        self.totalDistanceMeters = totalDistanceMeters
        self.currentPaceSecondsPerKm = currentPaceSecondsPerKm
        self.heartRateTrend = heartRateTrend
    }

    /// Construye el resumen a partir del estado actual de la carrera, en
    /// el instante de la decisión — un snapshot por valor, no una
    /// referencia al `RunState` (que sigue mutando después).
    public static func make(event: CoachEvent, runState: RunState) -> CoachEventSummary {
        CoachEventSummary(
            event: event,
            elapsedSeconds: runState.elapsedSeconds,
            totalDistanceMeters: runState.totalDistanceMeters,
            currentPaceSecondsPerKm: runState.currentPaceSecondsPerKm,
            heartRateTrend: runState.heartRateTrend
        )
    }
}
