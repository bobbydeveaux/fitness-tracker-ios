import Foundation
import SwiftData

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-3)

/// SwiftData-backed implementation of `UserProfileRepository`.
/// This stub satisfies the protocol so `AppEnvironment` compiles; the real
/// implementation with `@ModelActor` context access is added in the next task.
final class SwiftDataUserProfileRepository: UserProfileRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProfile() async throws -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func deleteProfile() async throws {}
}
