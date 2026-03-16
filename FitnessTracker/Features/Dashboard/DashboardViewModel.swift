import Foundation
import Observation

// MARK: - DashboardViewModel

/// ViewModel for the Dashboard feature screen.
///
/// Aggregates today's HealthKit statistics (step count, active energy,
/// heart rate) into observable state that the Dashboard view can bind to.
/// Additional data sources (nutrition macros, streak engine) will be wired
/// in the Dashboard UI task.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = DashboardViewModel()
///
/// var body: some View {
///     DashboardView()
///         .task { await viewModel.loadDailyStats() }
/// }
/// ```
@Observable
final class DashboardViewModel {

    // MARK: - State

    /// Today's HealthKit quantities. Updated each time `loadDailyStats()` is called.
    var dailyStats: DailyStats = DailyStats()

    /// `true` while a HealthKit query is in flight.
    var isLoadingStats: Bool = false

    // MARK: - Dependencies

    private let healthKitService: any HealthKitServiceProtocol

    // MARK: - Init

    /// - Parameter healthKitService: Defaults to the shared singleton; inject a
    ///   mock conforming to `HealthKitServiceProtocol` in tests or previews.
    init(healthKitService: any HealthKitServiceProtocol = HealthKitService.shared) {
        self.healthKitService = healthKitService
    }

    // MARK: - Actions

    /// Fetches today's HealthKit statistics and updates `dailyStats`.
    ///
    /// Call this when the scene moves to the foreground so the dashboard
    /// reflects up-to-date data without requiring a manual pull-to-refresh.
    func loadDailyStats() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        dailyStats = await healthKitService.readDailyStats()
    }
}
