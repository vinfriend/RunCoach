import Foundation
import RunCoachCore

/// De qué está alimentado el `RunState` actual.
enum RunMode: Equatable {
    /// Escenario simulado de RunCoachCore (Fase 3), con pacing acelerado.
    case simulated
    /// `BLEHeartRateSource` + `GPSLocationSource` reales (Fases 6-7).
    /// Sin validar con hardware real todavía (Fase 14) — este modo existe
    /// en código pero no hay forma de confirmar que funciona sin un
    /// sensor y un iPhone de verdad.
    case real
}

/// Orquesta una carrera — simulada o real — sobre un `RunState` de
/// RunCoachCore, y expone sus métricas como `@Published` para que
/// `RunView` las muestre.
///
/// **Modo simulado**: reproduce `Scenario.referenceRun` con pacing en
/// tiempo real acelerado (`DispatchQueue`, ver nota de Fase 5 más abajo).
/// Validado end-to-end desde Fase 5.
///
/// **Modo real** (Fase 8): crea un `BLEHeartRateSource` y un
/// `GPSLocationSource`, les fija el **mismo** `Date` de referencia antes
/// de arrancarlos — así los timestamps de FC y GPS quedan comparables
/// entre sí, resolviendo la nota pendiente de la Fase 6 (ver
/// docs/decisions.md) — y alimenta el mismo `RunState` con lo que vayan
/// entregando.
///
/// **Audio (Fase 9)**: anuncia inicio/fin de carrera y cada split
/// completado por `AudioCoach`. Son anuncios mecánicos atados a eventos
/// concretos que `RunCoachCore` ya calcula — no hay ninguna decisión de
/// "¿vale la pena hablar ahora?" en esa parte.
///
/// **Coach Decision Engine (Fase 10)**: además de los anuncios mecánicos,
/// en cada `refresh()` se consulta a `CoachDecisionEngine` (RunCoachCore)
/// — la pieza que sí decide cuándo vale la pena intervenir (cooldown,
/// deduplicación, contexto reciente).
///
/// **OpenAI (Fase 11)**: cuando el motor decide `.speak(event)`, primero
/// se intenta `OpenAICoachClient` (async, con timeout y un reintento
/// prudente — nunca bloquea `refresh()`). Si responde a tiempo, se dice
/// esa recomendación; si no (sin API key, sin red, timeout, error), se
/// cae de vuelta a la frase fija en español de siempre. La traducción a
/// texto del fallback vive acá (capa de presentación), no en
/// `RunCoachCore`.
///
/// **Historial (Fase 19)**: al terminar una carrera (parada a mano o
/// finalización natural de la simulación), se arma un `CompletedRun` y se
/// guarda con `RunHistoryStore` — sin esperar a tener firma/hardware real,
/// esto ya se puede probar en CI (aunque no verlo — ver docs/decisions.md).
final class RunSessionViewModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var mode: RunMode?
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var totalDistanceMeters: Double = 0
    @Published private(set) var currentPaceSecondsPerKm: Double?
    @Published private(set) var smoothedHeartRateBPM: Double?
    @Published private(set) var heartRateTrend: HeartRateTrend = .stable
    @Published private(set) var splits: [Split] = []

    /// Cuántas veces más rápido que tiempo real se reproduce el escenario
    /// simulado. Con el valor por defecto, el escenario de referencia de
    /// 20 minutos se ve en 1 minuto — no aplica al modo real, que
    /// obviamente corre a la velocidad de la carrera real.
    private let playbackSpeed: Double

    private var runState = RunState()
    private var coachDecisionEngine = CoachDecisionEngine()
    private var pendingWorkItems: [DispatchWorkItem] = []
    private let audioCoach = AudioCoach()
    private let openAIClient = OpenAICoachClient()
    private let historyStore = RunHistoryStore.documentsStore()
    private var runStartedAt: Date?

    // Modo real
    private var heartRateSource: BLEHeartRateSource?
    private var locationSource: GPSLocationSource?

    init(playbackSpeed: Double = 20) {
        self.playbackSpeed = playbackSpeed
    }

    // MARK: - Modo simulado (Fase 5)

    func startSimulated(scenario: Scenario = .referenceRun) {
        stop()
        mode = .simulated
        isRunning = true
        runState = RunState()
        coachDecisionEngine = CoachDecisionEngine()
        runStartedAt = Date()
        audioCoach.speak("Carrera simulada iniciada.")

        let heartRateSamples = ScenarioSimulator.generateHeartRateSamples(for: scenario)
        let locationSamples = ScenarioSimulator.generateLocationSamples(
            for: scenario,
            startLatitude: 40.0,
            startLongitude: -73.0
        )

        scheduleHeartRateSamples(heartRateSamples)
        scheduleLocationSamples(locationSamples)

        let endDelay = scenario.totalDuration / playbackSpeed
        scheduleEnd(after: endDelay)
    }

    // MARK: - Modo real (Fase 8)

    func startReal() {
        stop()
        mode = .real
        isRunning = true
        runState = RunState()
        coachDecisionEngine = CoachDecisionEngine()
        runStartedAt = Date()
        audioCoach.speak("Carrera iniciada.")

        // Mismo Date de referencia para ambas fuentes — ver el comentario
        // de la clase y docs/decisions.md (nota pendiente desde Fase 6).
        let referenceStartDate = Date()

        let heartRateSource = BLEHeartRateSource()
        heartRateSource.referenceStartDate = referenceStartDate
        heartRateSource.onSample = { [weak self] sample in
            self?.runState.ingest(heartRate: sample)
            self?.refresh()
        }

        let locationSource = GPSLocationSource()
        locationSource.referenceStartDate = referenceStartDate
        locationSource.onSample = { [weak self] sample in
            self?.runState.ingest(location: sample)
            self?.refresh()
        }

        self.heartRateSource = heartRateSource
        self.locationSource = locationSource

        heartRateSource.start()
        locationSource.start()
    }

    // MARK: - Común

    func stop() {
        let wasRunning = isRunning

        pendingWorkItems.forEach { $0.cancel() }
        pendingWorkItems.removeAll()

        if wasRunning {
            finishRun()
        }

        heartRateSource?.stop()
        locationSource?.stop()
        heartRateSource = nil
        locationSource = nil

        isRunning = false
        mode = nil

        if wasRunning {
            audioCoach.speak("Carrera detenida.")
        }
    }

    /// Arma un `CompletedRun` con el estado final de la carrera y lo
    /// guarda en el historial (Fase 19). Se llama tanto al parar a mano
    /// (`stop()`, mientras `mode`/`runStartedAt` todavía están seteados)
    /// como al terminar naturalmente la simulación (`scheduleEnd`).
    private func finishRun() {
        guard let mode, let runStartedAt else { return }
        let modeTag = mode == .simulated ? "simulated" : "real"
        let completedRun = CompletedRun.make(mode: modeTag, startedAt: runStartedAt, runState: runState)
        try? historyStore.save(completedRun)
    }

    private func scheduleHeartRateSamples(_ samples: [HeartRateSample]) {
        for sample in samples {
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.runState.ingest(heartRate: sample)
                self.refresh()
            }
            pendingWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + sample.timestamp / playbackSpeed, execute: item)
        }
    }

    private func scheduleLocationSamples(_ samples: [LocationSample]) {
        for sample in samples {
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.runState.ingest(location: sample)
                self.refresh()
            }
            pendingWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + sample.timestamp / playbackSpeed, execute: item)
        }
    }

    private func scheduleEnd(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.finishRun()
            self.isRunning = false
            self.audioCoach.speak("Carrera simulada finalizada.")
        }
        pendingWorkItems.append(item)
        // Un pequeño margen extra para que la última muestra ya se haya
        // procesado antes de marcar la carrera como terminada.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2, execute: item)
    }

    private func refresh() {
        let previousSplitCount = splits.count

        elapsedSeconds = runState.elapsedSeconds
        totalDistanceMeters = runState.totalDistanceMeters
        currentPaceSecondsPerKm = runState.currentPaceSecondsPerKm
        smoothedHeartRateBPM = runState.smoothedHeartRateBPM
        heartRateTrend = runState.heartRateTrend
        splits = runState.splits

        if splits.count > previousSplitCount, let latestSplit = splits.last {
            announceSplit(latestSplit)
        }

        if case .speak(let event) = coachDecisionEngine.evaluate(runState: runState) {
            handleSpeakDecision(for: event)
        }
    }

    /// Intenta una recomendación de OpenAI para `event` sin bloquear
    /// `refresh()` — corre en un `Task` aparte. `summary` se captura por
    /// valor en el instante de la decisión, así que no importa cuánto
    /// tarde la red: no lee el `RunState` (que sigue mutando) después.
    private func handleSpeakDecision(for event: CoachEvent) {
        let fallbackText = spokenText(for: event)
        let summary = CoachEventSummary.make(event: event, runState: runState)

        Task { [weak self] in
            guard let self else { return }
            if let recommendation = await self.openAIClient.recommendation(for: summary) {
                self.audioCoach.speak(recommendation.message)
            } else {
                self.audioCoach.speak(fallbackText)
            }
        }
    }

    /// Anuncio mecánico de un split recién completado — no es una
    /// decisión del coach, es simplemente leer en voz alta un dato que
    /// `RunState` ya calculó. Ver la nota de la clase sobre por qué esto
    /// no es el Coach Decision Engine.
    private func announceSplit(_ split: Split) {
        let km = split.index + 1
        audioCoach.speak("Kilómetro \(km). Ritmo: \(spokenPace(split.averagePaceSecondsPerKm)).")
    }

    /// Traduce un `CoachEvent` (RunCoachCore, sin idioma) a una frase en
    /// español. Esta traducción vive acá a propósito — `RunCoachCore` no
    /// sabe de idiomas ni de texto para voz.
    private func spokenText(for event: CoachEvent) -> String {
        switch event {
        case .effortRising(let bpm):
            return "Tu esfuerzo está subiendo. Frecuencia cardíaca: \(Int(bpm.rounded())) por minuto."
        case .effortFalling(let bpm):
            return "Estás recuperando. Frecuencia cardíaca bajando a \(Int(bpm.rounded())) por minuto."
        }
    }

    private func spokenPace(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite else { return "sin datos" }
        let totalSeconds = Int(secondsPerKm.rounded())
        return "\(totalSeconds / 60) minutos \(totalSeconds % 60) por kilómetro"
    }
}
