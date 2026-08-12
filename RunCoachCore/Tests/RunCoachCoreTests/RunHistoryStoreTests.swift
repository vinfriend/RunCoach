import XCTest
@testable import RunCoachCore

final class RunHistoryStoreTests: XCTestCase {

    private var testDirectory: URL!

    override func setUp() {
        super.setUp()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RunHistoryStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }

    private func makeRun(startedAt: Date, mode: String = "simulated") -> CompletedRun {
        CompletedRun(
            startedAt: startedAt,
            durationSeconds: 600,
            totalDistanceMeters: 2000,
            averageHeartRateBPM: 150,
            splits: [],
            mode: mode
        )
    }

    func testLoadAllOnFreshDirectoryReturnsEmpty() {
        let store = RunHistoryStore(directory: testDirectory)
        XCTAssertEqual(store.loadAll(), [])
    }

    func testSaveThenLoadAllReturnsIt() throws {
        let store = RunHistoryStore(directory: testDirectory)
        let run = makeRun(startedAt: Date(timeIntervalSince1970: 1_700_000_000))

        try store.save(run)

        XCTAssertEqual(store.loadAll(), [run])
    }

    func testLoadAllSortsByStartedAtDescending() throws {
        let store = RunHistoryStore(directory: testDirectory)
        let older = makeRun(startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = makeRun(startedAt: Date(timeIntervalSince1970: 1_800_000_000))

        try store.save(older)
        try store.save(newer)

        XCTAssertEqual(store.loadAll(), [newer, older])
    }

    func testDeleteRemovesRun() throws {
        let store = RunHistoryStore(directory: testDirectory)
        let run = makeRun(startedAt: Date())
        try store.save(run)
        XCTAssertEqual(store.loadAll().count, 1)

        try store.delete(run)

        XCTAssertEqual(store.loadAll(), [])
    }

    func testLoadAllIgnoresNonJSONFiles() throws {
        let store = RunHistoryStore(directory: testDirectory)
        let run = makeRun(startedAt: Date())
        try store.save(run)

        let strayFile = testDirectory.appendingPathComponent("notes.txt")
        try "hola".write(to: strayFile, atomically: true, encoding: .utf8)

        XCTAssertEqual(store.loadAll(), [run])
    }

    func testLoadAllIgnoresCorruptedJSONFiles() throws {
        let store = RunHistoryStore(directory: testDirectory)
        let run = makeRun(startedAt: Date())
        try store.save(run)

        let corruptedFile = testDirectory.appendingPathComponent("corrupted.json")
        try "{ esto no es json valido".write(to: corruptedFile, atomically: true, encoding: .utf8)

        XCTAssertEqual(store.loadAll(), [run])
    }
}
