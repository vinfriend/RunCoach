import Foundation

/// El estado acumulado de una carrera en curso: ingiere muestras de FC y
/// GPS a medida que llegan (desde una fuente real o simulada — a
/// `RunState` no le importa cuál) y mantiene las métricas derivadas:
/// distancia, tiempo transcurrido, ritmo suavizado, FC suavizada,
/// tendencia de FC, tendencia de ritmo, y splits.
///
/// Es una clase (no un struct) porque representa una única carrera en
/// curso que se va mutando con cada muestra — no tiene sentido copiarla.
public final class RunState {
    public let splitDistanceMeters: Double
    private let heartRateWindowSize: Int
    private let paceWindowSize: Int
    private let trendLookbackSeconds: TimeInterval
    private let trendThresholdBPM: Double
    private let paceTrendThresholdSecondsPerKm: Double

    public private(set) var heartRateSamples: [HeartRateSample] = []
    public private(set) var locationSamples: [LocationSample] = []
    public private(set) var splits: [Split] = []

    public private(set) var elapsedSeconds: TimeInterval = 0
    public private(set) var totalDistanceMeters: Double = 0

    private var heartRateMovingAverage: MovingAverage
    private var paceMovingAverage: MovingAverage

    /// Snapshot del valor suavizado (FC o ritmo) en cada instante en que
    /// se ingiere una muestra — permite calcular la tendencia comparando
    /// "ahora" contra "hace N segundos" sin volver a recorrer todo el
    /// historial. Mismo patrón para las dos métricas, ver `trend(from:...)`.
    private var heartRateSmoothedHistory: [(timestamp: TimeInterval, smoothed: Double)] = []
    private var paceSmoothedHistory: [(timestamp: TimeInterval, smoothed: Double)] = []

    private var distanceAtLastSplit: Double = 0
    private var timeAtLastSplit: TimeInterval = 0
    private var heartRateSamplesSinceLastSplit: [HeartRateSample] = []

    public init(
        splitDistanceMeters: Double = 1000,
        heartRateWindowSize: Int = 10,
        paceWindowSize: Int = 5,
        trendLookbackSeconds: TimeInterval = 60,
        trendThresholdBPM: Double = 3,
        paceTrendThresholdSecondsPerKm: Double = 10
    ) {
        precondition(splitDistanceMeters > 0, "splitDistanceMeters debe ser mayor a 0")
        self.splitDistanceMeters = splitDistanceMeters
        self.heartRateWindowSize = heartRateWindowSize
        self.paceWindowSize = paceWindowSize
        self.trendLookbackSeconds = trendLookbackSeconds
        self.trendThresholdBPM = trendThresholdBPM
        self.paceTrendThresholdSecondsPerKm = paceTrendThresholdSecondsPerKm
        self.heartRateMovingAverage = MovingAverage(capacity: heartRateWindowSize)
        self.paceMovingAverage = MovingAverage(capacity: paceWindowSize)
    }

    // MARK: - Ingestión

    public func ingest(heartRate sample: HeartRateSample) {
        heartRateSamples.append(sample)
        heartRateSamplesSinceLastSplit.append(sample)
        elapsedSeconds = max(elapsedSeconds, sample.timestamp)

        heartRateMovingAverage.add(Double(sample.bpm))
        if let smoothed = heartRateMovingAverage.value {
            heartRateSmoothedHistory.append((timestamp: sample.timestamp, smoothed: smoothed))
        }
    }

    public func ingest(location sample: LocationSample) {
        if let previous = locationSamples.last {
            let deltaDistance = GeoDistance.metersBetween(previous, sample)
            let deltaTime = sample.timestamp - previous.timestamp

            totalDistanceMeters += deltaDistance
            // elapsedSeconds se actualiza antes de chequear el split: si
            // esta muestra es la que cruza el umbral de distancia, la
            // duración del split debe contar hasta el timestamp de esta
            // muestra, no hasta el de la anterior.
            elapsedSeconds = max(elapsedSeconds, sample.timestamp)

            // Ignoramos deltas de tiempo nulos/negativos (muestras
            // duplicadas o desordenadas) para no dividir por cero ni meter
            // ritmos infinitos en la media móvil.
            if deltaTime > 0 && deltaDistance > 0 {
                let paceSecondsPerKm = deltaTime / (deltaDistance / 1000)
                paceMovingAverage.add(paceSecondsPerKm)
                if let smoothed = paceMovingAverage.value {
                    paceSmoothedHistory.append((timestamp: sample.timestamp, smoothed: smoothed))
                }
            }

            checkForSplit()
        }

        locationSamples.append(sample)
        elapsedSeconds = max(elapsedSeconds, sample.timestamp)
    }

