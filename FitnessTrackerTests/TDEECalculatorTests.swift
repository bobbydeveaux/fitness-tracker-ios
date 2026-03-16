import XCTest
@testable import FitnessTracker

// MARK: - TDEECalculatorTests

/// Unit tests for `TDEECalculator`.
///
/// Reference values were computed by hand using the Mifflin-St Jeor formula:
/// - Male BMR   = 10w + 6.25h − 5a + 5
/// - Female BMR = 10w + 6.25h − 5a − 161
///
/// Then multiplied by the relevant activity factor.
final class TDEECalculatorTests: XCTestCase {

    // MARK: - BMR / TDEE correctness

    func testMaleSedentaryTDEE() {
        // BMR: 10×80 + 6.25×175 − 5×30 + 5 = 800 + 1093.75 − 150 + 5 = 1748.75
        // TDEE: 1748.75 × 1.2 = 2098.5 → rounded = 2099
        let result = TDEECalculator.calculate(
            age: 30,
            gender: .male,
            heightCm: 175,
            weightKg: 80,
            activityLevel: .sedentary
        )
        XCTAssertEqual(result, 2099, accuracy: 0.5)
    }

    func testFemaleLightlyActiveTDEE() {
        // BMR: 10×60 + 6.25×165 − 5×25 − 161 = 600 + 1031.25 − 125 − 161 = 1345.25
        // TDEE: 1345.25 × 1.375 = 1849.72 → rounded = 1850
        let result = TDEECalculator.calculate(
            age: 25,
            gender: .female,
            heightCm: 165,
            weightKg: 60,
            activityLevel: .lightlyActive
        )
        XCTAssertEqual(result, 1850, accuracy: 0.5)
    }

    func testMaleModeratelyActiveTDEE() {
        // BMR: 10×90 + 6.25×180 − 5×35 + 5 = 900 + 1125 − 175 + 5 = 1855
        // TDEE: 1855 × 1.55 = 2875.25 → rounded = 2875
        let result = TDEECalculator.calculate(
            age: 35,
            gender: .male,
            heightCm: 180,
            weightKg: 90,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(result, 2875, accuracy: 0.5)
    }

    func testFemaleVeryActiveTDEE() {
        // BMR: 10×65 + 6.25×168 − 5×28 − 161 = 650 + 1050 − 140 − 161 = 1399
        // TDEE: 1399 × 1.725 = 2413.275 → rounded = 2413
        let result = TDEECalculator.calculate(
            age: 28,
            gender: .female,
            heightCm: 168,
            weightKg: 65,
            activityLevel: .veryActive
        )
        XCTAssertEqual(result, 2413, accuracy: 0.5)
    }

    func testMaleExtraActiveTDEE() {
        // BMR: 10×100 + 6.25×190 − 5×22 + 5 = 1000 + 1187.5 − 110 + 5 = 2082.5
        // TDEE: 2082.5 × 1.9 = 3956.75 → rounded = 3957
        let result = TDEECalculator.calculate(
            age: 22,
            gender: .male,
            heightCm: 190,
            weightKg: 100,
            activityLevel: .extraActive
        )
        XCTAssertEqual(result, 3957, accuracy: 0.5)
    }

    // MARK: - Gender constant difference

    func testMaleProducesHigherTDEEThanFemale() {
        let male = TDEECalculator.calculate(
            age: 30, gender: .male, heightCm: 170, weightKg: 70, activityLevel: .moderatelyActive
        )
        let female = TDEECalculator.calculate(
            age: 30, gender: .female, heightCm: 170, weightKg: 70, activityLevel: .moderatelyActive
        )
        XCTAssertGreaterThan(male, female, "Male TDEE should exceed female TDEE given identical inputs")
    }

    // MARK: - Activity level ordering

    func testTDEEIncreasesWithActivityLevel() {
        let sedentary = TDEECalculator.calculate(
            age: 30, gender: .male, heightCm: 175, weightKg: 80, activityLevel: .sedentary
        )
        let veryActive = TDEECalculator.calculate(
            age: 30, gender: .male, heightCm: 175, weightKg: 80, activityLevel: .veryActive
        )
        XCTAssertLessThan(sedentary, veryActive, "Higher activity level should produce higher TDEE")
    }
}
