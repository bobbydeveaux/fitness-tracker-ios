# High-Level Design: fitness-tracker-ios

**Created:** 2026-03-16T15:20:35Z
**Status:** Draft

## 1. Architecture Overview

The app is a **native iOS monolith** following an offline-first, MVVM + Repository architecture. There is no backend server; all business logic and persistence run on-device. External integrations are limited to three surfaces: HealthKit (read/write passive health data), CloudKit (optional iCloud sync via private database), and the Claude API (one-shot workout plan generation requiring a network connection).

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                     │
│  Onboarding │ Dashboard │ Nutrition │ Workout │ Progress │
└──────────────────────┬──────────────────────────────┘
                       │ @Observable ViewModels
┌──────────────────────▼──────────────────────────────┐
│                 Domain / Use Cases                   │
│  TDEECalculator │ StreakEngine │ PRDetector │ Timer  │
└──────────────────────┬──────────────────────────────┘
                       │ Repository Protocol
┌──────────────────────▼──────────────────────────────┐
│              SwiftData Persistence Layer             │
│              (ModelContainer / ModelContext)         │
└────┬──────────────┬──────────────────┬──────────────┘
     │              │                  │
┌────▼────┐  ┌──────▼──────┐  ┌───────▼───────┐
│HealthKit│  │  CloudKit   │  │  Claude API   │
│ HKStore │  │PrivateDB    │  │ (HTTPS/REST)  │
└─────────┘  └─────────────┘  └───────────────┘
```

---

## 2. System Components

| Component | Responsibility |
|---|---|
| **OnboardingModule** | Multi-step wizard; collects biometrics, computes TDEE/macros via Mifflin-St Jeor; persists `UserProfile` |
| **DashboardModule** | Aggregates daily nutrition, step data from HealthKit, and streak state into a single `DashboardViewModel`; drives animated progress rings |
| **NutritionModule** | Food search (FTS5 over bundled JSON index), AVFoundation barcode scanner, meal template management, real-time macro accumulation |
| **WorkoutPlanModule** | Calls Claude API to generate a structured plan; stores plan as `WorkoutPlan` → `WorkoutDay` → `PlannedExercise` entities; exposes bundled exercise library |
| **SessionModule** | Manages active `WorkoutSession` state machine (idle → active → paused → complete); rest timer using `Timer.publish`; inline previous-set lookup; PR detection on save |
| **ProgressModule** | Queries SwiftData for weight logs, body measurements, and session history; feeds Swift Charts with computed 1RM estimates and volume trends |
| **HealthKitService** | Singleton wrapping `HKHealthStore`; reads `stepCount`, `activeEnergyBurned`, `heartRate`; writes `HKWorkout` on session completion |
| **CloudSyncService** | Optional; mirrors SwiftData records to iCloud private container; last-write-wins conflict policy |
| **ClaudeAPIClient** | Thin `async/await` HTTP client; constructs structured prompt from `UserProfile`; parses JSON response into `WorkoutPlan` domain model |
| **NotificationScheduler** | Wraps `UNUserNotificationCenter`; schedules/cancels recurring workout reminders from user-configured days and times |
| **ExerciseLibraryService** | Loads bundled `exercises.json` into in-memory cache on first access; provides filtered queries by muscle group and equipment |

---

## 3. Data Model

```
UserProfile
  id: UUID (PK)
  age, gender, heightCm, weightKg, activityLevel, goal
  tdeeKcal, proteinTargetG, carbTargetG, fatTargetG

FoodItem
  id: UUID (PK)
  name, barcode?, kcalPer100g, proteinG, carbG, fatG, isCustom

MealLog        →  UserProfile
  id, date, mealType (breakfast/lunch/dinner/snack)
  entries: [MealEntry]

MealEntry      →  MealLog, FoodItem
  id, servingGrams, kcal, proteinG, carbG, fatG

Exercise       (read-only, seeded from JSON)
  id, name, muscleGroup, equipment, instructions, imageName

WorkoutPlan    →  UserProfile
  id, splitType (PPL/FullBody/UpperLower), daysPerWeek, generatedAt, isActive
  days: [WorkoutDay]

WorkoutDay     →  WorkoutPlan
  id, dayLabel, weekdayIndex
  plannedExercises: [PlannedExercise]

PlannedExercise →  WorkoutDay, Exercise
  id, targetSets, targetReps, targetRPE?

WorkoutSession  →  WorkoutDay?
  id, startedAt, completedAt?, durationSeconds
  totalVolumeKg, status (active/complete/abandoned)
  sets: [LoggedSet]

LoggedSet      →  WorkoutSession, Exercise
  id, setIndex, weightKg, reps, isComplete, isPR

