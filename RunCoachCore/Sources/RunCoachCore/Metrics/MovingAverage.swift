import Foundation

/// Media móvil simple sobre una ventana de tamaño fijo. Se usa para suavizar
/// tanto la frecuencia cardíaca como el ritmo, evitando que un solo dato
/// ruidoso dispare una reacción del Coach Decision Engine (Fase 10).
public struct MovingAverage {
    private var window: [Double] = []
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity debe ser mayor a 0")
        self.capacity = capacity
    }

    public var isEmpty: Bool { window.isEmpty }
    public var sampleCount: Int { window.count }

    @discardableResult
    public mutating func add(_ value: Double) -> Double {
        window.append(value)
        if window.count > capacity {
            window.removeFirst(window.count - capacity)
        }
        return value
    }

    public var value: Double? {
        guard !window.isEmpty else { return nil }
        return window.reduce(0, +) / Double(window.count)
    }
}
