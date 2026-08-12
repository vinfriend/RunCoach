import Foundation

/// Decodifica el JSON de respuesta de OpenAI Chat Completions en una
/// `CoachRecommendation` — lógica pura, sin red. Devuelve `nil` ante
/// cualquier forma inesperada (JSON malformado, sin `choices`, texto
/// vacío) en vez de lanzar: quien orqueste la llamada real
/// (`OpenAICoachClient`, RunCoach-iOS) trata "sin recomendación" como un
/// resultado válido y cae de vuelta a la frase fija en español.
public enum OpenAICoachResponseParser {
    public static func parseRecommendation(from data: Data) -> CoachRecommendation? {
        guard
            let response = try? JSONDecoder().decode(OpenAIChatResponse.self, from: data),
            let rawText = response.choices.first?.message.content
        else {
            return nil
        }

        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return CoachRecommendation(message: text)
    }
}
