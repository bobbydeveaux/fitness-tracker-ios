import Foundation
import SwiftData

// MARK: - Supporting Enums

enum MuscleGroup: String, Codable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case legs
    case glutes
    case core
    case fullBody
}

enum Equipment: String, Codable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case resistanceBand
}

// MARK: - Exercise Model

/// Read-only reference entry in the exercise library. Seeded from exercises.json on first launch.
@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var instructions: String
    /// Optional URL path to a bundled image asset
    var imageName: String?

    @Relationship(deleteRule: .nullify, inverse: \PlannedExercise.exercise)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedSet.exercise)
    var loggedSets: [LoggedSet] = []

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        instructions: String,
        imageName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
        self.imageName = imageName
    }
}
