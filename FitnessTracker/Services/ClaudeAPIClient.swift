import Foundation

// MARK: - WorkoutPlanGenerating

/// Protocol shared by `ClaudeAPIClient` (live) and `FallbackPlanProvider` (offline/test).
///
/// Conforming types accept a `UserProfile` and return a fully-populated
/// `WorkoutPlan` entity graph that the caller can insert into a SwiftData context.
protocol WorkoutPlanGenerating {
    func generatePlan(profile: UserProfile) async throws -> WorkoutPlan
}

// MARK: - WorkoutPlanResponse DTOs

/// Top-level JSON response returned by the Claude API for workout plan generation.
struct WorkoutPlanResponse: Decodable {
    let splitType: String
    let days: [DayResponse]

    struct DayResponse: Decodable {
        let label: String
        /// ISO weekday index (1 = Sunday … 7 = Saturday). Optional so the client
        /// can supply a default when Claude omits it.
        let weekdayIndex: Int?
        let exercises: [ExerciseResponse]
    }

    struct ExerciseResponse: Decodable {
        let name: String
        let sets: Int
        /// Rep range string, e.g. `"6-8"` or `"12"`.
        let reps: String
        let restSeconds: Int?
    }
}

// MARK: - ClaudeMessagesResponse

/// Envelope returned by the Anthropic Messages API (`/v1/messages`).
private struct ClaudeMessagesResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }
    let content: [Content]
}

// MARK: - ClaudeAPIError

