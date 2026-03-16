import Foundation

/// Protocol defining async/throws CRUD operations for UserProfile persistence.
/// Consumers must not import SwiftData directly; all access goes through this abstraction.
public protocol UserProfileRepository: Sendable {
    /// Fetches the single user profile, or nil if none has been created yet.
    func fetch() async throws -> UserProfile?

    /// Persists a new or updated UserProfile.
    func save(_ profile: UserProfile) async throws

    /// Removes the given UserProfile and all cascade-deleted child entities.
    func delete(_ profile: UserProfile) async throws
}
