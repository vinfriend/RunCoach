import Foundation

/// Un evento que el Coach Decision Engine considera potencialmente digno
/// de mención — todavía no es una decisión de hablar, solo lo que el
/// Event Detector observó. `CoachDecisionEngine` es quien decide si
/// realmente vale la pena decirlo ahora (ver esa clase).
///
/// No lleva texto: convertir esto a una frase en español es
/// responsabilidad de la capa de presentación (`RunCoach-iOS`), igual que
/// el resto del formateo para pantalla/voz — `RunCoachCore` se mantiene
/// libre de idioma y de UI.
public enum CoachEvent: Equatable, Sendable {
    /// La frecuencia cardíaca viene subiendo de forma sostenida
    /// (`RunState.heartRateTrend == .rising`).
    case effortRising(currentBPM: Double)
    /// La frecuencia cardíaca viene bajando de forma sostenida
    /// (`RunState.heartRateTrend == .falling`) — típicamente, recuperación.
    case effortFalling(currentBPM: Double)

    /// El "tipo" de evento, sin el valor de FC asociado. `CoachDecisionEngine`
    /// deduplica por `kind`, no por igualdad estricta: el BPM cambia en
    /// casi cada muestra mientras la tendencia se sostiene, así que
    /// comparar el evento completo (incluyendo el BPM exacto) nunca
    /// consideraría "igual" a la muestra anterior — se repetiría en cada
    /// muestra en vez de una sola vez por tendencia.
    public var kind: Kind {
        switch self {
        case .effortRising: return .effortRising
        case .effortFalling: return .effortFalling
        }
    }

    public enum Kind: Equatable, Sendable {
        case effortRising
        case effortFalling
    }
}
