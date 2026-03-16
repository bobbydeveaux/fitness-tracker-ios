import SwiftUI
import SwiftData

// MARK: - SummaryStepView

/// Onboarding step 4 — displays the computed TDEE and macro breakdown and lets
/// the user confirm their profile, persisting it to SwiftData.
///
/// On confirmation, `viewModel.finishOnboarding(context:)` is called.
/// The parent view observes `viewModel.isComplete` to route to the dashboard.
struct SummaryStepView: View {

    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Plan")
                        .font(.title.bold())
                    Text("Here's what we've calculated based on your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // MARK: Profile snapshot
                profileSnapshot

                Divider()

                // MARK: Calorie target
                calorieCard

                Divider()

                // MARK: Macro breakdown
                macroBreakdown

                if let error = viewModel.saveError {
                    Text("Could not save profile: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }

                Spacer(minLength: 32)

                // MARK: Action buttons
                VStack(spacing: 12) {
                    Button(action: confirmTapped) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSaving ? "Saving…" : "Start Tracking")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSaving ? Color.accentColor.opacity(0.6) : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Start Tracking")

                    Button(action: viewModel.goBack) {
                        Text("Back")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Back")
                }
            }
            .padding(24)
        }
    }

    // MARK: - Sub-views

    private var profileSnapshot: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Name").foregroundStyle(.secondary)
                    Text(viewModel.name.isEmpty ? "—" : viewModel.name)
                }
                GridRow {
                    Text("Age").foregroundStyle(.secondary)
                    Text("\(viewModel.age) yrs")
                }
                GridRow {
                    Text("Gender").foregroundStyle(.secondary)
                    Text(viewModel.gender == .male ? "Male" : "Female")
                }
                GridRow {
                    Text("Height").foregroundStyle(.secondary)
                    Text(String(format: "%.0f cm", viewModel.heightCm))
                }
                GridRow {
                    Text("Weight").foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", viewModel.weightKg))
                }
                GridRow {
                    Text("Activity").foregroundStyle(.secondary)
                    Text(viewModel.activityLevel.displayName)
                }
                GridRow {
                    Text("Goal").foregroundStyle(.secondary)
                    Text(viewModel.goal.displayName)
                }
            }
            .font(.subheadline)
        }
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Calorie Target")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", viewModel.computedTDEE))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text("kcal / day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(goalOffsetLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var macroBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Targets")
                .font(.headline)

            HStack(spacing: 12) {
                MacroTile(
                    label: "Protein",
                    value: viewModel.computedMacros.proteinG,
                    unit: "g",
                    color: .blue
                )
                MacroTile(
                    label: "Carbs",
                    value: viewModel.computedMacros.carbsG,
                    unit: "g",
                    color: .orange
                )
                MacroTile(
                    label: "Fat",
                    value: viewModel.computedMacros.fatG,
                    unit: "g",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Helpers

    private var goalOffsetLabel: String {
        switch viewModel.goal {
        case .cut:      return "500 kcal below maintenance — targets ~0.5 kg/week loss"
        case .maintain: return "Matches your maintenance calories"
        case .bulk:     return "300 kcal above maintenance — modest muscle-gain surplus"
        }
    }

    private func confirmTapped() {
        isSaving = true
        Task {
            await viewModel.finishOnboarding(context: modelContext)
            isSaving = false
        }
    }
}

// MARK: - MacroTile

private struct MacroTile: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", value))
                .font(.title2.bold())
                .foregroundStyle(color)
                .monospacedDigit()
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.0f", value)) \(unit)")
    }
}

// MARK: - Preview

#Preview {
    SummaryStepView(viewModel: {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 28
        vm.gender = .female
        vm.heightCm = 165
        vm.weightKg = 62
        vm.activityLevel = .moderatelyActive
        vm.goal = .maintain
        return vm
    }())
    .modelContainer(for: UserProfile.self, inMemory: true)
}
