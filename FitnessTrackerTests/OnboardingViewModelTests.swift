import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - MockUserProfileRepository

/// In-memory stub of `UserProfileRepository` for use in unit tests.
/// Captures the last saved profile for assertion.
final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {

    var storedProfile: UserProfile?
    var shouldThrow: Bool = false

    func fetch() async throws -> UserProfile? {
        if shouldThrow { throw TestError.forcedFailure }
        return storedProfile
    }

    func save(_ profile: UserProfile) async throws {
        if shouldThrow { throw TestError.forcedFailure }
        storedProfile = profile
    }

    func delete(_ profile: UserProfile) async throws {
        if shouldThrow { throw TestError.forcedFailure }
        storedProfile = nil
    }

    enum TestError: Error {
        case forcedFailure
    }
}

// MARK: - OnboardingViewModelTests

/// Unit tests for `OnboardingViewModel`.
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(repository: MockUserProfileRepository = MockUserProfileRepository()) -> OnboardingViewModel {
        OnboardingViewModel(userProfileRepository: repository)
    }

    // MARK: - Initial state

    func testInitialStepIsPersonalInfo() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, .personalInfo)
    }

    func testInitialStateIsNotComplete() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isComplete)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    // MARK: - Validation / canAdvance

    func testCannotAdvancePersonalInfoWithEmptyName() {
        let vm = makeViewModel()
        vm.name = ""
        XCTAssertFalse(vm.canAdvance)
    }

    func testCannotAdvancePersonalInfoWithWhitespaceOnlyName() {
        let vm = makeViewModel()
        vm.name = "   "
        XCTAssertFalse(vm.canAdvance)
    }

    func testCannotAdvancePersonalInfoWithZeroAge() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 0
        XCTAssertFalse(vm.canAdvance)
    }

    func testCanAdvancePersonalInfoWithValidData() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 28
        XCTAssertTrue(vm.canAdvance)
    }

    func testCannotAdvanceBodyMetricsWithZeroHeight() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 28
        vm.nextStep()  // advance to bodyMetrics
        vm.heightCm = 0
        vm.weightKg = 65
        XCTAssertFalse(vm.canAdvance)
    }

    func testCannotAdvanceBodyMetricsWithZeroWeight() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 28
        vm.nextStep()  // advance to bodyMetrics
        vm.heightCm = 165
        vm.weightKg = 0
        XCTAssertFalse(vm.canAdvance)
    }

    func testCanAlwaysAdvanceActivityLevel() {
        let vm = makeViewModel()
        vm.name = "Bob"
        vm.age = 30
        vm.nextStep()  // bodyMetrics
        vm.nextStep()  // activityLevel
        XCTAssertEqual(vm.currentStep, .activityLevel)
        XCTAssertTrue(vm.canAdvance)
    }

    func testCanAlwaysAdvanceGoalStep() {
        let vm = makeViewModel()
        vm.name = "Bob"
        vm.age = 30
        vm.nextStep()  // bodyMetrics
        vm.nextStep()  // activityLevel
        vm.nextStep()  // goal
        XCTAssertEqual(vm.currentStep, .goal)
        XCTAssertTrue(vm.canAdvance)
    }

    // MARK: - Navigation

    func testNextStepAdvancesStep() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 25
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .bodyMetrics)
    }

    func testNextStepDoesNothingWhenValidationFails() {
        let vm = makeViewModel()
        vm.name = ""
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .personalInfo, "Should stay on personalInfo when name is empty")
    }

    func testPreviousStepGoesBack() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 25
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .bodyMetrics)
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .personalInfo)
    }

    func testPreviousStepOnFirstStepDoesNothing() {
        let vm = makeViewModel()
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .personalInfo)
    }

    func testCannotNavigatePastLastStep() {
        let vm = makeViewModel()
        vm.name = "Alice"
        vm.age = 25
        for _ in 0..<10 { vm.nextStep() }
        XCTAssertEqual(vm.currentStep, .goal, "Should not advance past the last step")
    }

    // MARK: - finishOnboarding – success

    func testFinishOnboardingPersistsProfile() async throws {
        let repo = MockUserProfileRepository()
        let vm = makeViewModel(repository: repo)

        vm.name = "Alice"
        vm.age = 28
        vm.gender = .female
        vm.heightCm = 165
        vm.weightKg = 60
        vm.activityLevel = .moderatelyActive
        vm.goal = .maintain

        // Navigate to last step so all fields are set
        vm.nextStep(); vm.nextStep(); vm.nextStep()
        XCTAssertEqual(vm.currentStep, .goal)

        await vm.finishOnboarding()

        XCTAssertTrue(vm.isComplete, "isComplete should be true after successful save")
        XCTAssertFalse(vm.isLoading, "isLoading should be false after completion")
        XCTAssertNil(vm.error, "No error should be set on success")
        XCTAssertNotNil(repo.storedProfile, "Repository should have a saved profile")
    }

    func testFinishOnboardingProfileHasCorrectName() async {
        let repo = MockUserProfileRepository()
        let vm = makeViewModel(repository: repo)
        vm.name = "  Alice  "  // leading/trailing whitespace
        vm.age = 28
        vm.nextStep(); vm.nextStep(); vm.nextStep()

        await vm.finishOnboarding()

        XCTAssertEqual(repo.storedProfile?.name, "Alice", "Name should be trimmed")
    }

    func testFinishOnboardingComputesTDEE() async {
        let repo = MockUserProfileRepository()
        let vm = makeViewModel(repository: repo)

        vm.name = "Bob"
        vm.age = 30
        vm.gender = .male
        vm.heightCm = 175
        vm.weightKg = 80
        vm.activityLevel = .sedentary  // ×1.2
        vm.goal = .maintain
        vm.nextStep(); vm.nextStep(); vm.nextStep()

        await vm.finishOnboarding()

        // Expected TDEE: BMR = 10×80 + 6.25×175 − 5×30 + 5 = 1748.75; TDEE = 1748.75×1.2 ≈ 2099
        XCTAssertEqual(repo.storedProfile?.tdeeKcal ?? 0, 2099, accuracy: 0.5)
    }

    func testFinishOnboardingComputesMacros() async {
        let repo = MockUserProfileRepository()
        let vm = makeViewModel(repository: repo)

        vm.name = "Carol"
        vm.age = 25
        vm.gender = .female
        vm.heightCm = 165
        vm.weightKg = 60
        vm.activityLevel = .sedentary
        vm.goal = .maintain
        vm.nextStep(); vm.nextStep(); vm.nextStep()

        await vm.finishOnboarding()

        // Just verify macros are positive (exact values tested in MacroCalculatorTests)
        XCTAssertGreaterThan(repo.storedProfile?.proteinTargetG ?? 0, 0)
        XCTAssertGreaterThan(repo.storedProfile?.carbTargetG ?? 0,    0)
        XCTAssertGreaterThan(repo.storedProfile?.fatTargetG ?? 0,     0)
    }

    // MARK: - finishOnboarding – failure

    func testFinishOnboardingPropagatesRepositoryError() async {
        let repo = MockUserProfileRepository()
        repo.shouldThrow = true
        let vm = makeViewModel(repository: repo)

        vm.name = "Dave"
        vm.age = 40
        vm.nextStep(); vm.nextStep(); vm.nextStep()

        await vm.finishOnboarding()

        XCTAssertFalse(vm.isComplete, "isComplete should remain false when repository throws")
        XCTAssertNotNil(vm.error, "error should be set when repository throws")
        XCTAssertFalse(vm.isLoading, "isLoading should be reset to false after error")
    }

    // MARK: - OnboardingStep helpers

    func testOnboardingStepIsFirst() {
        XCTAssertTrue(OnboardingStep.personalInfo.isFirst)
        XCTAssertFalse(OnboardingStep.bodyMetrics.isFirst)
    }

    func testOnboardingStepIsLast() {
        XCTAssertTrue(OnboardingStep.goal.isLast)
        XCTAssertFalse(OnboardingStep.activityLevel.isLast)
    }

    func testOnboardingStepNextAndPrevious() {
        XCTAssertEqual(OnboardingStep.personalInfo.next,   .bodyMetrics)
        XCTAssertEqual(OnboardingStep.bodyMetrics.next,    .activityLevel)
        XCTAssertEqual(OnboardingStep.activityLevel.next,  .goal)
        XCTAssertNil(OnboardingStep.goal.next)

        XCTAssertNil(OnboardingStep.personalInfo.previous)
        XCTAssertEqual(OnboardingStep.bodyMetrics.previous,   .personalInfo)
        XCTAssertEqual(OnboardingStep.activityLevel.previous, .bodyMetrics)
        XCTAssertEqual(OnboardingStep.goal.previous,          .activityLevel)
    }

    func testOnboardingStepCaseCount() {
        XCTAssertEqual(OnboardingStep.allCases.count, 4)
    }
}
