import XCTest
@testable import RunCoachCore

final class OpenAICoachResponseParserTests: XCTestCase {

    func testParsesValidResponse() {
        let json = """
        {
          "choices": [
            { "message": { "content": "Bajá un poco el ritmo, todavía te queda carrera." } }
          ]
        }
        """
        let data = Data(json.utf8)

        let recommendation = OpenAICoachResponseParser.parseRecommendation(from: data)

        XCTAssertEqual(recommendation?.message, "Bajá un poco el ritmo, todavía te queda carrera.")
    }

    func testTrimsWhitespaceAndNewlines() {
        let json = """
        {
          "choices": [
            { "message": { "content": "  Vas bien, mantené el ritmo.\\n" } }
          ]
        }
        """
        let recommendation = OpenAICoachResponseParser.parseRecommendation(from: Data(json.utf8))

        XCTAssertEqual(recommendation?.message, "Vas bien, mantené el ritmo.")
    }

    func testEmptyChoicesReturnsNil() {
        let json = """
        { "choices": [] }
        """
        XCTAssertNil(OpenAICoachResponseParser.parseRecommendation(from: Data(json.utf8)))
    }

    func testBlankMessageReturnsNil() {
        let json = """
        { "choices": [ { "message": { "content": "   " } } ] }
        """
        XCTAssertNil(OpenAICoachResponseParser.parseRecommendation(from: Data(json.utf8)))
    }

    func testMalformedJSONReturnsNil() {
        let data = Data("no es json".utf8)
        XCTAssertNil(OpenAICoachResponseParser.parseRecommendation(from: data))
    }

    func testMissingChoicesKeyReturnsNil() {
        let json = """
        { "unexpected": "shape" }
        """
        XCTAssertNil(OpenAICoachResponseParser.parseRecommendation(from: Data(json.utf8)))
    }

    func testEmptyDataReturnsNil() {
        XCTAssertNil(OpenAICoachResponseParser.parseRecommendation(from: Data()))
    }
}
