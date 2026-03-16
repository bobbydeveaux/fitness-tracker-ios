import Foundation
import SwiftData

// MARK: - PlannedExercise

/// Associates an `Exercise` with a `WorkoutDay`, specifying prescribed sets, reps, and RPE.
@Model
final class PlannedExercise {

    @Attribute(.unique) var id: UUID

    var targetSets: Int
    var targetReps: String   // e.g. "6-8" or "12"
    var targetRPE: Double?   // Rate of Perceived Exertion (6-10), optional
    /// Display/insertion order within the workout day.
    var sortOrder: Int

    // MARK: - Relationships

    var workoutDay: WorkoutDay?
    var exercise: Exercise?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        targetSets: Int,
        targetReps: String,
        targetRPE: Double? = nil,
        sortOrder: Int = 0,
        workoutDay: WorkoutDay? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRPE = targetRPE
        self.sortOrder = sortOrder
        self.workoutDay = workoutDay
        self.exercise = exercise
    }
}
