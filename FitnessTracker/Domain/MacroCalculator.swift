import Foundation

// MARK: - MacroTargets

/// Macro nutrient targets in grams per day.
struct MacroTargets {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

// MARK: - MacroCalculator

/// Pure, framework-free struct for deriving protein, carb, and fat targets
/// from a calorie goal and the user's fitness goal.
///
/// Macro ratios (as % of target calories):
/// - maintain : protein 30%, carbs 40%, fat 30%
/// - cut       : protein 40%, carbs 35%, fat 25%  (high protein preserves muscle in deficit)
/// - bulk      : protein 25%, carbs 50%, fat 25%  (carb-rich surplus supports hypertrophy)
///
/// Calorie densities: protein 4 kcal/g, carbs 4 kcal/g, fat 9 kcal/g.
struct MacroCalculator {

    // MARK: - Macro Ratios

    /// Returns the (proteinRatio, carbRatio, fatRatio) tuple for a given goal.
    /// All three ratios sum to exactly 1.0.
    static func ratios(for goal: FitnessGoal) -> (protein: Double, carbs: Double, fat: Double) {
        switch goal {
        case .maintain: return (0.30, 0.40, 0.30)
        case .cut:      return (0.40, 0.35, 0.25)
        case .bulk:     return (0.25, 0.50, 0.25)
        }
    }

    // MARK: - Core Calculation

    /// Computes macro gram targets from a calorie goal and fitness goal.
    /// - Parameters:
    ///   - calories: Total target kilocalories per day (goal-adjusted TDEE).
    ///   - goal: User's fitness goal (cut / maintain / bulk).
    /// - Returns: `MacroTargets` with gram values rounded to one decimal place.
    static func macros(calories: Double, goal: FitnessGoal) -> MacroTargets {
        let (proteinRatio, carbsRatio, fatRatio) = ratios(for: goal)
        let proteinG = (calories * proteinRatio / 4).rounded(toPlaces: 1)
        let carbsG   = (calories * carbsRatio   / 4).rounded(toPlaces: 1)
        let fatG     = (calories * fatRatio      / 9).rounded(toPlaces: 1)
        return MacroTargets(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}

// MARK: - Double Rounding Helper

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
