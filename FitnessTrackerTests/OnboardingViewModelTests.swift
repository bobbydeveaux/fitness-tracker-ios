import XCTest
@testable import FitnessTracker

// MARK: - OnboardingViewModelTests

final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStep_isWelcome() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testInitialIsComplete_isFalse() {
        let vm = OnboardingViewModel()
        XCTAssertFalse(vm.isComplete)
    }

    func testInitialSaveError_isNil() {
        let vm = OnboardingViewModel()
        XCTAssertNil(vm.saveError)
    }

    // MARK: - Navigation

    func testAdvance_fromWelcome_movesToBiometrics() {
        let vm = OnboardingViewModel()
        vm.advance()
        XCTAssertEqual(vm.currentStep, .biometrics)
    }

    func testAdvance_fromBiometrics_movesToActivityGoal() {
        let vm = OnboardingViewModel()
        vm.advance()
        vm.advance()
        XCTAssertEqual(vm.currentStep, .activityGoal)
    }

    func testAdvance_fromActivityGoal_movesToSummary() {
        let vm = OnboardingViewModel()
        vm.advance(); vm.advance(); vm.advance()
        XCTAssertEqual(vm.currentStep, .summary)
    }

    func testAdvance_fromSummary_isNoOp() {
        let vm = OnboardingViewModel()
        vm.advance(); vm.advance(); vm.advance() // now on summary
        vm.advance() // should not crash or change
        XCTAssertEqual(vm.currentStep, .summary)
    }

    func testGoBack_fromBiometrics_movesToWelcome() {
        let vm = OnboardingViewModel()
        vm.advance() // biometrics
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testGoBack_fromWelcome_isNoOp() {
        let vm = OnboardingViewModel()
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testAdvanceThenGoBack_returnsToOriginalStep() {
        let vm = OnboardingViewModel()
        vm.advance()
        vm.advance()
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .biometrics)
    }

    // MARK: - Validation

    func testIsBiometricsValid_withValidInputs_isTrue() {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 28
        vm.heightCm = 165
        vm.weightKg = 62
        XCTAssertTrue(vm.isBiometricsValid)
    }

    func testIsBiometricsValid_emptyName_isFalse() {
        let vm = OnboardingViewModel()
        vm.name = "   "
        vm.age = 28
        vm.heightCm = 165
        vm.weightKg = 62
        XCTAssertFalse(vm.isBiometricsValid)
    }

    func testIsBiometricsValid_ageTooLow_isFalse() {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 17
        vm.heightCm = 165
        vm.weightKg = 62
        XCTAssertFalse(vm.isBiometricsValid)
    }

    func testIsBiometricsValid_heightOutOfRange_isFalse() {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 25
        vm.heightCm = 50 // too short
        vm.weightKg = 62
        XCTAssertFalse(vm.isBiometricsValid)
    }

    func testIsBiometricsValid_weightOutOfRange_isFalse() {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 25
        vm.heightCm = 170
        vm.weightKg = 500 // too heavy
        XCTAssertFalse(vm.isBiometricsValid)
    }

    // MARK: - Computed TDEE

    func testComputedTDEE_matchesTDEECalculator() {
        let vm = OnboardingViewModel()
        vm.gender = .male
        vm.age = 30
        vm.heightCm = 180
        vm.weightKg = 80
        vm.activityLevel = .sedentary
        vm.goal = .maintain

        let expected = TDEECalculator.tdee(
            gender: .male, weightKg: 80, heightCm: 180, age: 30,
            activityLevel: .sedentary, goal: .maintain
        )
        XCTAssertEqual(vm.computedTDEE, expected, accuracy: 0.01)
    }

    func testComputedTDEE_changesWithGoal() {
        let vm = OnboardingViewModel()
        vm.gender = .male; vm.age = 30; vm.heightCm = 180; vm.weightKg = 80
        vm.activityLevel = .sedentary
        vm.goal = .maintain
        let maintain = vm.computedTDEE

        vm.goal = .cut
        let cut = vm.computedTDEE
        XCTAssertLessThan(cut, maintain, "Cut goal should yield lower TDEE than maintain")

        vm.goal = .bulk
        let bulk = vm.computedTDEE
        XCTAssertGreaterThan(bulk, maintain, "Bulk goal should yield higher TDEE than maintain")
    }

    // MARK: - Computed Macros

    func testComputedMacros_matchesMacroCalculator() {
        let vm = OnboardingViewModel()
        vm.gender = .female; vm.age = 25; vm.heightCm = 165; vm.weightKg = 60
        vm.activityLevel = .moderatelyActive; vm.goal = .maintain

        let tdee = vm.computedTDEE
        let expected = MacroCalculator.macros(calories: tdee, goal: .maintain)

        XCTAssertEqual(vm.computedMacros.proteinG, expected.proteinG, accuracy: 0.01)
        XCTAssertEqual(vm.computedMacros.carbsG, expected.carbsG, accuracy: 0.01)
        XCTAssertEqual(vm.computedMacros.fatG, expected.fatG, accuracy: 0.01)
    }

    // MARK: - OnboardingStep helpers

    func testOnboardingStep_totalCases_isFour() {
        XCTAssertEqual(OnboardingStep.allCases.count, 4)
    }

    func testOnboardingStep_rawValues_areSequential() {
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.biometrics.rawValue, 1)
        XCTAssertEqual(OnboardingStep.activityGoal.rawValue, 2)
        XCTAssertEqual(OnboardingStep.summary.rawValue, 3)
    }
}
