import Foundation

// MARK: - MacroTargets

/// Computed macronutrient targets in grams per day.
struct MacroTargets {
    /// Grams of protein per day.
    let proteinG: Double
    /// Grams of carbohydrates per day.
    let carbsG: Double
    /// Grams of fat per day.
    let fatG: Double
}

// MARK: - MacroCalculator

/// Splits a TDEE into per-macronutrient gram targets based on the user's fitness goal.
///
/// **Energy constants:**
/// - Protein: 4 kcal / g
/// - Carbohydrates: 4 kcal / g
/// - Fat: 9 kcal / g
///
/// **Calorie adjustments and macro splits by goal (FR-001):**
///
/// | Goal     | Calorie delta | Protein | Carbs | Fat |
/// |----------|---------------|---------|-------|-----|
/// | cut      | −300 kcal     | 40 %    | 30 %  | 30 %|
/// | maintain |   0 kcal      | 30 %    | 40 %  | 30 %|
/// | bulk     | +300 kcal     | 25 %    | 50 %  | 25 %|
struct MacroCalculator {

    // MARK: - Calorie Adjustments

    private static let calorieAdjustment: [FitnessGoal: Double] = [
        .cut:      -300,
        .maintain:    0,
        .bulk:      +300
    ]

    // MARK: - Macro Ratios (protein, carbs, fat)

    private static let macroRatios: [FitnessGoal: (protein: Double, carbs: Double, fat: Double)] = [
        .cut:      (protein: 0.40, carbs: 0.30, fat: 0.30),
        .maintain: (protein: 0.30, carbs: 0.40, fat: 0.30),
        .bulk:     (protein: 0.25, carbs: 0.50, fat: 0.25)
    ]

    // MARK: - Energy per gram

    private static let kcalPerGramProtein: Double = 4
    private static let kcalPerGramCarbs:   Double = 4
    private static let kcalPerGramFat:     Double = 9

    // MARK: - Public API

    /// Calculates per-macronutrient gram targets for the given TDEE and goal.
    ///
    /// - Parameters:
    ///   - tdeeKcal: The user's Total Daily Energy Expenditure in kilocalories.
    ///   - goal: The user's fitness goal (cut / maintain / bulk).
    /// - Returns: A `MacroTargets` value with protein, carbs, and fat in grams (rounded).
    static func calculate(tdeeKcal: Double, goal: FitnessGoal) -> MacroTargets {
        let adjustment = calorieAdjustment[goal] ?? 0
        let targetKcal = tdeeKcal + adjustment

        let ratios = macroRatios[goal] ?? (protein: 0.30, carbs: 0.40, fat: 0.30)

        let proteinG = (targetKcal * ratios.protein / kcalPerGramProtein).rounded()
        let carbsG   = (targetKcal * ratios.carbs   / kcalPerGramCarbs).rounded()
        let fatG     = (targetKcal * ratios.fat      / kcalPerGramFat).rounded()

        return MacroTargets(proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
}