BodyMetric     →  UserProfile
  id, date, type (weight/chest/waist/hip/…), value

Streak         →  UserProfile
  id, currentCount, longestCount, lastActivityDate
```

Relationships are all one-to-many via SwiftData `@Relationship`. `Exercise` is seeded once from a bundled JSON asset and treated as read-only at runtime.

---

## 4. API Contracts

### Claude API — Workout Plan Generation

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Request (structured prompt payload):**
```json
{
  "model": "claude-opus-4-6",
  "max_tokens": 1024,
  "system": "You are a certified personal trainer. Return ONLY valid JSON matching the schema provided.",
  "messages": [{
    "role": "user",
    "content": "Generate a workout plan. Profile: {goal, experienceLevel, equipment[], daysPerWeek}. Schema: {splitType, days:[{label, exercises:[{name, sets, reps, restSeconds}]}]}"
  }]
}
```

**Response schema (parsed by `ClaudeAPIClient`):**
```json
{
  "splitType": "PPL",
  "days": [
    {
      "label": "Push A",
      "weekdayIndex": 1,
      "exercises": [
        { "name": "Barbell Bench Press", "sets": 4, "reps": "6-8", "restSeconds": 180 }
      ]
    }
  ]
}
```

**Error handling:** Network unavailable → display cached plan or prompt to retry. Non-200 → surface error banner. Malformed JSON → fallback to a predefined template plan matching the user's split preference.

### HealthKit (framework API, not HTTP)

- **Read:** `HKQuantityType` for `stepCount`, `activeEnergyBurned`, `heartRate` via `HKStatisticsCollectionQuery` on `sceneDidBecomeActive`
- **Write:** `HKWorkout` with `HKWorkoutActivityType.traditionalStrengthTraining`, duration, and active energy on session completion

---

## 5. Technology Stack

### Backend
No backend server. The Claude API (Anthropic managed) is the sole external compute surface — a stateless request/response call for plan generation.

### Frontend
- **Swift 5.9+ / SwiftUI** (iOS 17+) — declarative UI, `@Observable` macro for reactive state, `NavigationStack` for routing
- **Swift Charts** — native charting for progress visualisation
- **AVFoundation** — camera-based barcode scanning via `AVCaptureSession` + `AVCaptureMetadataOutput`

### Infrastructure
- **Apple App Store** — sole distribution channel
- **Xcode Cloud** — CI/CD: automated builds, unit/UI tests on iPhone simulator, App Store archive and upload on merge to `main`
- **Claude API (Anthropic)** — external HTTPS API; key stored in iOS Keychain, never hardcoded

### Data Storage
- **SwiftData** (primary) — `ModelContainer` with `NSFileProtectionComplete`; schema versioned via `VersionedSchema` for safe migrations
- **CloudKit Private Database** — optional iCloud sync via `ModelConfiguration` CloudKit option; end-to-end encrypted, user-scoped
- **In-memory cache** — `ExerciseLibraryService` holds deserialized exercise JSON (`[UUID: Exercise]`); invalidated on cold start
- **iOS Keychain** — Claude API key and sensitive credentials (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)

---

## 6. Integration Points

| Integration | Direction | Trigger | Notes |
|---|---|---|---|
| **Claude API** | Outbound | User taps "Generate Plan" | One-shot; response parsed to `WorkoutPlan`; cached locally; no polling |
| **HealthKit** | Bidirectional | App foreground / session complete | Read: daily stats on `sceneDidBecomeActive`. Write: `HKWorkout` post-session |
| **CloudKit** | Bidirectional | Background sync | Automatic via SwiftData+CloudKit; last-write-wins by `modificationDate` |
| **AVFoundation** | Device | Barcode scan modal | EAN-13/UPC-A decoded; lookup in local food index |
| **UNUserNotificationCenter** | Outbound | User configures reminders | Local triggers only; no APNs server required |
| **Bundled JSON assets** | Internal | First launch | `exercises.json` and seed food items loaded into SwiftData on first run |

---

## 7. Security Architecture

- **Data at rest:** SwiftData store uses `NSFileProtectionComplete` — encrypted when device is locked.
- **Data in transit:** All external calls use HTTPS; App Transport Security enforced with no HTTP fallback.
- **Claude API key:** Stored in iOS Keychain; never embedded in source or Info.plist; loaded at runtime via `KeychainService`.
- **HealthKit:** Minimal permission scope requested. No HealthKit data included in Claude API requests. Data not exported except to CloudKit private DB.
- **CloudKit:** Private database only; end-to-end encrypted by Apple's iCloud infrastructure; user must authenticate via iCloud before sync is enabled.
- **No third-party analytics SDKs** that collect PII. Local event flags written to SwiftData for success metrics only.
- **Privacy manifest (`PrivacyInfo.xcprivacy`):** Declares HealthKit, camera, and network usage per App Store requirements.

---

## 8. Deployment Architecture

```
Developer machine
  └─ Xcode (no third-party SPM packages)
       └─ Xcode Cloud CI pipeline
            ├─ Build & unit test  (xcodebuild test)
            ├─ UI tests on iPhone 16 simulator
            └─ Archive → TestFlight (beta) → App Store Connect (release)

