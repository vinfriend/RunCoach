import Foundation

/// La pieza central del proyecto: decide si el coach debería hablar en
/// este momento o quedarse callado. La salida más frecuente tiene que
/// poder ser `.silence` — no es un motor de alertas que dispara en cada
/// muestra, es un filtro deliberadamente conservador.
///
/// Combina tres cosas sobre lo que devuelve `CoachEventDetector`:
///
/// - **Deduplicación**: mientras el mismo evento siga vigente (por
///   ejemplo, la FC sigue subiendo desde hace rato), no lo repite — ya lo
///   dijo una vez.
/// - **Cooldown**: aunque aparezca un evento *distinto* al último que se
///   dijo, no interrumpe de nuevo si no pasó `cooldownSeconds` desde la
///   última intervención.
/// - **Contexto reciente**: mantiene un historial acotado
///   (`recentSpokenEvents`) de lo que ya se dijo, disponible para lógica
///   futura (por ejemplo, Fase 11 podría usarlo para no pedirle a OpenAI
///   una recomendación redundante con algo que ya se dijo).
///
/// **Un evento bloqueado por cooldown no se pierde**: al no marcarse como
/// "ya dicho", se vuelve a ofrecer en la próxima evaluación apenas el
/// cooldown lo permita, mientras la condición que lo generó siga vigente.
/// Ver docs/decisions.md para el razonamiento completo.
///
/// **Sobre "prioridades"**: el arbitraje entre eventos que compiten entre
/// sí vive en `CoachEventDetector`, no acá — cuando la FC sube y el ritmo
/// empeora al mismo tiempo, el detector devuelve `.deteriorating` en vez
/// de `.effortRising`, aunque técnicamente las dos condiciones se
/// cumplan. Este motor solo decide *cuándo* hablar de lo que el detector
/// ya resolvió, no *cuál* de varios candidatos elegir — con un único
/// detector activo, nunca hay más de un candidato por evaluación.
public final class CoachDecisionEngine {
    /// Historial acotado de eventos efectivamente hablados, más reciente
    /// al final.
    public private(set) var recentSpokenEvents: [CoachEvent] = []

    private let cooldownSeconds: TimeInterval
    private let recentEventsLimit: Int
    private var lastSpokenAtSeconds: TimeInterval?

    public init(cooldownSeconds: TimeInterval = 90, recentEventsLimit: Int = 5) {
        precondition(cooldownSeconds >= 0, "cooldownSeconds no puede ser negativo")
        precondition(recentEventsLimit > 0, "recentEventsLimit debe ser mayor a 0")
        self.cooldownSeconds = cooldownSeconds
        self.recentEventsLimit = recentEventsLimit
    }

    public func evaluate(runState: RunState) -> CoachDecision {
        guard let event = CoachEventDetector.detect(runState: runState) else {
            return .silence
        }

        // Deduplicamos por "tipo" de evento (subiendo/bajando), no por
        // igualdad estricta — el BPM asociado cambia en casi cada
        // muestra mientras la tendencia se sostiene (ver `CoachEvent.kind`).
        guard event.kind != recentSpokenEvents.last?.kind else {
            return .silence
        }

        if let lastSpokenAtSeconds, runState.elapsedSeconds - lastSpokenAtSeconds < cooldownSeconds {
            return .silence
        }

        recordSpoken(event, at: runState.elapsedSeconds)
        return .speak(event)
    }

    private func recordSpoken(_ event: CoachEvent, at timestamp: TimeInterval) {
        recentSpokenEvents.append(event)
        if recentSpokenEvents.count > recentEventsLimit {
            recentSpokenEvents.removeFirst(recentSpokenEvents.count - recentEventsLimit)
        }
        lastSpokenAtSeconds = timestamp
    }
}
