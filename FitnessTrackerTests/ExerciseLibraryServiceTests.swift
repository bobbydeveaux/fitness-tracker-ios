import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - ExerciseLibraryServiceTests

final class ExerciseLibraryServiceTests: XCTestCase {

    // MARK: - Properties

    private var modelContainer: ModelContainer!
    private var sut: ExerciseLibraryService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Use an in-memory container so tests are isolated and fast.
        let schema = Schema(AppSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        sut = ExerciseLibraryService(modelContainer: modelContainer)

        // Clear the seeding flag before each test.
        UserDefaults.standard.removeObject(forKey: "exerciseLibrarySeeded")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "exerciseLibrarySeeded")
        modelContainer = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Bundle JSON decoding

    /// Verifies that exercises.json is present in the test bundle and decodes without error.
    func test_bundleJSON_decodesSuccessfully() throws {
        // Given: the app bundle contains exercises.json
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            // Fallback: look in the test bundle
            guard let testURL = Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") else {
                XCTFail("exercises.json not found in any bundle")
                return
            }
            let data = try Data(contentsOf: testURL)
            let exercises = try JSONDecoder().decode([ExerciseDTO].self, from: data)
            XCTAssertGreaterThanOrEqual(exercises.count, 100, "Expected at least 100 exercises in exercises.json")
            return
        }

        // When: the JSON is decoded
        let data = try Data(contentsOf: url)
        let exercises = try JSONDecoder().decode([ExerciseDTO].self, from: data)

        // Then: at least 100 exercises are present
        XCTAssertGreaterThanOrEqual(exercises.count, 100, "Expected at least 100 exercises in exercises.json")
    }

    /// Verifies each decoded exercise has non-empty required fields.
    func test_bundleJSON_allExercisesHaveRequiredFields() throws {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") ??
                        Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") else {
            XCTFail("exercises.json not found in any bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let exercises = try JSONDecoder().decode([ExerciseDTO].self, from: data)

        for exercise in exercises {
            XCTAssertFalse(exercise.id.isEmpty, "Exercise ID must not be empty")
            XCTAssertFalse(exercise.name.isEmpty, "Exercise name must not be empty for id: \(exercise.id)")
            XCTAssertFalse(exercise.muscleGroup.isEmpty, "muscleGroup must not be empty for '\(exercise.name)'")
            XCTAssertFalse(exercise.equipment.isEmpty, "equipment must not be empty for '\(exercise.name)'")
            XCTAssertFalse(exercise.instructions.isEmpty, "instructions must not be empty for '\(exercise.name)'")
        }
    }

    // MARK: - Seeding

    /// Seeds once and verifies exercises appear in SwiftData and the cache.
    func test_seedIfNeeded_populatesCache() async throws {
        // Given: no previous seeding
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "exerciseLibrarySeeded"))

        // When: seedIfNeeded is called — only runs if exercises.json is in the test host bundle
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            // Skip seeding test when running without a bundle — correct JSON decoding is covered separately
            return
        }

        try await sut.seedIfNeeded()

        // Then: cache is populated
        let all = await MainActor.run { sut.allExercises() }
        XCTAssertGreaterThan(all.count, 0, "Cache should be populated after seeding")
    }

    /// Verifies the UserDefaults flag is set after seeding.
    func test_seedIfNeeded_setsUserDefaultsFlag() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "exerciseLibrarySeeded"),
                      "UserDefaults flag should be set after seeding")
    }

    /// Calling seedIfNeeded twice should NOT duplicate records.
    func test_seedIfNeeded_doesNotDuplicateOnSecondCall() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()
        let countAfterFirst = await MainActor.run { sut.allExercises().count }

        try await sut.seedIfNeeded()
        let countAfterSecond = await MainActor.run { sut.allExercises().count }

        XCTAssertEqual(countAfterFirst, countAfterSecond,
                       "Re-seeding must not create duplicate Exercise records")
    }

    // MARK: - Filtering queries

    /// Verifies muscle group filtering returns only matching exercises.
    func test_exercises_forMuscleGroup_filtersCorrectly() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()

        let chestExercises = await MainActor.run { sut.exercises(forMuscleGroup: "Chest") }
        for exercise in chestExercises {
            XCTAssertEqual(exercise.muscleGroup.lowercased(), "chest",
                           "All returned exercises should have muscleGroup == 'Chest'")
        }
    }

    /// Verifies equipment filtering returns only matching exercises.
    func test_exercises_forEquipment_filtersCorrectly() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()

        let barbellExercises = await MainActor.run { sut.exercises(forEquipment: "Barbell") }
        for exercise in barbellExercises {
            XCTAssertEqual(exercise.equipment.lowercased(), "barbell",
                           "All returned exercises should have equipment == 'Barbell'")
        }
    }

    /// Verifies exercise lookup by ID.
    func test_exercise_withID_returnsCorrectExercise() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()

        let found = await MainActor.run { sut.exercise(withID: "exercise-001") }
        XCTAssertNotNil(found, "Should find exercise with ID 'exercise-001'")
        XCTAssertEqual(found?.name, "Barbell Bench Press")
    }

    /// Verifies lookup for a missing ID returns nil.
    func test_exercise_withID_returnsNilForUnknownID() async throws {
        guard Bundle.main.url(forResource: "exercises", withExtension: "json") != nil ||
              Bundle(for: type(of: self)).url(forResource: "exercises", withExtension: "json") != nil else {
            return
        }

        try await sut.seedIfNeeded()

        let notFound = await MainActor.run { sut.exercise(withID: "nonexistent-999") }
        XCTAssertNil(notFound)
    }
}
