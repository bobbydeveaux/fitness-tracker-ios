# ROAM Analysis: ios-fitness-tracker-app

**Feature Count:** 9
**Created:** 2026-03-16T15:28:12Z

## Risks

1. **SwiftData Maturity & Migration Fragility** (High): SwiftData was introduced in iOS 17 and remains less battle-tested than CoreData for complex migrations. The schema involves 12 interdependent models with relationships; a botched `VersionedSchema` migration on an app update could corrupt or lose user health data irreversibly. The LLD references a `MigrationStage` policy but this is non-trivial to implement correctly across all relationship types.

2. **Claude API JSON Parsing Reliability** (High): `ClaudeAPIClient` relies on the model returning strictly valid JSON matching the expected schema. LLMs can drift from structured output instructions — especially when exercise names contain special characters, reps are expressed as ranges (e.g. "6-8"), or the model adds explanatory prose. The fallback to `FallbackPlanProvider` on `DecodingError` is present but the fallback plan quality directly impacts the AI plan adoption rate target (≥ 80%).

3. **HealthKit Permission Denial Rate** (Medium): If users deny HealthKit permissions, the Dashboard's step-count ring and the DashboardViewModel's aggregation logic must degrade gracefully without crashing or showing stale zeros as if they were real values. The dependency chain `ios-fitness-tracker-app-feat-healthkit → ios-fitness-tracker-app-feat-dashboard` means any unhandled nil state in `HealthKitService` propagates directly to the home screen on every foreground.

4. **AVFoundation Barcode Scanner on Simulator** (Medium): The barcode scanner feature (`BarcodeScannerView`) uses `AVCaptureSession`, which has no simulator support. This blocks UI testing of the full meal-logging flow in Xcode Cloud CI (configured to run on iPhone simulator). Any regression in the scan flow cannot be caught by automated tests without a physical device or a mock injection point.

5. **Claude API Key Distribution & Security** (Medium): The API key is stored in the iOS Keychain at runtime, but the design does not specify how the key reaches the device in the first place. Embedding it in the app bundle (even obfuscated) risks extraction via binary analysis. This is especially sensitive given the App Store review process and potential for key abuse if the app is widely distributed.

6. **SwiftData + CloudKit Conflict Resolution** (Medium): The last-write-wins conflict policy is simple to implement but can silently discard data when a user logs workouts on two devices while offline. A missed `LoggedSet` or `MealEntry` constitutes data loss from the user's perspective, directly threatening the App Store rating target (≥ 4.7 stars).

7. **Session State Machine Persistence on App Termination** (Low): `SessionViewModel` manages the active workout state in memory. If iOS terminates the app mid-session (low memory, crash, phone call), the in-progress `WorkoutSession` and any unsaved `LoggedSet` rows are lost. The LLD does not specify checkpoint persistence during an active session.

---

## Obstacles

- **No Claude API key provisioning strategy defined**: The LLD specifies that the key is read from the Keychain via `KeychainService` but does not document how it is written there initially. Without a provisioning mechanism (e.g., build-time injection via Xcode environment variable, a first-launch configuration screen, or a remote config endpoint), the workout plan feature cannot function in TestFlight or production builds.

- **Exercise demo images/animations not sourced**: The PRD (FR-006) and epic require ≥ 100 exercises with demo images or animations, and the `Exercise` model includes an `imageName` field. However, no asset source is identified in the planning documents. Sourcing, licensing, and bundling these assets (which could add 10–50 MB to the app binary) is unplanned work that could delay the Foundation feature and impact App Store review.

- **Bundled food dataset not defined**: The nutrition feature depends on a seeded food JSON for text search and barcode lookup, but the content, schema, and size of this dataset are unspecified. Without it, `NutritionViewModel` and `BarcodeLookupService` cannot be implemented or tested against realistic data.

- **Xcode Cloud CI not configured**: The HLD references Xcode Cloud for CI/CD, but as an enabler that has not been set up yet. Without it, there is no automated gate on regressions, and the TestFlight → App Store release pipeline is a manual process until configured.

---

## Assumptions

1. **iOS 17+ adoption is sufficient for target users**: The entire tech stack (SwiftData, `@Observable`, Swift Charts) requires iOS 17 as a hard minimum. This assumption should be validated against the target demographic's device upgrade cadence. As of early 2026, iOS 17+ adoption among active iPhone users is expected to be > 90%, but this must be confirmed before locking the deployment target.

