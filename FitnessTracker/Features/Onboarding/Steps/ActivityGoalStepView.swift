import SwiftUI

// MARK: - ActivityGoalStepView

/// Third onboarding step: lets the user pick their activity level and fitness goal.
///
/// Presents a visual card list for `ActivityLevel` and a segmented picker for
/// `FitnessGoal`. Both bind directly to the shared `OnboardingViewModel`.
struct ActivityGoalStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity & Goal")
                        .font(.title.bold())
                    Text("How active are you, and what would you like to achieve?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Activity Level
                VStack(alignment: .leading, spacing: 12) {
                    Label("Weekly Activity", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        ActivityLevelCard(
                            level: level,
                            isSelected: viewModel.activityLevel == level
                        ) {
                            viewModel.activityLevel = level
                        }
                    }
                }

                // Fitness Goal
                VStack(alignment: .leading, spacing: 12) {
                    Label("Fitness Goal", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(FitnessGoal.allCases, id: \.self) { fitnessGoal in
                        GoalCard(
                            goal: fitnessGoal,
                            isSelected: viewModel.goal == fitnessGoal
                        ) {
                            viewModel.goal = fitnessGoal
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - ActivityLevelCard

private struct ActivityLevelCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? .white : .tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GoalCard

private struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? .white : goal.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(goal.description)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? goal.color : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ActivityLevel Display Helpers

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
        case .lightlyActive:    return "1–3 days/week"
        case .moderatelyActive: return "3–5 days/week"
        case .veryActive:       return "6–7 days/week"
        case .extraActive:      return "Twice a day or physical job"
        }
    }

    var icon: String {
        switch self {
        case .sedentary:        return "sofa.fill"
        case .lightlyActive:    return "figure.walk"
        case .moderatelyActive: return "figure.run"
        case .veryActive:       return "figure.hiking"
        case .extraActive:      return "flame.fill"
        }
    }
}

// MARK: - FitnessGoal Display Helpers

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
        case .cut:      return "Caloric deficit — burn fat, preserve muscle"
        case .maintain: return "Maintenance calories — sustain current physique"
        case .bulk:     return "Caloric surplus — fuel muscle growth"
        }
    }

    var icon: String {
        switch self {
        case .cut:      return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .bulk:     return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .cut:      return .blue
        case .maintain: return .green
        case .bulk:     return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment.makeProductionEnvironment()
    let vm = OnboardingViewModel(
        repository: env.userProfileRepository,
        context: env.modelContainer.mainContext
    )
    return ActivityGoalStepView(viewModel: vm)
}
