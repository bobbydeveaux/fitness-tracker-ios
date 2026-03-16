import XCTest
@testable import FitnessTracker

// MARK: - SessionViewModelTests

@MainActor
final class SessionViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeWorkoutDay(exerciseCount: Int = 2) -> WorkoutDay {
        let day = WorkoutDay(dayLabel: "Push A", weekdayIndex: 2)
        let bench = Exercise(
            exerciseID: "bench",
            name: "Barbell Bench Press",
            muscleGroup: "Chest",
            equipment: "Barbell",
            instructions: "",
            imageName: "bench_press"
        )
        for i in 0..<exerciseCount {
            let pe = PlannedExercise(
                targetSets: 3,
                targetReps: "5",
                targetRPE: 8.0,
                sortOrder: i,
                exercise: bench
            )
            pe.workoutDay = day
            day.plannedExercises.append(pe)
        }
        return day
    }

    private func makeSUT(
        day: WorkoutDay? = nil,
        repository: (any WorkoutRepository)? = nil
    ) -> SessionViewModel {
        let workoutDay = day ?? makeWorkoutDay()
        let repo = repository ?? MockWorkoutRepository()
        let hk = MockHealthKitService()
        return SessionViewModel(workoutDay: workoutDay, repository: repo, healthKitService: hk)
    }

    // MARK: - Initial state

    func test_initialState_isIdle() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.elapsedSeconds, 0)
        XCTAssertNil(sut.restTimerSecondsRemaining)
        XCTAssertNil(sut.errorMessage)
    }

    func test_exerciseEntries_seededFromWorkoutDay() {
        let day = makeWorkoutDay(exerciseCount: 3)
        let sut = makeSUT(day: day)
        XCTAssertEqual(sut.exerciseEntries.count, 3)
    }

    func test_exerciseEntries_setsCountMatchesTargetSets() {
        let day = makeWorkoutDay(exerciseCount: 1)
        let sut = makeSUT(day: day)
        XCTAssertEqual(sut.exerciseEntries[0].sets.count, 3) // targetSets = 3
    }

    // MARK: - Start session

    func test_startSession_transitionsToActive() async {
        let sut = makeSUT()
        await sut.startSession()
        XCTAssertEqual(sut.state, .active)
    }

    func test_startSession_idempotent_whenAlreadyActive() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.startSession() // second call should be a no-op
        XCTAssertEqual(sut.state, .active)
    }

    func test_startSession_setsErrorMessage_whenRepositoryThrows() async {
        let failingRepo = FailingWorkoutRepository()
        let sut = makeSUT(repository: failingRepo)
        await sut.startSession()
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Pause / Resume

    func test_pauseSession_transitionsToPaused() async {
        let sut = makeSUT()
        await sut.startSession()
        sut.pauseSession()
        XCTAssertEqual(sut.state, .paused)
    }

    func test_resumeSession_transitionsToActive() async {
        let sut = makeSUT()
        await sut.startSession()
        sut.pauseSession()
        sut.resumeSession()
        XCTAssertEqual(sut.state, .active)
    }

    func test_pauseSession_noOp_whenIdle() {
        let sut = makeSUT()
        sut.pauseSession()
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Finish session

    func test_finishSession_transitionsToComplete() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.finishSession()
        XCTAssertEqual(sut.state, .complete)
    }

    func test_finishSession_producesSummaryData() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.finishSession()
        XCTAssertNotNil(sut.summaryData)
    }

    func test_finishSession_noOp_whenIdle() async {
        let sut = makeSUT()
        await sut.finishSession()
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Abandon session

    func test_abandonSession_transitionsToAbandoned() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.abandonSession()
        XCTAssertEqual(sut.state, .abandoned)
    }

    // MARK: - Complete set

    func test_completeSet_marksSetAsComplete() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertTrue(sut.exerciseEntries[0].sets[0].isComplete)
    }

    func test_completeSet_updatesWeight() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 80.0, reps: 8)
        XCTAssertEqual(sut.exerciseEntries[0].sets[0].weightKg, 80.0, accuracy: 0.001)
    }

    func test_completeSet_firstSet_markedAsPR_whenNoHistory() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertTrue(sut.exerciseEntries[0].sets[0].isPR)
    }

    func test_completeSet_notPR_whenWeightBelowBest() async {
        let day = makeWorkoutDay(exerciseCount: 1)
        let sut = makeSUT(day: day)
        // Manually inject a previous best.
        sut.exerciseEntries[0].previousBest = (weightKg: 120.0, reps: 5)
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertFalse(sut.exerciseEntries[0].sets[0].isPR)
    }

    func test_completeSet_isPR_whenWeightExceedsBest() async {
        let day = makeWorkoutDay(exerciseCount: 1)
        let sut = makeSUT(day: day)
        sut.exerciseEntries[0].previousBest = (weightKg: 100.0, reps: 5)
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 102.5, reps: 5)
        XCTAssertTrue(sut.exerciseEntries[0].sets[0].isPR)
    }

    func test_completeSet_updatesVolumeKg() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertEqual(sut.totalVolumeKg, 500, accuracy: 0.001) // 100 * 5
    }

    func test_completeSet_startsRestTimer() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertNotNil(sut.restTimerSecondsRemaining)
    }

    func test_completeSet_noOp_whenNotActive() async {
        let sut = makeSUT()
        // Session not started
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        XCTAssertFalse(sut.exerciseEntries[0].sets[0].isComplete)
    }

    func test_completeSet_noOp_outOfBoundsIndex() async {
        let sut = makeSUT()
        await sut.startSession()
        // exerciseIndex 99 doesn't exist — should not crash
        await sut.completeSet(exerciseIndex: 99, setIndex: 0, weightKg: 100, reps: 5)
    }

    // MARK: - PR count

    func test_prCount_reflectsCompletedPRSets() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        await sut.completeSet(exerciseIndex: 0, setIndex: 1, weightKg: 105, reps: 5) // new PR
        XCTAssertGreaterThanOrEqual(sut.prCount, 1)
    }

    // MARK: - Rest timer

    func test_cancelRestTimer_clearsSecondsRemaining() async {
        let sut = makeSUT()
        await sut.startSession()
        sut.startRestTimer(duration: 90)
        XCTAssertNotNil(sut.restTimerSecondsRemaining)
        sut.cancelRestTimer()
        XCTAssertNil(sut.restTimerSecondsRemaining)
    }

    func test_restTimerProgress_zeroWhenNoTimer() {
        let sut = makeSUT()
        XCTAssertEqual(sut.restTimerProgress, 0, accuracy: 0.001)
    }

    // MARK: - Elapsed formatted

    func test_elapsedFormatted_showsMMSS_underOneHour() {
        let sut = makeSUT()
        XCTAssertEqual(sut.elapsedFormatted, "00:00")
    }

    // MARK: - Summary data

    func test_summaryData_containsCorrectVolume() async {
        let sut = makeSUT()
        await sut.startSession()
        await sut.completeSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 5)
        await sut.completeSet(exerciseIndex: 0, setIndex: 1, weightKg: 100, reps: 5)
        await sut.finishSession()
        XCTAssertEqual(sut.summaryData?.totalVolumeKg, 1000, accuracy: 0.001)
    }
}

