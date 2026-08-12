import Foundation

/// Observa el estado actual de una carrera y clasifica si hay un
/// `CoachEvent` candidato en este momento — sin memoria de lo que pasó
/// antes, sin decidir si vale la pena decirlo. Esa parte (deduplicación,
/// cooldown, contexto reciente) es responsabilidad de
/// `CoachDecisionEngine`, que es quien lo consume.
///
/// Separar "¿hay algo que observar ahora?" (acá) de "¿vale la pena
/// decirlo ahora?" (`CoachDecisionEngine`) es lo que permite que un
/// evento bloqueado por cooldown se pueda re-ofrecer más adelante sin
/// depender de que la tendencia "resetee" — ver docs/decisions.md para
/// el detalle.
public enum CoachEventDetector {
    public static func detect(runState: RunState) -> CoachEvent? {
        guard let bpm = runState.smoothedHeartRateBPM else { return nil }

        // Prioridad: si la FC sube Y el ritmo empeora al mismo tiempo, eso
        // es más específico y accionable que "el esfuerzo está subiendo"
        // solo (que también incluye el caso normal de acelerar a
        // propósito) — ver CoachEvent.deteriorating. Es el primer caso
        // real de arbitraje entre dos señales que compiten; antes de
        // agregar paceTrend, no había nada que priorizar.
        if runState.heartRateTrend == .rising,
           runState.paceTrend == .worsening,
           let pace = runState.currentPaceSecondsPerKm {
            return .deteriorating(currentBPM: bpm, currentPaceSecondsPerKm: pace)
        }

        switch runState.heartRateTrend {
        case .rising:
            return .effortRising(currentBPM: bpm)
        case .falling:
            return .effortFalling(currentBPM: bpm)
        case .stable:
            return nil
        }
    }
}