2. **Claude API returns parseable JSON consistently enough for production use**: The structured prompt approach assumes `claude-opus-4-6` reliably produces valid JSON matching the `WorkoutPlanResponse` schema under diverse user inputs. This must be validated with a prompt test suite covering edge cases (unusual equipment combinations, very high/low days-per-week values, non-English locale inputs if internationalisation is planned).

3. **Bundled exercise dataset (~100 entries) is sufficient and stable**: The plan assumes a static JSON file updated only via app releases is acceptable for v1. This assumption holds only if exercise data does not need frequent correction and users do not expect a significantly larger library. If user research shows demand for 500+ exercises, the in-memory FTS approach and bundle size require re-evaluation.

4. **HealthKit data is accurate enough to drive dashboard metrics without calibration**: Steps and active calories from `HKHealthStore` are consumed as-is and displayed as primary dashboard metrics. If users have inconsistent HealthKit data (e.g., using a non-Apple step tracker), the dashboard may show misleading values. No data validation or source-preference logic is planned.

5. **Single `ModelContainer` shared across all features is safe for concurrent access**: The DI design injects one `ModelContainer` into `AppEnvironment` and uses it across all ViewModels. `ProgressViewModel` explicitly uses a `@ModelActor` background context, but other ViewModels' concurrency safety with the shared container is assumed to be handled correctly by SwiftData's actor isolation. This requires validation through integration testing under concurrent read/write scenarios.

---

## Mitigations

### Risk 1: SwiftData Migration Fragility
- Write migration integration tests before any schema change lands: create a `ModelContainer` from `AppSchemaV1`, populate it with representative data, migrate to the new version, and assert record counts and relationship integrity.
- Implement a pre-migration backup: copy the SQLite store file to a `.bak` path before any versioned migration runs; surface a recovery prompt if migration fails on first launch after update.
- Keep the `VersionedSchema` enum append-only and document each version's delta in a `SCHEMA_CHANGELOG.md`. Never modify existing `AppSchemaV1` model definitions in place.
- Limit schema changes in v1 post-launch to additive-only (new optional fields) until the migration pipeline is proven in production.

### Risk 2: Claude API JSON Parsing Reliability
- Expand the system prompt to include a concrete JSON example and explicitly forbid markdown fences, prose, or comments.
- Add a secondary parse attempt that strips markdown code fences (` ```json ... ``` `) before decoding — the LLD already mentions this, but it must be in the implementation checklist.
- Build a `ClaudeAPIClientTests` harness with 10+ recorded API response fixtures covering edge cases (range reps, special characters, unexpected extra fields) to prevent regressions.
- Improve `FallbackPlanProvider` to cover all three split types (PPL, Full Body, Upper/Lower) with quality pre-built plans so the fallback is a usable product experience, not a degraded one.

### Risk 3: HealthKit Permission Denial Rate
- In `HealthKitService`, always return a valid (possibly zero) `DailyStats` value regardless of authorisation status; never propagate `nil` to `DashboardViewModel`.
- Add a `isHealthKitAuthorised: Bool` flag to `DashboardState` and conditionally hide the steps ring (replacing it with an "Enable HealthKit" prompt card) rather than showing zero steps as real data.
- Trigger the HealthKit permission request from a contextual explanation screen inside onboarding (Step 4 / Summary), not cold on first Dashboard load, to maximise the grant rate target (≥ 75%).

### Risk 4: AVFoundation Barcode Scanner on Simulator
- Introduce a `BarcodeScannerProtocol` abstraction with a `LiveBarcodeScannerService` (real `AVCaptureSession`) and a `MockBarcodeScannerService` (accepts typed input or returns fixture barcodes). Inject via `AppEnvironment`.
- Use the mock implementation in Xcode Cloud UI tests to exercise the full scan → food lookup → log entry flow on simulator.
- Add a manual text-entry fallback in `BarcodeScannerView` (a "Enter barcode manually" button) so users on devices with camera issues are not blocked.