// MARK: - Mock Workout Repository

private final class MockWorkoutRepository: WorkoutRepository, @unchecked Sendable {
    private(set) var savedSessions: [WorkoutSession] = []
    private(set) var loggedSets: [LoggedSet] = []

    func fetchExercises() async throws -> [Exercise] { [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { nil }
    func saveExercise(_ exercise: Exercise) async throws {}
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { nil }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { savedSessions }
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] { [] }
    func saveWorkoutSession(_ session: WorkoutSession) async throws { savedSessions.append(session) }
    func deleteWorkoutSession(_ session: WorkoutSession) async throws {}
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws { loggedSets.append(set) }
}

// MARK: - Failing Workout Repository

private final class FailingWorkoutRepository: WorkoutRepository, @unchecked Sendable {
    enum Failure: Error { case forced }
    func fetchExercises() async throws -> [Exercise] { throw Failure.forced }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { throw Failure.forced }
    func saveExercise(_ exercise: Exercise) async throws { throw Failure.forced }
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { throw Failure.forced }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { throw Failure.forced }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws { throw Failure.forced }
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws { throw Failure.forced }
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { throw Failure.forced }
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] { throw Failure.forced }
    func saveWorkoutSession(_ session: WorkoutSession) async throws { throw Failure.forced }
    func deleteWorkoutSession(_ session: WorkoutSession) async throws { throw Failure.forced }
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws { throw Failure.forced }
}

// MARK: - Mock HealthKit Service

private final class MockHealthKitService: HealthKitServiceProtocol {
    private(set) var workoutSavedDuration: TimeInterval?
    func requestAuthorisationIfNeeded() async {}
    func readDailyStats() async -> DailyStats { DailyStats() }
    func saveWorkout(duration: TimeInterval) async { workoutSavedDuration = duration }
}
