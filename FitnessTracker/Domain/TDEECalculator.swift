import Foundation

// MARK: - TDEECalculator

/// Pure, framework-free struct for computing Total Daily Energy Expenditure
/// using the Mifflin-St Jeor equation.
///
/// Formula:
/// - Male BMR   = 10 × weightKg + 6.25 × heightCm − 5 × age + 5
/// - Female BMR = 10 × weightKg + 6.25 × heightCm − 5 × age − 161
///
/// TDEE = BMR × activityMultiplier
/// Adjusted TDEE = TDEE ± goalOffset
struct TDEECalculator {

    // MARK: - Activity Multipliers

    /// Harris-Benedict activity multipliers applied to BMR.
    static func activityMultiplier(for level: ActivityLevel) -> Double {
        switch level {
        case .sedentary:        return 1.2    // little or no exercise
        case .lightlyActive:    return 1.375  // 1–3 days/week
        case .moderatelyActive: return 1.55   // 3–5 days/week
        case .veryActive:       return 1.725  // 6–7 days/week
        case .extraActive:      return 1.9    // twice/day or physical job
        }
    }

    // MARK: - Goal Offsets (kcal)

    /// Caloric adjustment applied on top of TDEE based on the user's goal.
    static func goalOffset(for goal: FitnessGoal) -> Double {
        switch goal {
        case .cut:      return -500   // deficit to lose ~0.5 kg/week
        case .maintain: return 0
        case .bulk:     return +300   // modest surplus to minimise fat gain
        }
    }

    // MARK: - Core Calculations

    /// Computes the Basal Metabolic Rate (kcal/day) using Mifflin-St Jeor.
    /// - Parameters:
    ///   - gender: Biological sex of the user.
    ///   - weightKg: Body weight in kilograms.
    ///   - heightCm: Height in centimetres.
    ///   - age: Age in whole years.
    /// - Returns: BMR in kilocalories per day.
    static func bmr(
        gender: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        age: Int
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5.0 * Double(age)
        switch gender {
        case .male:   return base + 5
        case .female: return base - 161
        }
    }

    /// Computes goal-adjusted TDEE (kcal/day).
    /// - Parameters:
    ///   - gender: Biological sex.
    ///   - weightKg: Body weight in kilograms.
    ///   - heightCm: Height in centimetres.
    ///   - age: Age in whole years.
    ///   - activityLevel: Daily activity level.
    ///   - goal: User's fitness goal (cut / maintain / bulk).
    /// - Returns: Adjusted TDEE in kilocalories per day.
    static func tdee(
        gender: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        age: Int,
        activityLevel: ActivityLevel,
        goal: FitnessGoal
    ) -> Double {
        let bmrValue = bmr(gender: gender, weightKg: weightKg, heightCm: heightCm, age: age)
        let maintenance = bmrValue * activityMultiplier(for: activityLevel)
        return maintenance + goalOffset(for: goal)
    }
}
