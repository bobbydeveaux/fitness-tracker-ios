import Foundation
import SwiftData

/// Records a single performed set during a WorkoutSession.
@Model
final class LoggedSet {
    var id: UUID
    /// Weight lifted in kilograms
    var weightKg: Double
    var reps: Int
    /// Rate of perceived exertion (1–10). Nil if not recorded.
    var rpe: Double?
    /// True when this set established a new personal record for the exercise
    var isPR: Bool
    var isComplete: Bool
    var performedAt: Date
    /// Display/insertion order within the session
    var sortOrder: Int

    var session: WorkoutSession?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        isPR: Bool = false,
        isComplete: Bool = false,
        performedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.isPR = isPR
        self.isComplete = isComplete
        self.performedAt = performedAt
        self.sortOrder = sortOrder
    }
}
