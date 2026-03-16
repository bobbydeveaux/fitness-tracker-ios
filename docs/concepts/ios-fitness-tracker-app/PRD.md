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