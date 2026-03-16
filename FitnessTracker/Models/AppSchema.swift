import SwiftData

// MARK: - AppSchema

/// Registers all SwiftData model types and defines the current versioned schema.
///
/// When a new model is added or an existing model changes, bump the version by
/// adding a new `VersionedSchema`-conforming type and a `MigrationStage` entry.
enum AppSchema {

    /// The flat list of all `@Model` types that form the SwiftData schema.
    ///
    /// `ModelContainer` is initialised from this list via `Schema(AppSchema.models)`.
    static let models: [any PersistentModel.Type] = [
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
        Streak.self
    ]
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
