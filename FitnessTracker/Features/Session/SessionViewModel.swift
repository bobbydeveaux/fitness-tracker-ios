import Foundation
import Observation
import Combine

// MARK: - SessionState

/// Lifecycle states for an active gym session.
enum SessionState: Equatable {
    case idle
    case active
    case paused
    case complete
    case abandoned
}

// MARK: - ExerciseSessionEntry

/// In-memory representation of all logged sets for a single exercise within a session.
struct ExerciseSessionEntry {
    let plannedExercise: PlannedExercise
    var sets: [LoggedSet]
    /// Best (weight, reps) from any previous session for this exercise. Used for PR detection and inline display.
    var previousBest: (weightKg: Double, reps: Int)?
}

// MARK: - SessionSummaryData

/// Snapshot produced when the user finishes a session, fed into `SessionSummaryView`.
struct SessionSummaryData {
    let durationSeconds: Int
    let totalVolumeKg: Double
    let prCount: Int
    let exerciseEntries: [ExerciseSessionEntry]
}

// MARK: - SessionViewModel

/// `@Observable` view model that drives the active gym session feature.
///
/// ## State machine
/// ```
/// idle → active → paused ⇆ active → complete
///              ↘ abandoned
/// ```
///
/// ## Responsibilities
/// - Creates and persists a `WorkoutSession` record on start.
/// - Provides per-exercise set entries seeded from the `WorkoutDay`'s `PlannedExercise` list.
/// - Detects personal records inline when a set is saved.
/// - Manages a configurable rest timer via `Timer.publish`.
/// - Writes a HealthKit workout on session completion.
@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Session state

    private(set) var state: SessionState = .idle
    private(set) var elapsedSeconds: Int = 0
    /// Mutable so tests and `loadPreviousBests()` can inject historical data.
    var exerciseEntries: [ExerciseSessionEntry] = []
    private(set) var errorMessage: String?
    private(set) var summaryData: SessionSummaryData?

    // MARK: - Rest timer

    /// Seconds remaining in the current rest period, or `nil` when the timer is inactive.
    private(set) var restTimerSecondsRemaining: Int? = nil
    /// Configurable rest duration in seconds (default 90 s).
    var restTimerDuration: Int = 90

    // MARK: - Computed

    var totalVolumeKg: Double {
        exerciseEntries.flatMap(\.sets).reduce(0.0) { acc, set in
            acc + (set.isComplete ? set.weightKg * Double(set.reps) : 0)
        }
    }

    var prCount: Int {
        exerciseEntries.flatMap(\.sets).filter(\.isPR).count
    }

    var elapsedFormatted: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var restTimerFormatted: String {
        guard let remaining = restTimerSecondsRemaining else { return "" }
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var restTimerProgress: Double {
        guard let remaining = restTimerSecondsRemaining, restTimerDuration > 0 else { return 0 }
        return Double(restTimerDuration - remaining) / Double(restTimerDuration)
    }

    // MARK: - Private

    let workoutDay: WorkoutDay
    private let repository: any WorkoutRepository
    private let healthKitService: any HealthKitServiceProtocol
    private var activeSession: WorkoutSession?

    /// Elapsed timer cancellable — fires every second while session is active.
    private var elapsedTimerCancellable: AnyCancellable?
    /// Rest timer cancellable — fires every second during a rest period.
    private var restTimerCancellable: AnyCancellable?

    // MARK: - Init

    init(
        workoutDay: WorkoutDay,
        repository: any WorkoutRepository,
        healthKitService: any HealthKitServiceProtocol
    ) {
        self.workoutDay = workoutDay
        self.repository = repository
        self.healthKitService = healthKitService
        buildExerciseEntries()
    }

    // MARK: - Session Lifecycle

    /// Transitions from `idle` to `active`, persists a new `WorkoutSession`, and starts the elapsed timer.
    func startSession() async {
        guard state == .idle else { return }
        let session = WorkoutSession(workoutDay: workoutDay)
        do {
            try await repository.saveWorkoutSession(session)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        activeSession = session
        state = .active
        startElapsedTimer()
    }

    /// Pauses the elapsed timer without saving; the session remains in SwiftData.
    func pauseSession() {
        guard state == .active else { return }
        state = .paused
        stopElapsedTimer()
    }

    /// Resumes from `paused` back to `active` and restarts the elapsed timer.
    func resumeSession() {
        guard state == .paused else { return }
        state = .active
        startElapsedTimer()
    }

    /// Completes the session: persists final totals, writes to HealthKit, transitions to `complete`.
    func finishSession() async {
        guard state == .active || state == .paused,
              let session = activeSession else { return }

        stopElapsedTimer()
        cancelRestTimer()

        session.status = .complete
        session.completedAt = Date()
        session.durationSeconds = elapsedSeconds
        session.totalVolumeKg = totalVolumeKg

        do {
            try await repository.saveWorkoutSession(session)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        summaryData = SessionSummaryData(
            durationSeconds: elapsedSeconds,
            totalVolumeKg: totalVolumeKg,
            prCount: prCount,
            exerciseEntries: exerciseEntries
        )

        await healthKitService.saveWorkout(duration: TimeInterval(elapsedSeconds))
        state = .complete
    }

    /// Marks the session as abandoned without producing a summary.
    func abandonSession() async {
        guard let session = activeSession else {
            state = .abandoned
            return
        }
        stopElapsedTimer()
        cancelRestTimer()
        session.status = .abandoned
        session.durationSeconds = elapsedSeconds
        do {
            try await repository.saveWorkoutSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
        state = .abandoned
    }

    // MARK: - Set Logging

    /// Logs a completed set for the exercise at `exerciseIndex`, detects PRs, and starts the rest timer.
    ///
    /// - Parameters:
    ///   - exerciseIndex: Index into `exerciseEntries`.
    ///   - setIndex: 0-based index of the set within that exercise.
    ///   - weightKg: Load lifted in kilograms.
    ///   - reps: Repetitions performed.
    ///   - rpe: Rate of Perceived Exertion (optional, 1–10).
    func completeSet(
        exerciseIndex: Int,
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil
    ) async {
        guard state == .active,
              exerciseIndex < exerciseEntries.count,
              setIndex < exerciseEntries[exerciseIndex].sets.count,
              let session = activeSession else { return }

        var entry = exerciseEntries[exerciseIndex]
        var set = entry.sets[setIndex]

        set.weightKg = weightKg
        set.reps = reps
        set.rpe = rpe
        set.isComplete = true
        set.isPR = detectPR(
            weightKg: weightKg,
            reps: reps,
            existingBest: entry.previousBest
        )

        // Update previous best if this set is a PR.
        if set.isPR {
            entry.previousBest = (weightKg, reps)
        }

        entry.sets[setIndex] = set
        exerciseEntries[exerciseIndex] = entry

        // Persist to SwiftData.
        do {
            try await repository.logSet(set, for: session)
        } catch {
            errorMessage = error.localizedDescription
        }

        startRestTimer()
    }

    // MARK: - Rest Timer

    /// Starts (or restarts) the rest timer with the current `restTimerDuration`.
    func startRestTimer(duration: Int? = nil) {
        let targetDuration = duration ?? restTimerDuration
        cancelRestTimer()
        restTimerSecondsRemaining = targetDuration
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard var remaining = self.restTimerSecondsRemaining else { return }
                remaining -= 1
                if remaining <= 0 {
                    self.restTimerSecondsRemaining = nil
                    self.restTimerCancellable?.cancel()
                } else {
                    self.restTimerSecondsRemaining = remaining
                }
            }
    }

    /// Cancels the rest timer without completing it.
    func cancelRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restTimerSecondsRemaining = nil
    }

    // MARK: - Private Helpers

    /// Seeds `exerciseEntries` from the `workoutDay`'s planned exercises.
    private func buildExerciseEntries() {
        let sorted = workoutDay.plannedExercises.sorted { $0.sortOrder < $1.sortOrder }
        exerciseEntries = sorted.map { planned in
            let sets = (0..<planned.targetSets).map { idx in
                LoggedSet(
                    setIndex: idx,
                    weightKg: 0,
                    reps: 0,
                    sortOrder: idx
                )
            }
            return ExerciseSessionEntry(plannedExercise: planned, sets: sets, previousBest: nil)
        }
    }

    /// Loads previous-best data for all exercises in the session.
    ///
    /// Call from the view's `.task {}` modifier so previous performance appears before the session starts.
    func loadPreviousBests() async {
        // Fetch all sessions to find previous bests per exercise.
        guard let allSessions = try? await repository.fetchWorkoutSessions() else { return }

        for (idx, entry) in exerciseEntries.enumerated() {
            guard let exercise = entry.plannedExercise.exercise else { continue }
            let exerciseID = exercise.exerciseID

            // Collect all logged sets for this exercise from completed sessions
            // that are not the current one.
            let historicalSets = allSessions
                .filter { $0.id != activeSession?.id && $0.status == .complete }
                .flatMap(\.sets)
                .filter { $0.exercise?.exerciseID == exerciseID && $0.isComplete }

            // Best = highest weight lifted for any rep count.
            if let best = historicalSets.max(by: { $0.weightKg < $1.weightKg }) {
                exerciseEntries[idx].previousBest = (best.weightKg, best.reps)
            }
        }
    }

    /// Returns `true` if the current (weightKg, reps) surpasses the recorded best.
    ///
    /// PR logic: a new PR is detected when `weightKg` exceeds the previous best weight.
    private func detectPR(
        weightKg: Double,
        reps: Int,
        existingBest: (weightKg: Double, reps: Int)?
    ) -> Bool {
        guard weightKg > 0, reps > 0 else { return false }
        guard let best = existingBest else {
            // No historical data — first time performing this exercise counts as a PR.
            return true
        }
        return weightKg > best.weightKg
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }

    private func stopElapsedTimer() {
        elapsedTimerCancellable?.cancel()
        elapsedTimerCancellable = nil
    }
}
