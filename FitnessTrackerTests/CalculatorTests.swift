import XCTest
@testable import FitnessTracker

// MARK: - TDEECalculatorTests

final class TDEECalculatorTests: XCTestCase {

    // MARK: - BMR

    func testBMR_male_referenceSample() {
        // Male, 30y, 180 cm, 80 kg
        // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let result = TDEECalculator.bmr(gender: .male, weightKg: 80, heightCm: 180, age: 30)
        XCTAssertEqual(result, 1780, accuracy: 0.5)
    }

    func testBMR_female_referenceSample() {
        // Female, 25y, 165 cm, 60 kg
        // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
        let result = TDEECalculator.bmr(gender: .female, weightKg: 60, heightCm: 165, age: 25)
        XCTAssertEqual(result, 1345.25, accuracy: 0.5)
    }

    func testBMR_male_vs_female_differ_by166() {
        // The only difference in Mifflin-St Jeor between male/female is +5 vs -161 → Δ = 166
        let male   = TDEECalculator.bmr(gender: .male,   weightKg: 70, heightCm: 170, age: 35)
        let female = TDEECalculator.bmr(gender: .female, weightKg: 70, heightCm: 170, age: 35)
        XCTAssertEqual(male - female, 166, accuracy: 0.001)
    }

    // MARK: - Activity Multipliers

    func testActivityMultiplier_sedentary() {
        XCTAssertEqual(TDEECalculator.activityMultiplier(for: .sedentary), 1.2, accuracy: 0.001)
    }

    func testActivityMultiplier_lightlyActive() {
        XCTAssertEqual(TDEECalculator.activityMultiplier(for: .lightlyActive), 1.375, accuracy: 0.001)
    }

    func testActivityMultiplier_moderatelyActive() {
        XCTAssertEqual(TDEECalculator.activityMultiplier(for: .moderatelyActive), 1.55, accuracy: 0.001)
    }

    func testActivityMultiplier_veryActive() {
        XCTAssertEqual(TDEECalculator.activityMultiplier(for: .veryActive), 1.725, accuracy: 0.001)
    }

    func testActivityMultiplier_extraActive() {
        XCTAssertEqual(TDEECalculator.activityMultiplier(for: .extraActive), 1.9, accuracy: 0.001)
    }

    // MARK: - Goal Offsets

    func testGoalOffset_cut_isMinus500() {
        XCTAssertEqual(TDEECalculator.goalOffset(for: .cut), -500, accuracy: 0.001)
    }

    func testGoalOffset_maintain_isZero() {
        XCTAssertEqual(TDEECalculator.goalOffset(for: .maintain), 0, accuracy: 0.001)
    }

    func testGoalOffset_bulk_isPlus300() {
        XCTAssertEqual(TDEECalculator.goalOffset(for: .bulk), 300, accuracy: 0.001)
    }

    // MARK: - TDEE (maintenance, no goal adjustment)

    func testTDEE_male_sedentary_maintain() {
        // BMR = 1780, multiplier = 1.2, offset = 0 → TDEE = 1780 * 1.2 = 2136
        let result = TDEECalculator.tdee(
            gender: .male,
            weightKg: 80,
            heightCm: 180,
            age: 30,
            activityLevel: .sedentary,
            goal: .maintain
        )
        XCTAssertEqual(result, 2136, accuracy: 1)
    }

    func testTDEE_male_sedentary_cut() {
        // TDEE maintain = 2136, cut offset = -500 → 1636
        let result = TDEECalculator.tdee(
            gender: .male,
            weightKg: 80,
            heightCm: 180,
            age: 30,
            activityLevel: .sedentary,
            goal: .cut
        )
        XCTAssertEqual(result, 1636, accuracy: 1)
    }

    func testTDEE_male_sedentary_bulk() {
        // TDEE maintain = 2136, bulk offset = +300 → 2436
        let result = TDEECalculator.tdee(
            gender: .male,
            weightKg: 80,
            heightCm: 180,
            age: 30,
            activityLevel: .sedentary,
            goal: .bulk
        )
        XCTAssertEqual(result, 2436, accuracy: 1)
    }

    func testTDEE_female_moderatelyActive_maintain() {
        // BMR = 1345.25, multiplier = 1.55, offset = 0 → 2085.1375
        let result = TDEECalculator.tdee(
            gender: .female,
            weightKg: 60,
            heightCm: 165,
            age: 25,
            activityLevel: .moderatelyActive,
            goal: .maintain
        )
        XCTAssertEqual(result, 2085.14, accuracy: 1)
    }

    func testTDEE_allActivityLevels_increaseMonotonically() {
        let levels: [ActivityLevel] = [.sedentary, .lightlyActive, .moderatelyActive, .veryActive, .extraActive]
        var previous = 0.0
        for level in levels {
            let current = TDEECalculator.tdee(
                gender: .male,
                weightKg: 75,
                heightCm: 175,
                age: 28,
                activityLevel: level,
                goal: .maintain
            )
            XCTAssertGreaterThan(current, previous, "TDEE should increase with each higher activity level")
            previous = current
        }
    }
}

