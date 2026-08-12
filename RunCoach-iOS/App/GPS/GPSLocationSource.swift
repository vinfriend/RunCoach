import CoreLocation
import Foundation
import RunCoachCore

/// Implementación real de `LocationSource` (RunCoachCore, Fase 2) vía
/// CoreLocation.
///
/// A diferencia de `BLEHeartRateSource` (Fase 6), el simulador de iOS sí
/// puede simular una ubicación GPS (Xcode: Debug > Simulate Location) —
/// pero como seguimos sin Mac para abrir Xcode y lanzar el simulador,
/// esto también queda sin poder probarse de mi lado, solo validado por
/// compilación en CI. El seguimiento en background de verdad (con
/// autorización "Always" y pruebas de que el sistema no mata la app) es
/// la Fase 15, no esta.
final class GPSLocationSource: NSObject, LocationSource {
    var onSample: ((LocationSample) -> Void)?

    /// Igual que en `BLEHeartRateSource`: instante de referencia contra
    /// el que se calculan los timestamps relativos de cada
    /// `LocationSample`. Quien coordine varias fuentes (Fase 8,
    /// `RunSessionViewModel`) debe fijar el mismo `Date` acá y en
    /// `BLEHeartRateSource.referenceStartDate` antes de llamar `start()`.
    var referenceStartDate = Date()

    private let locationManager = CLLocationManager()
    private var isRunning = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        // Un semáforo o esperar para cruzar no debería hacer que iOS
        // decida que "la carrera terminó" y pause las actualizaciones.
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        isRunning = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdating()
        case .denied, .restricted:
            break // Fase 8 decide cómo avisarle al usuario en la UI.
        @unknown default:
            break
        }
    }

    func stop() {
        isRunning = false
        locationManager.stopUpdatingLocation()
    }

    private func beginUpdating() {
        // allowsBackgroundLocationUpdates solo tiene efecto real con
        // autorización "Always" (que todavía no pedimos, ver comentario
        // de arriba sobre Fase 15) y con el background mode "location"
        // (ya declarado en project.yml desde Fase 4). Dejarlo condicionado
        // así es inofensivo si ninguna de las dos cosas está lista todavía.
        locationManager.allowsBackgroundLocationUpdates =
            locationManager.authorizationStatus == .authorizedAlways
        locationManager.startUpdatingLocation()
    }
}

extension GPSLocationSource: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRunning else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdating()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning else { return }
        for location in locations {
            let sample = LocationSample(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp.timeIntervalSince(referenceStartDate),
                horizontalAccuracyMeters: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
            )
            onSample?(sample)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Sin manejo elaborado todavía — igual que en BLE, afinar esto
        // tiene sentido recién con datos reales (Fase 15).
    }
}
