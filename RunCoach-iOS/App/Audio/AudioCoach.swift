import AVFoundation

/// Envuelve `AVSpeechSynthesizer` para que la app pueda "hablar" texto
/// simple por los auriculares (AirPods u otra salida activa), incluso con
/// la pantalla bloqueada.
///
/// **Fase 9 es solo la infraestructura de voz — sin ninguna inteligencia
/// sobre qué decir ni cuándo.** `AudioCoach` no decide nada: recibe texto
/// ya armado y lo dice. Las llamadas a `speak(_:)` en esta fase vienen de
/// eventos mecánicos y deterministas que `RunCoachCore` ya calcula
/// (inicio de carrera, cada split completado) — no hay lógica de
/// prioridad, cooldown, ni "¿vale la pena interrumpir?". Eso es el Coach
/// Decision Engine, Fase 10, explícitamente fuera de alcance acá.
///
/// A diferencia de BLE (Fase 6), esto sí podría probarse en el simulador
/// de iOS (el simulador reproduce audio) — pero seguimos sin Mac para
/// abrir Xcode, así que sigue sin validarse funcionalmente de mi lado.
final class AudioCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    init(languageCode: String = "es-AR") {
        voice = AVSpeechSynthesisVoice(language: languageCode)
        configureAudioSession()
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// `.playback` + `.spokenAudio` es la combinación recomendada por
    /// Apple para contenido hablado: suena aunque el iPhone esté en
    /// silencio, y baja el volumen de otro audio (música, podcasts)
    /// mientras el coach habla en vez de cortarlo del todo.
    ///
    /// Sin manejo de interrupciones (llamadas telefónicas, otras apps
    /// tomando la sesión de audio) todavía — afinar eso tiene más sentido
    /// una vez que haya un iPhone real para probarlo (Fase 13+), igual
    /// que el resto de la resiliencia de BLE/GPS.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }
}
