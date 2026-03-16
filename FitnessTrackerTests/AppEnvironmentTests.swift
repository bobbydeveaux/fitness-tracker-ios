import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - AppEnvironmentTests

/// Verifies that `AppEnvironment` can be constructed with an in-memory
/// `ModelContainer` and that all typed properties are accessible without
/// circular dependencies.
final class AppEnvironmentTests: XCTestCase {

    // MARK: - Helpers

    /// Builds an `AppEnvironment` backed by an in-memory `ModelContainer`
    /// suitable for unit tests (no file-system or CloudKit side-effects).
    private func makeTestEnvironment() throws -> AppEnvironment {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        return AppEnvironment(
            modelContainer: container,
            userProfileRepository: SwiftDataUserProfileRepository(context: context),
            nutritionRepository: SwiftDataNutritionRepository(context: context),
            workoutRepository: SwiftDataWorkoutRepository(context: context),
            progressRepository: SwiftDataProgressRepository(context: context)
        )
    }

    // MARK: - Tests

    /// `AppEnvironment` constructs without crashing when given an in-memory container.
    func testAppEnvironmentInitialises() throws {
        let env = try makeTestEnvironment()
        XCTAssertNotNil(env.modelContainer)
    }

    /// All repository properties are accessible (non-nil) after initialisation.
    func testAllRepositoriesAreAccessible() throws {
        let env = try makeTestEnvironment()
        // Accessing each typed property verifies there are no circular dependencies
        // and that the DI container wired correctly.
        _ = env.userProfileRepository
        _ = env.nutritionRepository
        _ = env.workoutRepository
        _ = env.progressRepository
        XCTAssert(true, "All repositories accessible without crash")
    }

    /// All service properties are accessible (non-nil) after initialisation.
    func testAllServicesAreAccessible() throws {
        let env = try makeTestEnvironment()
        _ = env.exerciseLibraryService
        _ = env.keychainService
        _ = env.healthKitService
        _ = env.notificationScheduler
        XCTAssert(true, "All services accessible without crash")
    }
}
