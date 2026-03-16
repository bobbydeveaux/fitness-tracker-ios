import Foundation
import Observation

// MARK: - ProgressChartPoint

/// A single data point for a body-measurement chart.
struct ProgressChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double

    init(metric: BodyMetric) {
        self.id = metric.id
        self.date = metric.date
        self.value = metric.value
    }
}

// MARK: - ProgressViewModel

/// ViewModel for the Progress feature screen.
///
/// Manages loading, saving, and deleting `BodyMetric` records for a `UserProfile`.
/// Exposes filtered chart data and history lists that `ProgressView` binds to.
///
/// Usage:
/// ```swift
/// @State private var viewModel = ProgressViewModel(repository: env.progressRepository)
///
/// var body: some View {
///     ProgressView(viewModel: viewModel)
///         .task { await viewModel.loadMetrics(for: profile) }
/// }
/// ```
@Observable
@MainActor
final class ProgressViewModel {

    // MARK: - State

    /// All body metrics for the current user, sorted by date ascending.
    private(set) var bodyMetrics: [BodyMetric] = []

    /// `true` while metrics are being fetched from the repository.
    private(set) var isLoading: Bool = false

    /// `true` while a save or delete operation is in flight.
    private(set) var isSaving: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    /// The currently selected metric type for the chart and filtered list.
    var selectedMetricType: BodyMetricType = .weight

    // MARK: - Computed Properties

    /// Chart points for the selected metric type, sorted by date ascending.
    var chartPoints: [ProgressChartPoint] {
        bodyMetrics
            .filter { $0.type == selectedMetricType }
            .sorted { $0.date < $1.date }
            .map(ProgressChartPoint.init)
    }

    /// History entries for the selected metric type, sorted by date descending
    /// (most recent first for the list view).
    var filteredMetrics: [BodyMetric] {
        bodyMetrics
            .filter { $0.type == selectedMetricType }
            .sorted { $0.date > $1.date }
    }

    /// The most recent value for the selected metric type, or `nil` if none exists.
    var latestValue: Double? {
        chartPoints.last?.value
    }

    /// The unit label appropriate for the selected metric type.
    var unitLabel: String {
        switch selectedMetricType {
        case .weight:            return "kg"
        case .bodyFatPercentage: return "%"
        default:                 return "cm"
        }
    }

    // MARK: - Dependencies

    private let repository: any ProgressRepository

    // MARK: - Init

    /// Creates a `ProgressViewModel` backed by the given repository.
    ///
    /// - Parameter repository: Repository conforming to `ProgressRepository`.
    init(repository: any ProgressRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    /// Loads all body metrics for `userProfile` and updates `bodyMetrics`.
    ///
    /// Sets `isLoading` to `true` during the fetch and populates `errorMessage`
    /// on failure while leaving any previously loaded data in place.
    ///
    /// - Parameter userProfile: The profile whose metrics should be fetched.
    func loadMetrics(for userProfile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            bodyMetrics = try await repository.fetchBodyMetrics(for: userProfile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves a new body measurement and reloads the metrics list.
    ///
    /// - Parameters:
    ///   - type: The measurement type (e.g. `.weight`, `.waist`).
    ///   - value: The numeric value in the appropriate unit (kg, cm, or %).
    ///   - date: The date/time of the measurement.
    ///   - userProfile: The profile this measurement belongs to.
    func logMeasurement(
        type: BodyMetricType,
        value: Double,
        date: Date,
        for userProfile: UserProfile
    ) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let metric = BodyMetric(date: date, type: type, value: value, userProfile: userProfile)
            try await repository.saveBodyMetric(metric)
            // Append locally to avoid a full round-trip unless needed.
            bodyMetrics.append(metric)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes a body metric and updates the local list.
    ///
    /// - Parameter metric: The metric to delete.
    func deleteMetric(_ metric: BodyMetric) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await repository.deleteBodyMetric(metric)
            bodyMetrics.removeAll { $0.id == metric.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
