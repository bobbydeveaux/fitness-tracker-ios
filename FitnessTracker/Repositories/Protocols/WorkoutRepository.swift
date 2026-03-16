import Foundation

// MARK: - Protocol (implemented fully in task-ios-fitness-tracker-app-feat-foundation-3)

/// Provides async CRUD access to `WorkoutPlan`, `WorkoutSession`, and related records.
protocol WorkoutRepository: Sendable {
    func fetchActivePlan() async throws -> WorkoutPlan?
    func save(_ plan: WorkoutPlan) async throws
    func fetchSessions(from start: Date, to end: Date) async throws -> [WorkoutSession]
    func save(_ session: WorkoutSession) async throws
    func delete(_ session: WorkoutSession) async throws
}
