import Foundation
import SwiftData

// MARK: - AppSchema

/// Registers all SwiftData model types and defines the current versioned schema.
///
/// When a new model is added or an existing model changes, bump the version by
/// adding a new `VersionedSchema`-conforming type and a `MigrationStage` entry.
enum AppSchema {

    /// The currently active versioned schema.
    typealias CurrentVersion = AppSchemaV1

    /// The flat list of all `@Model` types that form the SwiftData schema.
    ///
    /// `ModelContainer` is initialised from this list via `Schema(versionedSchema:)`.
    static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        FoodItem.self,
        MealLog.self,
        MealEntry.self,
        MealTemplate.self,
        MealTemplateItem.self,
        Exercise.self,
        WorkoutPlan.self,
        WorkoutDay.self,
        PlannedExercise.self,
        WorkoutSession.self,
        LoggedSet.self,
        BodyMetric.self,
        Streak.self
    ]

    /// Builds and returns the shared `ModelContainer` configured for production or test use.
    ///
    /// - Parameter inMemory: Pass `true` for XCTest / SwiftUI previews.
    /// - Throws: A `SwiftDataError` if the container cannot be initialised (e.g. migration failure).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentVersion.self)

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

// MARK: - AppSchemaV1

/// Version 1 of the SwiftData schema.
///
/// Extend with additional `VersionedSchema` types and `MigrationStage` values
/// when the schema changes in a future release.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        AppSchema.models
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
