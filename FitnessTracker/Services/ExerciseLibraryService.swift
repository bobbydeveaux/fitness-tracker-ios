import Foundation
import SwiftData

// MARK: - JSON Decodable DTO

/// Represents a single exercise record as stored in exercises.json.
struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let muscleGroup: String
    let equipment: String
    let instructions: String
    let imageName: String
}

// MARK: - ExerciseLibraryService

/// Loads the bundled exercises.json and seeds `Exercise` records into SwiftData exactly once.
///
/// Seeding is guarded by the `"exerciseLibrarySeeded"` UserDefaults flag so that
/// subsequent app launches do not duplicate records. The service also provides
/// filtered in-memory queries so callers never need to import SwiftData directly.
@Observable
final class ExerciseLibraryService {

    // MARK: - Constants

    private enum Keys {
        static let seededFlag = "exerciseLibrarySeeded"
        static let jsonFileName = "exercises"
        static let jsonFileExtension = "json"
    }

    // MARK: - Stored properties

    private let modelContainer: ModelContainer
    private var cache: [Exercise] = []

    // MARK: - Initialisation

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Seeding

    /// Seeds exercises from the bundled JSON on first launch.
    ///
    /// Guards against duplicate records by checking `UserDefaults` before inserting.
    /// Must be called once from `FitnessTrackerApp` inside a `.task` modifier.
    func seedIfNeeded() async throws {
        guard !UserDefaults.standard.bool(forKey: Keys.seededFlag) else {
            await loadCache()
            return
        }

        let dtos = try loadExercisesFromBundle()
        try await insertExercises(dtos)

        UserDefaults.standard.set(true, forKey: Keys.seededFlag)
        await loadCache()
    }

    // MARK: - Queries

    /// Returns all cached exercises.
    func allExercises() -> [Exercise] {
        cache
    }

    /// Returns exercises filtered by muscle group (case-insensitive).
    func exercises(forMuscleGroup muscleGroup: String) -> [Exercise] {
        cache.filter { $0.muscleGroup.lowercased() == muscleGroup.lowercased() }
    }

    /// Returns exercises filtered by equipment type (case-insensitive).
    func exercises(forEquipment equipment: String) -> [Exercise] {
        cache.filter { $0.equipment.lowercased() == equipment.lowercased() }
    }

    /// Returns exercises matching both muscle group and equipment (case-insensitive).
    func exercises(forMuscleGroup muscleGroup: String, equipment: String) -> [Exercise] {
        cache.filter {
            $0.muscleGroup.lowercased() == muscleGroup.lowercased() &&
            $0.equipment.lowercased() == equipment.lowercased()
        }
    }

    /// Returns the exercise with the given identifier, or `nil` if not found.
    func exercise(withID id: String) -> Exercise? {
        cache.first { $0.exerciseID == id }
    }

    // MARK: - Private helpers

    /// Decodes `exercises.json` from the main app bundle.
    private func loadExercisesFromBundle() throws -> [ExerciseDTO] {
        guard let url = Bundle.main.url(
            forResource: Keys.jsonFileName,
            withExtension: Keys.jsonFileExtension
        ) else {
            throw ExerciseLibraryError.bundleFileNotFound(Keys.jsonFileName + "." + Keys.jsonFileExtension)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([ExerciseDTO].self, from: data)
    }

    /// Inserts `ExerciseDTO` records as `Exercise` SwiftData models in a background context.
    @MainActor
    private func insertExercises(_ dtos: [ExerciseDTO]) throws {
        let context = modelContainer.mainContext
        for dto in dtos {
            let exercise = Exercise(
                exerciseID: dto.id,
                name: dto.name,
                muscleGroup: dto.muscleGroup,
                equipment: dto.equipment,
                instructions: dto.instructions,
                imageName: dto.imageName
            )
            context.insert(exercise)
        }
        try context.save()
    }

    /// Fetches all `Exercise` records from SwiftData into the in-memory cache.
    @MainActor
    private func loadCache() {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        cache = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Errors

enum ExerciseLibraryError: LocalizedError {
    case bundleFileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .bundleFileNotFound(let fileName):
            return "Exercise library JSON '\(fileName)' was not found in the app bundle."
        }
    }
}
