import Foundation

/// Fuente de datos de frecuencia cardíaca, agnóstica de marca y de
/// mecanismo de transporte. `RunCoachCore` solo conoce este protocolo:
/// no sabe (ni le importa) si detrás hay un `MockHeartRateSource`
/// (Fase 3) o un `BLEHeartRateSource` leyendo el Heart Rate Service
/// estándar (0x180D) de un WHOOP, un Polar, etc. (Fase 6).
///
/// Se usa un closure en vez de Combine para que `RunCoachCore` siga
/// compilando y testeando en Windows/Linux (Combine es exclusivo de
/// plataformas Apple).
public protocol HeartRateSource: AnyObject {
    var onSample: ((HeartRateSample) -> Void)? { get set }
    func start()
    func stop()
}
