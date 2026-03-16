import Foundation
import SwiftData

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-3)

/// SwiftData-backed implementation of `WorkoutRepository`.
final class SwiftDataWorkoutRepository: WorkoutRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchActivePlan() async throws -> WorkoutPlan? { nil }
    func save(_ plan: WorkoutPlan) async throws {}
    func fetchSessions(from start: Date, to end: Date) async throws -> [WorkoutSession] { [] }
    func save(_ session: WorkoutSession) async throws {}
    func delete(_ session: WorkoutSession) async throws {}
}
