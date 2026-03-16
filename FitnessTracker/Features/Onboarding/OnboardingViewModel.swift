import Foundation
import Observation
import SwiftData

// MARK: - OnboardingStep

/// Represents each step in the 4-step onboarding wizard.
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case biometrics = 1
    case activityGoal = 2
    case summary = 3

    var title: String {
        switch self {
        case .welcome:      return "Welcome"
        case .biometrics:   return "Your Stats"
        case .activityGoal: return "Your Goals"
        case .summary:      return "Summary"
        }
    }
}

// MARK: - OnboardingViewModel

/// Observable ViewModel driving the 4-step onboarding wizard.
///
/// Holds all mutable user-input state, computes live TDEE and macro previews,
/// and persists the completed `UserProfile` via the SwiftData `ModelContext` on
/// confirmation. Emits `isComplete = true` when the profile has been saved so
/// the parent view can route to the dashboard.
@Observable
final class OnboardingViewModel {

    // MARK: - User Input State

    /// Display name collected on the biometrics step.
    var name: String = ""

    /// User's age in whole years (18–100).
    var age: Int = 25

    /// Biological sex used in the Mifflin-St Jeor BMR formula.
    var gender: BiologicalSex = .male

    /// Height in centimetres (100–250).
    var heightCm: Double = 170

    /// Body weight in kilograms (30–300).
    var weightKg: Double = 70

    /// Self-reported daily activity level.
    var activityLevel: ActivityLevel = .moderatelyActive

    /// The user's primary fitness goal (cut / maintain / bulk).
    var goal: FitnessGoal = .maintain

    // MARK: - Navigation State

    /// The currently rendered step.
    private(set) var currentStep: OnboardingStep = .welcome

    /// Set to `true` after the profile is successfully persisted. Parent views
    /// observe this flag to transition to the dashboard.
    private(set) var isComplete: Bool = false

    /// Non-nil when `finishOnboarding()` throws an error saving the profile.
    private(set) var saveError: Error? = nil

    // MARK: - Computed Properties

    /// Total number of wizard steps (excludes welcome from progress indicator).
    var totalSteps: Int { OnboardingStep.allCases.count }

    /// Goal-adjusted TDEE computed live from current input state.
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

    /// Macro targets derived from `computedTDEE` and the selected `goal`.
    var computedMacros: MacroTargets {
        MacroCalculator.macros(calories: computedTDEE, goal: goal)
    }

    /// Validation: name must be non-empty and age in valid range.
    var isBiometricsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (18...100).contains(age) &&
        (100...250).contains(heightCm) &&
        (30...300).contains(weightKg)
    }

    // MARK: - Navigation

    /// Advances to the next wizard step. No-op if already on the last step.
    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    /// Returns to the previous wizard step. No-op if already on the first step.
    func goBack() {
        guard let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    // MARK: - Persistence

    /// Computes final TDEE + macros, constructs a `UserProfile`, inserts it into
    /// the provided `ModelContext`, and sets `isComplete = true` on success.
    ///
    /// - Parameter context: The SwiftData `ModelContext` used for persistence.
    @MainActor
    func finishOnboarding(context: ModelContext) async {
        saveError = nil
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
            context.insert(profile)
            try context.save()
            isComplete = true
        } catch {
            saveError = error
        }
    }
}
