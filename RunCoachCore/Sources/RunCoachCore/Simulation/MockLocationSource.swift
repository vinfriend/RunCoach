import Foundation

/// Fuente de GPS simulada — equivalente a `MockHeartRateSource` para
/// ubicación. Ver esa clase para el motivo de la reproducción síncrona.
public final class MockLocationSource: LocationSource {
    public var onSample: ((LocationSample) -> Void)?
    private let samples: [LocationSample]
    public private(set) var isRunning = false

    public init(samples: [LocationSample]) {
        self.samples = samples
    }

    public func start() {
        isRunning = true
        for sample in samples {
            guard isRunning else { break }
            onSample?(sample)
        }
        isRunning = false
    }

    public func stop() {
        isRunning = false
    }
}
