import Foundation
import Observation

// MARK: - DashboardState

/// Aggregated state snapshot for the Dashboard screen.
///
/// Contains HealthKit daily statistics, today's consumed macro totals,
/// and the user's activity streak — all loaded concurrently and bundled
/// into a single value type that views can bind to.
struct DashboardState {

    /// HealthKit step count, active energy, and average heart rate for today.
    var dailyStats: DailyStats = DailyStats()

    /// Total calories consumed today (kcal).
    var todayKcal: Double = 0

    /// Total protein consumed today (grams).
    var todayProteinG: Double = 0

    /// Total carbohydrates consumed today (grams).
    var todayCarbG: Double = 0

    /// Total fat consumed today (grams).
    var todayFatG: Double = 0

    /// The user's current consecutive-day activity streak.
    var currentStreak: Int = 0

    /// The user's all-time longest activity streak.
    var longestStreak: Int = 0
}

// MARK: - DashboardViewModel

/// ViewModel for the Dashboard feature screen.
///
/// Aggregates today's HealthKit statistics (step count, active energy,
/// heart rate), today's consumed nutrition macros, and the user's activity
/// streak into a single observable `DashboardState`.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = DashboardViewModel(
///     healthKitService: env.healthKitService,
///     nutritionRepository: env.nutritionRepository,
///     progressRepository: env.progressRepository
/// )
///
/// var body: some View {
///     DashboardView()
///         .task { await viewModel.loadDashboard(for: profile) }
/// }
/// ```
@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State

    /// The current aggregated dashboard state. Starts with zeroed values.
    private(set) var state: DashboardState = DashboardState()

    /// `true` while any data source query is in flight.
    private(set) var isLoading: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    // MARK: - Convenience Accessors

    /// Today's HealthKit quantities. Convenience accessor for `state.dailyStats`.
    var dailyStats: DailyStats { state.dailyStats }

    /// `true` while a query is in flight. Convenience alias for `isLoading`.
    var isLoadingStats: Bool { isLoading }

    // MARK: - Dependencies

    private let healthKitService: any HealthKitServiceProtocol
    private let nutritionRepository: (any NutritionRepository)?
    private let progressRepository: (any ProgressRepository)?

    // MARK: - Init

    /// Creates a `DashboardViewModel` with the required service dependencies.
    ///
    /// - Parameters:
    ///   - healthKitService: Defaults to the shared singleton; inject a mock conforming
    ///     to `HealthKitServiceProtocol` in tests or previews.
    ///   - nutritionRepository: When provided, today's macro totals are loaded and
    ///     included in `state`. Pass `nil` to skip nutrition aggregation.
    ///   - progressRepository: When provided, the user's streak is loaded and included
    ///     in `state`. Pass `nil` to skip streak aggregation.
    init(
        healthKitService: any HealthKitServiceProtocol = HealthKitService.shared,
        nutritionRepository: (any NutritionRepository)? = nil,
        progressRepository: (any ProgressRepository)? = nil
    ) {
        self.healthKitService = healthKitService
        self.nutritionRepository = nutritionRepository
        self.progressRepository = progressRepository
    }

    // MARK: - Actions

    /// Loads all dashboard data and updates `state`.
    ///
    /// Fetches HealthKit stats, today's nutrition logs, and the user's activity
    /// streak. Errors from individual sources are captured in `errorMessage`;
    /// successful results from other sources are still applied so the dashboard
    /// degrades gracefully on partial failure.
    ///
    /// - Parameter userProfile: The profile used to scope streak queries. When
    ///   `nil`, only HealthKit stats and nutrition data are loaded.
    func loadDashboard(for userProfile: UserProfile? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let stats = await healthKitService.readDailyStats()
        let macros = await fetchMacrosToday()
        let streakCounts = await fetchStreakCounts(for: userProfile)

        state = DashboardState(
            dailyStats: stats,
            todayKcal: macros.kcal,
            todayProteinG: macros.protein,
            todayCarbG: macros.carbs,
            todayFatG: macros.fat,
            currentStreak: streakCounts.current,
            longestStreak: streakCounts.longest
        )
    }

    /// Fetches only HealthKit statistics and updates `state.dailyStats`.
    ///
    /// Use this as a lightweight refresh when only step/energy/heart-rate
    /// data needs to be updated without reloading nutrition or streak data.
    func loadDailyStats() async {
        isLoading = true
        defer { isLoading = false }
        let stats = await healthKitService.readDailyStats()
        state.dailyStats = stats
    }

    // MARK: - Private Helpers

    private struct MacroTotals {
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    private struct StreakCounts {
        var current: Int = 0
        var longest: Int = 0
    }

    /// Returns macro totals for today, or zeros if the repository is unavailable.
    private func fetchMacrosToday() async -> MacroTotals {
        guard let repo = nutritionRepository else { return MacroTotals() }
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let logs = try await repo.fetchMealLogs(for: today)
            let entries = logs.flatMap(\.entries)
            return MacroTotals(
                kcal: entries.reduce(0) { $0 + $1.kcal },
                protein: entries.reduce(0) { $0 + $1.proteinG },
                carbs: entries.reduce(0) { $0 + $1.carbG },
                fat: entries.reduce(0) { $0 + $1.fatG }
            )
        } catch {
            errorMessage = error.localizedDescription
            return MacroTotals()
        }
    }

    /// Returns (current, longest) streak counts, or zeros if unavailable.
    private func fetchStreakCounts(for userProfile: UserProfile?) async -> StreakCounts {
        guard let profile = userProfile, let repo = progressRepository else {
            return StreakCounts()
        }
        do {
            let streak = try await repo.fetchStreak(for: profile)
            return StreakCounts(
                current: streak?.currentCount ?? 0,
                longest: streak?.longestCount ?? 0
            )
        } catch {
            errorMessage = error.localizedDescription
            return StreakCounts()
        }
    }
}
