import Foundation
import SwiftData

/// A single training day within a WorkoutPlan (e.g. "Push A", "Pull B").
@Model
final class WorkoutDay {
    var id: UUID
    /// Human-readable label, e.g. "Push A", "Legs"
    var label: String
    /// 1 = Monday … 7 = Sunday (matches `Calendar.weekdaySymbols` offset convention)
    var weekdayIndex: Int

    var workoutPlan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.workoutDay)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutDay)
    var sessions: [WorkoutSession] = []

    init(
        id: UUID = UUID(),
        label: String,
        weekdayIndex: Int
    ) {
        self.id = id
        self.label = label
        self.weekdayIndex = weekdayIndex
    }
}
