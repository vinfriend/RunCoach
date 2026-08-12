import Foundation

/// Arma el request de OpenAI Chat Completions a partir de un
/// `CoachEventSummary` — lógica pura de formateo de texto y JSON, sin
/// red. `gpt-4o-mini` y `maxTokens` bajo son control de costo
/// deliberado: la frecuencia de llamadas ya está acotada por
/// `CoachDecisionEngine` (cooldown + deduplicación), así que no hace
/// falta además un modelo caro para mantener el gasto bajo.
public struct OpenAICoachRequestBuilder: Sendable {
    public let model: String
    public let systemPrompt: String
    public let maxTokens: Int
    public let temperature: Double

    public init(
        model: String = "gpt-4o-mini",
        systemPrompt: String = OpenAICoachRequestBuilder.defaultSystemPrompt,
        maxTokens: Int = 60,
        temperature: Double = 0.7
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    public static let defaultSystemPrompt = """
    Sos un coach de running conciso y prudente, hablando en español \
    rioplatense. Respondés en una sola frase corta (máximo 20 palabras), \
    sin emojis y sin signos de exclamación de más. No das consejos \
    médicos ni diagnósticos, solo coaching deportivo. Tu respuesta se lee \
    en voz alta durante la carrera, así que tiene que sonar natural y \
    breve.
    """

    public func build(for summary: CoachEventSummary) -> OpenAIChatRequest {
        OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt(for: summary))
            ],
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    func userPrompt(for summary: CoachEventSummary) -> String {
        let minutes = Int(summary.elapsedSeconds) / 60
        let km = summary.totalDistanceMeters / 1000

        let eventDescription: String
        switch summary.event {
        case .effortRising(let bpm):
            eventDescription = "la frecuencia cardíaca viene subiendo de forma sostenida, ahora está en \(Int(bpm.rounded())) por minuto"
        case .effortFalling(let bpm):
            eventDescription = "la frecuencia cardíaca viene bajando de forma sostenida, ahora está en \(Int(bpm.rounded())) por minuto"
        }

        let paceDescription: String
        if let pace = summary.currentPaceSecondsPerKm, pace.isFinite {
            let paceMinutes = Int(pace) / 60
            let paceSeconds = Int(pace) % 60
            paceDescription = "ritmo actual \(paceMinutes):\(String(format: "%02d", paceSeconds)) por kilómetro"
        } else {
            paceDescription = "sin datos de ritmo todavía"
        }

        return """
        Minuto \(minutes) de carrera, \(String(format: "%.1f", km)) km recorridos, \(paceDescription). \
        Evento detectado: \(eventDescription). Dale una recomendación breve al corredor.
        """
    }
}
