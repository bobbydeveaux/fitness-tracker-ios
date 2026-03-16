import Foundation
import SwiftData

/// Prescribes a specific exercise within a WorkoutDay with target sets, reps, and RPE.
@Model
final class PlannedExercise {
    var id: UUID
    var targetSets: Int
    var targetReps: Int
    /// Rate of perceived exertion target (1–10). Nil means no RPE target specified.
    var targetRPE: Double?
    /// Display order within the day
    var sortOrder: Int

    var workoutDay: WorkoutDay?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        targetSets: Int,
        targetReps: Int,
        targetRPE: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRPE = targetRPE
        self.sortOrder = sortOrder
    }
}