// MARK: - MacroCalculatorTests

final class MacroCalculatorTests: XCTestCase {

    // MARK: - Macro Ratios

    func testRatios_maintain_sumToOne() {
        let (p, c, f) = MacroCalculator.ratios(for: .maintain)
        XCTAssertEqual(p + c + f, 1.0, accuracy: 0.001)
    }

    func testRatios_cut_sumToOne() {
        let (p, c, f) = MacroCalculator.ratios(for: .cut)
        XCTAssertEqual(p + c + f, 1.0, accuracy: 0.001)
    }

    func testRatios_bulk_sumToOne() {
        let (p, c, f) = MacroCalculator.ratios(for: .bulk)
        XCTAssertEqual(p + c + f, 1.0, accuracy: 0.001)
    }

    func testRatios_maintain_splits() {
        let (p, c, f) = MacroCalculator.ratios(for: .maintain)
        XCTAssertEqual(p, 0.30, accuracy: 0.001)
        XCTAssertEqual(c, 0.40, accuracy: 0.001)
        XCTAssertEqual(f, 0.30, accuracy: 0.001)
    }

    func testRatios_cut_higherProtein() {
        let (p, _, _) = MacroCalculator.ratios(for: .cut)
        let (mp, _, _) = MacroCalculator.ratios(for: .maintain)
        XCTAssertGreaterThan(p, mp, "Cut should have higher protein ratio than maintain")
    }

    func testRatios_bulk_higherCarbs() {
        let (_, c, _) = MacroCalculator.ratios(for: .bulk)
        let (_, mc, _) = MacroCalculator.ratios(for: .maintain)
        XCTAssertGreaterThan(c, mc, "Bulk should have higher carb ratio than maintain")
    }

    // MARK: - Macro Gram Calculations

    func testMacros_maintain_2000kcal() {
        // 2000 kcal maintain: protein 30% = 600 kcal / 4 = 150 g
        //                     carbs   40% = 800 kcal / 4 = 200 g
        //                     fat     30% = 600 kcal / 9 ≈ 66.7 g
        let result = MacroCalculator.macros(calories: 2000, goal: .maintain)
        XCTAssertEqual(result.calories, 2000, accuracy: 0.1)
        XCTAssertEqual(result.proteinG, 150, accuracy: 1)
        XCTAssertEqual(result.carbsG, 200, accuracy: 1)
        XCTAssertEqual(result.fatG, 66.7, accuracy: 1)
    }

    func testMacros_cut_2000kcal() {
        // 2000 kcal cut: protein 40% = 800 kcal / 4 = 200 g
        //               carbs   35% = 700 kcal / 4 = 175 g
        //               fat     25% = 500 kcal / 9 ≈ 55.6 g
        let result = MacroCalculator.macros(calories: 2000, goal: .cut)
        XCTAssertEqual(result.proteinG, 200, accuracy: 1)
        XCTAssertEqual(result.carbsG, 175, accuracy: 1)
        XCTAssertEqual(result.fatG, 55.6, accuracy: 1)
    }

    func testMacros_bulk_2400kcal() {
        // 2400 kcal bulk: protein 25% = 600 kcal / 4 = 150 g
        //                 carbs   50% = 1200 kcal / 4 = 300 g
        //                 fat     25% = 600 kcal / 9 ≈ 66.7 g
        let result = MacroCalculator.macros(calories: 2400, goal: .bulk)
        XCTAssertEqual(result.proteinG, 150, accuracy: 1)
        XCTAssertEqual(result.carbsG, 300, accuracy: 1)
        XCTAssertEqual(result.fatG, 66.7, accuracy: 1)
    }

    func testMacros_allGoals_positiveGrams() {
        let goals: [FitnessGoal] = [.cut, .maintain, .bulk]
        for goal in goals {
            let result = MacroCalculator.macros(calories: 2000, goal: goal)
            XCTAssertGreaterThan(result.proteinG, 0, "Protein must be positive for goal \(goal)")
            XCTAssertGreaterThan(result.carbsG, 0, "Carbs must be positive for goal \(goal)")
            XCTAssertGreaterThan(result.fatG, 0, "Fat must be positive for goal \(goal)")
        }
    }

    // MARK: - End-to-end: TDEE → Macros

    func testEndToEnd_male_referenceProfile_maintain() {
        // Male, 30y, 180 cm, 80 kg, sedentary, maintain
        // BMR = 1780, TDEE = 1780 * 1.2 = 2136 kcal
        // protein 30% = 2136*0.30/4 = 160.2 g
        let tdee = TDEECalculator.tdee(
            gender: .male,
            weightKg: 80,
            heightCm: 180,
            age: 30,
            activityLevel: .sedentary,
            goal: .maintain
        )
        let macros = MacroCalculator.macros(calories: tdee, goal: .maintain)
        XCTAssertEqual(macros.proteinG, tdee * 0.30 / 4, accuracy: 1)
        XCTAssertEqual(macros.carbsG,   tdee * 0.40 / 4, accuracy: 1)
        XCTAssertEqual(macros.fatG,     tdee * 0.30 / 9, accuracy: 1)
    }
}
