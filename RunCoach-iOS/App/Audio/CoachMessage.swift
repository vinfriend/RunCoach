import Foundation

/// Un mensaje en español, ya armado, listo para decirse por voz. Es el
/// límite explícito entre "qué evento pasó" (`CoachEvent`, RunCoachCore) y
/// "cómo se dice y se reproduce" (`AudioCoachService`) — `RunSessionViewModel`
/// arma el texto (mecánico o traducido desde un `CoachEvent`) y lo envuelve
/// acá antes de pasarlo a la capa de audio.
struct CoachMessage: Equatable {
    let text: String
}
