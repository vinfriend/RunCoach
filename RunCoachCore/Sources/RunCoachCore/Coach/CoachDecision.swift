import Foundation

/// El resultado de `CoachDecisionEngine.evaluate(runState:)`. La salida
/// más frecuente debe ser `.silence` — la intervención solo se justifica
/// cuando aporta valor real (ver docs/decisions.md).
public enum CoachDecision: Equatable, Sendable {
    case silence
    case speak(CoachEvent)
}