### Risk 5: Claude API Key Distribution
- Never embed the API key in the app bundle. Instead, implement a first-launch "API Key" settings field in the app (a developer/power-user flow acceptable for v1) that writes to the Keychain via `KeychainService`.
- For internal TestFlight builds, inject the key via an Xcode Cloud environment variable into a build-time config file (`.xcconfig`) that writes to a known Keychain item on first launch using a dedicated setup target.
- Add a `KeychainService` unit test that verifies write → read → delete round-trips with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Document the key provisioning steps in the project README so no team member hardcodes the key as a workaround.

### Risk 6: CloudKit Last-Write-Wins Data Loss
- Expose a `SyncConflictLog` entity in SwiftData that records when a local record was overwritten by a CloudKit version, including the discarded value. Surface a "Sync conflicts detected" banner in Settings with a detail view showing what was replaced.
- For `LoggedSet` and `MealEntry` — the highest-value records — consider a merge strategy that favours the record with the higher `totalVolumeKg` or keeps both entries rather than discarding the local one.
- Document the conflict behaviour clearly in the Settings CloudKit sync explanation text so users understand the risk before enabling sync.

### Risk 7: Session State Machine Persistence on App Termination
- Persist `WorkoutSession` to SwiftData immediately on session start (status = `.active`), and write each `LoggedSet` to SwiftData on every set completion tap rather than batching at session end.
- On `FitnessTrackerApp` init, check for any `WorkoutSession` with `status == .active` and `completedAt == nil`; if found, offer a "Resume session" prompt on the Dashboard.
- Use `UIApplication.willResignActiveNotification` to flush any pending `ModelContext` saves before the app enters the background.

---

## Appendix: Plan Documents

### PRD
# Product Requirements Document: iOS Fitness Tracker App

Build a native iOS fitness tracking app with a premium, sexy UI that helps users track workouts and meals while managing their fitness goals.

## Core Features

### Onboarding & Profile Setup
- Welcome flow with sleek animated UI
- Collect user details: age, gender, height, weight, activity level, fitness goal (lose/maintain/gain)
- Calculate TDEE (Total Daily Energy Expenditure) using Mifflin-St Jeor equation
- Set calorie and macro targets based on goal

### Dashboard
- Beautiful home screen with daily progress rings (calories, protein, steps)
- Quick-add buttons for meals and workouts
- Streak tracking and motivational stats
- Weekly summary cards

### Nutrition Tracking
- Log meals with calorie and macro breakdown (protein, carbs, fat)
- Food search with barcode scanner
- Custom food/meal creation
- Daily totals vs targets with visual progress

### Workout Planning
- AI-generated personalised workout plan based on user goals, experience level, available equipment, and days per week
- Pre-built exercise library with instructions and demo images/animations
- Custom workout builder
- Workout plans: Push/Pull/Legs, Full Body, Upper/Lower splits

### Gym Session Tracking
- Start a workout session from the plan
- Log sets, reps, and weights for each exercise
- Rest timer between sets
- Previous performance shown for progression tracking
- Session completion summary with volume, PRs hit, etc.

### Progress & Analytics
- Weight tracking with chart
- Body measurements logging
- Workout history and volume trends
- Strength progress per exercise
- Weekly/monthly reports

## UI/UX Requirements
- Dark mode first, with optional light mode
- Bold typography, vibrant accent colours (e.g. electric blue or neon green)
- Smooth animations and haptic feedback
- SwiftUI-based with modern iOS design patterns
- Minimalist but information-dense — no clutter
- Inspirational imagery and iconography

## Tech Stack
- Swift / SwiftUI (iOS 17+)
- SwiftData or CoreData for local persistence
- HealthKit integration (steps, heart rate, active calories)
- Push notifications for workout reminders
- Optional: CloudKit for sync across devices

## Acceptance Criteria
- User can complete full onboarding and get a TDEE + macro target
- User can log a meal and see calories/macros update in real time
- User can view and start a workout from their plan
- User can log sets/reps/weights during a gym session
- User can see their progress over time in charts
- App looks polished and premium — production quality UI

**Created:** 2026-03-16T15:18:57Z
**Status:** Draft

## 1. Overview

**Concept:** iOS Fitness Tracker App

Build a native iOS fitness tracking app with a premium, sexy UI that helps users track workouts and meals while managing their fitness goals.

