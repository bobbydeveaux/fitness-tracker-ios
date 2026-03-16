import Foundation

/// Protocol defining async/throws CRUD and query operations for workout data.
/// Consumers must not import SwiftData directly; all access goes through this abstraction.
public protocol WorkoutRepository: Sendable {

    // MARK: - Exercise Library

    /// Returns all exercises ordered by name ascending.
    func fetchExercises() async throws -> [Exercise]

    /// Returns the exercise with the given identifier, or nil if not found.
    func fetchExercise(byID id: UUID) async throws -> Exercise?

    /// Persists a new or updated Exercise (used by ExerciseLibraryService during seeding).
    func saveExercise(_ exercise: Exercise) async throws

    // MARK: - WorkoutPlan

    /// Returns all workout plans ordered by generatedAt descending.
    func fetchWorkoutPlans() async throws -> [WorkoutPlan]

    /// Returns the currently active workout plan, or nil if none is set.
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan?

    /// Persists a new or updated WorkoutPlan and its child entities.
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws

    /// Removes the WorkoutPlan and its cascade-deleted children (WorkoutDay, PlannedExercise).
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws

    // MARK: - WorkoutSession

    /// Returns all workout sessions ordered by startedAt descending.
    func fetchWorkoutSessions() async throws -> [WorkoutSession]

    /// Returns workout sessions whose startedAt falls within the given range (inclusive).
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession]

    /// Persists a new or updated WorkoutSession.
    func saveWorkoutSession(_ session: WorkoutSession) async throws

    /// Removes the WorkoutSession and its cascade-deleted LoggedSet children.
    func deleteWorkoutSession(_ session: WorkoutSession) async throws

    // MARK: - LoggedSet

    /// Appends a LoggedSet to the given session and persists both.
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws
}
