import Foundation
import SwiftData

/// SwiftData-backed implementation of ProgressRepository.
/// Uses @ModelActor to ensure all SwiftData operations run on a background serial executor,
/// keeping the ModelContext off the main thread.
@ModelActor
public actor SwiftDataProgressRepository: ProgressRepository {

    // MARK: - BodyMetric

    public func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] {
        let profileID = userProfile.id
        let descriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate { $0.userProfile?.id == profileID },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] {
        let descriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate { $0.type == type && $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? {
        let profileID = userProfile.id
        var descriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate { $0.type == type && $0.userProfile?.id == profileID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func saveBodyMetric(_ metric: BodyMetric) async throws {
        if metric.modelContext == nil {
            modelContext.insert(metric)
        }
        try modelContext.save()
    }

    public func deleteBodyMetric(_ metric: BodyMetric) async throws {
        modelContext.delete(metric)
        try modelContext.save()
    }

    // MARK: - Streak

    public func fetchStreak(for userProfile: UserProfile) async throws -> Streak? {
        let profileID = userProfile.id
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userProfile?.id == profileID }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func saveStreak(_ streak: Streak) async throws {
        if streak.modelContext == nil {
            modelContext.insert(streak)
        }
        try modelContext.save()
    }
}
