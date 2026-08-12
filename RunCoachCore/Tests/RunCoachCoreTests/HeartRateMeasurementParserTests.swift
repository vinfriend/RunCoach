import XCTest
@testable import RunCoachCore

final class HeartRateMeasurementParserTests: XCTestCase {

    func testUInt8FormatBasic() {
        // flags = 0x00 (UINT8, sin sensor contact), valor = 72.
        let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [0x00, 72])
        XCTAssertEqual(bpm, 72)
    }

    func testUInt8FormatWithSensorContactFlags() {
        // flags = 0x06 (UINT8, sensor contact soportado y detectado),
        // valor = 85. Los bits de sensor contact no deberían afectar el
        // parseo del valor.
        let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [0x06, 85])
        XCTAssertEqual(bpm, 85)
    }

    func testUInt16FormatBasic() {
        // flags = 0x01 (UINT16), valor = 300 (0x012C) en little-endian:
        // byte bajo primero.
        let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [0x01, 0x2C, 0x01])
        XCTAssertEqual(bpm, 300)
    }

    func testUInt16FormatIgnoresTrailingEnergyExpendedField() {
        // flags = 0x09 (UINT16 + Energy Expended presente), valor = 150
        // (0x0096), seguido de 2 bytes de energy expended que se ignoran.
        let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [0x09, 0x96, 0x00, 0x10, 0x00])
        XCTAssertEqual(bpm, 150)
    }

    func testUInt8FormatBoundaryValue() {
        let bpm = HeartRateMeasurementParser.parseHeartRateBPM(from: [0x00, 255])
        XCTAssertEqual(bpm, 255)
    }

    func testEmptyDataReturnsNil() {
        XCTAssertNil(HeartRateMeasurementParser.parseHeartRateBPM(from: []))
    }

    func testUInt8FormatMissingValueByteReturnsNil() {
        XCTAssertNil(HeartRateMeasurementParser.parseHeartRateBPM(from: [0x00]))
    }

    func testUInt16FormatMissingHighByteReturnsNil() {
        XCTAssertNil(HeartRateMeasurementParser.parseHeartRateBPM(from: [0x01, 0x2C]))
    }
}
