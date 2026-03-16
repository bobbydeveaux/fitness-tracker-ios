import Foundation
import SwiftData

/// SwiftData-backed implementation of WorkoutRepository.
/// Uses @ModelActor to ensure all SwiftData operations run on a background serial executor,
/// keeping the ModelContext off the main thread.
@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {

    // MARK: - Exercise Library

    public func fetchExercises() async throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchExercise(byID id: UUID) async throws -> Exercise? {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func saveExercise(_ exercise: Exercise) async throws {
        if exercise.modelContext == nil {
            modelContext.insert(exercise)
        }
        try modelContext.save()
    }

    // MARK: - WorkoutPlan

    public func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.isActive }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        if plan.modelContext == nil {
            modelContext.insert(plan)
        }
        try modelContext.save()
    }

    public func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {
        modelContext.delete(plan)
        try modelContext.save()
    }

    // MARK: - WorkoutSession

    public func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.startedAt >= startDate && $0.startedAt <= endDate },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func saveWorkoutSession(_ session: WorkoutSession) async throws {
        if session.modelContext == nil {
            modelContext.insert(session)
        }
        try modelContext.save()
    }

    public func deleteWorkoutSession(_ session: WorkoutSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }

    // MARK: - LoggedSet

    public func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {
        if set.modelContext == nil {
            modelContext.insert(set)
        }
        session.sets.append(set)
        set.session = session
        try modelContext.save()
    }
}
