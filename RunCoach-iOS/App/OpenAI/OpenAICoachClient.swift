import Foundation
import RunCoachCore

/// Consulta a OpenAI una recomendación de coaching para un evento que
/// `CoachDecisionEngine` (RunCoachCore, Fase 10) ya decidió que vale la
/// pena mencionar. El request/response en sí (`OpenAICoachRequestBuilder`/
/// `OpenAICoachResponseParser`) son lógica pura de RunCoachCore, testeada
/// en Windows — acá solo vive lo que necesita `URLSession` de verdad.
///
/// **Nunca bloquea el motor de carrera ni lanza errores hacia quien
/// llama**: sin API key, sin red, timeout, respuesta inesperada — todo
/// termina en `nil`, y quien orquesta la carrera (`RunSessionViewModel`)
/// cae de vuelta a la frase fija en español. "Sin recomendación" es un
/// resultado válido, no una excepción.
///
/// Sin validar contra la API real todavía — no hay una API key configurada
/// en este entorno (Fase 11 recién construye la integración; probarla con
/// una key real es una acción de Vicente, ver PROJECT_STATUS.md).
final class OpenAICoachClient {
    private let apiKeyProvider: () -> String?
    private let requestBuilder: OpenAICoachRequestBuilder
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(
        apiKeyProvider: @escaping () -> String? = { OpenAIAPIKeyStore.currentKey },
        requestBuilder: OpenAICoachRequestBuilder = OpenAICoachRequestBuilder(),
        timeoutSeconds: TimeInterval = 5
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.requestBuilder = requestBuilder
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutSeconds
        self.session = URLSession(configuration: configuration)
    }

    /// Pide una recomendación para `summary`. Hace **un** reintento
    /// prudente ante fallas transitorias de red (timeout, sin conexión,
    /// 429, 5xx) — no ante errores que reintentar no arregla (401 sin
    /// autorización, JSON inesperado).
    func recommendation(for summary: CoachEventSummary) async -> CoachRecommendation? {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else { return nil }

        if case .success(let recommendation) = await attempt(apiKey: apiKey, summary: summary) {
            return recommendation
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if case .success(let recommendation) = await attempt(apiKey: apiKey, summary: summary) {
            return recommendation
        }

        return nil
    }

    private enum AttemptOutcome {
        case success(CoachRecommendation)
        case retryableFailure
        case permanentFailure
    }

    private func attempt(apiKey: String, summary: CoachEventSummary) async -> AttemptOutcome {
        guard let body = try? JSONEncoder().encode(requestBuilder.build(for: summary)) else {
            return .permanentFailure
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else { return .permanentFailure }

            guard (200..<300).contains(http.statusCode) else {
                // Rate limit o error del lado de OpenAI: vale la pena
                // reintentar una vez. Error de cliente (401, 400, etc.):
                // no — reintentar no lo va a arreglar.
                return (http.statusCode == 429 || http.statusCode >= 500) ? .retryableFailure : .permanentFailure
            }

            guard let recommendation = OpenAICoachResponseParser.parseRecommendation(from: data) else {
                return .permanentFailure
            }

            return .success(recommendation)
        } catch {
            // Timeout, sin conexión, DNS, etc. — transitorio, vale la
            // pena el reintento.
            return .retryableFailure
        }
    }
}
