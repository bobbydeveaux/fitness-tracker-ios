import Foundation
import Observation

// MARK: - DashboardViewModel

/// ViewModel for the Dashboard feature screen.
///
/// Aggregates today's HealthKit statistics (step count, active energy,
/// heart rate) and the trailing 7-day activity window into observable state
/// that `DashboardView` binds to.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel: DashboardViewModel
///
/// init(env: AppEnvironment) {
///     _viewModel = State(initialValue: DashboardViewModel(
///         healthKitService: env.healthKitService,
///         nutritionRepository: env.nutritionRepository,
///         workoutRepository: env.workoutRepository
///     ))
/// }
///
/// var body: some View {
///     DashboardView()
///         .task { await viewModel.loadAll() }
/// }
/// ```
@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State

    /// Today's HealthKit quantities. Updated each time `loadDailyStats()` is called.
    var dailyStats: DailyStats = DailyStats()

    /// Aggregated metrics for the trailing 7-day window.
    var weeklyStats: WeeklyStats = WeeklyStats()

    /// `true` while any background query is in flight.
    var isLoadingStats: Bool = false

    // MARK: - Dependencies

    private let healthKitService: any HealthKitServiceProtocol
    private let nutritionRepository: any NutritionRepository
    private let workoutRepository: any WorkoutRepository

    // MARK: - Init

    /// - Parameters:
    ///   - healthKitService: Defaults to the shared singleton; inject a mock in tests/previews.
    ///   - nutritionRepository: Used to compute average weekly caloric intake.
    ///   - workoutRepository: Used to count completed sessions in the trailing 7 days.
    init(
        healthKitService: any HealthKitServiceProtocol = HealthKitService.shared,
        nutritionRepository: any NutritionRepository,
        workoutRepository: any WorkoutRepository
    ) {
        self.healthKitService = healthKitService
        self.nutritionRepository = nutritionRepository
        self.workoutRepository = workoutRepository
    }

    // MARK: - Actions

    /// Loads all dashboard data concurrently: HealthKit stats and weekly aggregates.
    func loadAll() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        async let statsTask: Void = loadDailyStats()
        async let weeklyTask: Void = loadWeeklyStats()
        _ = await (statsTask, weeklyTask)
    }

    /// Fetches today's HealthKit statistics and updates `dailyStats`.
    ///
    /// Call this when the scene moves to the foreground so the dashboard
    /// reflects up-to-date data without requiring a manual pull-to-refresh.
    func loadDailyStats() async {
        dailyStats = await healthKitService.readDailyStats()
        // Mirror HealthKit values into weeklyStats for at-a-glance display.
        weeklyStats.todaySteps = dailyStats.stepCount
        weeklyStats.todayActiveEnergyKcal = dailyStats.activeEnergyBurned
    }

    /// Queries the nutrition and workout repositories for trailing-7-day aggregates
    /// and updates `weeklyStats`.
    func loadWeeklyStats() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        // Fetch concurrently; ignore individual failures — partial data is fine.
        async let mealLogsTask = fetchMealLogs(from: sevenDaysAgo, to: today)
        async let sessionsTask = fetchCompletedSessions(from: sevenDaysAgo, to: today)

        let (mealLogs, sessionCount) = await (mealLogsTask, sessionsTask)

        weeklyStats.completedWorkouts = sessionCount

        // Compute average daily kcal over the 7-day window.
        let totalKcal = mealLogs
            .flatMap(\.entries)
            .reduce(0.0) { $0 + $1.kcal }
        weeklyStats.avgDailyKcal = totalKcal / 7.0
    }

    // MARK: - Private Helpers

    private func fetchMealLogs(from start: Date, to end: Date) async -> [MealLog] {
        do {
            return try await nutritionRepository.fetchMealLogs(from: start, to: end)
        } catch {
            return []
        }
    }

    private func fetchCompletedSessions(from start: Date, to end: Date) async -> Int {
        do {
            let sessions = try await workoutRepository.fetchWorkoutSessions(from: start, to: end)
            return sessions.filter { $0.status == .complete }.count
        } catch {
            return 0
        }
    }
}
