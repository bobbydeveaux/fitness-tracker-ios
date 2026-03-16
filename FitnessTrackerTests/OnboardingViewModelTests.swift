import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - MockUserProfileRepository

/// In-memory stub for `UserProfileRepository` that avoids SwiftData disk I/O.
final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private(set) var savedProfile: UserProfile? = nil
    private(set) var saveCallCount: Int = 0
    var shouldThrowOnSave: Bool = false

    func fetch() async throws -> UserProfile? {
        return savedProfile
    }

    func save(_ profile: UserProfile) async throws {
        if shouldThrowOnSave {
            throw MockError.saveFailed
        }
        savedProfile = profile
        saveCallCount += 1
    }

    func delete(_ profile: UserProfile) async throws {
        savedProfile = nil
    }

    enum MockError: Error, LocalizedError {
        case saveFailed
        var errorDescription: String? { "Mock save failed" }
    }
}

// MARK: - OnboardingViewModelTests

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        return try AppSchema.makeContainer(inMemory: true)
    }

    private func makeViewModel(
        repository: MockUserProfileRepository = MockUserProfileRepository()
    ) throws -> OnboardingViewModel {
        let container = try makeContainer()
        return OnboardingViewModel(
            repository: repository,
            context: container.mainContext
        )
    }

    // MARK: - Initial State

    func testInitialStep_isWelcome() throws {
        let vm = try makeViewModel()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testTotalSteps_isFour() throws {
        let vm = try makeViewModel()
        XCTAssertEqual(vm.totalSteps, 4)
    }

    func testIsComplete_initiallyFalse() throws {
        let vm = try makeViewModel()
        XCTAssertFalse(vm.isComplete)
    }

    func testIsSaving_initiallyFalse() throws {
        let vm = try makeViewModel()
        XCTAssertFalse(vm.isSaving)
    }

    // MARK: - Step Navigation

    func testNextStep_advancesFromWelcomeToBiometrics() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .biometrics)
    }

    func testNextStep_advancesThroughAllSteps() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .biometrics)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .activityGoal)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .summary)
    }

    func testNextStep_clampedAtLastStep() throws {
        let vm = try makeViewModel()
        // Advance to last step
        vm.nextStep(); vm.nextStep(); vm.nextStep()
        XCTAssertEqual(vm.currentStep, .summary)
        // Call nextStep beyond last — should remain at summary
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .summary)
    }

    func testPreviousStep_clampedAtWelcome() throws {
        let vm = try makeViewModel()
        // Already at first step — should stay there
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testPreviousStep_goesBack() throws {
        let vm = try makeViewModel()
        vm.nextStep()  // → biometrics
        vm.nextStep()  // → activityGoal
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .biometrics)
    }

    func testNextThenPreviousReturnsToStart() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    // MARK: - canProceed

    func testCanProceed_welcome_isAlwaysTrue() throws {
        let vm = try makeViewModel()
        XCTAssertEqual(vm.currentStep, .welcome)
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_biometrics_falseWhenNameEmpty() throws {
        let vm = try makeViewModel()
        vm.nextStep()  // → biometrics
        vm.name = ""
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_biometrics_falseWhenNameIsWhitespace() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        vm.name = "   "
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_biometrics_trueWhenAllFieldsValid() throws {
        let vm = try makeViewModel()
        vm.nextStep()  // → biometrics
        vm.name = "Alex"
        vm.age = 25
        vm.heightCm = 175
        vm.weightKg = 75
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_biometrics_falseWhenAgeTooLow() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        vm.name = "Alex"
        vm.age = 5  // below minimum of 10
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_biometrics_falseWhenHeightTooLow() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        vm.name = "Alex"
        vm.heightCm = 10  // below minimum of 50
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_biometrics_falseWhenWeightTooLow() throws {
        let vm = try makeViewModel()
        vm.nextStep()
        vm.name = "Alex"
        vm.weightKg = 5  // below minimum of 20
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_activityGoal_isAlwaysTrue() throws {
        let vm = try makeViewModel()
        vm.nextStep(); vm.nextStep()  // → activityGoal
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_summary_isAlwaysTrue() throws {
        let vm = try makeViewModel()
        vm.nextStep(); vm.nextStep(); vm.nextStep()  // → summary
        XCTAssertTrue(vm.canProceed)
    }

    // MARK: - Computed Targets

    func testComputedTDEE_isPositive() throws {
        let vm = try makeViewModel()
        vm.gender = .male
        vm.weightKg = 80
        vm.heightCm = 180
        vm.age = 30
        vm.activityLevel = .sedentary
        vm.goal = .maintain
        // Male 80kg 180cm 30y sedentary maintain → 2136 kcal
        XCTAssertGreaterThan(vm.computedTDEE, 0)
        XCTAssertEqual(vm.computedTDEE, 2136, accuracy: 5)
    }

    func testComputedMacros_proteinPositive() throws {
        let vm = try makeViewModel()
        vm.weightKg = 75; vm.heightCm = 175; vm.age = 28
        XCTAssertGreaterThan(vm.computedMacros.proteinG, 0)
    }

    func testComputedMacros_reflectGoal() throws {
        let vm = try makeViewModel()
        vm.weightKg = 75; vm.heightCm = 175; vm.age = 28; vm.gender = .male
        vm.activityLevel = .moderatelyActive

        vm.goal = .cut
        let cutProtein = vm.computedMacros.proteinG

        vm.goal = .bulk
        let bulkProtein = vm.computedMacros.proteinG

        // Cut has higher protein ratio (40%) vs bulk (25%)
        XCTAssertGreaterThan(cutProtein, bulkProtein)
    }

    // MARK: - Completion

    func testCompleteOnboarding_savesProfileToRepository() async throws {
        let repository = MockUserProfileRepository()
        let vm = try makeViewModel(repository: repository)

        vm.name = "Alex"
        vm.age = 30
        vm.gender = .male
        vm.heightCm = 180
        vm.weightKg = 80
        vm.activityLevel = .sedentary
        vm.goal = .maintain

        await vm.completeOnboarding()

        XCTAssertEqual(repository.saveCallCount, 1)
        let saved = try XCTUnwrap(repository.savedProfile)
        XCTAssertEqual(saved.name, "Alex")
        XCTAssertEqual(saved.age, 30)
        XCTAssertEqual(saved.gender, .male)
        XCTAssertEqual(saved.heightCm, 180, accuracy: 0.1)
        XCTAssertEqual(saved.weightKg, 80, accuracy: 0.1)
        XCTAssertEqual(saved.activityLevel, .sedentary)
        XCTAssertEqual(saved.goal, .maintain)
    }

    func testCompleteOnboarding_setsIsCompleteTrue() async throws {
        let repository = MockUserProfileRepository()
        let vm = try makeViewModel(repository: repository)
        vm.name = "Alex"

        await vm.completeOnboarding()

        XCTAssertTrue(vm.isComplete)
    }

    func testCompleteOnboarding_correctTDEEAndMacrosInProfile() async throws {
        let repository = MockUserProfileRepository()
        let vm = try makeViewModel(repository: repository)

        // Male 80kg 180cm 30y sedentary maintain → TDEE = 2136 kcal
        vm.name = "Alex"
        vm.age = 30
        vm.gender = .male
        vm.heightCm = 180
        vm.weightKg = 80
        vm.activityLevel = .sedentary
        vm.goal = .maintain

        let expectedTDEE = TDEECalculator.tdee(
            gender: .male, weightKg: 80, heightCm: 180, age: 30,
            activityLevel: .sedentary, goal: .maintain
        )
        let expectedMacros = MacroCalculator.macros(calories: expectedTDEE, goal: .maintain)

        await vm.completeOnboarding()

        let saved = try XCTUnwrap(repository.savedProfile)
        XCTAssertEqual(saved.tdeeKcal, expectedTDEE, accuracy: 1)
        XCTAssertEqual(saved.proteinTargetG, expectedMacros.proteinG, accuracy: 1)
        XCTAssertEqual(saved.carbTargetG, expectedMacros.carbsG, accuracy: 1)
        XCTAssertEqual(saved.fatTargetG, expectedMacros.fatG, accuracy: 1)
    }

    func testCompleteOnboarding_onRepositoryError_setsErrorMessage() async throws {
        let repository = MockUserProfileRepository()
        repository.shouldThrowOnSave = true
        let vm = try makeViewModel(repository: repository)
        vm.name = "Alex"

        await vm.completeOnboarding()

        XCTAssertFalse(vm.isComplete)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testCompleteOnboarding_onRepositoryError_doesNotCallComplete() async throws {
        let repository = MockUserProfileRepository()
        repository.shouldThrowOnSave = true
        let vm = try makeViewModel(repository: repository)
        vm.name = "Alex"

        await vm.completeOnboarding()

        XCTAssertFalse(vm.isComplete)
    }

    func testCompleteOnboarding_trimsWhitespaceFromName() async throws {
        let repository = MockUserProfileRepository()
        let vm = try makeViewModel(repository: repository)
        vm.name = "  Alex  "

        await vm.completeOnboarding()

        let saved = try XCTUnwrap(repository.savedProfile)
        XCTAssertEqual(saved.name, "Alex")
    }

    func testCompleteOnboarding_guardAgainstDoubleCall() async throws {
        let repository = MockUserProfileRepository()
        let vm = try makeViewModel(repository: repository)
        vm.name = "Alex"

        // Simulate two rapid taps
        async let first: Void = vm.completeOnboarding()
        async let second: Void = vm.completeOnboarding()
        await _ = (first, second)

        // Should only save once due to isSaving guard
        XCTAssertEqual(repository.saveCallCount, 1)
    }
}
