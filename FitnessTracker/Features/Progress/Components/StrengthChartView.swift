import SwiftUI
import Charts

// MARK: - StrengthChartView

/// A Swift Charts line chart displaying per-exercise Epley 1RM estimates over time.
///
/// Includes a `Picker` to switch between exercises that have logged sets in the
/// selected time range. Shows an empty-state placeholder when no strength data
/// is available (no sessions logged or no exercises with completed sets).
///
/// Binds to `ProgressViewModel` for both its data and its loading state. The chart
/// re-renders automatically when the selected exercise or time range changes.
///
/// ```swift
/// StrengthChartView(viewModel: progressViewModel)
/// ```
struct StrengthChartView: View {

    // MARK: - Properties

    @Bindable var viewModel: ProgressViewModel

    // MARK: - Computed

    private var dataPoints: [StrengthDataPoint] { viewModel.currentStrengthPoints }

    private var yDomain: ClosedRange<Double> {
        guard let min = dataPoints.map(\.estimatedOneRMKg).min(),
              let max = dataPoints.map(\.estimatedOneRMKg).max() else {
            return 0...100
        }
        let padding = max(1.0, (max - min) * 0.2)
        return max(0, min - padding)...(max + padding)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if viewModel.isLoading {
                loadingView
            } else if viewModel.availableExercises.isEmpty {
                emptyStateView
            } else {
                exercisePickerView
                if dataPoints.isEmpty {
                    noDataForExerciseView
                } else {
                    chartView
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Sub-views

    private var headerView: some View {
        Label("Strength Progress", systemImage: "dumbbell.fill")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Strength Data",
            systemImage: "dumbbell",
            description: Text("Complete a workout session to track your strength progress.")
        )
        .frame(minHeight: 160)
    }

    private var noDataForExerciseView: some View {
        ContentUnavailableView(
            "No Data for Exercise",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("No logged sets found for this exercise in the selected time range.")
        )
        .frame(minHeight: 160)
    }

    private var exercisePickerView: some View {
        Menu {
            ForEach(viewModel.availableExercises) { exercise in
                Button(exercise.name) {
                    viewModel.selectedExercise = exercise
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedExercise?.name ?? "Select Exercise")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .accessibilityLabel("Select exercise for strength chart")
    }

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Latest 1RM label
            if let latest = dataPoints.last {
                HStack(spacing: 4) {
                    Text("Est. 1RM:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", latest.estimatedOneRMKg))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.purple)
                }
            }

            Chart(dataPoints) { point in
                // Gradient area fill
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Est. 1RM (kg)", point.estimatedOneRMKg)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.purple.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Trend line
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Est. 1RM (kg)", point.estimatedOneRMKg)
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                // Point dots
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Est. 1RM (kg)", point.estimatedOneRMKg)
                )
                .foregroundStyle(Color.purple)
                .symbolSize(30)
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xAxisLabelCount)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let kg = value.as(Double.self) {
                            Text(String(format: "%.0f", kg))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)

            Text("Based on Epley formula: 1RM = weight × (1 + reps/30)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private var xAxisLabelCount: Int {
        switch viewModel.selectedRange {
        case .oneWeek:      return 7
        case .oneMonth:     return 5
        case .threeMonths:  return 4
        case .allTime:      return 6
        }
    }

    private var xAxisDateFormat: Date.FormatStyle {
        switch viewModel.selectedRange {
        case .oneWeek:
            return .dateTime.weekday(.abbreviated)
        case .oneMonth, .threeMonths:
            return .dateTime.month(.abbreviated).day()
        case .allTime:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }
}

// MARK: - Preview

#Preview("With data") {
    let viewModel = ProgressViewModel(
        progressRepository: PreviewStrengthProgressRepository(),
        workoutRepository: PreviewStrengthWorkoutRepository()
    )
    return StrengthChartView(viewModel: viewModel)
        .padding()
}

#Preview("Empty state") {
    let viewModel = ProgressViewModel(
        progressRepository: PreviewStrengthProgressRepository(),
        workoutRepository: PreviewStrengthWorkoutRepository()
    )
    return StrengthChartView(viewModel: viewModel)
        .padding()
}

// MARK: - Preview Helpers

private final class PreviewStrengthProgressRepository: ProgressRepository {
    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] { [] }
    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] { [] }
    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? { nil }
    func saveBodyMetric(_ metric: BodyMetric) async throws {}
    func deleteBodyMetric(_ metric: BodyMetric) async throws {}
    func fetchStreak(for userProfile: UserProfile) async throws -> Streak? { nil }
    func saveStreak(_ streak: Streak) async throws {}
}

private final class PreviewStrengthWorkoutRepository: WorkoutRepository {
    func fetchExercises() async throws -> [Exercise] { [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { nil }
    func saveExercise(_ exercise: Exercise) async throws {}
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { nil }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] { [] }
    func saveWorkoutSession(_ session: WorkoutSession) async throws {}
    func deleteWorkoutSession(_ session: WorkoutSession) async throws {}
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {}
}
