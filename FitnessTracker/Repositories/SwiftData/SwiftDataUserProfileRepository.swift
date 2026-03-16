import Foundation
import SwiftData

/// SwiftData-backed implementation of UserProfileRepository.
/// Uses @ModelActor to ensure all SwiftData operations run on a background serial executor,
/// keeping the ModelContext off the main thread.
@ModelActor
public actor SwiftDataUserProfileRepository: UserProfileRepository {

    public func fetch() async throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        let results = try modelContext.fetch(descriptor)
        return results.first
    }

    public func save(_ profile: UserProfile) async throws {
        if profile.modelContext == nil {
            modelContext.insert(profile)
        }
        try modelContext.save()
    }

    public func delete(_ profile: UserProfile) async throws {
        modelContext.delete(profile)
        try modelContext.save()
    }
}
