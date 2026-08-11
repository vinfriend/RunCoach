import XCTest
@testable import RunCoachCore

final class GeoDistanceTests: XCTestCase {
    func testZeroDistanceForSamePoint() {
        let point = LocationSample(latitude: -34.6037, longitude: -58.3816, timestamp: 0)
        XCTAssertEqual(GeoDistance.metersBetween(point, point), 0, accuracy: 0.001)
    }

    func testKnownDistanceBetweenTwoObeliscoLikePoints() {
        // ~1000m aproximados moviendo la latitud ~0.009 grados (regla
        // práctica: 1 grado de latitud ≈ 111,320 m).
        let a = LocationSample(latitude: -34.6037, longitude: -58.3816, timestamp: 0)
        let b = LocationSample(latitude: -34.6037 - 0.008991, longitude: -58.3816, timestamp: 60)
        let distance = GeoDistance.metersBetween(a, b)
        XCTAssertEqual(distance, 1000, accuracy: 5)
    }

    func testDistanceIsSymmetric() {
        let a = LocationSample(latitude: 40.0, longitude: -73.0, timestamp: 0)
        let b = LocationSample(latitude: 40.01, longitude: -73.01, timestamp: 10)
        XCTAssertEqual(
            GeoDistance.metersBetween(a, b),
            GeoDistance.metersBetween(b, a),
            accuracy: 0.001
        )
    }
}
