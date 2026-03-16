import Foundation
import SwiftData

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-3)

/// SwiftData-backed implementation of `ProgressRepository`.
final class SwiftDataProgressRepository: ProgressRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchBodyMetrics(from start: Date, to end: Date) async throws -> [BodyMetric] { [] }
    func save(_ metric: BodyMetric) async throws {}
    func fetchStreak() async throws -> Streak? { nil }
    func save(_ streak: Streak) async throws {}
}