**Description:** A native iOS application built with SwiftUI that combines nutrition tracking, AI-personalised workout planning, real-time gym session logging, and progress analytics into a single premium experience. The app targets fitness-conscious iOS users who want an all-in-one tool that is both functionally powerful and visually exceptional.

---

## 2. Goals

1. **Complete fitness management in one app:** Users can track both nutrition and workouts without switching tools, with daily calorie/macro targets derived from scientifically validated TDEE calculation.
2. **AI-personalised workout plans:** Generate structured training programmes (PPL, Full Body, Upper/Lower) tailored to the user's goal, experience, equipment, and schedule — measurable by plan adoption rate ≥ 80% of onboarded users.
3. **Premium, production-quality UI:** Deliver a dark-first SwiftUI interface with animations and haptics that rivals top-tier fitness apps on the App Store (target App Store rating ≥ 4.7).
4. **Real-time session tracking with progression data:** Enable in-gym logging with previous performance context, reducing friction so users complete session logs in < 2 minutes per exercise.
5. **Visible, motivating progress:** Surface weight trends, strength gains, and streaks in clear charts so users can quantify improvement week-over-week.

---

## 3. Non-Goals

1. **Social / community features:** No social feed, friend challenges, or leaderboards in v1.
2. **Wearable or Apple Watch app:** No watchOS companion app; HealthKit read/write covers passive data.
3. **Subscription billing / paywall:** No in-app purchases or monetisation layer in initial scope.
4. **Online food database API:** No third-party nutrition API (e.g., Nutritionix, Edamam); food data is user-created or barcode-scanned via a local/bundled dataset.
5. **Coaching or live video content:** No guided video workouts or trainer communication features.

---

## 4. User Stories

1. As a **new user**, I want to complete an onboarding flow that collects my stats and goal so that I receive a personalised calorie and macro target immediately.
2. As a **daily user**, I want to see a dashboard with progress rings for calories, protein, and steps so that I can gauge where I stand at a glance.
3. As a **nutrition tracker**, I want to search for foods and scan barcodes to log meals so that I can record what I eat quickly and accurately.
4. As a **gym-goer**, I want an AI-generated workout plan matched to my goals and schedule so that I follow a structured, progressive programme without designing it myself.
5. As an **athlete in the gym**, I want to log sets, reps, and weight during a session with my previous performance visible so that I can aim for progressive overload every workout.
6. As a **progress-focused user**, I want to view weight and strength charts over time so that I can see measurable improvement and stay motivated.
7. As a **busy user**, I want workout reminders via push notification so that I don't miss scheduled training days.
8. As a **multi-device user**, I want optional CloudKit sync so that my data is available on any of my iOS devices.

---

## 5. Acceptance Criteria

**Onboarding**
- Given a new install, when the user completes all onboarding steps, then TDEE is calculated via Mifflin-St Jeor and macro targets are displayed before reaching the dashboard.

**Nutrition Logging**
- Given the dashboard, when the user adds a meal, then calorie and macro totals update in real time and progress rings animate to reflect the new values.
- Given the food search, when the user scans a barcode, then the matching food item (if found) is pre-populated in the log form.

**Workout Planning**
- Given a completed profile, when the user requests a plan, then an AI-generated programme is presented with split type, days per week, and exercises appropriate to their goal and equipment.

**Gym Session Tracking**
- Given an active session, when the user logs a set, then the previous session's weight/reps for that exercise is visible and the new entry is persisted immediately.
- Given a completed session, when the user taps "Finish," then a summary card shows total volume, duration, and any PRs achieved.

**Progress & Analytics**
- Given at least two weight entries, when the user opens the Progress tab, then a line chart renders the trend with date-stamped data points.

---

## 6. Functional Requirements

