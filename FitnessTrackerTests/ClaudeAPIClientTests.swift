import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - MockURLProtocol

/// Intercepts URL requests in tests and returns pre-configured responses.
/// Register a `requestHandler` before each test that uses this protocol.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// Set this to provide the (HTTPURLResponse, Data) the mock returns, or throw
    /// to simulate a network-level failure.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - ClaudeAPIClientTests

@MainActor
final class ClaudeAPIClientTests: XCTestCase {

    // MARK: - Properties

    private var mockSession: URLSession!
    private var keychainService: KeychainService!
    private let testKeychainService = "com.fitnessTracker.tests.claude"
    private var sut: ClaudeAPIClient!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()

        // Configure URLSession to use MockURLProtocol for all requests.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        keychainService = KeychainService(service: testKeychainService)
        // Pre-populate a test API key so tests don't fail with missingAPIKey.
        try? keychainService.saveAPIKey("sk-ant-test-key")

        sut = ClaudeAPIClient(keychainService: keychainService, session: mockSession)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        try? keychainService.deleteAPIKey()
        sut = nil
        mockSession = nil
        keychainService = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(
        goal: FitnessGoal = .bulk,
        activityLevel: ActivityLevel = .moderatelyActive
    ) throws -> UserProfile {
        let container = try AppSchema.makeContainer(inMemory: true)
        return UserProfile(
            name: "Test User",
            age: 28,
            gender: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: activityLevel,
            goal: goal,
            tdeeKcal: 2800,
            proteinTargetG: 200,
            carbTargetG: 300,
            fatTargetG: 80
        )
    }

    /// Builds a valid Claude API JSON response for the given plan JSON string.
    private func makeClaudeEnvelope(planJSON: String) -> Data {
        let escaped = planJSON
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let envelope = """
        {
          "content": [
            { "type": "text", "text": "\(escaped)" }
          ]
        }
        """
        return Data(envelope.utf8)
    }

    private func makeHTTPResponse(statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    /// A minimal valid `WorkoutPlanResponse` JSON.
    private var validPlanJSON: String {
        """
        {
          "splitType": "FullBody",
          "days": [
            {
              "label": "Full Body A",
              "weekdayIndex": 2,
              "exercises": [
                { "name": "Barbell Squat", "sets": 4, "reps": "5", "restSeconds": 180 },
                { "name": "Bench Press", "sets": 4, "reps": "6-8", "restSeconds": 120 }
              ]
            }
          ]
        }
        """
    }

    // MARK: - Success path

    func test_generatePlan_validResponse_returnsPopulatedWorkoutPlan() async throws {
        let profile = try makeProfile()
        let responseData = makeClaudeEnvelope(planJSON: validPlanJSON)

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        let plan = try await sut.generatePlan(profile: profile)

        XCTAssertEqual(plan.splitType, .fullBody)
        XCTAssertEqual(plan.daysPerWeek, 1)
        XCTAssertFalse(plan.days.isEmpty)
        XCTAssertEqual(plan.days.first?.dayLabel, "Full Body A")
        XCTAssertEqual(plan.days.first?.weekdayIndex, 2)
        XCTAssertEqual(plan.days.first?.plannedExercises.count, 2)
    }

    func test_generatePlan_setsAndRepsAreMapped() async throws {
        let profile = try makeProfile()
        let responseData = makeClaudeEnvelope(planJSON: validPlanJSON)

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        let plan = try await sut.generatePlan(profile: profile)
        let first = plan.days.first?.plannedExercises.first

        XCTAssertEqual(first?.targetSets, 4)
        XCTAssertEqual(first?.targetReps, "5")
        XCTAssertEqual(first?.sortOrder, 0)
    }

    func test_generatePlan_unknownSplitType_defaultsToFullBody() async throws {
        let profile = try makeProfile()
        let json = """
        {
          "splitType": "UnknownSplit",
          "days": [
            {
              "label": "Day 1",
              "weekdayIndex": 2,
              "exercises": [
                { "name": "Push-Up", "sets": 3, "reps": "15", "restSeconds": 60 }
              ]
            }
          ]
        }
        """
        let responseData = makeClaudeEnvelope(planJSON: json)
        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertEqual(plan.splitType, .fullBody)
    }

    func test_generatePlan_stripsMarkdownFences() async throws {
        let profile = try makeProfile()
        let fencedJSON = "```json\n\(validPlanJSON)\n```"
        let responseData = makeClaudeEnvelope(planJSON: fencedJSON)

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        // Should not throw — fences must be stripped before JSON decode.
        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertFalse(plan.days.isEmpty)
    }

    func test_generatePlan_stripsBareMarkdownFences() async throws {
        let profile = try makeProfile()
        let fencedJSON = "```\n\(validPlanJSON)\n```"
        let responseData = makeClaudeEnvelope(planJSON: fencedJSON)

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertFalse(plan.days.isEmpty)
    }

    // MARK: - Error paths

    func test_generatePlan_missingAPIKey_throwsMissingAPIKey() async throws {
        try keychainService.deleteAPIKey()
        let profile = try makeProfile()

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.missingAPIKey")
        } catch ClaudeAPIError.missingAPIKey {
            // Expected
        }
    }

