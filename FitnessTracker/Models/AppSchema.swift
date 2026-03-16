import Foundation
import SwiftData

// MARK: - AppSchemaV1

/// Version 1 of the application's SwiftData schema.
///
/// All model types are registered here. Adding a new version (V2, V3, …) requires:
///   1. Declaring a new `enum AppSchemaV2: VersionedSchema` with updated model types.
///   2. Adding a `MigrationStage` in `AppSchemaMigrationPlan.stages`.
///   3. Bumping `AppSchema.currentEntitiesVersion` to the new enum.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            FoodItem.self,
            MealLog.self,
            MealEntry.self,
            Exercise.self,
            WorkoutPlan.self,
            WorkoutDay.self,
            PlannedExercise.self,
            WorkoutSession.self,
            LoggedSet.self,
            BodyMetric.self,
            Streak.self,
        ]
    }
}

// MARK: - Migration Plan

/// Defines the ordered list of lightweight/custom migration stages between schema versions.
///
/// To add a migration from V1 → V2:
/// ```swift
/// static var stages: [MigrationStage] {
///     [
///         MigrationStage.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)
///     ]
/// }
/// ```
enum AppSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations required yet — V1 is the initial version.
        []
    }
}

// MARK: - ModelContainer Factory

/// Centralised factory for creating the application's `ModelContainer`.
///
/// - Parameter inMemory: When `true` the container uses an ephemeral in-memory store
///   (useful for previews and XCTest). When `false` the production SQLite store is used,
///   optionally backed by the user's CloudKit private database.
enum AppSchema {
    /// The currently active versioned schema.
    typealias CurrentVersion = AppSchemaV1

    /// Builds and returns the shared `ModelContainer` configured for production or test use.
    ///
    /// - Parameter inMemory: Pass `true` for XCTest / SwiftUI previews.
    /// - Throws: A `SwiftDataError` if the container cannot be initialised (e.g. migration failure).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(
            versionedSchema: CurrentVersion.self
        )

        let modelConfiguration: ModelConfiguration
        if inMemory {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.com.fitness-tracker.app")
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: AppSchemaMigrationPlan.self,
            configurations: [modelConfiguration]
        )
    }
}
