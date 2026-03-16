import SwiftUI
import Charts

// MARK: - WeightChartView

/// A Swift Charts line chart displaying the user's bodyweight trend over the selected time range.
///
/// Renders a gradient-filled area chart beneath the trend line for visual depth.
/// Shows an empty-state placeholder when no weight data is available for the range.
///
/// Binds to `ProgressViewModel` for both its data and its loading state. The chart
/// automatically re-renders when `viewModel.weightDataPoints` changes (e.g. after a
/// range change in `TimeRangePicker`).
///
/// ```swift
/// WeightChartView(viewModel: progressViewModel)
/// ```
struct WeightChartView: View {

    // MARK: - Properties

    let viewModel: ProgressViewModel

    // MARK: - Computed

    private var dataPoints: [WeightDataPoint] { viewModel.weightDataPoints }

    private var yDomain: ClosedRange<Double> {
        guard let min = dataPoints.map(\.weightKg).min(),
              let max = dataPoints.map(\.weightKg).max() else {
            return 50...100
        }
        let padding = max(1.0, (max - min) * 0.15)
        return (min - padding)...(max + padding)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if viewModel.isLoading {
                loadingView
            } else if dataPoints.isEmpty {
                emptyStateView
            } else {
                chartView
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
        HStack {
            Label("Weight Trend", systemImage: "scalemass.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if let latest = dataPoints.last {
                Text(String(format: "%.1f kg", latest.weightKg))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Weight Data",
            systemImage: "scalemass",
            description: Text("Log your weight to see your trend here.")
        )
        .frame(minHeight: 160)
    }

    private var chartView: some View {
        Chart(dataPoints) { point in
            // Gradient area fill
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Weight (kg)", point.weightKg)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Trend line
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight (kg)", point.weightKg)
            )
            .foregroundStyle(Color.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            // Point dots
            PointMark(
                x: .value("Date", point.date),
                y: .value("Weight (kg)", point.weightKg)
            )
            .foregroundStyle(Color.blue)
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
    let calendar = Calendar.current
    let today = Date()
    let points: [WeightDataPoint] = (0..<30).map { offset in
        let date = calendar.date(byAdding: .day, value: -offset, to: today)!
        let weight = 80.0 + Double.random(in: -1.5...1.5)
        return WeightDataPoint(id: UUID(), date: date, weightKg: weight)
    }.reversed()

    let viewModel = ProgressViewModel(
        progressRepository: PreviewProgressRepository(),
        workoutRepository: PreviewWorkoutRepository()
    )
    // Inject sample data directly for preview
    return WeightChartView(viewModel: viewModel)
        .padding()
        .task {
            // Preview uses empty state since we can't inject data easily
        }
}

#Preview("Empty state") {
    let viewModel = ProgressViewModel(
        progressRepository: PreviewProgressRepository(),
        workoutRepository: PreviewWorkoutRepository()
    )
    return WeightChartView(viewModel: viewModel)
        .padding()
}

// MARK: - Preview Helpers

private final class PreviewProgressRepository: ProgressRepository {
    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] { [] }
    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] { [] }
    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? { nil }
    func saveBodyMetric(_ metric: BodyMetric) async throws {}
    func deleteBodyMetric(_ metric: BodyMetric) async throws {}
    func fetchStreak(for userProfile: UserProfile) async throws -> Streak? { nil }
    func saveStreak(_ streak: Streak) async throws {}
}

private final class PreviewWorkoutRepository: WorkoutRepository {
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
