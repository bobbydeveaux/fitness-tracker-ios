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

## WorkoutPlan ViewModel

`WorkoutPlanViewModel` (`FitnessTracker/Features/Workout/WorkoutPlanViewModel.swift`) is the
`@Observable @MainActor` view model driving the Workout Plan screen.

### Responsibilities

| Responsibility | Method |
|---|---|
| Load all plans from persistence | `loadPlans()` |
| Generate a new plan from the exercise library | `generatePlan(splitType:daysPerWeek:goal:)` |
| Switch the active plan | `setActivePlan(_:)` |
| Delete a plan (cascade-deletes days + exercises) | `deletePlan(_:)` |

### Plan Generation Logic

`generatePlan` fetches the seeded exercise library via `WorkoutRepository.fetchExercises()`,
then builds `WorkoutDay` + `PlannedExercise` objects according to the chosen split:

| Split | Day cycle |
|---|---|
| Push/Pull/Legs | Push → Pull → Legs (cycled to fill `daysPerWeek`) |
| Upper/Lower | Upper A → Lower A → Upper B → Lower B (cycled) |
| Full Body | Full Body A/B/C… repeated |

**Rep/set prescription by goal:**

| Goal | Sets | Reps | RPE |
|---|---|---|---|
| `cut` | 4 | 12–15 | 7.0 |
| `maintain` | 3 | 8–12 | 7.5 |
| `bulk` | 4 | 6–8 | 8.0 |

Up to 2 exercises per muscle group are selected from the library per day.
`WorkoutDay.weekdayIndex` is assigned by a fixed schedule (Mon/Wed/Fri for 3 days, etc.).

### Tests

`FitnessTrackerTests/WorkoutPlanViewModelTests.swift` covers:

- Initial state assertions
- `loadPlans` — empty repo, populated repo, active plan identification, error handling
- `generatePlan` — correct day count, day labels per split, prescription per goal,
  deactivation of previous plan, empty library fallback, weekday index assignment
- `setActivePlan` — activation and mutual deactivation
- `deletePlan` — list removal, active-plan clearing, error handling

## SessionView & SessionViewModel

`SessionView` (`FitnessTracker/Features/Workout/SessionView.swift`) is the primary UI for
conducting a live workout session. `SessionViewModel` (`SessionViewModel.swift`) is its
`@Observable @MainActor` state machine.

### SessionViewModel Lifecycle

| Phase | Trigger |
|---|---|
| `idle` | Initial state |
| `active` | `startSession(day:exercises:previousSetsMap:)` |
| `paused` | `pauseSession()` |
| `active` | `resumeSession()` |
| `complete` | `finishSession()` |

### Responsibilities

| Responsibility | Method |
|---|---|
| Start a session and save to SwiftData | `startSession(day:exercises:previousSetsMap:)` |
| Pause the session (freeze timers) | `pauseSession()` |
| Resume from pause | `resumeSession()` |
| Finish, persist to SwiftData + HealthKit | `finishSession()` |
| Discard session without summary | `abandonSession()` |
| Mark a set complete, detect PRs, start rest timer | `logSet(_:exerciseID:)` |
| Append a blank set row to an exercise | `addSet(to:)` |
| Skip the active rest countdown | `skipRest()` |

### SwiftData Persistence

`finishSession()` persists the completed `WorkoutSession` (with `status = .complete`,
`completedAt`, `durationSeconds`, `totalVolumeKg`) via `WorkoutRepository.saveWorkoutSession(_:)`.
Each individual set is saved during the session via `WorkoutRepository.logSet(_:for:)`.

### HealthKit Integration

`finishSession()` calls `HealthKitService.saveWorkout(duration:)` which writes an
`HKWorkout` with `.traditionalStrengthTraining` activity type. Errors are non-fatal —
the app degrades gracefully when HealthKit is unavailable (e.g. simulator, iPad).

### Tests

`FitnessTrackerTests/SessionViewModelTests.swift` covers:

- Initial state assertions (phase, activeExercises, timers, summary)
- `startSession` — phase transition, exercise list population, set-row count,
  previous-sets map propagation, repository persistence, error handling
- `pauseSession` / `resumeSession` — phase transitions and guards
- `addSet` — appends row, no-op for unknown exercise IDs
- `logSet` — marks row complete, starts rest timer, persists to repository
- `skipRest` — clears rest timer state
- `finishSession` — phase transition, summary population, SwiftData + HealthKit persistence,
  volume calculation, idle guard
- `abandonSession` — phase reset, abandoned status persistence
