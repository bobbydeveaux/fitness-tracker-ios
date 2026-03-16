import SwiftUI
import SwiftData

// MARK: - DashboardView

/// Main dashboard view shown after onboarding is complete.
///
/// Displays the user's welcome banner, weekly activity summary via
/// `WeeklySummaryCard`, daily macro progress via `NutritionSummaryWidget`,
/// daily target tiles, and a quick-add action strip for one-tap access to
/// meal logging and workout tracking.
struct DashboardView: View {

    @Environment(AppEnvironment.self) private var env
    @Query private var profiles: [UserProfile]

    @State private var dashboardViewModel: DashboardViewModel?
    @State private var nutritionViewModel: NutritionViewModel?

    // MARK: - Sheet / navigation state
    @State private var showingAddMeal: Bool = false
    @State private var showingNutrition: Bool = false
    @State private var showingWorkout: Bool = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let profile {
                        WelcomeBannerView(profile: profile)

                        // Weekly activity summary
                        if let dashboardViewModel {
                            WeeklySummaryCard(stats: dashboardViewModel.weeklyStats)
                        }

                        // Live macro progress for today
                        if let nutritionViewModel {
                            NutritionSummaryWidget(
                                viewModel: nutritionViewModel,
                                profile: profile,
                                onTap: { showingNutrition = true }
                            )
                        }

                        // Daily macro targets reference
                        DailyTargetsView(profile: profile)

                        // Quick-add action strip
                        QuickAddStrip(
                            onLogMeal: { showingAddMeal = true },
                            onLogWorkout: { showingWorkout = true }
                        )
                    } else {
                        ContentUnavailableView(
                            "No Profile Found",
                            systemImage: "person.slash",
                            description: Text("Complete onboarding to set up your profile.")
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            // Navigate to full Nutrition screen
            .navigationDestination(isPresented: $showingNutrition) {
                NutritionView(repository: env.nutritionRepository)
            }
            // Navigate to Workout Plan screen
            .navigationDestination(isPresented: $showingWorkout) {
                WorkoutPlanView(repository: env.workoutRepository)
            }
            // Quick-add meal sheet
            .sheet(isPresented: $showingAddMeal, onDismiss: {
                Task {
                    await nutritionViewModel?.loadTodaysLogs()
                    await dashboardViewModel?.loadWeeklyStats()
                }
            }) {
                if let nutritionViewModel {
                    MealLogEntryView(repository: env.nutritionRepository) { food, grams, mealType in
                        Task {
                            await nutritionViewModel.addEntry(
                                foodItem: food,
                                servingGrams: grams,
                                mealType: mealType
                            )
                        }
                    }
                }
            }
            .task {
                await env.healthKitService.requestAuthorisationIfNeeded()
                setupViewModels()
                await dashboardViewModel?.loadAll()
            }
            .onChange(of: profiles) { _, _ in
                setupViewModels()
            }
        }
    }

    // MARK: - Private

    private func setupViewModels() {
        if dashboardViewModel == nil {
            dashboardViewModel = DashboardViewModel(
                healthKitService: env.healthKitService,
                nutritionRepository: env.nutritionRepository,
                workoutRepository: env.workoutRepository
            )
        }
        if nutritionViewModel == nil {
            let vm = NutritionViewModel(repository: env.nutritionRepository)
            nutritionViewModel = vm
            Task { await vm.loadTodaysLogs() }
        }
    }
}

// MARK: - QuickAddStrip

/// A horizontal pair of prominent buttons providing one-tap entry into the
/// most common logging flows: meal logging and workout recording.
private struct QuickAddStrip: View {
    let onLogMeal: () -> Void
    let onLogWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)

            HStack(spacing: 12) {
                QuickAddButton(
                    title: "Log Meal",
                    icon: "fork.knife",
                    color: .orange,
                    action: onLogMeal
                )
                QuickAddButton(
                    title: "Log Workout",
                    icon: "dumbbell.fill",
                    color: .purple,
                    action: onLogWorkout
                )
            }
        }
    }
}

// MARK: - QuickAddButton

/// A single large-tap-target button inside `QuickAddStrip`.
private struct QuickAddButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(color)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NutritionSummaryWidget

/// A tappable card on the Dashboard that shows today's calorie and macro
/// progress. Tapping it navigates to the full `NutritionView`.
private struct NutritionSummaryWidget: View {
    let viewModel: NutritionViewModel
    let profile: UserProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Today's Nutrition", systemImage: "fork.knife")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MacroSummaryBar(
                    consumedKcal: viewModel.totalKcal,
                    consumedProteinG: viewModel.totalProteinG,
                    consumedCarbG: viewModel.totalCarbG,
                    consumedFatG: viewModel.totalFatG,
                    targetKcal: profile.tdeeKcal,
                    targetProteinG: profile.proteinTargetG,
                    targetCarbG: profile.carbTargetG,
                    targetFatG: profile.fatTargetG
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WelcomeBannerView

private struct WelcomeBannerView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(profile.name)
                        .font(.title.bold())
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - DailyTargetsView

private struct DailyTargetsView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Targets")
                .font(.headline)

            HStack(spacing: 12) {
                TargetTile(
                    label: "Calories",
                    value: String(format: "%.0f", profile.tdeeKcal),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
                TargetTile(
                    label: "Protein",
                    value: String(format: "%.0f", profile.proteinTargetG),
                    unit: "g",
                    icon: "p.circle.fill",
                    color: .red
                )
            }
            HStack(spacing: 12) {
                TargetTile(
                    label: "Carbs",
                    value: String(format: "%.0f", profile.carbTargetG),
                    unit: "g",
                    icon: "c.circle.fill",
                    color: .blue
                )
                TargetTile(
                    label: "Fat",
                    value: String(format: "%.0f", profile.fatTargetG),
                    unit: "g",
                    icon: "f.circle.fill",
                    color: .yellow
                )
            }
        }
    }
}

// MARK: - TargetTile

private struct TargetTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2.bold())
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppEnvironment.makeProductionEnvironment())
}
