import XCTest
@testable import RunCoachCore

final class OpenAICoachRequestBuilderTests: XCTestCase {

    private func makeSummary(
        event: CoachEvent = .effortRising(currentBPM: 165),
        elapsedSeconds: TimeInterval = 630, // 10:30
        totalDistanceMeters: Double = 2150,
        currentPaceSecondsPerKm: Double? = 300,
        heartRateTrend: HeartRateTrend = .rising
    ) -> CoachEventSummary {
        CoachEventSummary(
            event: event,
            elapsedSeconds: elapsedSeconds,
            totalDistanceMeters: totalDistanceMeters,
            currentPaceSecondsPerKm: currentPaceSecondsPerKm,
            heartRateTrend: heartRateTrend
        )
    }

    func testRequestUsesConfiguredModelAndParameters() {
        let builder = OpenAICoachRequestBuilder(model: "gpt-4o-mini", maxTokens: 60, temperature: 0.7)
        let request = builder.build(for: makeSummary())

        XCTAssertEqual(request.model, "gpt-4o-mini")
        XCTAssertEqual(request.maxTokens, 60)
        XCTAssertEqual(request.temperature, 0.7)
    }

    func testRequestHasSystemAndUserMessages() {
        let builder = OpenAICoachRequestBuilder()
        let request = builder.build(for: makeSummary())

        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.messages[0].role, "system")
        XCTAssertEqual(request.messages[1].role, "user")
        XCTAssertFalse(request.messages[0].content.isEmpty)
    }

    func testUserPromptIncludesMinutesDistanceAndPace() {
        let builder = OpenAICoachRequestBuilder()
        let prompt = builder.userPrompt(for: makeSummary(
            elapsedSeconds: 630,
            totalDistanceMeters: 2150,
            currentPaceSecondsPerKm: 300
        ))

        XCTAssertTrue(prompt.contains("Minuto 10"))
        XCTAssertTrue(prompt.contains("2.2 km") || prompt.contains("2.1 km")) // redondeo de 2.15
        XCTAssertTrue(prompt.contains("5:00 por kilómetro"))
    }

    func testUserPromptDescribesRisingEffort() {
        let builder = OpenAICoachRequestBuilder()
        let prompt = builder.userPrompt(for: makeSummary(event: .effortRising(currentBPM: 165)))
        XCTAssertTrue(prompt.contains("subiendo"))
        XCTAssertTrue(prompt.contains("165"))
    }

    func testUserPromptDescribesDeterioration() {
        let builder = OpenAICoachRequestBuilder()
        let prompt = builder.userPrompt(for: makeSummary(
            event: .deteriorating(currentBPM: 170, currentPaceSecondsPerKm: 360)
        ))
        XCTAssertTrue(prompt.contains("deterioro"))
        XCTAssertTrue(prompt.contains("170"))
        XCTAssertTrue(prompt.contains("6:00 por kilómetro"))
    }

    func testUserPromptDescribesFallingEffort() {
        let builder = OpenAICoachRequestBuilder()
        let prompt = builder.userPrompt(for: makeSummary(event: .effortFalling(currentBPM: 140)))
        XCTAssertTrue(prompt.contains("bajando"))
        XCTAssertTrue(prompt.contains("140"))
    }

    func testUserPromptHandlesMissingPace() {
        let builder = OpenAICoachRequestBuilder()
        let prompt = builder.userPrompt(for: makeSummary(currentPaceSecondsPerKm: nil))
        XCTAssertTrue(prompt.contains("sin datos de ritmo"))
    }

    func testRequestEncodesToExpectedJSONKeys() throws {
        let builder = OpenAICoachRequestBuilder()
        let request = builder.build(for: makeSummary())

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["model"])
        XCTAssertNotNil(json?["messages"])
        XCTAssertNotNil(json?["max_tokens"]) // snake_case, como espera la API de OpenAI
        XCTAssertNotNil(json?["temperature"])
    }
}