    // MARK: - Métricas actuales

    public var smoothedHeartRateBPM: Double? {
        heartRateMovingAverage.value
    }

    /// Promedio de FC de toda la carrera hasta ahora (no una media móvil
    /// reciente como `smoothedHeartRateBPM`) — pensado para resúmenes
    /// post-carrera (Fase 19), no para decisiones en tiempo real.
    public var averageHeartRateBPM: Double? {
        guard !heartRateSamples.isEmpty else { return nil }
        let total = heartRateSamples.reduce(0) { $0 + $1.bpm }
        return Double(total) / Double(heartRateSamples.count)
    }

    /// Ritmo actual suavizado, en segundos por kilómetro.
    public var currentPaceSecondsPerKm: Double? {
        paceMovingAverage.value
    }

    public var heartRateTrend: HeartRateTrend {
        trend(from: heartRateSmoothedHistory) { recent, previous in
            HeartRateTrend.classify(recentAverage: recent, previousAverage: previous, thresholdBPM: trendThresholdBPM)
        } ?? .stable
    }

    /// Hacia dónde viene el ritmo: `.improving` (más rápido),
    /// `.worsening` (más lento) o `.stable`. Junto con `heartRateTrend`,
    /// es lo que permite al Coach Decision Engine (`CoachEventDetector`)
    /// distinguir "el esfuerzo sube porque estoy acelerando a propósito"
    /// de "el esfuerzo sube y encima voy más lento" (deterioro real).
    public var paceTrend: PaceTrend {
        trend(from: paceSmoothedHistory) { recent, previous in
            PaceTrend.classify(
                recentAverage: recent,
                previousAverage: previous,
                thresholdSecondsPerKm: paceTrendThresholdSecondsPerKm
            )
        } ?? .stable
    }

    /// Compara el valor suavizado más reciente de `history` contra el que
    /// había hace `trendLookbackSeconds`, y lo clasifica con `classify`.
    /// `nil` si no hay historial suficiente (menos de `trendLookbackSeconds`
    /// de datos todavía) — quien llama decide el valor "neutro" para ese
    /// caso (`heartRateTrend`/`paceTrend` usan `.stable`).
    private func trend<T>(
        from history: [(timestamp: TimeInterval, smoothed: Double)],
        classify: (_ recent: Double, _ previous: Double) -> T
    ) -> T? {
        guard let latest = history.last else { return nil }

        let targetTimestamp = latest.timestamp - trendLookbackSeconds
        // Buscamos la muestra más reciente que sea igual o anterior al
        // punto de comparación ("hace trendLookbackSeconds").
        guard let reference = history.last(where: { $0.timestamp <= targetTimestamp }) else {
            return nil
        }

        return classify(latest.smoothed, reference.smoothed)
    }

    // MARK: - Splits

    private func checkForSplit() {
        while totalDistanceMeters - distanceAtLastSplit >= splitDistanceMeters {
            let splitDistance = totalDistanceMeters - distanceAtLastSplit
            let splitDuration = elapsedSeconds - timeAtLastSplit
            let averageHR = averageBPM(of: heartRateSamplesSinceLastSplit)

            let split = Split(
                index: splits.count,
                distanceMeters: splitDistance,
                durationSeconds: splitDuration,
                averageHeartRateBPM: averageHR
            )
            splits.append(split)

            distanceAtLastSplit = totalDistanceMeters
            timeAtLastSplit = elapsedSeconds
            heartRateSamplesSinceLastSplit = []
        }
    }

    private func averageBPM(of samples: [HeartRateSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0) { $0 + $1.bpm }
        return Double(total) / Double(samples.count)
    }
}
