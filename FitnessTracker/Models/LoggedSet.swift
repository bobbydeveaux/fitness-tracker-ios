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
    var isComplete: Bool
    var isPR: Bool

    // MARK: - Relationships

    var session: WorkoutSession?
    var exercise: Exercise?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        isComplete: Bool = false,
        isPR: Bool = false,
        session: WorkoutSession? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.isComplete = isComplete
        self.isPR = isPR
        self.session = session
        self.exercise = exercise
    }
}
