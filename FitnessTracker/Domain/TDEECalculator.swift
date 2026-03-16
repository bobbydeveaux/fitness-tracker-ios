import Foundation

// MARK: - TDEECalculator

/// Calculates Total Daily Energy Expenditure (TDEE) using the Mifflin-St Jeor equation.
///
/// **Mifflin-St Jeor BMR formulas:**
/// - Male:   `10 × weightKg + 6.25 × heightCm − 5 × age + 5`
/// - Female: `10 × weightKg + 6.25 × heightCm − 5 × age − 161`
///
/// BMR is then multiplied by an activity factor to produce TDEE.
struct TDEECalculator {

    // MARK: - Activity Multipliers

    private static let activityMultiplier: [ActivityLevel: Double] = [
        .sedentary:        1.2,
        .lightlyActive:    1.375,
        .moderatelyActive: 1.55,
        .veryActive:       1.725,
        .extraActive:      1.9
    ]

    // MARK: - Public API

    /// Computes the TDEE (kcal/day) for the given biometric inputs.
    ///
    /// - Parameters:
    ///   - age: Age in years (must be > 0).
    ///   - gender: Biological sex used for the gender constant in Mifflin-St Jeor.
    ///   - heightCm: Height in centimetres (must be > 0).
    ///   - weightKg: Body weight in kilograms (must be > 0).
    ///   - activityLevel: Self-reported activity level.
    /// - Returns: Estimated TDEE in kilocalories per day, rounded to the nearest whole number.
    static func calculate(
        age: Int,
        gender: BiologicalSex,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel
    ) -> Double {
        let bmr = mifflinStJeorBMR(age: age, gender: gender, heightCm: heightCm, weightKg: weightKg)
        let multiplier = activityMultiplier[activityLevel] ?? 1.2
        return (bmr * multiplier).rounded()
    }

    // MARK: - Private

    private static func mifflinStJeorBMR(
        age: Int,
        gender: BiologicalSex,
        heightCm: Double,
        weightKg: Double
    ) -> Double {
        let genderConstant: Double = gender == .male ? 5.0 : -161.0
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + genderConstant
    }
}
