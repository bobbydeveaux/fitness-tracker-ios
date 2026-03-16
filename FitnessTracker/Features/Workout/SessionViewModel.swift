import Foundation
import Observation
import UIKit

// MARK: - SessionPhase

/// The lifecycle phase of an active gym session.
enum SessionPhase: Equatable {
    /// No session is in progress.
    case idle
    /// A session is actively running (timer is ticking).
    case active
    /// The session has been manually paused.
    case paused
    /// The session has been completed and a summary is available.
    case complete
}

// MARK: - ActiveExercise

/// A transient view-model wrapper for a `PlannedExercise` during an active session.
///
/// Holds the mutable set rows the user is filling in as they train, plus
/// a reference to the most recent completed sets from the prior session for
/// "previous session" display.
struct ActiveExercise: Identifiable {
    /// The `PlannedExercise.id` (UUID) that uniquely identifies this entry.
    let id: UUID
    /// The stable library identifier (e.g. `"bench_press"`).
    let exerciseID: String
    let name: String
    let targetSets: Int
    let targetReps: String
    let targetRPE: Double?

    /// Mutable set rows the user is editing during the session.
    var setRows: [SetRow]

    /// Sets from the most recent prior session for comparison display.
    var previousSets: [LoggedSet]
}

// MARK: - SetRow

/// A single editable row within an `ActiveExercise` set table.
struct SetRow: Identifiable {
    let id: UUID
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var isComplete: Bool
    var isPR: Bool
}

// MARK: - SessionSummary

/// An immutable value summarising a completed workout session.
struct SessionSummary {
    /// Total weight moved across all sets (kg × reps summed).
    let totalVolumeKg: Double
    /// Wall-clock duration from session start to finish.
    let durationSeconds: Int
    /// All sets that were flagged as personal records.
    let prSets: [(exerciseName: String, weightKg: Double, reps: Int)]
}

// MARK: - SessionViewModel