    func test_generatePlan_networkFailure_throwsNetworkFailure() async throws {
        let profile = try makeProfile()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.networkFailure")
        } catch ClaudeAPIError.networkFailure {
            // Expected
        }
    }

    func test_generatePlan_non200StatusCode_throwsHTTPError() async throws {
        let profile = try makeProfile()
        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(statusCode: 401), Data())
        }

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.httpError")
        } catch ClaudeAPIError.httpError(let code) {
            XCTAssertEqual(code, 401)
        }
    }

    func test_generatePlan_500StatusCode_throwsHTTPError() async throws {
        let profile = try makeProfile()
        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(statusCode: 500), Data())
        }

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.httpError")
        } catch ClaudeAPIError.httpError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    func test_generatePlan_malformedJSON_throwsDecodingFailure() async throws {
        let profile = try makeProfile()
        // Return a Claude envelope, but with invalid inner JSON.
        let badInner = "this is not json at all"
        let responseData = makeClaudeEnvelope(planJSON: badInner)
        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), responseData)
        }

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.decodingFailure")
        } catch ClaudeAPIError.decodingFailure {
            // Expected
        }
    }

    func test_generatePlan_invalidClaudeEnvelope_throwsDecodingFailure() async throws {
        let profile = try makeProfile()
        // Raw bytes that are not valid JSON at all.
        let garbage = Data("not-json".utf8)
        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), garbage)
        }

        do {
            _ = try await sut.generatePlan(profile: profile)
            XCTFail("Expected ClaudeAPIError.decodingFailure")
        } catch ClaudeAPIError.decodingFailure {
            // Expected
        }
    }

    // MARK: - Prompt content

    func test_generatePlan_requestContainsAllFourInputFields() async throws {
        let profile = try makeProfile(goal: .cut, activityLevel: .veryActive)

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { [weak self] request in
            capturedRequest = request
            return (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: self!.validPlanJSON))
        }

        _ = try? await sut.generatePlan(profile: profile)

        guard let body = capturedRequest?.httpBody,
              let bodyString = String(data: body, encoding: .utf8) else {
            XCTFail("Request body was empty or not UTF-8")
            return
        }

        // Verify the four required input fields appear in the prompt.
        XCTAssertTrue(bodyString.contains("Goal"), "Prompt must include goal field")
        XCTAssertTrue(bodyString.contains("Experience level"), "Prompt must include experience level field")
        XCTAssertTrue(bodyString.contains("equipment"), "Prompt must include equipment field")
        XCTAssertTrue(bodyString.contains("days per week"), "Prompt must include days per week field")
    }

    func test_generatePlan_requestUsesCorrectModel() async throws {
        let profile = try makeProfile()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { [weak self] request in
            capturedRequest = request
            return (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: self!.validPlanJSON))
        }

        _ = try? await sut.generatePlan(profile: profile)

        guard let body = capturedRequest?.httpBody,
              let bodyString = String(data: body, encoding: .utf8) else {
            XCTFail("Request body was empty")
            return
        }

        XCTAssertTrue(bodyString.contains("claude-opus-4-6"), "Request must use claude-opus-4-6 model")
    }

    func test_generatePlan_requestSetsRequiredHeaders() async throws {
        let profile = try makeProfile()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { [weak self] request in
            capturedRequest = request
            return (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: self!.validPlanJSON))
        }

        _ = try? await sut.generatePlan(profile: profile)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(capturedRequest?.value(forHTTPHeaderField: "x-api-key"))
        XCTAssertNotNil(capturedRequest?.value(forHTTPHeaderField: "anthropic-version"))
    }

    // MARK: - Goal mapping in prompt

    func test_generatePlan_cutGoal_includesGoalInPrompt() async throws {
        let profile = try makeProfile(goal: .cut)
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { [weak self] request in
            capturedRequest = request
            return (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: self!.validPlanJSON))
        }

        _ = try? await sut.generatePlan(profile: profile)

        let body = capturedRequest.flatMap { $0.httpBody }
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        XCTAssertTrue(body.contains("cut"), "Prompt must include the user's goal value")
    }

    // MARK: - Multi-day plan mapping

    func test_generatePlan_multipleDays_mapsSortOrderCorrectly() async throws {
        let profile = try makeProfile()
        let multiDayJSON = """
        {
          "splitType": "PPL",
          "days": [
            {
              "label": "Push",
              "weekdayIndex": 2,
              "exercises": [
                { "name": "Bench Press", "sets": 4, "reps": "6-8", "restSeconds": 120 },
                { "name": "Overhead Press", "sets": 3, "reps": "8-10", "restSeconds": 90 },
                { "name": "Lateral Raise", "sets": 3, "reps": "12-15", "restSeconds": 60 }
              ]
            }
          ]
        }
        """

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: multiDayJSON))
        }

        let plan = try await sut.generatePlan(profile: profile)
        let exercises = plan.days.first?.plannedExercises.sorted { $0.sortOrder < $1.sortOrder } ?? []

        XCTAssertEqual(exercises.count, 3)
        XCTAssertEqual(exercises[0].sortOrder, 0)
        XCTAssertEqual(exercises[1].sortOrder, 1)
        XCTAssertEqual(exercises[2].sortOrder, 2)
    }

    func test_generatePlan_weekdayIndexAbsent_assignsDefault() async throws {
        let profile = try makeProfile()
        let noIndexJSON = """
        {
          "splitType": "FullBody",
          "days": [
            {
              "label": "Day 1",
              "exercises": [
                { "name": "Squat", "sets": 3, "reps": "8", "restSeconds": 90 }
              ]
            }
          ]
        }
        """

        MockURLProtocol.requestHandler = { [weak self] _ in
            (self!.makeHTTPResponse(), self!.makeClaudeEnvelope(planJSON: noIndexJSON))
        }

        let plan = try await sut.generatePlan(profile: profile)
        let weekdayIndex = plan.days.first?.weekdayIndex ?? 0
        // Default for first day (index 0): (0 % 7) + 2 = 2
        XCTAssertEqual(weekdayIndex, 2)
    }
}
