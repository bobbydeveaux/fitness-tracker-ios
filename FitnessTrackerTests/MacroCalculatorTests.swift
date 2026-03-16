import XCTest
@testable import FitnessTracker

// MARK: - MacroCalculatorTests

/// Unit tests for `MacroCalculator`.
///
/// Reference calculations:
/// - cut:      TDEE − 300 kcal; protein 40%, carbs 30%, fat 30%
/// - maintain: TDEE ± 0 kcal;   protein 30%, carbs 40%, fat 30%
/// - bulk:     TDEE + 300 kcal; protein 25%, carbs 50%, fat 25%
final class MacroCalculatorTests: XCTestCase {

    // MARK: - Maintain

    func testMaintainMacros() {
        // TDEE = 2500, maintain → target = 2500
        // protein: 2500 × 0.30 / 4 = 187.5 → 188
        // carbs:   2500 × 0.40 / 4 = 250
        // fat:     2500 × 0.30 / 9 = 83.33 → 83
        let result = MacroCalculator.calculate(tdeeKcal: 2500, goal: .maintain)
        XCTAssertEqual(result.proteinG, 188, accuracy: 0.5)
        XCTAssertEqual(result.carbsG,   250, accuracy: 0.5)
        XCTAssertEqual(result.fatG,      83, accuracy: 0.5)
    }

    // MARK: - Cut

    func testCutMacros() {
        // TDEE = 2500, cut → target = 2200
        // protein: 2200 × 0.40 / 4 = 220
        // carbs:   2200 × 0.30 / 4 = 165
        // fat:     2200 × 0.30 / 9 = 73.33 → 73
        let result = MacroCalculator.calculate(tdeeKcal: 2500, goal: .cut)
        XCTAssertEqual(result.proteinG, 220, accuracy: 0.5)
        XCTAssertEqual(result.carbsG,   165, accuracy: 0.5)
        XCTAssertEqual(result.fatG,      73, accuracy: 0.5)
    }

    // MARK: - Bulk

    func testBulkMacros() {
        // TDEE = 2500, bulk → target = 2800
        // protein: 2800 × 0.25 / 4 = 175
        // carbs:   2800 × 0.50 / 4 = 350
        // fat:     2800 × 0.25 / 9 = 77.78 → 78
        let result = MacroCalculator.calculate(tdeeKcal: 2500, goal: .bulk)
        XCTAssertEqual(result.proteinG, 175, accuracy: 0.5)
        XCTAssertEqual(result.carbsG,   350, accuracy: 0.5)
        XCTAssertEqual(result.fatG,      78, accuracy: 0.5)
    }

    // MARK: - Calorie adjustment ordering

    func testCutProducesLowerCarbsThanBulk() {
        let cut  = MacroCalculator.calculate(tdeeKcal: 2000, goal: .cut)
        let bulk = MacroCalculator.calculate(tdeeKcal: 2000, goal: .bulk)
        XCTAssertLessThan(cut.carbsG, bulk.carbsG, "Cut should have fewer carbs than bulk")
    }

    func testCutProducesHigherProteinRatioThanBulk() {
        let tdee: Double = 2000
        let cut  = MacroCalculator.calculate(tdeeKcal: tdee, goal: .cut)
        let bulk = MacroCalculator.calculate(tdeeKcal: tdee, goal: .bulk)
        XCTAssertGreaterThan(cut.proteinG, bulk.proteinG, "Cut goal should have higher protein than bulk given same TDEE")
    }

    // MARK: - Positive gram values

    func testAllMacroValuesArePositive() {
        for goal in [FitnessGoal.cut, .maintain, .bulk] {
            let result = MacroCalculator.calculate(tdeeKcal: 2000, goal: goal)
            XCTAssertGreaterThan(result.proteinG, 0, "Protein must be > 0 for goal \(goal)")
            XCTAssertGreaterThan(result.carbsG,   0, "Carbs must be > 0 for goal \(goal)")
            XCTAssertGreaterThan(result.fatG,     0, "Fat must be > 0 for goal \(goal)")
        }
    }
}
