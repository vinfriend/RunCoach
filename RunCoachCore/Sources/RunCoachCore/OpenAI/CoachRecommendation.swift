import Foundation

/// El resultado de consultarle a OpenAI sobre un `CoachEventSummary` — un
/// mensaje corto, listo para pasarle a `AudioCoach` (RunCoach-iOS). Sin
/// texto no hay recomendación: quien orqueste la llamada real cae de
/// vuelta a la frase fija en español si esto nunca llega a construirse
/// (sin API key, sin red, timeout, respuesta inesperada — ver
/// docs/openai.md).
public struct CoachRecommendation: Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
