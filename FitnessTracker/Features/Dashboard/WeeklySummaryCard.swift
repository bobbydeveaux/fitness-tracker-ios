import SwiftUI

// MARK: - WeeklyStats

/// Aggregated statistics for the trailing 7-day window shown on the Dashboard.
struct WeeklyStats {
    /// Number of completed workout sessions in the past 7 days.
    var completedWorkouts: Int = 0

    /// Average daily caloric intake over the past 7 days (kcal).
    var avgDailyKcal: Double = 0

    /// Total step count from HealthKit for today (surfaced here for at-a-glance display).
    var todaySteps: Double = 0

    /// Total active energy burned today in kcal (from HealthKit).
    var todayActiveEnergyKcal: Double = 0
}

// MARK: - WeeklySummaryCard

/// A dashboard card that presents the user's activity highlights for the
/// trailing 7-day window.
///
/// Displays four `WeeklyStatTile` items in a 2-column grid:
/// - Completed workouts (count)
/// - Average daily calories (kcal)
/// - Today's steps (count)
/// - Active energy burned today (kcal)
///
/// Data is provided by `DashboardViewModel` which queries both the
/// `WorkoutRepository` and `NutritionRepository` in parallel.
///
/// Usage:
/// ```swift
/// WeeklySummaryCard(stats: viewModel.weeklyStats)
/// ```
struct WeeklySummaryCard: View {

    let stats: WeeklyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Label("This Week", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Text("Last 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 2×2 stat grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WeeklyStatTile(
                    value: "\(stats.completedWorkouts)",
                    label: "Workouts",
                    unit: "sessions",
                    icon: "dumbbell.fill",
                    color: .purple
                )

                WeeklyStatTile(
                    value: stats.avgDailyKcal > 0
                        ? String(format: "%.0f", stats.avgDailyKcal)
                        : "—",
                    label: "Avg Daily",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )

                WeeklyStatTile(
                    value: stats.todaySteps > 0
                        ? String(format: "%.0f", stats.todaySteps)
                        : "—",
                    label: "Steps Today",
                    unit: "steps",
                    icon: "figure.walk",
                    color: .green
                )

                WeeklyStatTile(
                    value: stats.todayActiveEnergyKcal > 0
                        ? String(format: "%.0f", stats.todayActiveEnergyKcal)
                        : "—",
                    label: "Active Energy",
                    unit: "kcal",
                    icon: "bolt.heart.fill",
                    color: .red
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - WeeklyStatTile

/// A single metric tile inside `WeeklySummaryCard`.
///
/// Displays an icon, a prominent numeric value, a unit label, and a
/// descriptive metric label arranged vertically.
private struct WeeklyStatTile: View {
    let value: String
    let label: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.title2.bold())
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview("WeeklySummaryCard – with data") {
    WeeklySummaryCard(stats: WeeklyStats(
        completedWorkouts: 4,
        avgDailyKcal: 2_150,
        todaySteps: 8_432,
        todayActiveEnergyKcal: 320
    ))
    .padding()
}

#Preview("WeeklySummaryCard – empty state") {
    WeeklySummaryCard(stats: WeeklyStats())
        .padding()
}