Runtime (on-device)
  ├─ App bundle (SwiftUI + SwiftData + bundled JSON assets)
  ├─ iOS Keychain (API key)
  ├─ SwiftData store  (~/Library/Application Support/ — NSFileProtectionComplete)
  └─ iCloud private container  (optional, managed by Apple)
```

- No containerisation or server infrastructure required.
- **App versioning:** Semantic (`major.minor.patch`); SwiftData schema versioned via `VersionedSchema` enum independently.
- **OTA updates:** Via App Store only; no custom update mechanism.

---

## 9. Scalability Strategy

The app is single-user and device-local; scalability concerns are about **data volume and query performance**.

- **SwiftData query performance:** `MealLog`, `WorkoutSession`, and `BodyMetric` entities include indexed `date` predicates for O(log n) range queries.
- **5-year data volume:** ~18,000 `LoggedSet` rows + ~5,500 `MealEntry` rows — well within SQLite's comfortable range; no pagination required.
- **Chart down-sampling:** For "All time" ranges (> 365 points), data is aggregated to weekly averages on a background `ModelActor` before binding to Swift Charts, keeping render time < 300 ms.
- **Food search:** Pre-sorted in-memory array with prefix-match filter; adequate for local datasets < 10,000 items.
- **CloudKit:** Single-user private database; eventual consistency with last-write-wins is sufficient with no concurrent multi-user access.

---

## 10. Monitoring & Observability

| Signal | Tool | Detail |
|---|---|---|
| **Crash reports** | Xcode Organizer / MetricKit | Automatic symbolication; SLO ≥ 99.5% crash-free |
| **Performance metrics** | MetricKit (`MXMetricPayload`) | Launch time, hang rate, memory footprint; next-day delivery |
| **Local analytics events** | SwiftData `AnalyticsEvent` rows | Onboarding completion, session start/complete, HealthKit grant; no external transmission |
| **App Store rating** | App Store Connect | `SKStoreReviewController` prompt triggered after 3rd completed session |
| **CloudKit sync errors** | `NSPersistentCloudKitContainer` notifications | Surfaced as Settings banner if sync fails > 24 h |
| **Claude API errors** | In-app error state | HTTP/parse failures logged locally; user sees actionable error banner |

No third-party observability SDK in v1. MetricKit + Xcode Organizer provide sufficient signal for crash rate and performance SLOs.

---

## 11. Architectural Decisions (ADRs)

**ADR-001: SwiftData over CoreData**
Swift-native `@Model` macro and `@Observable` integration reduce boilerplate significantly. CoreData remains the underlying SQLite engine. `VersionedSchema` provides safe migrations. Risk: SwiftData requires iOS 17+ — mitigated by iOS 17 being the minimum deployment target.

**ADR-002: Offline-first, no custom backend**
All features except AI plan generation work fully offline. Eliminates server infrastructure cost and user data privacy risks. CloudKit provides sync without a custom auth system. AI plan generation requires connectivity — acceptable as a one-time or infrequent action with a graceful fallback.

**ADR-003: Claude API for workout plan generation**
A structured prompt with a strict JSON schema output produces deterministic, parseable plans. `claude-opus-4-6` selected for reasoning quality on fitness programming. Fallback to a hardcoded template plan ensures the app remains functional if the API is unreachable.

**ADR-004: MVVM + Repository pattern**
`@Observable` ViewModels own UI state. Repository protocols abstract SwiftData access, enabling unit testing with in-memory `ModelContainer` instances. Domain logic (TDEE calculation, PR detection, streak evaluation) lives in pure, testable Swift structs with no framework dependencies.

**ADR-005: Bundled exercise JSON over network fetch**
Ensures offline availability, eliminates a runtime API dependency, and avoids licensing costs. ~100 exercises is stable enough to update via app releases in v1.

**ADR-006: Zero third-party Swift package dependencies**
Avoids supply-chain risk, keeps the binary lean, and ensures all functionality is covered by platform SDKs available at iOS 17+: SwiftData, SwiftUI, Swift Charts, AVFoundation, HealthKit, CloudKit, UserNotifications.

---

## Appendix: PRD Reference

See [PRD.md](./PRD.md) for full product requirements.