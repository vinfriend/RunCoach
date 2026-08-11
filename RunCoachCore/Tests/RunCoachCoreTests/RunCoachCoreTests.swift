import XCTest
@testable import RunCoachCore

final class RunCoachCoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(RunCoachCore.version.isEmpty)
    }
}
