import Foundation
import SwiftData

// MARK: - LoggedSet

/// A single set performed during a `WorkoutSession`.
@Model
final class LoggedSet {

    @Attribute(.unique) var id: UUID

    var setIndex: Int
    var weightKg: Double
    var reps: Int
    /// Rate of perceived exertion (1–10). Nil if not recorded.
    var rpe: Double?
    var isComplete: Bool
    var isPR: Bool
    /// Display/insertion order within the session.
    var sortOrder: Int

    // MARK: - Relationships

    var session: WorkoutSession?
    var exercise: Exercise?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        isComplete: Bool = false,
        isPR: Bool = false,
        sortOrder: Int = 0,
        session: WorkoutSession? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.isComplete = isComplete
        self.isPR = isPR
        self.sortOrder = sortOrder
        self.session = session
        self.exercise = exercise
    }
}
