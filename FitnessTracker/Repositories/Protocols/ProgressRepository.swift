import Foundation

// MARK: - Protocol (implemented fully in task-ios-fitness-tracker-app-feat-foundation-3)

/// Provides async access to `BodyMetric` and `Streak` records for progress tracking.
protocol ProgressRepository: Sendable {
    func fetchBodyMetrics(from start: Date, to end: Date) async throws -> [BodyMetric]
    func save(_ metric: BodyMetric) async throws
    func fetchStreak() async throws -> Streak?
    func save(_ streak: Streak) async throws
}
