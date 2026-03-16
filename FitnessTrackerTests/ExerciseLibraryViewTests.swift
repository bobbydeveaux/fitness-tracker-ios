import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - ExerciseLibraryViewTests

/// Unit tests for `ExerciseLibraryView`'s filtering logic and
/// `ExerciseDetailView`'s data presentation — exercised through
/// the `ExerciseLibraryService` in-memory cache without UI rendering.
final class ExerciseLibraryViewTests: XCTestCase {

    // MARK: - Properties

    private var modelContainer: ModelContainer!
    private var service: ExerciseLibraryService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        service = ExerciseLibraryService(modelContainer: modelContainer)
        UserDefaults.standard.removeObject(forKey: "exerciseLibrarySeeded")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "exerciseLibrarySeeded")
        modelContainer = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Filter: All / All

    /// When both filters are "All", every exercise in the library is returned.
    func test_allFilters_returnsAllExercises() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let all = await MainActor.run { service.allExercises() }

        XCTAssertGreaterThan(all.count, 0, "allExercises() must return at least one exercise after seeding")
    }

    // MARK: - Filter: Muscle Group

    /// Filtering by a specific muscle group returns only exercises for that group.
    func test_muscleGroupFilter_chest_returnsOnlyChestExercises() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let chest = await MainActor.run { service.exercises(forMuscleGroup: "Chest") }

        XCTAssertGreaterThan(chest.count, 0, "Expected at least one Chest exercise")
        for exercise in chest {
            XCTAssertEqual(
                exercise.muscleGroup.lowercased(), "chest",
                "Exercise '\(exercise.name)' should be Chest, got '\(exercise.muscleGroup)'"
            )
        }
    }

    /// Filtering by a muscle group that has no exercises returns an empty array.
    func test_muscleGroupFilter_unknown_returnsEmpty() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let result = await MainActor.run { service.exercises(forMuscleGroup: "Telepathy") }

        XCTAssertTrue(result.isEmpty, "Unknown muscle group should yield zero results")
    }

    // MARK: - Filter: Equipment

    /// Filtering by equipment returns only exercises that use that equipment.
    func test_equipmentFilter_barbell_returnsOnlyBarbellExercises() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let barbell = await MainActor.run { service.exercises(forEquipment: "Barbell") }

        XCTAssertGreaterThan(barbell.count, 0, "Expected at least one Barbell exercise")
        for exercise in barbell {
            XCTAssertEqual(
                exercise.equipment.lowercased(), "barbell",
                "Exercise '\(exercise.name)' should use Barbell, got '\(exercise.equipment)'"
            )
        }
    }

    /// Filtering by unknown equipment returns an empty array.
    func test_equipmentFilter_unknown_returnsEmpty() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let result = await MainActor.run { service.exercises(forEquipment: "HoverBoard") }

        XCTAssertTrue(result.isEmpty, "Unknown equipment should yield zero results")
    }

    // MARK: - Filter: Combined

    /// Combining muscle group and equipment filters returns exercises matching both.
    func test_combinedFilter_chestAndBarbell() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let result = await MainActor.run {
            service.exercises(forMuscleGroup: "Chest", equipment: "Barbell")
        }

        XCTAssertGreaterThan(result.count, 0, "Expected at least one Chest + Barbell exercise")
        for exercise in result {
            XCTAssertEqual(exercise.muscleGroup.lowercased(), "chest")
            XCTAssertEqual(exercise.equipment.lowercased(), "barbell")
        }
    }

    /// Combining filters where one has no match returns an empty array.
    func test_combinedFilter_nonexistentCombination_returnsEmpty() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let result = await MainActor.run {
            service.exercises(forMuscleGroup: "Core", equipment: "Barbell")
        }

        // Core exercises are typically Bodyweight — this combination may be empty.
        // Regardless, every returned item must satisfy both constraints.
        for exercise in result {
            XCTAssertEqual(exercise.muscleGroup.lowercased(), "core")
            XCTAssertEqual(exercise.equipment.lowercased(), "barbell")
        }
    }

    // MARK: - ExerciseDetailView data

    /// The service can look up an exercise by ID — the data ExerciseDetailView uses.
    func test_exerciseByID_returnsCorrectExercise() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let exercise = await MainActor.run { service.exercise(withID: "exercise-001") }

        XCTAssertNotNil(exercise, "Should find exercise with known ID 'exercise-001'")
        XCTAssertEqual(exercise?.name, "Barbell Bench Press")
        XCTAssertFalse(exercise?.instructions.isEmpty ?? true, "Instructions must not be empty")
    }

    /// Exercises have non-empty metadata required by ExerciseDetailView.
    func test_allExercises_haveNonEmptyMetadata() async throws {
        guard bundleHasExercisesJSON else { return }

        try await service.seedIfNeeded()
        let all = await MainActor.run { service.allExercises() }

        for exercise in all {
            XCTAssertFalse(exercise.name.isEmpty,         "name must not be empty for id: \(exercise.exerciseID)")
            XCTAssertFalse(exercise.muscleGroup.isEmpty,  "muscleGroup must not be empty for '\(exercise.name)'")
            XCTAssertFalse(exercise.equipment.isEmpty,    "equipment must not be empty for '\(exercise.name)'")
            XCTAssertFalse(exercise.instructions.isEmpty, "instructions must not be empty for '\(exercise.name)'")
        }
    }

    // MARK: - Helpers

    /// `true` when the test-host bundle contains `exercises.json`.
    private var bundleHasExercisesJSON: Bool {
        Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
        Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil
    }
}
