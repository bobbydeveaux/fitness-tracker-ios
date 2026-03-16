# Fitness Tracker iOS

A native iOS fitness tracking app with workout and meal tracking, TDEE calculation, and personalised workout plans.

## Architecture

- **Language / UI:** Swift 5.9 + SwiftUI (iOS 17+)
- **Persistence:** SwiftData with VersionedSchema and optional CloudKit sync
- **Pattern:** MVVM + Repository, single Xcode target

## Data Layer

12 SwiftData models cover all domain entities. See [docs/swiftdata-models.md](docs/swiftdata-models.md) for the full schema reference including relationships, delete rules, and migration guidance.

## Project Structure

```
FitnessTracker/
  App/           – Entry point & AppEnvironment DI container
  Models/        – SwiftData @Model classes & AppSchema
  Features/      – Feature modules (Onboarding, Dashboard, Nutrition, Workout, Progress)
  Services/      – HealthKit, ExerciseLibrary, Keychain
  Repositories/  – Protocol + SwiftData implementations
  Domain/        – Pure domain logic (TDEECalculator, MacroCalculator, etc.)
  Resources/     – exercises.json and other assets
FitnessTrackerTests/
  AppSchemaTests.swift – ModelContainer unit tests
```
