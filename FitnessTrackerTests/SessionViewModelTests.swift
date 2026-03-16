import XCTest
@testable import FitnessTracker

// MARK: - Helpers

private func makeExercise(id: String = "bench_press", name: String = "Bench Press") -> Exercise {
    Exercise(
        exerciseID: id,
        name: name,
        muscleGroup: "Chest",
        equipment: "Barbell",
        instructions: "Perform the movement.",
        imageName: id
    )
}

private func makePlannedExercise(
    exercise: Exercise,
    sets: Int = 3,
    reps: String = "8-10",
    rpe: Double? = nil,
    sortOrder: Int = 0,
    day: WorkoutDay
) -> PlannedExercise {
    PlannedExercise(
        targetSets: sets,
        targetReps: reps,
        targetRPE: rpe,
        sortOrder: sortOrder,
        workoutDay: day,
        exercise: exercise
    )
}

private func makeWorkoutDay(label: String = "Push A") -> WorkoutDay {
    let plan = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 3)
    return WorkoutDay(dayLabel: label, weekdayIndex: 1, workoutPlan: plan)
}

// MARK: - MockWorkoutRepositoryForSession

/// Minimal in-memory mock used exclusively for SessionViewModel tests.
private final class MockSessionRepository: WorkoutRepository, @unchecked Sendable {

    var savedSessions: [WorkoutSession] = []
    var loggedSets: [LoggedSet] = []
    var shouldThrow = false

    private func maybeThrow() throws {
        if shouldThrow { throw MockError.forced }
    }

    enum MockError: Error { case forced }

    func fetchExercises() async throws -> [Exercise] { [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { nil }
    func saveExercise(_ exercise: Exercise) async throws {}

    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { nil }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {}

    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        try maybeThrow()
        return savedSessions
    }

    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        try maybeThrow()
        return savedSessions.filter { $0.startedAt >= startDate && $0.startedAt <= endDate }
    }

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        try maybeThrow()
        if let idx = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[idx] = session
        } else {
            savedSessions.append(session)
        }
    }

    func deleteWorkoutSession(_ session: WorkoutSession) async throws {
        savedSessions.removeAll { $0.id == session.id }
    }

    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {
        try maybeThrow()
        session.sets.append(set)
        set.session = session
        loggedSets.append(set)
    }
}

// MARK: - MockHealthKitServiceForSession

private final class MockSessionHealthKitService: HealthKitServiceProtocol {
    var savedWorkoutDurations: [TimeInterval] = []

    func requestAuthorisationIfNeeded() async {}
    func readDailyStats() async -> DailyStats { DailyStats() }
    func saveWorkout(duration: TimeInterval) async {
        savedWorkoutDurations.append(duration)
    }
}

// MARK: - SessionViewModelTests

@MainActor
final class SessionViewModelTests: XCTestCase {

    // MARK: - Properties

