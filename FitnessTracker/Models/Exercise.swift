import Foundation
import SwiftData

// MARK: - Exercise

/// An exercise from the bundled library. Seeded once from `exercises.json` on
/// first launch and treated as read-only at runtime.
@Model
final class Exercise {

    // MARK: - Stored properties

    /// Stable string identifier matching the `"id"` field in `exercises.json`.
    @Attribute(.unique) var exerciseID: String

    /// Display name of the exercise (e.g. "Barbell Bench Press").
    var name: String

    /// Primary muscle group targeted (e.g. "Chest", "Back", "Quadriceps").
    var muscleGroup: String

    /// Equipment required (e.g. "Barbell", "Dumbbell", "Bodyweight", "Cable", "Machine").
    var equipment: String

    /// Step-by-step instructions for performing the exercise safely and correctly.
    var instructions: String

    /// Name of the image asset in the Asset Catalogue (without extension).
    var imageName: String

    // MARK: - Relationships

    /// Back-reference to `PlannedExercise` records that reference this exercise.
    @Relationship(deleteRule: .nullify, inverse: \PlannedExercise.exercise)
    var plannedExercises: [PlannedExercise] = []

    /// Back-reference to `LoggedSet` records that reference this exercise.
    @Relationship(deleteRule: .nullify, inverse: \LoggedSet.exercise)
    var loggedSets: [LoggedSet] = []

    // MARK: - Initialisation

    init(
        exerciseID: String,
        name: String,
        muscleGroup: String,
        equipment: String,
        instructions: String,
        imageName: String
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
        self.imageName = imageName
    }
}
