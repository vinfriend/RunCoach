import AVFoundation

/// Envuelve `AVSpeechSynthesizer` para que la app pueda "hablar" texto
/// simple por la salida de audio activa (AirPods u otra), sin apropiarse
/// de la sesión de audio más allá de lo que dura cada mensaje — así el
/// usuario puede escuchar música de Spotify/YouTube Music/Apple Music/etc.
/// normalmente mientras corre, y solo baja de volumen (duck) el instante
/// en que el coach tiene algo que decir. Es un requisito permanente del
/// producto (no de una fase puntual) — ver [docs/audio-coach.md](../../../docs/audio-coach.md)
/// y [docs/decisions.md](../../../docs/decisions.md) para el diseño completo
/// y las fuentes de la documentación de Apple consultadas.
///
/// **`AudioCoachService` no decide nada**: recibe un `CoachMessage` ya
/// armado en español y lo dice. Las llamadas a `speak(_:)` vienen de
/// eventos mecánicos (inicio/fin de carrera, splits) o de una traducción
/// de `CoachEvent` (Coach Decision Engine) — ninguna decisión de "¿vale la
/// pena interrumpir?" vive acá.
///
/// **Patrón de sesión "tipo navegación GPS"**: `AVAudioSession` se activa
/// justo antes de cada frase (categoría `.playback`, modo `.voicePrompt`,
/// opción `.duckOthers` — la misma combinación documentada por Apple para
/// apps de navegación) y se desactiva apenas termina de hablar, con
/// `.notifyOthersOnDeactivation` para que la música de otras apps vuelva a
/// su volumen normal. Esto es necesario porque `AVSpeechSynthesizer`
/// activa la sesión solo, pero **no la desactiva sola** al terminar — sin
/// este manejo explícito, la música quedaría "duckeada" para siempre
/// después del primer mensaje (comportamiento documentado, no un bug
/// nuestro). Ver `docs/decisions.md` para las fuentes.
final class AudioCoachService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    /// Cuántas frases están en cola o hablándose ahora mismo. Mientras sea
    /// mayor a cero, la sesión de audio se mantiene activa (y la música de
    /// otras apps, "duckeada"); al llegar a cero, se desactiva para que la
    /// música recupere su volumen normal — igual que una app de navegación.
    private var pendingUtterances = 0

    init(languageCode: String = "es-AR") {
        voice = AVSpeechSynthesisVoice(language: languageCode)
        super.init()
        synthesizer.delegate = self
        observeAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Dice `message` por la salida de audio activa. Nunca lanza ni
    /// bloquea — si algo falla al configurar la sesión de audio (por
    /// ejemplo, otra app la tiene tomada de una forma incompatible), la
    /// carrera sigue corriendo igual: GPS, frecuencia cardíaca y métricas
    /// no dependen en absoluto de que esto funcione.
    func speak(_ message: CoachMessage) {
        activateSession()

        let utterance = AVSpeechUtterance(string: message.text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        pendingUtterances += 1
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// `.playback` + `.voicePrompt` + `.duckOthers` es la combinación que
    /// Apple documenta para apps que hablan sobre música de otras apps sin
    /// interrumpirla (patrón de navegación GPS) — `.duckOthers` además deja
    /// `.mixWithOthers` implícito según la documentación oficial, así que
    /// no hace falta agregarlo aparte. A propósito **no** se usa
    /// `.interruptSpokenAudioAndMixWithOthers`: esa opción pausa podcasts/
    /// audiolibros de otras apps en vez de solo bajarles el volumen, y acá
    /// el requisito explícito es no interrumpir más de lo necesario.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// Solo desactiva la sesión cuando no queda ninguna frase pendiente —
    /// varios mensajes seguidos (por ejemplo, un split y un evento del
    /// coach casi al mismo tiempo) no deben hacer parpadear la sesión
    /// (desactivar y reactivar entre frase y frase), que es justo el tipo
    /// de "cambio molesto de sesión de audio" que no queremos.
    private func deactivateSessionIfIdle() {
        guard pendingUtterances == 0 else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func observeAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    /// Una interrupción (llamada, Siri, alarma) hace que iOS desactive
    /// nuestra sesión por su cuenta — cualquier frase que estuviera "en
    /// curso" en `pendingUtterances` ya no va a disparar su callback
    /// `didFinish`/`didCancel` de forma confiable, así que se resetea acá
    /// para no quedar con el contador desincronizado. No hace falta
    /// reintentar la frase interrumpida ni reactivar nada a mano: el
    /// próximo `speak(_:)` (el próximo evento real del coach) va a
    /// reactivar la sesión desde cero con `activateSession()`.
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .began
        else { return }
        pendingUtterances = 0
    }

    /// Cambios de ruta (conectar/desconectar AirPods, por ejemplo) los
    /// resuelve iOS solo — `AVSpeechSynthesizer` sigue hablando por la
    /// salida activa que el sistema elija. No hace falta ninguna acción
    /// nuestra; el handler existe para dejar documentado que el caso se
    /// consideró, no porque haga algo hoy.
    @objc private func handleRouteChange(_ notification: Notification) {}
}

extension AudioCoachService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        pendingUtterances = max(0, pendingUtterances - 1)
        deactivateSessionIfIdle()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        pendingUtterances = max(0, pendingUtterances - 1)
        deactivateSessionIfIdle()
    }
}
