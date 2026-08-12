import Foundation

/// Genera muestras de FC y GPS deterministas a partir de un `Scenario`.
/// Es la pieza central del Simulation Mode: el mismo `RunState` que
/// consume estas muestras sintéticas es el que va a consumir muestras
/// reales de BLE/GPS más adelante (Fases 6-7) — no hay ninguna rama de
/// código distinta para "modo simulado" dentro de `RunCoachCore`.
public enum ScenarioSimulator {
    private static let earthRadiusMeters = 6_371_000.0

    /// Genera las muestras de FC de un escenario completo.
    ///
    /// - Parameter sampleIntervalSeconds: cada cuánto se emite una
    ///   muestra (por defecto 1s, similar a la cadencia típica de un
    ///   sensor BLE de FC).
    public static func generateHeartRateSamples(
        for scenario: Scenario,
        sampleIntervalSeconds: TimeInterval = 1
    ) -> [HeartRateSample] {
        var samples: [HeartRateSample] = []
        var elapsed: TimeInterval = 0

        for segment in scenario.segments {
            if !segment.heartRateSignalLost {
                var t: TimeInterval = 0
                while t < segment.duration {
                    var bpm = segment.heartRateBPM(at: t)
                    for anomaly in segment.anomalies
                    where abs(anomaly.atRelativeTime - t) < sampleIntervalSeconds / 2 {
                        bpm += anomaly.heartRateBPMDelta
                    }
                    samples.append(HeartRateSample(bpm: bpm, timestamp: elapsed + t))
                    t += sampleIntervalSeconds
                }
            }
            elapsed += segment.duration
        }

        return samples
    }

    /// Genera las muestras de GPS de un escenario completo, moviendo un
    /// punto sintético en línea recta hacia el norte a la velocidad
    /// derivada del ritmo de cada segmento.
    ///
    /// La posición se integra internamente en pasos finos de 1s
    /// independientemente de `sampleIntervalSeconds`, así que la distancia
    /// real recorrida durante un tramo de pérdida de señal no se pierde:
    /// simplemente no se emite ninguna muestra hasta que la señal vuelve,
    /// y ahí aparece como un salto de posición — igual que GPS real
    /// reconectando.
    ///
    /// - Parameters:
    ///   - sampleIntervalSeconds: cada cuánto se emite una muestra (por
    ///     defecto 3s, similar a la cadencia típica de CoreLocation).
    ///   - startLatitude/startLongitude: punto de partida sintético.
    public static func generateLocationSamples(
        for scenario: Scenario,
        sampleIntervalSeconds: TimeInterval = 3,
        startLatitude: Double = 0,
        startLongitude: Double = 0
    ) -> [LocationSample] {
        var samples: [LocationSample] = []
        var elapsed: TimeInterval = 0
        var latitude = startLatitude
        let integrationStep: TimeInterval = 1
        var timeSinceLastEmission: TimeInterval = sampleIntervalSeconds // fuerza una emisión temprana

        for segment in scenario.segments {
            var t: TimeInterval = 0
            while t < segment.duration {
                let pace = segment.paceSecondsPerKm(at: t)
                let speedMetersPerSecond = pace > 0 ? 1000 / pace : 0
                let step = min(integrationStep, segment.duration - t)
                let distanceMeters = speedMetersPerSecond * step

                latitude += (distanceMeters / earthRadiusMeters) * (180 / .pi)
                t += step
                timeSinceLastEmission += step

                if !segment.locationSignalLost && timeSinceLastEmission >= sampleIntervalSeconds {
                    samples.append(LocationSample(
                        latitude: latitude,
                        longitude: startLongitude,
                        timestamp: elapsed + t
                    ))
                    timeSinceLastEmission = 0
                }
            }
            elapsed += segment.duration
        }

        return samples
    }
}