/// Typed errors thrown by `ClaudeAPIClient`.
enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkFailure(Error)
    case httpError(statusCode: Int)
    case decodingFailure(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is not configured. Please add your API key in Settings."
        case .invalidURL:
            return "The Claude API endpoint URL is invalid."
        case .networkFailure(let underlying):
            return "Network request failed: \(underlying.localizedDescription)"
        case .httpError(let code):
            return "Claude API returned HTTP \(code)."
        case .decodingFailure(let underlying):
            return "Failed to decode workout plan response: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - ClaudeAPIClient

/// Thin `async/await` HTTP client for the Anthropic Messages API.
///
/// Constructs a structured prompt from a `UserProfile` (deriving experience level,
/// recommended days per week, and a default equipment list), POSTs to
/// `https://api.anthropic.com/v1/messages`, strips any markdown fences from the
/// response, and maps the decoded `WorkoutPlanResponse` into a SwiftData
/// `WorkoutPlan` entity graph.
///
/// The Claude API key is retrieved at call time from the iOS Keychain via
/// `KeychainService`. If the key is absent, or if the network call fails,
/// the caller should catch `ClaudeAPIError` and fall back to `FallbackPlanProvider`.
///
/// Example usage:
/// ```swift
/// let client = ClaudeAPIClient(keychainService: env.keychainService)
/// let plan = try await client.generatePlan(profile: userProfile)
/// ```
final class ClaudeAPIClient: WorkoutPlanGenerating {

    // MARK: - Constants

    private enum Constants {
        static let apiURLString = "https://api.anthropic.com/v1/messages"
        static let model = "claude-opus-4-6"
        static let maxTokens = 1024
        static let anthropicVersion = "2023-06-01"
    }

    // MARK: - Dependencies

    private let keychainService: KeychainService
    private let session: URLSession

    // MARK: - Init

    /// - Parameters:
    ///   - keychainService: Provides the Claude API key stored in the Keychain.
    ///   - session: URL session to use for network requests. Defaults to `.shared`.
    ///              Inject a custom session in tests to avoid real network calls.
    init(keychainService: KeychainService, session: URLSession = .shared) {
        self.keychainService = keychainService
        self.session = session
    }

    // MARK: - WorkoutPlanGenerating

    /// Generates a `WorkoutPlan` by calling the Claude Messages API.
    ///
    /// The returned plan is detached (not yet inserted into a `ModelContext`).
    /// Insert it and any related `WorkoutDay` / `PlannedExercise` entities via your
    /// repository after this call succeeds.
    ///
    /// - Parameter profile: The user's profile, used to derive goal, experience
    ///   level, and recommended training days per week.
    /// - Returns: A populated `WorkoutPlan` entity graph.
    /// - Throws: `ClaudeAPIError` on missing key, network failure, non-200 HTTP
    ///   status, or JSON decoding failure.
    func generatePlan(profile: UserProfile) async throws -> WorkoutPlan {
        let apiKey = try retrieveAPIKey()

        guard let url = URL(string: Constants.apiURLString) else {
            throw ClaudeAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Constants.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(makeRequestBody(for: profile))

        let (data, response) = try await performRequest(urlRequest)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ClaudeAPIError.httpError(statusCode: http.statusCode)
        }

        let planResponse = try decodeWorkoutPlanResponse(from: data)
        return mapToWorkoutPlan(planResponse: planResponse, profile: profile)
    }

    // MARK: - Private — network

    private func retrieveAPIKey() throws -> String {
        guard let key = try keychainService.apiKey(), !key.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }
        return key
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ClaudeAPIError.networkFailure(error)
        }
    }

    // MARK: - Private — decoding

    private func decodeWorkoutPlanResponse(from data: Data) throws -> WorkoutPlanResponse {
        let claudeResponse: ClaudeMessagesResponse
        do {
            claudeResponse = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)
        } catch {
            throw ClaudeAPIError.decodingFailure(error)
        }

        guard let text = claudeResponse.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeAPIError.decodingFailure(
                NSError(
                    domain: "ClaudeAPIClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No text content found in Claude response"]
                )
            )
        }

        let jsonText = stripMarkdownFences(from: text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ClaudeAPIError.decodingFailure(
                NSError(
                    domain: "ClaudeAPIClient",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not re-encode trimmed response text as UTF-8"]
                )
            )
        }

        do {
            return try JSONDecoder().decode(WorkoutPlanResponse.self, from: jsonData)
        } catch {
            throw ClaudeAPIError.decodingFailure(error)
        }
    }

    /// Removes leading ` ```json ` / ` ``` ` fences and trailing ` ``` ` fences that
    /// Claude sometimes wraps its JSON output in, then trims whitespace.
    private func stripMarkdownFences(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```json") {
            result = String(result.dropFirst("```json".count))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private — mapping

    /// Maps a decoded `WorkoutPlanResponse` into a SwiftData entity graph.
    ///
    /// `PlannedExercise.exercise` is left `nil`; callers may resolve exercise
    /// references by name via `ExerciseLibraryService` before persisting.
    private func mapToWorkoutPlan(planResponse: WorkoutPlanResponse, profile: UserProfile) -> WorkoutPlan {
        let splitType = SplitType(rawValue: planResponse.splitType) ?? .fullBody
        let plan = WorkoutPlan(
            splitType: splitType,
            daysPerWeek: planResponse.days.count,
            userProfile: profile
        )

        for (index, dayResponse) in planResponse.days.enumerated() {
            // Default to consecutive weekdays starting Monday (weekdayIndex 2)
            // when the API omits the field.
            let weekdayIndex = dayResponse.weekdayIndex ?? ((index % 7) + 2)
            let day = WorkoutDay(
                dayLabel: dayResponse.label,
                weekdayIndex: weekdayIndex,
                workoutPlan: plan
            )
            plan.days.append(day)

            for (sortOrder, exerciseResponse) in dayResponse.exercises.enumerated() {
                let planned = PlannedExercise(
                    targetSets: exerciseResponse.sets,
                    targetReps: exerciseResponse.reps,
                    sortOrder: sortOrder,
                    workoutDay: day
                )
                day.plannedExercises.append(planned)
            }
        }

        return plan
    }

    // MARK: - Private — request body

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case system
            case messages
        }

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    /// Builds the Claude API request body, embedding the four user-profile inputs
    /// (goal, experience level, equipment list, days per week) into a structured prompt.
    private func makeRequestBody(for profile: UserProfile) -> RequestBody {
        let goal = profile.goal.rawValue
        let experience = experienceLabel(for: profile.activityLevel)
        let daysPerWeek = recommendedDays(for: profile.activityLevel)
        let equipment = defaultEquipment()

        let userContent = """
        Generate a workout plan for the following profile:
        - Goal: \(goal)
        - Experience level: \(experience)
        - Available equipment: \(equipment.joined(separator: ", "))
        - Training days per week: \(daysPerWeek)

        Return ONLY valid JSON matching this exact schema (no markdown, no extra text):
        {
          "splitType": "<PPL|FullBody|UpperLower>",
          "days": [
            {
              "label": "<day label, e.g. Push A>",
              "weekdayIndex": <1-7>,
              "exercises": [
                { "name": "<exercise name>", "sets": <int>, "reps": "<e.g. 6-8>", "restSeconds": <int> }
              ]
            }
          ]
        }
        """

        return RequestBody(
            model: Constants.model,
            maxTokens: Constants.maxTokens,
            system: "You are a certified personal trainer. Return ONLY valid JSON matching the schema provided. Do not include markdown fences, explanations, or any text outside the JSON object.",
            messages: [.init(role: "user", content: userContent)]
        )
    }

    // MARK: - Private — profile-to-prompt helpers

    /// Maps `ActivityLevel` to a human-readable experience label for the prompt.
    private func experienceLabel(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary, .lightlyActive:   return "beginner"
        case .moderatelyActive:            return "intermediate"
        case .veryActive, .extraActive:    return "advanced"
        }
    }

    /// Derives a recommended training frequency from `ActivityLevel`.
    private func recommendedDays(for level: ActivityLevel) -> Int {
        switch level {
        case .sedentary:        return 3
        case .lightlyActive:    return 3
        case .moderatelyActive: return 4
        case .veryActive:       return 5
        case .extraActive:      return 6
        }
    }

    /// Standard equipment list used in every generated plan.
    private func defaultEquipment() -> [String] {
        ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight"]
    }
}
