import SwiftUI

// MARK: - SummaryStepView

/// Fourth onboarding step: displays the computed TDEE and macro breakdown
/// before the user confirms and completes onboarding.
///
/// All values are derived from `OnboardingViewModel.computedTDEE` and
/// `computedMacros` so the summary always reflects current wizard inputs.
struct SummaryStepView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Daily Targets")
                        .font(.title.bold())
                    Text("Based on your profile, here are the personalised targets we've calculated for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Profile recap
                ProfileRecapCard(viewModel: viewModel)

                // TDEE
                TDEECard(tdee: viewModel.computedTDEE)

                // Macros
                MacroBreakdownCard(macros: viewModel.computedMacros)

                // Disclaimer
                Text("These targets are a starting point and can be adjusted at any time from your profile settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - ProfileRecapCard

private struct ProfileRecapCard: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                RecapRow(label: "Name", value: viewModel.name)
                Divider().padding(.leading)
                RecapRow(label: "Gender", value: viewModel.gender.rawValue.capitalized)
                Divider().padding(.leading)
                RecapRow(label: "Age", value: "\(viewModel.age) yrs")
                Divider().padding(.leading)
                RecapRow(label: "Height", value: String(format: "%.0f cm", viewModel.heightCm))
                Divider().padding(.leading)
                RecapRow(label: "Weight", value: String(format: "%.1f kg", viewModel.weightKg))
                Divider().padding(.leading)
                RecapRow(label: "Activity", value: viewModel.activityLevel.displayName)
                Divider().padding(.leading)
                RecapRow(label: "Goal", value: viewModel.goal.displayName)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

private struct RecapRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - TDEECard

private struct TDEECard: View {
    let tdee: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Calories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.0f", tdee))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                    Text("kcal per day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

// MARK: - MacroBreakdownCard

private struct MacroBreakdownCard: View {
    let macros: MacroTargets

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Targets")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MacroPill(
                    label: "Protein",
                    grams: macros.proteinG,
                    color: .red,
                    icon: "p.circle.fill"
                )
                MacroPill(
                    label: "Carbs",
                    grams: macros.carbsG,
                    color: .blue,
                    icon: "c.circle.fill"
                )
                MacroPill(
                    label: "Fat",
                    grams: macros.fatG,
                    color: .yellow,
                    icon: "f.circle.fill"
                )
            }
        }
    }
}

private struct MacroPill: View {
    let label: String
    let grams: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            Text(String(format: "%.0fg", grams))
                .font(.title3.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment.makeProductionEnvironment()
    let vm = OnboardingViewModel(
        repository: env.userProfileRepository,
        context: env.modelContainer.mainContext
    )
    vm.name = "Alex"
    vm.age = 30
    vm.gender = .male
    vm.heightCm = 180
    vm.weightKg = 80
    vm.activityLevel = .moderatelyActive
    vm.goal = .maintain
    return SummaryStepView(viewModel: vm)
}