- **FR-001:** Onboarding collects age, gender, height, weight, activity level, and goal; calculates TDEE and macro splits (protein 30%, carbs 40%, fat 30% for maintenance; adjusted per goal).
- **FR-002:** Dashboard displays animated progress rings for calories consumed, protein consumed, and steps (via HealthKit); updates in real time.
- **FR-003:** Streak counter increments when the user logs at least one meal or workout per day; resets on a missed day.
- **FR-004:** Food log supports text search, barcode scan (AVFoundation), custom food creation, and meal templates (saved combinations).
- **FR-005:** AI workout plan generation uses Claude API with user profile inputs (goal, experience level, equipment, days/week) to produce a structured weekly programme.
- **FR-006:** Exercise library contains ≥ 100 exercises with muscle group, instructions, and demo image/animation; supports filtering by equipment and body part.
- **FR-007:** Gym session view shows each exercise with sets table; each row captures weight, reps, and completion checkbox; previous session data displayed inline.
- **FR-008:** Configurable rest timer (default 90 s) triggers haptic feedback and optional sound on expiry between sets.
- **FR-009:** Session summary persists to SwiftData with volume (total kg lifted), duration, and PR flags per exercise.
- **FR-010:** Progress tab renders Charts-framework line graphs for bodyweight, body measurements, and per-exercise 1RM estimate over selectable time ranges (1 W, 1 M, 3 M, All).
- **FR-011:** HealthKit integration reads step count, active energy, and heart rate; writes workout sessions on completion.
- **FR-012:** Push notifications are scheduled locally for workout reminder days/times set by the user in Settings.
- **FR-013:** Light/dark mode toggle in Settings; app defaults to dark mode on first launch.
- **FR-014:** Optional CloudKit sync mirrors SwiftData store; toggled in Settings with iCloud sign-in gate.

---

## 7. Non-Functional Requirements

### Performance
- App cold launch to interactive dashboard in < 2 seconds on iPhone 12 or newer.
- Meal log update and ring animation render within 100 ms of user confirmation.
- Charts render within 300 ms for datasets up to 365 data points.

### Security
- All user health data stored locally via SwiftData with iOS Data Protection (NSFileProtectionComplete).
- HealthKit permissions requested with minimal required scope; no health data transmitted externally without explicit user consent.
- CloudKit sync uses end-to-end encrypted private database; no plaintext health data in public containers.
- No analytics SDKs that transmit PII without user opt-in.

### Scalability
- Local SwiftData schema supports up to 5 years of daily logs (≈ 1,800 workout sessions, ≈ 5,500 food log entries) without degraded query performance.
- CloudKit sync designed for eventual consistency; conflict resolution uses last-write-wins per record.

### Reliability
- All core features (logging, session tracking, plan viewing) function fully offline.
- SwiftData migrations are versioned; no data loss on app update.
- Push notification scheduling survives app restart via persistent UNUserNotificationCenter triggers.

---

## 8. Dependencies

| Dependency | Purpose | Type |
|---|---|---|
| SwiftUI / Swift 5.9+ | UI framework | Platform SDK |
| SwiftData | Local persistence | Platform SDK |
| HealthKit | Steps, heart rate, active calories | Platform SDK |
| CloudKit | Optional cross-device sync | Platform SDK |
| AVFoundation | Barcode scanning | Platform SDK |
| Swift Charts | Progress visualisation | Platform SDK |
| UserNotifications | Workout reminders | Platform SDK |
| Claude API (Anthropic) | AI workout plan generation | External API |
| Bundled exercise dataset | Exercise library (JSON) | Internal asset |

---

## 9. Out of Scope

- Social features: friend lists, shared workouts, leaderboards
- Apple Watch / watchOS companion app
- In-app purchases, subscriptions, or paywall
- Live video or guided workout content
- Third-party nutrition database API integrations
- Android or web versions
- Coach/trainer messaging or booking
- Automated periodisation or plan auto-progression beyond initial AI generation

---

## 10. Success Metrics

| Metric | Target | Measurement Method |
|---|---|---|
| Onboarding completion rate | ≥ 85% of installs reach dashboard | SwiftData event flag on onboarding finish |
| Daily Active Usage | ≥ 60% of users log at least 1 meal or workout on install day+7 | Local analytics event |
| Session log completion | ≥ 70% of started gym sessions are marked complete | SwiftData session status |
| App Store rating | ≥ 4.7 stars within 90 days of launch | App Store Connect |
| Crash-free sessions | ≥ 99.5% | Xcode Organizer / crash reporter |
| HealthKit permission grant rate | ≥ 75% of users grant steps/calories access | Local permission state flag |

---

## Appendix: Clarification Q&A

### Clarification Questions & Answers

No clarification questions were raised. All requirements derived from the initial concept specification.

### HLD
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

### LLD
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