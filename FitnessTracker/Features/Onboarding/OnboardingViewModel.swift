import Foundation
import Observation

// MARK: - OnboardingStep

/// Ordered steps in the onboarding wizard.
enum OnboardingStep: Int, CaseIterable {
    case personalInfo  = 0  // Name, age, biological sex
    case bodyMetrics   = 1  // Height, weight
    case activityLevel = 2  // Activity level selection
    case goal          = 3  // Fitness goal selection

    var isFirst: Bool { self == .personalInfo }
    var isLast:  Bool { self == .goal }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

// MARK: - OnboardingViewModel

/// ViewModel driving the 4-step onboarding wizard.
///
/// Wizard flow:
/// 1. **Personal Info** — name, age, biological sex
/// 2. **Body Metrics** — height (cm), weight (kg)
/// 3. **Activity Level** — sedentary → extra active
/// 4. **Goal** — cut / maintain / bulk
///
/// On completing the final step, `finishOnboarding()` synchronously computes
/// TDEE (`TDEECalculator`) and macro targets (`MacroCalculator`), then
/// persists a new `UserProfile` via the injected `UserProfileRepository`.
@Observable
final class OnboardingViewModel {

    // MARK: - Wizard navigation

    /// The currently displayed wizard step.
    private(set) var currentStep: OnboardingStep = .personalInfo

    // MARK: - Step 1: Personal Info

    var name: String = ""
    var age: Int = 25
    var gender: BiologicalSex = .male

    // MARK: - Step 2: Body Metrics

    /// Height in centimetres.
    var heightCm: Double = 170
    /// Body weight in kilograms.
    var weightKg: Double = 70

    // MARK: - Step 3: Activity Level

    var activityLevel: ActivityLevel = .moderatelyActive

    // MARK: - Step 4: Goal

    var goal: FitnessGoal = .maintain

    // MARK: - Async state

    /// `true` while `finishOnboarding()` is awaiting the repository save.
    private(set) var isLoading: Bool = false

    /// Populated when `finishOnboarding()` encounters an error.
    private(set) var error: Error?

    /// Set to `true` after the profile has been successfully persisted.
    private(set) var isComplete: Bool = false

    // MARK: - Dependencies

    private let userProfileRepository: any UserProfileRepository

    // MARK: - Init

    /// - Parameter userProfileRepository: Repository used to persist the new `UserProfile`.
    init(userProfileRepository: any UserProfileRepository) {
        self.userProfileRepository = userProfileRepository
    }

    // MARK: - Validation

    /// Whether the user has supplied enough data on the *current* step to advance.
    var canAdvance: Bool {
        switch currentStep {
        case .personalInfo:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && age > 0 && age <= 120
        case .bodyMetrics:
            return heightCm > 0 && weightKg > 0
        case .activityLevel:
            return true
        case .goal:
            return true
        }
    }

    // MARK: - Navigation

    /// Moves to the next wizard step if validation passes and a next step exists.
    func nextStep() {
        guard canAdvance, let next = currentStep.next else { return }
        currentStep = next
    }

    /// Returns to the previous wizard step.
    func previousStep() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
    }

    // MARK: - Completion

    /// Computes TDEE & macro targets, creates a `UserProfile`, and persists it.
    ///
    /// Call this when the user confirms the final wizard step.
    /// Populates `isComplete` on success or `error` on failure.
    func finishOnboarding() async {
        guard canAdvance else { return }

        isLoading = true
        error = nil

        do {
            let tdee = TDEECalculator.calculate(
                age: age,
                gender: gender,
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel
            )

            let macros = MacroCalculator.calculate(tdeeKcal: tdee, goal: goal)

            let profile = UserProfile(
                name: name.trimmingCharacters(in: .whitespaces),
                age: age,
                gender: gender,
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel,
                goal: goal,
                tdeeKcal: tdee,
                proteinTargetG: macros.proteinG,
                carbTargetG: macros.carbsG,
                fatTargetG: macros.fatG
            )

            try await userProfileRepository.save(profile)
            isComplete = true
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
