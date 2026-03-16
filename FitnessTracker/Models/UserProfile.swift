import Foundation
import SwiftData

// MARK: - Supporting enums

enum BiologicalSex: String, Codable {
    case male
    case female
}

enum ActivityLevel: String, Codable {
    case sedentary       // little or no exercise
    case lightlyActive   // 1-3 days/week
    case moderatelyActive // 3-5 days/week
    case veryActive      // 6-7 days/week
    case extraActive     // twice/day or physical job
}

enum FitnessGoal: String, Codable {
    case cut       // caloric deficit, lose fat
    case maintain  // maintenance calories
    case bulk      // caloric surplus, gain muscle
}

// MARK: - UserProfile

/// Stores the user's biometric data, computed TDEE, macro targets, and preferences.
@Model
final class UserProfile {

    @Attribute(.unique) var id: UUID

    var name: String
    var age: Int
    var gender: BiologicalSex
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: FitnessGoal

    /// Computed Total Daily Energy Expenditure in kcal.
    var tdeeKcal: Double

    // Macro targets in grams
    var proteinTargetG: Double
    var carbTargetG: Double
    var fatTargetG: Double

    var createdAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \MealLog.userProfile)
    var mealLogs: [MealLog] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkoutPlan.userProfile)
    var workoutPlans: [WorkoutPlan] = []

    @Relationship(deleteRule: .cascade, inverse: \BodyMetric.userProfile)
    var bodyMetrics: [BodyMetric] = []

    @Relationship(deleteRule: .cascade, inverse: \Streak.userProfile)
    var streaks: [Streak] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        gender: BiologicalSex,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel,
        goal: FitnessGoal,
        tdeeKcal: Double,
        proteinTargetG: Double,
        carbTargetG: Double,
        fatTargetG: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.tdeeKcal = tdeeKcal
        self.proteinTargetG = proteinTargetG
        self.carbTargetG = carbTargetG
        self.fatTargetG = fatTargetG
        self.createdAt = createdAt
    }
}
