import Foundation

/// Decodifica el payload crudo de la característica Heart Rate
/// Measurement (`0x2A37`) del Bluetooth Heart Rate Service estándar
/// (`0x180D`), según la especificación del Bluetooth SIG.
///
/// Es lógica pura de parsing de bytes — no depende de CoreBluetooth, así
/// que se puede testear en Windows con datos sintéticos sin esperar a
/// tener hardware real (eso es la Fase 14). Todo lo que sí depende de
/// CoreBluetooth (escanear, conectar, suscribirse a notificaciones) vive
/// en `RunCoach-iOS` — ver `BLEHeartRateSource`.
///
/// Formato del payload (byte 0 = flags):
/// - bit 0: `0` = valor de FC en 1 byte (UINT8), `1` = en 2 bytes (UINT16,
///   little-endian).
/// - bits 1-2, 3, 4: sensor contact / energy expended / RR-interval — se
///   ignoran por ahora, no hace falta ese dato para el motor de métricas
///   actual.
public enum HeartRateMeasurementParser {
    private static let uint16FormatFlag: UInt8 = 0x01

    /// Devuelve `nil` si `data` está vacío o no alcanza para el formato
    /// indicado por sus flags.
    public static func parseHeartRateBPM(from data: [UInt8]) -> Int? {
        guard let flags = data.first else { return nil }
        let isUInt16Format = (flags & uint16FormatFlag) != 0

        if isUInt16Format {
            guard data.count >= 3 else { return nil }
            let low = UInt16(data[1])
            let high = UInt16(data[2])
            return Int(low | (high << 8))
        } else {
            guard data.count >= 2 else { return nil }
            return Int(data[1])
        }
    }
}