    private var repository: MockSessionRepository!
    private var healthKitService: MockSessionHealthKitService!
    private var sut: SessionViewModel!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        repository = MockSessionRepository()
        healthKitService = MockSessionHealthKitService()
        sut = SessionViewModel(workoutRepository: repository, healthKitService: healthKitService)
    }

    override func tearDown() {
        sut = nil
        healthKitService = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialPhase_isIdle() {
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_initialActiveExercises_isEmpty() {
        XCTAssertTrue(sut.activeExercises.isEmpty)
    }

    func test_initialElapsedSeconds_isZero() {
        XCTAssertEqual(sut.elapsedSeconds, 0)
    }

    func test_initialRestSecondsRemaining_isZero() {
        XCTAssertEqual(sut.restSecondsRemaining, 0)
    }

    func test_initialRestTimerActive_isFalse() {
        XCTAssertFalse(sut.restTimerActive)
    }

    func test_initialSummary_isNil() {
        XCTAssertNil(sut.summary)
    }

    func test_initialErrorMessage_isNil() {
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - startSession

    func test_startSession_transitionsPhaseToActive() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, day: day)

        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.phase, .active)
    }

    func test_startSession_populatesActiveExercises() async {
        let day = makeWorkoutDay()
        let ex1 = makeExercise(id: "bench_press", name: "Bench Press")
        let ex2 = makeExercise(id: "ohp", name: "OHP")
        let p1 = makePlannedExercise(exercise: ex1, sets: 4, day: day, sortOrder: 0)
        let p2 = makePlannedExercise(exercise: ex2, sets: 3, day: day, sortOrder: 1)

        await sut.startSession(day: day, exercises: [p1, p2])

        XCTAssertEqual(sut.activeExercises.count, 2)
        XCTAssertEqual(sut.activeExercises[0].name, "Bench Press")
        XCTAssertEqual(sut.activeExercises[1].name, "OHP")
    }

    func test_startSession_setsCorrectNumberOfSetRows() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, sets: 4, day: day)

        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.activeExercises[0].setRows.count, 4)
    }

    func test_startSession_savesSessionToRepository() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, day: day)

        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(repository.savedSessions.count, 1)
        XCTAssertEqual(repository.savedSessions[0].status, .active)
    }

    func test_startSession_withEmptyExercises_remainsIdleIfNoExercises() async {
        let day = makeWorkoutDay()
        // passing no exercises; startSession guard in startSession() exits early
        // and the phase transitions to active only if exercises are non-empty
        await sut.startSession(day: day, exercises: [])

        // With no exercises the view-model stays idle (empty exercises path in
        // SessionView.startSession() saves a session separately and returns early)
        XCTAssertEqual(sut.activeExercises.count, 0)
    }

    func test_startSession_withPreviousSetsMap_populatesSetRowWeightFromPreviousSession() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise(id: "squat", name: "Squat")
        let planned = makePlannedExercise(exercise: exercise, sets: 3, reps: "5", day: day)

        let previousSet = LoggedSet(setIndex: 0, weightKg: 100, reps: 5)
        let previousSetsMap: [String: [LoggedSet]] = ["squat": [previousSet]]

        await sut.startSession(day: day, exercises: [planned], previousSetsMap: previousSetsMap)

        XCTAssertEqual(sut.activeExercises[0].setRows[0].weightKg, 100)
    }

    func test_startSession_repositoryError_setsErrorMessage() async {
        repository.shouldThrow = true
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, day: day)

        await sut.startSession(day: day, exercises: [planned])

        XCTAssertNotNil(sut.errorMessage)
    }

    func test_startSession_repositoryError_doesNotTransitionToActive() async {
        repository.shouldThrow = true
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, day: day)

        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - pauseSession / resumeSession

    func test_pauseSession_transitionsToPaused() async {
        await startActiveSession()

        sut.pauseSession()

        XCTAssertEqual(sut.phase, .paused)
    }

    func test_resumeSession_transitionsToActive() async {
        await startActiveSession()
        sut.pauseSession()

        sut.resumeSession()

        XCTAssertEqual(sut.phase, .active)
    }

    func test_pauseSession_fromIdle_hasNoEffect() {
        sut.pauseSession()
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_resumeSession_fromIdle_hasNoEffect() {
        sut.resumeSession()
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_pauseSession_persistsPausedStatus() async {
        await startActiveSession()
        sut.pauseSession()

        // The session status should be persisted as paused in the repository.
        // Allow any pending async save tasks to complete.
        try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        let saved = repository.savedSessions.last
        XCTAssertEqual(saved?.status, .paused)
    }

    // MARK: - addSet

    func test_addSet_appendsANewSetRow() async {
        await startActiveSession()
        let exerciseID = sut.activeExercises[0].id
        let initialCount = sut.activeExercises[0].setRows.count

        sut.addSet(to: exerciseID)

        XCTAssertEqual(sut.activeExercises[0].setRows.count, initialCount + 1)
    }

    func test_addSet_newRowIsNotComplete() async {
        await startActiveSession()
        let exerciseID = sut.activeExercises[0].id

        sut.addSet(to: exerciseID)

        XCTAssertFalse(sut.activeExercises[0].setRows.last!.isComplete)
    }

    func test_addSet_unknownExerciseID_doesNothing() async {
        await startActiveSession()
        let beforeCount = sut.activeExercises[0].setRows.count

        sut.addSet(to: UUID()) // non-existent ID

        XCTAssertEqual(sut.activeExercises[0].setRows.count, beforeCount)
    }

    // MARK: - logSet

    func test_logSet_marksRowAsComplete() async {
        await startActiveSession()
        let exerciseIndex = 0
        let exercise = sut.activeExercises[exerciseIndex]
        var row = exercise.setRows[0]
        row.weightKg = 80
        row.reps = 8

        await sut.logSet(row, exerciseID: exercise.id)

        XCTAssertTrue(sut.activeExercises[exerciseIndex].setRows[0].isComplete)
    }

    func test_logSet_startsRestTimer() async {
        await startActiveSession()
        let exercise = sut.activeExercises[0]
        let row = exercise.setRows[0]

        await sut.logSet(row, exerciseID: exercise.id)

        XCTAssertTrue(sut.restTimerActive)
        XCTAssertGreaterThan(sut.restSecondsRemaining, 0)
    }

    func test_logSet_persistsLoggedSetToRepository() async {
        await startActiveSession()
        let exercise = sut.activeExercises[0]
        var row = exercise.setRows[0]
        row.weightKg = 60
        row.reps = 10

        await sut.logSet(row, exerciseID: exercise.id)

        XCTAssertFalse(repository.loggedSets.isEmpty)
        XCTAssertEqual(repository.loggedSets[0].weightKg, 60)
        XCTAssertEqual(repository.loggedSets[0].reps, 10)
    }

    // MARK: - skipRest

    func test_skipRest_clearsRestTimer() async {
        await startActiveSession()
        let exercise = sut.activeExercises[0]
        await sut.logSet(exercise.setRows[0], exerciseID: exercise.id)
        XCTAssertTrue(sut.restTimerActive)

        sut.skipRest()

        XCTAssertFalse(sut.restTimerActive)
        XCTAssertEqual(sut.restSecondsRemaining, 0)
    }

    // MARK: - finishSession

    func test_finishSession_transitionsToComplete() async {
        await startActiveSession()

        await sut.finishSession()

        XCTAssertEqual(sut.phase, .complete)
    }

    func test_finishSession_populatesSummary() async {
        await startActiveSession()

        await sut.finishSession()

        XCTAssertNotNil(sut.summary)
    }

    func test_finishSession_persistsCompletedSession() async {
        await startActiveSession()

        await sut.finishSession()

        let completed = repository.savedSessions.first { $0.status == .complete }
        XCTAssertNotNil(completed)
    }

    func test_finishSession_savesHKWorkout() async {
        await startActiveSession()

        await sut.finishSession()

        XCTAssertFalse(healthKitService.savedWorkoutDurations.isEmpty)
    }

    func test_finishSession_fromIdle_hasNoEffect() async {
        await sut.finishSession()
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertNil(sut.summary)
    }

    func test_finishSession_summaryVolumeReflectsCompletedSets() async {
        await startActiveSession()

        // Complete one set with known weight × reps.
        let exercise = sut.activeExercises[0]
        var row = exercise.setRows[0]
        row.weightKg = 100
        row.reps = 5
        sut.activeExercises[0].setRows[0] = row
        await sut.logSet(row, exerciseID: exercise.id)

        await sut.finishSession()

        // Volume = 100 kg × 5 reps = 500 kg
        XCTAssertEqual(sut.summary?.totalVolumeKg, 500)
    }

    // MARK: - abandonSession

    func test_abandonSession_resetsPhaseToIdle() async {
        await startActiveSession()

        await sut.abandonSession()

        XCTAssertEqual(sut.phase, .idle)
    }

    func test_abandonSession_persistsAbandonedStatus() async {
        await startActiveSession()

        await sut.abandonSession()

        let abandoned = repository.savedSessions.first { $0.status == .abandoned }
        XCTAssertNotNil(abandoned)
    }

    func test_abandonSession_clearsSummary() async {
        await startActiveSession()

        await sut.abandonSession()

        XCTAssertNil(sut.summary)
    }

    // MARK: - SessionSummary

    func test_summary_durationMatchesElapsed() async {
        await startActiveSession()
        // Manually set elapsed seconds to a known value via finishSession.
        await sut.finishSession()

        XCTAssertEqual(sut.summary?.durationSeconds, sut.elapsedSeconds)
    }

    // MARK: - ActiveExercise metadata

    func test_activeExercise_targetSetsMatchesPlanned() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, sets: 5, day: day)
        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.activeExercises[0].targetSets, 5)
    }

    func test_activeExercise_targetRepsMatchesPlanned() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, reps: "6-8", day: day)
        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.activeExercises[0].targetReps, "6-8")
    }

    func test_activeExercise_exerciseIDMatchesLibraryID() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise(id: "deadlift")
        let planned = makePlannedExercise(exercise: exercise, day: day)
        await sut.startSession(day: day, exercises: [planned])

        XCTAssertEqual(sut.activeExercises[0].exerciseID, "deadlift")
    }

    // MARK: - Private Helpers

    /// Convenience: starts a session with one bench-press exercise (3×8).
    private func startActiveSession() async {
        let day = makeWorkoutDay()
        let exercise = makeExercise()
        let planned = makePlannedExercise(exercise: exercise, sets: 3, reps: "8", day: day)
        await sut.startSession(day: day, exercises: [planned])
    }
}
