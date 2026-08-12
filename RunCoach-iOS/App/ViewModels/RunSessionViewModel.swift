import Foundation
import RunCoachCore

/// Envuelve un `RunState` de RunCoachCore y lo alimenta con el escenario
/// simulado de Fase 3, pero con pacing en tiempo real (acelerado) para que
/// tenga sentido verlo en pantalla — algo que `MockHeartRateSource`/
/// `MockLocationSource` no hacen a propósito (reproducen todo de forma
/// síncrona e inmediata, pensado para tests deterministas, no para UI).
///
/// Este pacing en tiempo real es intencionalmente una preocupación de la
/// capa de UI (usa `DispatchQueue`, que no existe en Windows/Linux), no de
/// `RunCoachCore` — no se toca el motor de dominio para esto.
///
/// Sin conexión a hardware real todavía: eso son las Fases 6 (BLE) y 7
/// (GPS). Esta pantalla sirve para probar la UI y el motor de métricas de
/// punta a punta sin esperar a tener sensores.
final class RunSessionViewModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var totalDistanceMeters: Double = 0
    @Published private(set) var currentPaceSecondsPerKm: Double?
    @Published private(set) var smoothedHeartRateBPM: Double?
    @Published private(set) var heartRateTrend: HeartRateTrend = .stable
    @Published private(set) var splits: [Split] = []

    /// Cuántas veces más rápido que tiempo real se reproduce el escenario.
    /// Con el valor por defecto, el escenario de referencia de 20 minutos
    /// se ve en 1 minuto — suficiente para probar la pantalla sin esperar
    /// una carrera entera.
    private let playbackSpeed: Double

    private let runState = RunState()
    private var pendingWorkItems: [DispatchWorkItem] = []

    init(playbackSpeed: Double = 20) {
        self.playbackSpeed = playbackSpeed
    }

    func start(scenario: Scenario = .referenceRun) {
        stop()
        isRunning = true

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

    func stop() {
        pendingWorkItems.forEach { $0.cancel() }
        pendingWorkItems.removeAll()
        isRunning = false
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
