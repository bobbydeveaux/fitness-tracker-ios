import Foundation
import SwiftData

// MARK: - WorkoutDay

/// A single training day within a `WorkoutPlan` (e.g. "Push A").
@Model
final class WorkoutDay {

    @Attribute(.unique) var id: UUID

    /// Human-readable label for the day (e.g. "Push A", "Leg Day").
    var dayLabel: String

    /// ISO weekday index (1 = Sunday … 7 = Saturday).
    var weekdayIndex: Int

    // MARK: - Relationships

    var workoutPlan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.workoutDay)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutDay)
    var sessions: [WorkoutSession] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        dayLabel: String,
        weekdayIndex: Int,
        workoutPlan: WorkoutPlan? = nil
    ) {
        self.id = id
        self.dayLabel = dayLabel
        self.weekdayIndex = weekdayIndex
        self.workoutPlan = workoutPlan
    }
}
