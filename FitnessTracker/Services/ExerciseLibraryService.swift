import Foundation

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-4)

/// Loads and caches the bundled `exercises.json` asset, seeding `Exercise`
/// records into SwiftData on first launch via a `UserDefaults` flag.
///
/// The full implementation — including JSON decoding, SwiftData upsert, and
/// deduplication logic — is added in task-ios-fitness-tracker-app-feat-foundation-4.
final class ExerciseLibraryService {

    // MARK: - Singleton

    static let shared = ExerciseLibraryService()

    // MARK: - State

    private(set) var exercises: [Exercise] = []

    // MARK: - Init

    init() {}

    // MARK: - API (stub bodies replaced in foundation-4)

    /// Seeds exercises from `exercises.json` into SwiftData on first launch.
    /// Subsequent calls are a no-op (guarded by a `UserDefaults` flag).
    func seedIfNeeded() async {
        // Implementation added in task-ios-fitness-tracker-app-feat-foundation-4
    }

    /// Returns exercises filtered by muscle group, or all exercises when `nil`.
    func exercises(for muscleGroup: String? = nil) -> [Exercise] {
        exercises
    }
}
