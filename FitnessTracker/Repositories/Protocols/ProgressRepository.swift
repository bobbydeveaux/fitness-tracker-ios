import Foundation

/// Protocol defining async/throws CRUD and query operations for progress tracking data.
/// Consumers must not import SwiftData directly; all access goes through this abstraction.
public protocol ProgressRepository: Sendable {

    // MARK: - BodyMetric

    /// Returns all body metrics for the given user profile, ordered by date ascending.
    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric]

    /// Returns body metrics of a specific type within the given date range (inclusive).
    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric]

    /// Returns the most recent body metric of a specific type for the given user profile.
    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric?

    /// Persists a new or updated BodyMetric.
    func saveBodyMetric(_ metric: BodyMetric) async throws

    /// Removes the given BodyMetric.
    func deleteBodyMetric(_ metric: BodyMetric) async throws

    // MARK: - Streak

    /// Returns the streak record for the given user profile, or nil if none exists.
    func fetchStreak(for userProfile: UserProfile) async throws -> Streak?

    /// Persists a new or updated Streak.
    func saveStreak(_ streak: Streak) async throws
}
