import Foundation

/// Fuente de datos de posición GPS, agnóstica de mecanismo de transporte —
/// el equivalente a `HeartRateSource` para ubicación. Implementaciones
/// previstas: simulada (Fase 3) y `CoreLocation` real (Fase 7).
public protocol LocationSource: AnyObject {
    var onSample: ((LocationSample) -> Void)? { get set }
    func start()
    func stop()
}
