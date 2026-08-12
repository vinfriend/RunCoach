import CoreBluetooth
import Foundation
import RunCoachCore

/// Implementación real de `HeartRateSource` (RunCoachCore, Fase 2) vía
/// CoreBluetooth, contra el Bluetooth Heart Rate Service estándar
/// (`0x180D`) investigado en Fase 1 — funciona con cualquier sensor que lo
/// exponga (WHOOP con HR Broadcast activado, Polar, Garmin, Scosche,
/// etc.), sin código específico de marca.
///
/// El parsing del payload (`HeartRateMeasurementParser`) vive en
/// `RunCoachCore` porque es lógica pura, portable. Lo que sí es exclusivo
/// de Apple y vive acá es todo el manejo de `CBCentralManager`: escanear,
/// conectar, descubrir servicios/características, y suscribirse a
/// notificaciones.
///
/// **Sin validar con hardware real todavía** (eso es la Fase 14). Tampoco
/// se puede probar en el simulador de iOS — CoreBluetooth no tiene acceso
/// a radio Bluetooth real ahí, así que el `CBCentralManager` va a
/// reportar un estado no disponible y nunca va a encontrar nada. Esta
/// clase solo se valida por compilación en CI hasta que haya un iPhone y
/// un sensor reales.
final class BLEHeartRateSource: NSObject, HeartRateSource {
    var onSample: ((HeartRateSample) -> Void)?

    private static let heartRateServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")

    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?

    /// Instante de referencia contra el que se calculan los timestamps
    /// relativos de cada `HeartRateSample` (ver la nota sobre
    /// `TimeInterval` relativo en `HeartRateSample`). No-nil mientras la
    /// fuente está "corriendo" — también se usa como flag interno para
    /// decidir si hay que reintentar escanear tras una desconexión.
    private var referenceStartDate: Date?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func start() {
        referenceStartDate = Date()
        if centralManager.state == .poweredOn {
            startScanning()
        }
        // Si todavía no está poweredOn, `centralManagerDidUpdateState`
        // arranca el escaneo apenas lo esté.
    }

    func stop() {
        referenceStartDate = nil
        centralManager.stopScan()
        if let heartRatePeripheral {
            centralManager.cancelPeripheralConnection(heartRatePeripheral)
        }
        heartRatePeripheral = nil
    }

    private func startScanning() {
        centralManager.scanForPeripherals(withServices: [Self.heartRateServiceUUID])
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEHeartRateSource: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn, referenceStartDate != nil else { return }
        startScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        central.stopScan()
        heartRatePeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.heartRateServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard referenceStartDate != nil else { return }
        heartRatePeripheral = nil
        startScanning()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Reconexión simple: si seguimos "corriendo", reintentar escanear.
        // Una estrategia más sofisticada (backoff, aviso al usuario) se
        // ajusta con datos reales en la Fase 14 — no hay forma de afinar
        // esto sin un sensor de verdad.
        guard referenceStartDate != nil else { return }
        heartRatePeripheral = nil
        startScanning()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEHeartRateSource: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.heartRateServiceUUID {
            peripheral.discoverCharacteristics([Self.heartRateMeasurementCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.heartRateMeasurementCharacteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard
            characteristic.uuid == Self.heartRateMeasurementCharacteristicUUID,
            let data = characteristic.value,
            let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [UInt8](data)),
            let referenceStartDate
        else { return }

        let sample = HeartRateSample(bpm: bpm, timestamp: Date().timeIntervalSince(referenceStartDate))
        onSample?(sample)
    }
}
