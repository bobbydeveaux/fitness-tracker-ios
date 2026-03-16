import Foundation

// MARK: - Protocol (implemented fully in task-ios-fitness-tracker-app-feat-foundation-3)

/// Provides async CRUD access to the single `UserProfile` record.
protocol UserProfileRepository: Sendable {
    func fetchProfile() async throws -> UserProfile?
    func save(_ profile: UserProfile) async throws
    func deleteProfile() async throws
}
