import Foundation

/// Tipos `Codable` que reflejan el formato de la API de OpenAI Chat
/// Completions — lo suficiente para armar el request y leer el texto de
/// la respuesta, nada más. Lógica pura, sin `URLSession`: el cliente HTTP
/// real vive en `RunCoach-iOS` (`OpenAICoachClient`), igual que el patrón
/// de `HeartRateMeasurementParser`/`BLEHeartRateSource` en Fase 6.
public struct OpenAIChatMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIChatRequest: Codable, Equatable, Sendable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let maxTokens: Int
    public let temperature: Double

    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }

    public init(model: String, messages: [OpenAIChatMessage], maxTokens: Int, temperature: Double) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public struct OpenAIChatResponse: Codable, Equatable, Sendable {
    public struct Choice: Codable, Equatable, Sendable {
        public struct Message: Codable, Equatable, Sendable {
            public let content: String
        }
        public let message: Message
    }
    public let choices: [Choice]
}
