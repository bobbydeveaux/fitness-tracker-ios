# SwiftData Models & Versioned Schema

This document describes the SwiftData persistence layer for the Fitness Tracker iOS app.

## Model Overview

All 12 model classes reside under `FitnessTracker/Models/` and are decorated with `@Model`
(SwiftData's macro for persistent types). Relationships are declared with `@Relationship` to
specify delete rules and inverse references.

| Model | File | Purpose |
|---|---|---|
| `UserProfile` | `UserProfile.swift` | Core user identity, biometrics, TDEE & macro targets |
| `FoodItem` | `FoodItem.swift` | Nutritional reference data per 100 g |
| `MealLog` | `MealLog.swift` | Groups meal entries by date and meal type |
| `MealEntry` | `MealEntry.swift` | Single food item logged with serving size and computed macros |
| `Exercise` | `Exercise.swift` | Read-only exercise library entry (seeded from exercises.json) |
| `WorkoutPlan` | `WorkoutPlan.swift` | AI-generated training split |
| `WorkoutDay` | `WorkoutDay.swift` | A single day within a workout plan |
| `PlannedExercise` | `PlannedExercise.swift` | Exercise prescription (sets / reps / RPE) |
| `WorkoutSession` | `WorkoutSession.swift` | Live or completed gym session |
| `LoggedSet` | `LoggedSet.swift` | Single performed set within a session |
| `BodyMetric` | `BodyMetric.swift` | A body measurement data point |
| `Streak` | `Streak.swift` | User activity streak counters |

## Versioned Schema

`AppSchema.swift` wires everything together:

```
AppSchemaV1: VersionedSchema   — version 1.0.0, lists all 12 model types
AppSchemaMigrationPlan         — SchemaMigrationPlan, empty stages (no migrations yet)
AppSchema                      — factory enum with makeContainer(inMemory:) helper
```

### Adding a new schema version

1. Declare `enum AppSchemaV2: VersionedSchema` with the updated models.
2. Add a `MigrationStage` to `AppSchemaMigrationPlan.stages`.
3. Update `AppSchema.CurrentVersion` to `AppSchemaV2`.

## Relationship & Delete Rules

| Parent | Child | Delete rule |
|---|---|---|
| `UserProfile` | `BodyMetric` | cascade |
| `UserProfile` | `Streak` | cascade |
| `MealLog` | `MealEntry` | cascade |
| `FoodItem` | `MealEntry` | nullify |
| `WorkoutPlan` | `WorkoutDay` | cascade |
| `WorkoutDay` | `PlannedExercise` | cascade |
| `WorkoutDay` | `WorkoutSession` | nullify |
| `Exercise` | `PlannedExercise` | nullify |
| `Exercise` | `LoggedSet` | nullify |
| `WorkoutSession` | `LoggedSet` | cascade |

## Indexed Attributes

The following attributes carry `@Attribute(.index)` for O(log n) predicate queries:

- `MealLog.date`
- `WorkoutSession.startedAt`
- `BodyMetric.recordedAt`

## CloudKit Support

The production `ModelContainer` is configured with:

```swift
ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.fitness-tracker.app")
)
```

This enables optional iCloud sync using the user's private CloudKit database with
last-write-wins conflict resolution. No CloudKit entitlement is required during
development/testing — use `inMemory: true` via `AppSchema.makeContainer(inMemory: true)`.

## Testing

`FitnessTrackerTests/AppSchemaTests.swift` covers:

- Container instantiation with in-memory configuration
- Insert + fetch for all 12 model types
- Cascade delete behaviour (MealLog → MealEntry, WorkoutSession → LoggedSet)
- Full end-to-end test inserting one instance of every model type
