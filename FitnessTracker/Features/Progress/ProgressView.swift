import SwiftUI
import Charts
import SwiftData

// MARK: - ProgressView

/// Main Progress feature screen.
///
/// Displays a line chart of historical body measurements for the currently
/// selected `BodyMetricType`, a latest-value summary tile, and a scrollable
/// history list with swipe-to-delete. A "+" toolbar button opens
/// `MeasurementLogView` as a sheet for recording new measurements.
///
/// The view is driven by `ProgressViewModel` which handles all async data
/// operations against `ProgressRepository`.
struct ProgressView: View {

    // MARK: - Environment

    @Environment(AppEnvironment.self) private var env
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    // MARK: - State

    @State private var viewModel: ProgressViewModel
    @State private var showingLogSheet: Bool = false

    // MARK: - Init

    init(repository: any ProgressRepository) {
        _viewModel = State(initialValue: ProgressViewModel(repository: repository))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Progress")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingLogSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingLogSheet, onDismiss: {
                    if let profile {
                        Task { await viewModel.loadMetrics(for: profile) }
                    }
                }) {
                    MeasurementLogView { type, value, date in
                        guard let profile else { return }
                        Task {
                            await viewModel.logMeasurement(
                                type: type,
                                value: value,
                                date: date,
                                for: profile
                            )
                        }
                    }
                }
                .task {
                    if let profile {
                        await viewModel.loadMetrics(for: profile)
                    }
                }
                .onChange(of: profiles) { _, _ in
                    if let profile {
                        Task { await viewModel.loadMetrics(for: profile) }
                    }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            errorBanner(message: error)
        } else {
            mainScrollView
        }
    }

    // MARK: - Main Scroll Content

    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                metricTypePicker
                    .padding(.horizontal, 16)

                if viewModel.chartPoints.isEmpty {
                    emptyState
                        .padding(.horizontal, 16)
                } else {
                    latestValueTile
                        .padding(.horizontal, 16)

                    chartCard
                        .padding(.horizontal, 16)

                    historySection
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Subviews

    private var metricTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BodyMetricType.allCases, id: \.self) { type in
                    MetricTypeChip(
                        title: type.displayName,
                        isSelected: viewModel.selectedMetricType == type,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedMetricType = type
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var latestValueTile: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Latest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let latest = viewModel.latestValue {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", latest))
                            .font(.title.bold())
                        Text(viewModel.unitLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("—")
                        .font(.title.bold())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.filteredMetrics.count)")
                    .font(.title.bold())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedMetricType.displayName + " Over Time")
                .font(.headline)

            MetricLineChart(
                points: viewModel.chartPoints,
                unitLabel: viewModel.unitLabel
            )
            .frame(height: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            if viewModel.filteredMetrics.isEmpty {
                Text("No entries yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.filteredMetrics, id: \.id) { metric in
                    MetricHistoryRow(metric: metric, unitLabel: viewModel.unitLabel)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteMetric(metric) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Measurements",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Tap + to log your first \(viewModel.selectedMetricType.displayName.lowercased()) measurement.")
        )
        .padding(.top, 40)
    }

    private func errorBanner(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Failed to load progress")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let profile {
                Button("Retry") {
                    Task { await viewModel.loadMetrics(for: profile) }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MetricTypeChip

private struct MetricTypeChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - MetricLineChart

/// A Swift Charts line chart for a series of `ProgressChartPoint` values.
private struct MetricLineChart: View {
    let points: [ProgressChartPoint]
    let unitLabel: String

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", minY),
                yEnd: .value("Value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            PointMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .symbolSize(40)
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(v, specifier: "%.1f") \(unitLabel)")
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var minY: Double {
        (points.map(\.value).min() ?? 0) * 0.95
    }

    private var xAxisStride: Int {
        guard points.count > 1,
              let first = points.first?.date,
              let last = points.last?.date else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        switch days {
        case 0..<14:  return 1
        case 14..<60: return 7
        default:       return 30
        }
    }
}

// MARK: - MetricHistoryRow

private struct MetricHistoryRow: View {
    let metric: BodyMetric
    let unitLabel: String

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: metric.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", metric.value))
                    .font(.subheadline.bold())
                    .foregroundStyle(.accent)
                Text(unitLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    ProgressView(repository: PreviewProgressRepository())
        .environment(AppEnvironment.makeProductionEnvironment())
}

// MARK: - PreviewProgressRepository

private final class PreviewProgressRepository: ProgressRepository, @unchecked Sendable {

    private var metrics: [BodyMetric] = {
        let calendar = Calendar.current
        let today = Date()
        return (0..<10).compactMap { i -> BodyMetric? in
            guard let date = calendar.date(byAdding: .day, value: -i * 3, to: today) else { return nil }
            return BodyMetric(date: date, type: .weight, value: Double.random(in: 73.0...78.0))
        }
    }()

    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] { metrics }
    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] { metrics }
    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? { metrics.first }
    func saveBodyMetric(_ metric: BodyMetric) async throws { metrics.append(metric) }
    func deleteBodyMetric(_ metric: BodyMetric) async throws { metrics.removeAll { $0.id == metric.id } }
    func fetchStreak(for userProfile: UserProfile) async throws -> Streak? { nil }
    func saveStreak(_ streak: Streak) async throws {}
}
