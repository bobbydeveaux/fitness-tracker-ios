import SwiftUI

// MARK: - ActivityGoalStepView

/// Onboarding step 3 — lets the user choose their activity level and fitness goal.
///
/// Both pickers write directly to the bound `OnboardingViewModel`, which
/// recomputes the live TDEE and macro preview shown on the following Summary step.
struct ActivityGoalStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Activity & Goals")
                        .font(.title.bold())
                    Text("We use this to fine-tune your daily calorie target.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // MARK: Activity Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("How active are you?")
                        .font(.headline)

                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        ActivityOptionRow(
                            level: level,
                            isSelected: viewModel.activityLevel == level
                        )
                        .onTapGesture { viewModel.activityLevel = level }
                    }
                }

                Divider()

                // MARK: Fitness Goal
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's your primary goal?")
                        .font(.headline)

                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        GoalOptionRow(
                            goal: goal,
                            isSelected: viewModel.goal == goal
                        )
                        .onTapGesture { viewModel.goal = goal }
                    }
                }

                Spacer(minLength: 32)

                // MARK: Next button
                Button(action: viewModel.advance) {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Next")
            }
            .padding(24)
        }
    }
}

// MARK: - ActivityOptionRow

private struct ActivityOptionRow: View {
    let level: ActivityLevel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .tint : .secondary)
                .imageScale(.large)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayName)
                    .font(.subheadline.bold())
                Text(level.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - GoalOptionRow

private struct GoalOptionRow: View {
    let goal: FitnessGoal
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .tint : .secondary)
                .imageScale(.large)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.displayName)
                    .font(.subheadline.bold())
                Text(goal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - ActivityLevel + CaseIterable display helpers

extension ActivityLevel: CaseIterable {
    public static var allCases: [ActivityLevel] {
        [.sedentary, .lightlyActive, .moderatelyActive, .veryActive, .extraActive]
    }

    var displayName: String {
        switch self {
        case .sedentary:        return "Sedentary"
        case .lightlyActive:    return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive:       return "Very Active"
        case .extraActive:      return "Extra Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary:        return "Little or no exercise"
        case .lightlyActive:    return "Light exercise 1–3 days/week"
        case .moderatelyActive: return "Moderate exercise 3–5 days/week"
        case .veryActive:       return "Hard exercise 6–7 days/week"
        case .extraActive:      return "Twice/day training or physical job"
        }
    }
}

// MARK: - FitnessGoal + CaseIterable display helpers

extension FitnessGoal: CaseIterable {
    public static var allCases: [FitnessGoal] {
        [.cut, .maintain, .bulk]
    }

    var displayName: String {
        switch self {
        case .cut:      return "Lose Fat"
        case .maintain: return "Maintain Weight"
        case .bulk:     return "Build Muscle"
        }
    }

    var description: String {
        switch self {
        case .cut:      return "500 kcal deficit — approx. 0.5 kg/week loss"
        case .maintain: return "Match your maintenance calories"
        case .bulk:     return "300 kcal surplus — steady muscle gain"
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityGoalStepView(viewModel: {
        let vm = OnboardingViewModel()
        vm.activityLevel = .moderatelyActive
        vm.goal = .cut
        return vm
    }())
}
