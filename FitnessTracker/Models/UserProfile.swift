import Foundation
import SwiftData

// MARK: - Supporting Enums

enum BiologicalSex: String, Codable {
    case male
    case female
}

enum ActivityLevel: String, Codable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive
}

enum FitnessGoal: String, Codable {
    case cut
    case maintain
    case bulk
}

// MARK: - UserProfile Model

@Model
final class UserProfile {
    var id: UUID
    var age: Int
    var biologicalSex: BiologicalSex
    /// Height in centimetres
    var heightCm: Double
    /// Weight in kilograms
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: FitnessGoal
    /// Total daily energy expenditure (kcal)
    var tdee: Double
    /// Protein target in grams
    var proteinGrams: Double
    /// Carbohydrate target in grams
    var carbGrams: Double
    /// Fat target in grams
    var fatGrams: Double
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BodyMetric.userProfile)
    var bodyMetrics: [BodyMetric] = []

    @Relationship(deleteRule: .cascade, inverse: \Streak.userProfile)
    var streaks: [Streak] = []

    init(
        id: UUID = UUID(),
        age: Int,
        biologicalSex: BiologicalSex,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel,
        goal: FitnessGoal,
        tdee: Double,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.age = age
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.tdee = tdee
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
