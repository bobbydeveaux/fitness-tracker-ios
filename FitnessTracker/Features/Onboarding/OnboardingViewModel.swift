import Foundation
import Observation
import SwiftData

// MARK: - OnboardingStep

/// Enumeration of the four onboarding wizard steps.
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case biometrics = 1
    case activityGoal = 2
    case summary = 3

    var title: String {
        switch self {
        case .welcome:      return "Welcome"
        case .biometrics:   return "Your Body"
        case .activityGoal: return "Your Goals"
        case .summary:      return "Summary"
        }
    }
}

// MARK: - OnboardingViewModel

/// `@Observable` view model driving the 4-step onboarding wizard.
///
/// Holds all biometric fields collected across steps, validates each step's
/// required inputs via `canProceed`, and on final completion calls
/// `TDEECalculator` + `MacroCalculator` to persist a `UserProfile` via the
/// repository. Sets `isComplete = true` to trigger dashboard routing.
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Navigation State

    /// Zero-based index of the currently visible wizard step.
    private(set) var currentStep: OnboardingStep = .welcome

    /// Total number of wizard steps.
    let totalSteps: Int = OnboardingStep.allCases.count

    /// Set to `true` when the user completes the final step and the profile
    /// is successfully persisted. Observed by `OnboardingView` to trigger
    /// dashboard navigation.
    private(set) var isComplete: Bool = false

    /// Non-nil when an error occurs during profile persistence.
    private(set) var errorMessage: String? = nil

    /// Whether the profile save is in progress.
    private(set) var isSaving: Bool = false

    // MARK: - Biometric Fields (Step 1 — Biometrics)

    var name: String = ""
    var age: Int = 25
    var gender: BiologicalSex = .male
    var heightCm: Double = 170
    var weightKg: Double = 70

    // MARK: - Goal Fields (Step 2 — Activity & Goal)

    var activityLevel: ActivityLevel = .moderatelyActive
    var goal: FitnessGoal = .maintain

    // MARK: - Computed Targets (derived in Step 3 — Summary)

    /// Goal-adjusted TDEE in kcal/day, computed from the current field values.
    var computedTDEE: Double {
        TDEECalculator.tdee(
            gender: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            activityLevel: activityLevel,
            goal: goal
        )
    }

    /// Macro targets derived from `computedTDEE`.
    var computedMacros: MacroTargets {
        MacroCalculator.macros(calories: computedTDEE, goal: goal)
    }

    // MARK: - Dependencies

    private let repository: any UserProfileRepository
    private let context: ModelContext

    // MARK: - Init

    init(repository: any UserProfileRepository, context: ModelContext) {
        self.repository = repository
        self.context = context
    }

    // MARK: - Step Validation

    /// Returns `true` when the current step's required fields are filled.
    ///
    /// Used by the "Continue" button to gate forward navigation.
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .biometrics:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
                && age >= 10 && age <= 120
                && heightCm >= 50 && heightCm <= 300
                && weightKg >= 20 && weightKg <= 500
        case .activityGoal:
            return true  // selectors always have a valid default
        case .summary:
            return true
        }
    }

    // MARK: - Navigation

    /// Advances to the next wizard step, clamped to `totalSteps - 1`.
    func nextStep() {
        let nextIndex = currentStep.rawValue + 1
        if nextIndex < totalSteps, let next = OnboardingStep(rawValue: nextIndex) {
            currentStep = next
        }
    }

    /// Returns to the previous wizard step, clamped to 0.
    func previousStep() {
        let prevIndex = currentStep.rawValue - 1
        if prevIndex >= 0, let prev = OnboardingStep(rawValue: prevIndex) {
            currentStep = prev
        }
    }

    // MARK: - Completion

    /// Persists the collected data as a `UserProfile` and signals completion.
    ///
    /// Calls `TDEECalculator` and `MacroCalculator` to produce computed targets,
    /// constructs a `UserProfile`, saves it via the repository, then sets
    /// `isComplete = true` to trigger dashboard routing.
    func completeOnboarding() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        let tdee = computedTDEE
        let macros = computedMacros

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

        do {
            try await repository.save(profile)
            isComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
