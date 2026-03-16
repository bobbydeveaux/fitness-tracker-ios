# Fitness Tracker iOS

A native iOS fitness tracking app with workout and meal tracking, TDEE calculation, and personalised workout plans.

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+
- No third-party Swift package dependencies

## Architecture

MVVM + Repository pattern with SwiftData for on-device persistence.

- **`@Observable` ViewModels** — reactive state, no Combine required
- **Repository protocols** — abstract SwiftData access; swap real implementations for in-memory test doubles
- **`AppEnvironment` DI container** — single `@Observable` instance injected via `.environment` at the root

## Project Structure

```
FitnessTracker/
├── App/
│   ├── FitnessTrackerApp.swift   # @main entry point; creates & injects AppEnvironment
│   ├── AppEnvironment.swift      # @Observable DI container holding all services & repositories
│   └── RootView.swift            # Root router (onboarding ↔ dashboard)
├── Models/                       # SwiftData @Model classes (added in sprint 1, task 2)
├── Features/
│   ├── Onboarding/               # Sprint 1 – wizard, TDEE/macro calc
│   ├── Dashboard/                # Sprint 2
│   ├── Nutrition/                # Sprint 3
│   ├── Workout/                  # Sprint 4
│   └── Progress/                 # Sprint 5
├── Services/
│   ├── ExerciseLibraryService.swift  # Decodes & caches bundled exercises.json
│   ├── KeychainService.swift         # Security framework wrapper
│   └── HealthKitService.swift        # HKHealthStore reads/writes
├── Repositories/
│   ├── Protocols/                # Repository protocol definitions
│   │   ├── UserProfileRepository.swift
│   │   ├── NutritionRepository.swift
│   │   ├── WorkoutRepository.swift
│   │   └── ProgressRepository.swift
│   └── SwiftData/                # SwiftData-backed implementations
│       ├── SwiftDataUserProfileRepository.swift
│       ├── SwiftDataNutritionRepository.swift
│       ├── SwiftDataWorkoutRepository.swift
│       └── SwiftDataProgressRepository.swift
├── Domain/                       # Pure Swift calculators & engines (no frameworks)
└── Resources/                    # exercises.json, assets, PrivacyInfo.xcprivacy

FitnessTrackerTests/
└── AppEnvironmentTests.swift     # Verifies DI container wires without circular deps
```

## Dependency Injection

`AppEnvironment` is created once in `FitnessTrackerApp` and injected into the SwiftUI environment:

```swift
// In any view
@Environment(AppEnvironment.self) private var env

// Access services
let profile = try await env.userProfileRepository.fetchProfile()
let apiKey  = try env.keychainService.read(for: "claudeAPIKey")
```

For unit tests, pass in-memory doubles:

```swift
let container = try ModelContainer(for: Schema([]), configurations: [
    ModelConfiguration(isStoredInMemoryOnly: true)
])
let env = AppEnvironment(
    modelContainer: container,
    userProfileRepository: SwiftDataUserProfileRepository(context: container.mainContext),
    ...
)
```

## Sprint Plan

| Sprint | Focus | Status |
|--------|-------|--------|
| 1 | Foundation, SwiftData schema, services | 🔄 In progress |
| 2 | Onboarding wizard, HealthKit | ⏳ Planned |
| 3 | Nutrition & Settings | ⏳ Planned |
| 4 | Dashboard & Workout Planning | ⏳ Planned |
| 5 | Session Tracking & Progress Analytics | ⏳ Planned |

## Security

- Claude API key stored in iOS Keychain via `KeychainService` — never hardcoded
- SwiftData store uses `NSFileProtectionComplete`
- HealthKit: minimal permission scope; no data sent to Claude API
- Zero third-party analytics SDKs
