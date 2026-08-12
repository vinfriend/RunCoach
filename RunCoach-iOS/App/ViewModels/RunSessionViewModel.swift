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
/// entregando. Sin conectar a nada más (audio, Coach Decision Engine):
/// eso son las Fases 9-10.
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
    private var pendingWorkItems: [DispatchWorkItem] = []

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
        pendingWorkItems.forEach { $0.cancel() }
        pendingWorkItems.removeAll()

        heartRateSource?.stop()
        locationSource?.stop()
        heartRateSource = nil
        locationSource = nil

        isRunning = false
        mode = nil
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
            self?.isRunning = false
        }
        pendingWorkItems.append(item)
        // Un pequeño margen extra para que la última muestra ya se haya
        // procesado antes de marcar la carrera como terminada.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2, execute: item)
    }

    private func refresh() {
        elapsedSeconds = runState.elapsedSeconds
        totalDistanceMeters = runState.totalDistanceMeters
        currentPaceSecondsPerKm = runState.currentPaceSecondsPerKm
        smoothedHeartRateBPM = runState.smoothedHeartRateBPM
        heartRateTrend = runState.heartRateTrend
        splits = runState.splits
    }
}