/// `@Observable` state machine for a live gym session.
///
/// Manages the full session lifecycle:
/// - **idle → active**: `startSession(day:exercises:)` creates a new `WorkoutSession`,
///   starts the elapsed-time ticker and begins the rest timer.
/// - **active → paused**: `pauseSession()` freezes elapsed time and rest timer.
/// - **paused → active**: `resumeSession()` unfreezes both timers.
/// - **active/paused → complete**: `finishSession()` persists the `WorkoutSession`
///   to SwiftData, saves an `HKWorkout` via `HealthKitService`, and exposes a
///   `SessionSummary` for display in `SessionSummaryView`.
///
/// Set-level interactions:
/// - `logSet(_:exerciseID:)` finalises a `SetRow`, runs `PRDetector`, marks
///   `isPR` on the row, resets the rest timer, and fires a haptic.
/// - `addSet(to:)` appends a new blank row to the exercise's set table.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = SessionViewModel(
///     workoutRepository: env.workoutRepository,
///     healthKitService: env.healthKitService
/// )
///
/// // Start a session for today's workout day:
/// await viewModel.startSession(day: workoutDay, exercises: exercises)
/// ```
@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Phase & State

    /// Current lifecycle phase of the session.
    private(set) var phase: SessionPhase = .idle

    /// List of exercises being worked through in this session.
    private(set) var activeExercises: [ActiveExercise] = []

    /// Elapsed session time in whole seconds (pauses while `phase == .paused`).
    private(set) var elapsedSeconds: Int = 0

    /// Remaining rest time in seconds; counts down after a set is logged.
    private(set) var restSecondsRemaining: Int = 0

    /// `true` while the rest timer is actively counting down.
    private(set) var restTimerActive: Bool = false

    /// Summary of the session; populated when `phase` transitions to `.complete`.
    private(set) var summary: SessionSummary?

    /// Non-nil when a data-persistence or HealthKit error occurred.
    private(set) var errorMessage: String?

    // MARK: - Configuration

    /// Default rest interval in seconds between sets (90 s).
    var restDurationSeconds: Int = 90

    // MARK: - Private State

    private var session: WorkoutSession?
    private var elapsedTimer: Timer?
    private var restTimer: Timer?
    private var sessionStartDate: Date?
    private var pauseStartDate: Date?
    private var totalPausedSeconds: Int = 0

    // MARK: - Dependencies

    private let workoutRepository: any WorkoutRepository
    private let healthKitService: any HealthKitServiceProtocol

    // MARK: - Init

    init(
        workoutRepository: any WorkoutRepository,
        healthKitService: any HealthKitServiceProtocol = HealthKitService.shared
    ) {
        self.workoutRepository = workoutRepository
        self.healthKitService = healthKitService
    }

    // MARK: - Lifecycle

    /// Transitions from `.idle` to `.active`, creating a new `WorkoutSession`
    /// in SwiftData and populating the exercise list.
    ///
    /// - Parameters:
    ///   - day: The `WorkoutDay` being trained.
    ///   - exercises: All `PlannedExercise` items for the day, in display order.
    ///   - previousSetsMap: Historical sets keyed by `Exercise.exerciseID` for "last session" data.
    func startSession(
        day: WorkoutDay,
        exercises: [PlannedExercise],
        previousSetsMap: [String: [LoggedSet]] = [:]
    ) async {
        let newSession = WorkoutSession(startedAt: .now, status: .active, workoutDay: day)
        do {
            try await workoutRepository.saveWorkoutSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        session = newSession
        sessionStartDate = .now
        totalPausedSeconds = 0

        activeExercises = exercises.map { planned in
            let libID = planned.exercise?.exerciseID ?? ""
            let previous = previousSetsMap[libID] ?? []
            let defaultReps = Int(planned.targetReps.split(separator: "-").first.flatMap { Int($0) } ?? 0)
            let initialRows = (0..<planned.targetSets).map { idx in
                SetRow(
                    id: UUID(),
                    setIndex: idx,
                    weightKg: previous.first?.weightKg ?? 0,
                    reps: defaultReps,
                    rpe: planned.targetRPE,
                    isComplete: false,
                    isPR: false
                )
            }
            return ActiveExercise(
                id: planned.id,
                exerciseID: libID,
                name: planned.exercise?.name ?? "Exercise",
                targetSets: planned.targetSets,
                targetReps: planned.targetReps,
                targetRPE: planned.targetRPE,
                setRows: initialRows,
                previousSets: previous
            )
        }

        phase = .active
        startElapsedTimer()
    }

    /// Pauses the session, freezing both the elapsed-time and rest timers.
    func pauseSession() {
        guard phase == .active else { return }
        pauseStartDate = .now
        phase = .paused
        stopElapsedTimer()
        restTimer?.invalidate()
        restTimer = nil
        // Persist pause state.
        updateSessionStatus(.paused)
    }

    /// Resumes a paused session, resuming both timers.
    func resumeSession() {
        guard phase == .paused else { return }
        if let pauseStart = pauseStartDate {
            totalPausedSeconds += Int(Date.now.timeIntervalSince(pauseStart))
        }
        pauseStartDate = nil
        phase = .active
        startElapsedTimer()
        if restSecondsRemaining > 0 {
            startRestTimer()
        }
        updateSessionStatus(.active)
    }

    /// Finalises the session: persists to SwiftData and writes an `HKWorkout`.
    ///
    /// Transitions `phase` to `.complete` and populates `summary`.
    func finishSession() async {
        guard phase == .active || phase == .paused, let session else { return }

        stopElapsedTimer()
        restTimer?.invalidate()
        restTimer = nil

        let duration = elapsedSeconds
        let volume = computeTotalVolume()

        session.completedAt = .now
        session.durationSeconds = duration
        session.totalVolumeKg = volume
        session.status = .complete

        do {
            try await workoutRepository.saveWorkoutSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }

        await healthKitService.saveWorkout(duration: TimeInterval(duration))

        let prSets = collectPRSets()
        summary = SessionSummary(
            totalVolumeKg: volume,
            durationSeconds: duration,
            prSets: prSets
        )
        phase = .complete
    }

    /// Abandons the active session without saving a summary.
    func abandonSession() async {
        guard let session else { return }
        stopElapsedTimer()
        restTimer?.invalidate()
        restTimer = nil

        session.status = .abandoned
        try? await workoutRepository.saveWorkoutSession(session)
        resetState()
    }

    // MARK: - Set Management

    /// Marks a set row as complete, runs PR detection, resets the rest timer,
    /// and fires a haptic.
    ///
    /// - Parameters:
    ///   - row: The `SetRow` to finalise (must have `isComplete == false`).
    ///   - exerciseID: The `id` of the `ActiveExercise` that owns the row.
    func logSet(_ row: SetRow, exerciseID: UUID) async {
        guard let exerciseIndex = activeExercises.firstIndex(where: { $0.id == exerciseID }),
              let rowIndex = activeExercises[exerciseIndex].setRows.firstIndex(where: { $0.id == row.id }),
              let session else { return }

        let exercise = activeExercises[exerciseIndex]
        let prResult = PRDetector.check(
            weightKg: row.weightKg,
            reps: row.reps,
            against: exercise.previousSets
        )

        activeExercises[exerciseIndex].setRows[rowIndex].isComplete = true
        activeExercises[exerciseIndex].setRows[rowIndex].isPR = prResult.isPR

        let loggedSet = LoggedSet(
            setIndex: row.setIndex,
            weightKg: row.weightKg,
            reps: row.reps,
            rpe: row.rpe,
            isComplete: true,
            isPR: prResult.isPR,
            sortOrder: row.setIndex,
            session: session,
            exercise: nil
        )
        do {
            try await workoutRepository.logSet(loggedSet, for: session)
        } catch {
            errorMessage = error.localizedDescription
        }

        resetRestTimer()
        fireHaptic(.light)
        if prResult.isPR {
            fireHaptic(.medium)
        }
    }

    /// Appends a new blank `SetRow` to the exercise identified by `exerciseID`.
    func addSet(to exerciseID: UUID) {
        guard let idx = activeExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let currentCount = activeExercises[idx].setRows.count
        let lastWeight = activeExercises[idx].setRows.last?.weightKg ?? 0
        let lastReps = activeExercises[idx].setRows.last?.reps ?? 0
        let newRow = SetRow(
            id: UUID(),
            setIndex: currentCount,
            weightKg: lastWeight,
            reps: lastReps,
            rpe: nil,
            isComplete: false,
            isPR: false
        )
        activeExercises[idx].setRows.append(newRow)
    }

    /// Skips the remaining rest time, clearing the timer immediately.
    func skipRest() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = 0
        restTimerActive = false
    }

    // MARK: - Timer Management

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func resetRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = restDurationSeconds
        restTimerActive = true
        startRestTimer()
    }

    private func startRestTimer() {
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 0 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.restTimer?.invalidate()
                    self.restTimer = nil
                    self.restTimerActive = false
                    self.fireHaptic(.heavy)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func computeTotalVolume() -> Double {
        activeExercises
            .flatMap(\.setRows)
            .filter(\.isComplete)
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
    }

    private func collectPRSets() -> [(exerciseName: String, weightKg: Double, reps: Int)] {
        activeExercises.flatMap { exercise in
            exercise.setRows
                .filter { $0.isPR }
                .map { (exercise.name, $0.weightKg, $0.reps) }
        }
    }

    private func updateSessionStatus(_ status: SessionStatus) {
        session?.status = status
        Task {
            guard let session else { return }
            try? await workoutRepository.saveWorkoutSession(session)
        }
    }

    private func resetState() {
        phase = .idle
        activeExercises = []
        elapsedSeconds = 0
        restSecondsRemaining = 0
        restTimerActive = false
        summary = nil
        session = nil
        sessionStartDate = nil
    }

    private func fireHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
