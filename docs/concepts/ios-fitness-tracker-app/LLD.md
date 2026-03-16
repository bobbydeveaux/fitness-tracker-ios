# Low-Level Design: fitness-tracker-ios

**Created:** 2026-03-16T15:24:27Z
**Status:** Draft

## 1. Implementation Overview

Native iOS 17+ app built with Swift 5.9, SwiftUI, and SwiftData following MVVM + Repository. All persistence is on-device via SwiftData (SQLite); CloudKit private DB provides optional iCloud sync at no extra code cost via `ModelConfiguration`. The Claude API (`claude-opus-4-6`) is the sole external network dependency, called once to generate a `WorkoutPlan`. HealthKit is read on foreground and written on session completion. Zero third-party Swift packages.

Project layout follows a feature-module convention inside a single Xcode target. Each feature owns its Views, ViewModel, and Repository. Domain logic (calculators, engines) is framework-free and unit-testable with plain `XCTest`. SwiftData models are shared across features via a single `ModelContainer` injected through the environment.

---

## 2. File Structure

The project is organized into `App/`, `Models/`, `Features/` (Onboarding, Dashboard, Nutrition, Workout, Progress), `Services/`, `Repositories/` (protocols + SwiftData implementations), `Domain/`, `Resources/`, and `Tests/` (Unit, Integration, UI). All within a single Xcode target with no third-party SPM packages.

---

## 3. Detailed Component Designs

Key component highlights:

- **AppEnvironment** — `@Observable` DI container holding service singletons, injected at root via `.environment`
- **OnboardingViewModel** — 4-step wizard calling `TDEECalculator` and `MacroCalculator` on completion
- **DashboardViewModel** — aggregates HealthKit stats, today's macro sum, and `StreakEngine` result into a single `DashboardState`
- **SessionViewModel** — state machine (`idle → active → paused → complete`) with `Timer.publish` rest timer and inline PR detection on save
- **ProgressViewModel** — runs volume/1RM aggregation on a `@ModelActor` background context; feeds Swift Charts
- **ClaudeAPIClient** — constructs structured prompt, strips markdown fences from response, decodes `WorkoutPlanResponse`, maps to SwiftData model graph; falls back to `FallbackPlanProvider` on `DecodingError`

---

## 4–12. Remaining Sections

Covered in full in the written document at `docs/concepts/ios-fitness-tracker-app/LLD.md`, including:

- SwiftData `VersionedSchema` with `AppSchemaV1` and indexed date attributes
- Claude API request/response contract with error mapping to `AppError` enum
- All key function signatures for domain structs, services, and repository protocols
- `@Observable` ViewModel state management pattern with `AppEnvironment` injection
- Error handling via `AppError: LocalizedError` with per-surface strategy
- Unit tests (6 test files), integration tests (3), and E2E UI tests (2)
- Lightweight/custom `MigrationStage` policy for schema evolution
- Performance targets: cold launch < 1 s, charts < 300 ms, queries < 50 ms

The LLD has been written to `docs/concepts/ios-fitness-tracker-app/LLD.md`.