import XCTest
@testable import FitnessTracker

// MockProgressRepository and MockWorkoutRepository are defined in
// DashboardViewModelTests.swift and WorkoutPlanViewModelTests.swift respectively
// and are visible across the test target.

// MARK: - ProgressViewModelTests

@MainActor
final class ProgressViewModelTests: XCTestCase {

    // MARK: - Helpers

    private var mockProgress: MockProgressRepository!
    private var mockWorkout: MockWorkoutRepository!

    override func setUp() {
        super.setUp()
        mockProgress = MockProgressRepository()
        mockWorkout = MockWorkoutRepository()
    }

    override func tearDown() {
        mockProgress = nil
        mockWorkout = nil
        super.tearDown()
    }

    private func makeViewModel() -> ProgressViewModel {
        ProgressViewModel(
            progressRepository: mockProgress,
            workoutRepository: mockWorkout
        )
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            name: "Test User",
            age: 28,
            gender: .female,
            heightCm: 165,
            weightKg: 65,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            tdeeKcal: 2000,
            proteinTargetG: 140,
            carbTargetG: 200,
            fatTargetG: 55
        )
    }

    private func makeBodyMetric(type: BodyMetricType = .weight, value: Double, daysAgo: Int = 0) -> BodyMetric {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return BodyMetric(date: date, type: type, value: value)
    }

    private func makeSession(
        daysAgo: Int = 0,
        totalVolumeKg: Double = 1000,
        status: SessionStatus = .complete
    ) -> WorkoutSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return WorkoutSession(startedAt: date, totalVolumeKg: totalVolumeKg, status: status)
    }

    private func makeExercise(id: String = "bench_press", name: String = "Bench Press") -> Exercise {
        Exercise(
            exerciseID: id,
            name: name,
            muscleGroup: "Chest",
            equipment: "Barbell",
            instructions: "Press the bar.",
            imageName: "bench_press"
        )
    }

    private func makeSet(
        weightKg: Double,
        reps: Int,
        isComplete: Bool = true,
        exercise: Exercise? = nil
    ) -> LoggedSet {
        LoggedSet(
            setIndex: 0,
            weightKg: weightKg,
            reps: reps,
            isComplete: isComplete,
            exercise: exercise
        )
    }

    // MARK: - Initial State

    func test_initialState_isEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.state.bodyWeightPoints.isEmpty)
        XCTAssertTrue(vm.state.volumePoints.isEmpty)
        XCTAssertTrue(vm.state.exerciseSeries.isEmpty)
    }

    func test_initialIsLoading_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    func test_initialErrorMessage_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func test_initialSelectedTimeRange_isMonth() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedTimeRange, .month)
    }

    // MARK: - ProgressTimeRange

    func test_progressTimeRange_startDate_all_returnsNil() {
        XCTAssertNil(ProgressTimeRange.all.startDate())
    }

    func test_progressTimeRange_startDate_week_isSevenDaysAgo() {
        let now = Date.now
        let start = ProgressTimeRange.week.startDate(relativeTo: now)!
        let diff = now.timeIntervalSince(start)
        // Allow 1-second tolerance for test execution time.
        XCTAssertEqual(diff, 7 * 24 * 3600, accuracy: 1)
    }

    func test_progressTimeRange_startDate_month_isOneMonthAgo() {
        let now = Date.now
        let start = ProgressTimeRange.month.startDate(relativeTo: now)!
        let expected = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        XCTAssertEqual(start.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func test_progressTimeRange_startDate_threeMonths_isThreeMonthsAgo() {
        let now = Date.now
        let start = ProgressTimeRange.threeMonths.startDate(relativeTo: now)!
        let expected = Calendar.current.date(byAdding: .month, value: -3, to: now)!
        XCTAssertEqual(start.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func test_progressTimeRange_allCases_count() {
        XCTAssertEqual(ProgressTimeRange.allCases.count, 4)
    }

    func test_progressTimeRange_rawValues() {
        XCTAssertEqual(ProgressTimeRange.week.rawValue, "1W")
        XCTAssertEqual(ProgressTimeRange.month.rawValue, "1M")
        XCTAssertEqual(ProgressTimeRange.threeMonths.rawValue, "3M")
        XCTAssertEqual(ProgressTimeRange.all.rawValue, "All")
    }

    func test_progressTimeRange_id_equalsRawValue() {
        for range in ProgressTimeRange.allCases {
            XCTAssertEqual(range.id, range.rawValue)
        }
    }

    // MARK: - loadProgress — body weight

    func test_loadProgress_bodyWeightPointsPopulated() async {
        let profile = makeProfile()
        mockProgress.bodyMetrics = [
            makeBodyMetric(type: .weight, value: 80.0, daysAgo: 10),
            makeBodyMetric(type: .weight, value: 79.5, daysAgo: 5)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.bodyWeightPoints.count, 2)
        XCTAssertEqual(vm.state.bodyWeightPoints[0].value, 80.0, accuracy: 0.001)
        XCTAssertEqual(vm.state.bodyWeightPoints[1].value, 79.5, accuracy: 0.001)
    }

    func test_loadProgress_bodyWeightPointsOrderedByDateAscending() async {
        let profile = makeProfile()
        // Add out of order
        mockProgress.bodyMetrics = [
            makeBodyMetric(type: .weight, value: 79.0, daysAgo: 2),
            makeBodyMetric(type: .weight, value: 81.0, daysAgo: 10),
            makeBodyMetric(type: .weight, value: 80.0, daysAgo: 5)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.bodyWeightPoints.count, 3)
        XCTAssertEqual(vm.state.bodyWeightPoints[0].value, 81.0, accuracy: 0.001)
        XCTAssertEqual(vm.state.bodyWeightPoints[1].value, 80.0, accuracy: 0.001)
        XCTAssertEqual(vm.state.bodyWeightPoints[2].value, 79.0, accuracy: 0.001)
    }

    func test_loadProgress_bodyWeightEmpty_whenNoWeightMetrics() async {
        let profile = makeProfile()
        // Only non-weight metrics
        mockProgress.bodyMetrics = [
            makeBodyMetric(type: .waist, value: 80.0, daysAgo: 5)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.state.bodyWeightPoints.isEmpty)
    }

    func test_loadProgress_bodyWeightEmpty_whenNoMetrics() async {
        let profile = makeProfile()
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.state.bodyWeightPoints.isEmpty)
    }

    // MARK: - loadProgress — volume

    func test_loadProgress_volumePointsFromCompletedSessions() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 5, totalVolumeKg: 1500, status: .complete),
            makeSession(daysAgo: 3, totalVolumeKg: 1800, status: .complete)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 2)
    }

    func test_loadProgress_volumePointsExcludeIncompleteSessions() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 5, totalVolumeKg: 1500, status: .complete),
            makeSession(daysAgo: 3, totalVolumeKg: 800, status: .active),
            makeSession(daysAgo: 1, totalVolumeKg: 600, status: .abandoned)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 1)
        XCTAssertEqual(vm.state.volumePoints[0].value, 1500, accuracy: 0.001)
    }

    func test_loadProgress_volumePointsOrderedByDateAscending() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 1, totalVolumeKg: 2000, status: .complete),
            makeSession(daysAgo: 10, totalVolumeKg: 1000, status: .complete),
            makeSession(daysAgo: 5, totalVolumeKg: 1500, status: .complete)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 3)
        XCTAssertEqual(vm.state.volumePoints[0].value, 1000, accuracy: 0.001)
        XCTAssertEqual(vm.state.volumePoints[1].value, 1500, accuracy: 0.001)
        XCTAssertEqual(vm.state.volumePoints[2].value, 2000, accuracy: 0.001)
    }

    func test_loadProgress_volumeEmpty_whenNoSessions() async {
        let profile = makeProfile()
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.state.volumePoints.isEmpty)
    }

    // MARK: - loadProgress — 1RM aggregation

    func test_loadProgress_oneRM_epleyFormula() async {
        // Epley: 1RM = weight × (1 + reps / 30)
        // 100kg × 5 reps → 1RM = 100 × (1 + 5/30) = 116.667kg
        let profile = makeProfile()
        let exercise = makeExercise()
        let set = makeSet(weightKg: 100, reps: 5, exercise: exercise)
        let session = makeSession(daysAgo: 2, status: .complete)
        session.sets.append(set)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.exerciseSeries.count, 1)
        XCTAssertEqual(vm.state.exerciseSeries[0].exerciseName, "Bench Press")
        XCTAssertEqual(vm.state.exerciseSeries[0].dataPoints.count, 1)
        let expectedOneRM = 100.0 * (1.0 + 5.0 / 30.0)
        XCTAssertEqual(vm.state.exerciseSeries[0].dataPoints[0].value, expectedOneRM, accuracy: 0.001)
    }

    func test_loadProgress_oneRM_singleRepEqualsWeight() async {
        // 1 rep → 1RM = weight × (1 + 1/30) ≈ weight × 1.0333
        let profile = makeProfile()
        let exercise = makeExercise()
        let set = makeSet(weightKg: 140, reps: 1, exercise: exercise)
        let session = makeSession(daysAgo: 1, status: .complete)
        session.sets.append(set)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        let expected = 140.0 * (1.0 + 1.0 / 30.0)
        XCTAssertEqual(vm.state.exerciseSeries[0].dataPoints[0].value, expected, accuracy: 0.001)
    }

    func test_loadProgress_exerciseSeriesGroupedByExercise() async {
        let profile = makeProfile()
        let benchPress = makeExercise(id: "bench_press", name: "Bench Press")
        let squat = makeExercise(id: "squat", name: "Squat")

        let set1 = makeSet(weightKg: 100, reps: 5, exercise: benchPress)
        let set2 = makeSet(weightKg: 120, reps: 5, exercise: squat)
        let session = makeSession(daysAgo: 3, status: .complete)
        session.sets.append(set1)
        session.sets.append(set2)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.exerciseSeries.count, 2)
        let names = vm.state.exerciseSeries.map(\.exerciseName)
        XCTAssertTrue(names.contains("Bench Press"))
        XCTAssertTrue(names.contains("Squat"))
    }

    func test_loadProgress_exerciseSeriesExcludesIncompleteSets() async {
        let profile = makeProfile()
        let exercise = makeExercise()
        let completeSet = makeSet(weightKg: 100, reps: 5, isComplete: true, exercise: exercise)
        let incompleteSet = makeSet(weightKg: 200, reps: 5, isComplete: false, exercise: exercise)
        let session = makeSession(daysAgo: 1, status: .complete)
        session.sets.append(completeSet)
        session.sets.append(incompleteSet)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        // Only the complete set contributes.
        XCTAssertEqual(vm.state.exerciseSeries[0].dataPoints.count, 1)
        let expectedOneRM = 100.0 * (1.0 + 5.0 / 30.0)
        XCTAssertEqual(vm.state.exerciseSeries[0].dataPoints[0].value, expectedOneRM, accuracy: 0.001)
    }

    func test_loadProgress_exerciseSeriesExcludesSetsWithoutExercise() async {
        let profile = makeProfile()
        // Set with no exercise assigned
        let orphanSet = makeSet(weightKg: 100, reps: 5, isComplete: true, exercise: nil)
        let session = makeSession(daysAgo: 1, status: .complete)
        session.sets.append(orphanSet)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.state.exerciseSeries.isEmpty)
    }

    func test_loadProgress_exerciseSeriesExcludesZeroRepSets() async {
        let profile = makeProfile()
        let exercise = makeExercise()
        let zeroRepSet = makeSet(weightKg: 100, reps: 0, isComplete: true, exercise: exercise)
        let session = makeSession(daysAgo: 1, status: .complete)
        session.sets.append(zeroRepSet)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.state.exerciseSeries.isEmpty)
    }

    func test_loadProgress_exerciseSeries_fromIncompleteSession_isExcluded() async {
        let profile = makeProfile()
        let exercise = makeExercise()
        let set = makeSet(weightKg: 100, reps: 5, exercise: exercise)
        let session = makeSession(daysAgo: 1, status: .active)
        session.sets.append(set)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        // Active/paused/abandoned sessions should not contribute to 1RM series.
        XCTAssertTrue(vm.state.exerciseSeries.isEmpty)
    }

    func test_loadProgress_exerciseSeriesSortedByName() async {
        let profile = makeProfile()
        let squatExercise = makeExercise(id: "squat", name: "Squat")
        let benchExercise = makeExercise(id: "bench_press", name: "Bench Press")

        let set1 = makeSet(weightKg: 100, reps: 5, exercise: squatExercise)
        let set2 = makeSet(weightKg: 80, reps: 5, exercise: benchExercise)
        let session = makeSession(daysAgo: 1, status: .complete)
        session.sets.append(set1)
        session.sets.append(set2)
        mockWorkout.workoutSessions = [session]

        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.exerciseSeries.count, 2)
        XCTAssertEqual(vm.state.exerciseSeries[0].exerciseName, "Bench Press")
        XCTAssertEqual(vm.state.exerciseSeries[1].exerciseName, "Squat")
    }

    // MARK: - Time-range filtering

    func test_loadProgress_timeRangeWeek_excludesOldSessions() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 3, totalVolumeKg: 1000, status: .complete),    // within 1W
            makeSession(daysAgo: 10, totalVolumeKg: 2000, status: .complete)   // outside 1W
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .week

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 1)
        XCTAssertEqual(vm.state.volumePoints[0].value, 1000, accuracy: 0.001)
    }

    func test_loadProgress_timeRangeMonth_excludesOldSessions() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 20, totalVolumeKg: 1500, status: .complete),   // within 1M
            makeSession(daysAgo: 40, totalVolumeKg: 3000, status: .complete)    // outside 1M
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .month

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 1)
        XCTAssertEqual(vm.state.volumePoints[0].value, 1500, accuracy: 0.001)
    }

    func test_loadProgress_timeRangeAll_includesAllSessions() async {
        let profile = makeProfile()
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 3, totalVolumeKg: 1000, status: .complete),
            makeSession(daysAgo: 90, totalVolumeKg: 2000, status: .complete),
            makeSession(daysAgo: 365, totalVolumeKg: 500, status: .complete)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.state.volumePoints.count, 3)
    }

    // MARK: - Loading state

    func test_isLoadingFalseAfterLoadProgress() async {
        let profile = makeProfile()
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Error handling

    func test_loadProgress_progressRepoError_setsErrorMessage() async {
        let profile = makeProfile()
        mockProgress.shouldThrow = true
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_loadProgress_workoutRepoError_setsErrorMessage() async {
        let profile = makeProfile()
        mockWorkout.shouldThrow = true
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_loadProgress_progressRepoError_stillLoadsVolumeData() async {
        let profile = makeProfile()
        mockProgress.shouldThrow = true
        mockWorkout.workoutSessions = [
            makeSession(daysAgo: 2, totalVolumeKg: 1200, status: .complete)
        ]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        // Volume data loaded despite progress repo failure.
        XCTAssertEqual(vm.state.volumePoints.count, 1)
    }

    func test_loadProgress_workoutRepoError_stillLoadsBodyWeightData() async {
        let profile = makeProfile()
        mockWorkout.shouldThrow = true
        mockProgress.bodyMetrics = [makeBodyMetric(type: .weight, value: 75.0, daysAgo: 3)]
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)

        // Body weight data loaded despite workout repo failure.
        XCTAssertEqual(vm.state.bodyWeightPoints.count, 1)
    }

    func test_loadProgress_clearsErrorOnSuccess() async {
        let profile = makeProfile()
        mockProgress.shouldThrow = true
        let vm = makeViewModel()
        vm.selectedTimeRange = .all

        await vm.loadProgress(for: profile)
        XCTAssertNotNil(vm.errorMessage)

        mockProgress.shouldThrow = false
        await vm.loadProgress(for: profile)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - ProgressDataPoint

    func test_progressDataPoint_hasUniqueIDs() {
        let p1 = ProgressDataPoint(date: .now, value: 100)
        let p2 = ProgressDataPoint(date: .now, value: 100)
        XCTAssertNotEqual(p1.id, p2.id)
    }

    // MARK: - ProgressState

    func test_progressState_defaultValues() {
        let state = ProgressState()
        XCTAssertTrue(state.bodyWeightPoints.isEmpty)
        XCTAssertTrue(state.volumePoints.isEmpty)
        XCTAssertTrue(state.exerciseSeries.isEmpty)
    }
}
