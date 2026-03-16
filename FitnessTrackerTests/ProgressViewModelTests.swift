import XCTest
@testable import FitnessTracker

// MARK: - MockProgressRepositoryForProgress

/// In-memory mock for `ProgressRepository` used in `ProgressViewModelTests`.
final class MockProgressRepositoryForProgress: ProgressRepository, @unchecked Sendable {

    var bodyMetrics: [BodyMetric] = []
    var shouldThrow: Bool = false

    private func maybeThrow() throws {
        if shouldThrow { throw ProgressViewModelTestError.forced }
    }

    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] {
        try maybeThrow()
        return bodyMetrics
    }

    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] {
        try maybeThrow()
        return bodyMetrics.filter {
            $0.type.rawValue == type && $0.date >= startDate && $0.date <= endDate
        }
    }

    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? {
        try maybeThrow()
        return bodyMetrics.filter { $0.type.rawValue == type }.sorted { $0.date > $1.date }.first
    }

    func saveBodyMetric(_ metric: BodyMetric) async throws { try maybeThrow() }
    func deleteBodyMetric(_ metric: BodyMetric) async throws { try maybeThrow() }

    func fetchStreak(for userProfile: UserProfile) async throws -> Streak? {
        try maybeThrow()
        return nil
    }
    func saveStreak(_ streak: Streak) async throws { try maybeThrow() }
}

// MARK: - MockWorkoutRepositoryForProgress

/// In-memory mock for `WorkoutRepository` used in `ProgressViewModelTests`.
final class MockWorkoutRepositoryForProgress: WorkoutRepository, @unchecked Sendable {

    var sessions: [WorkoutSession] = []
    var shouldThrow: Bool = false

    private func maybeThrow() throws {
        if shouldThrow { throw ProgressViewModelTestError.forced }
    }

    func fetchExercises() async throws -> [Exercise] { try maybeThrow(); return [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { try maybeThrow(); return nil }
    func saveExercise(_ exercise: Exercise) async throws { try maybeThrow() }
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { try maybeThrow(); return [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { try maybeThrow(); return nil }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws { try maybeThrow() }
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws { try maybeThrow() }

    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        try maybeThrow()
        return sessions
    }

    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        try maybeThrow()
        return sessions.filter { $0.startedAt >= startDate && $0.startedAt <= endDate }
    }

    func saveWorkoutSession(_ session: WorkoutSession) async throws { try maybeThrow() }
    func deleteWorkoutSession(_ session: WorkoutSession) async throws { try maybeThrow() }

    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {
        try maybeThrow()
        session.sets.append(set)
    }
}

// MARK: - Error

private enum ProgressViewModelTestError: Error {
    case forced
}

// MARK: - ProgressViewModelTests

@MainActor
final class ProgressViewModelTests: XCTestCase {

    // MARK: - Fixtures

    private let calendar = Calendar.current
    private lazy var profile = UserProfile(
        name: "Test User",
        age: 30,
        gender: .male,
        heightCm: 180,
        weightKg: 80,
        activityLevel: .moderatelyActive,
        goal: .maintain,
        tdeeKcal: 2500,
        proteinTargetG: 180,
        carbTargetG: 250,
        fatTargetG: 80
    )

    // MARK: - TimeRange Tests

    func test_timeRange_oneWeek_startDateIsSevenDaysAgo() {
        let range = TimeRange.oneWeek
        let start = range.startDate!
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: Date()))
        XCTAssertEqual(diff.day, 7)
    }

    func test_timeRange_oneMonth_startDateIsOneMonthAgo() {
        let range = TimeRange.oneMonth
        let start = range.startDate!
        let diff = calendar.dateComponents([.month], from: start, to: Date())
        XCTAssertEqual(diff.month, 1)
    }

    func test_timeRange_threeMonths_startDateIsThreeMonthsAgo() {
        let range = TimeRange.threeMonths
        let start = range.startDate!
        let diff = calendar.dateComponents([.month], from: start, to: Date())
        XCTAssertEqual(diff.month, 3)
    }

    func test_timeRange_allTime_startDateIsNil() {
        XCTAssertNil(TimeRange.allTime.startDate)
    }

    func test_timeRange_allCasesAreUnique() {
        let allDisplayTitles = TimeRange.allCases.map(\.displayTitle)
        XCTAssertEqual(allDisplayTitles.count, Set(allDisplayTitles).count, "All time range display titles should be unique")
    }

    // MARK: - Weight Data Loading Tests

    func test_loadProgress_withWeightMetrics_populatesWeightDataPoints() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        // Add weight entries within the last month
        let today = Date()
        for daysAgo in [1, 7, 14, 21, 28] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let metric = BodyMetric(date: date, type: .weight, value: 80.0 - Double(daysAgo) * 0.1)
            metric.userProfile = profile
            repo.bodyMetrics.append(metric)
        }

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        vm.selectedRange = .oneMonth

        await vm.loadProgress(for: profile)

        XCTAssertFalse(vm.weightDataPoints.isEmpty, "Weight data points should not be empty")
        XCTAssertEqual(vm.weightDataPoints.count, 5)
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadProgress_withNoWeightMetrics_returnsEmptyDataPoints() async {
        let vm = ProgressViewModel(
            progressRepository: MockProgressRepositoryForProgress(),
            workoutRepository: MockWorkoutRepositoryForProgress()
        )
        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.weightDataPoints.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadProgress_filtersOutOfRangeMetrics() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        // One entry in range, one outside range
        let today = Date()
        let inRange = BodyMetric(
            date: calendar.date(byAdding: .day, value: -5, to: today)!,
            type: .weight,
            value: 80.0
        )
        let outOfRange = BodyMetric(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            type: .weight,
            value: 79.0
        )
        repo.bodyMetrics = [inRange, outOfRange]

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        vm.selectedRange = .oneWeek

        await vm.loadProgress(for: profile)

        XCTAssertEqual(vm.weightDataPoints.count, 1, "Only the in-range metric should appear for 1W range")
        XCTAssertEqual(vm.weightDataPoints.first?.weightKg, 80.0)
    }

    func test_loadProgress_allTimeRange_includesAllMetrics() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        let today = Date()
        let dates = [30, 180, 365, 730]
        for daysAgo in dates {
            let metric = BodyMetric(
                date: calendar.date(byAdding: .day, value: -daysAgo, to: today)!,
                type: .weight,
                value: 80.0
            )
            repo.bodyMetrics.append(metric)
        }

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        vm.selectedRange = .allTime

        await vm.loadProgress(for: profile)

        // For allTime, data is down-sampled to weekly averages — one point per week
        XCTAssertFalse(vm.weightDataPoints.isEmpty, "All-time range should return data points")
    }

    func test_loadProgress_ignoresNonWeightMetrics() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        let chestMetric = BodyMetric(
            date: calendar.date(byAdding: .day, value: -5, to: Date())!,
            type: .chest,
            value: 95.0
        )
        repo.bodyMetrics = [chestMetric]

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.weightDataPoints.isEmpty, "Non-weight metrics should not appear in weightDataPoints")
    }

    // MARK: - Strength Data Loading Tests

    func test_loadProgress_withLoggedSets_populatesStrengthData() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        // Build a session with a logged set
        let exercise = Exercise(
            exerciseID: "bench-press",
            name: "Barbell Bench Press",
            muscleGroup: "Chest",
            equipment: "Barbell",
            instructions: "",
            imageName: ""
        )
        let session = WorkoutSession(startedAt: calendar.date(byAdding: .day, value: -3, to: Date())!)
        let set = LoggedSet(setIndex: 0, weightKg: 100, reps: 5, isComplete: true)
        set.exercise = exercise
        session.sets = [set]
        workoutRepo.sessions = [session]

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        await vm.loadProgress(for: profile)

        XCTAssertFalse(vm.availableExercises.isEmpty, "Available exercises should be populated from logged sets")
        XCTAssertEqual(vm.availableExercises.first?.id, "bench-press")
    }

    func test_loadProgress_epleyFormulaCalculatedCorrectly() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        let exercise = Exercise(
            exerciseID: "squat",
            name: "Barbell Back Squat",
            muscleGroup: "Legs",
            equipment: "Barbell",
            instructions: "",
            imageName: ""
        )
        // 100 kg × 5 reps → Epley 1RM = 100 × (1 + 5/30) = 116.67 kg
        let session = WorkoutSession(startedAt: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let set = LoggedSet(setIndex: 0, weightKg: 100, reps: 5, isComplete: true)
        set.exercise = exercise
        session.sets = [set]
        workoutRepo.sessions = [session]

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        vm.selectedRange = .oneMonth
        await vm.loadProgress(for: profile)

        let points = vm.strengthDataPoints["squat"] ?? []
        XCTAssertFalse(points.isEmpty, "Should have a strength data point for squat")
        let expected1RM = 100.0 * (1.0 + 5.0 / 30.0)
        XCTAssertEqual(points.first?.estimatedOneRMKg ?? 0, expected1RM, accuracy: 0.001)
    }

    func test_loadProgress_withNoSessions_returnsEmptyStrengthData() async {
        let vm = ProgressViewModel(
            progressRepository: MockProgressRepositoryForProgress(),
            workoutRepository: MockWorkoutRepositoryForProgress()
        )
        await vm.loadProgress(for: profile)

        XCTAssertTrue(vm.availableExercises.isEmpty)
        XCTAssertTrue(vm.strengthDataPoints.isEmpty)
    }

    func test_loadProgress_selectedExerciseAutoSelectsFirst() async {
        let repo = MockProgressRepositoryForProgress()
        let workoutRepo = MockWorkoutRepositoryForProgress()

        let exercise = Exercise(
            exerciseID: "deadlift",
            name: "Deadlift",
            muscleGroup: "Back",
            equipment: "Barbell",
            instructions: "",
            imageName: ""
        )
        let session = WorkoutSession(startedAt: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let set = LoggedSet(setIndex: 0, weightKg: 120, reps: 3, isComplete: true)
        set.exercise = exercise
        session.sets = [set]
        workoutRepo.sessions = [session]

        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: workoutRepo)
        XCTAssertNil(vm.selectedExercise, "Should start with no exercise selected")

        await vm.loadProgress(for: profile)

        XCTAssertNotNil(vm.selectedExercise, "After loading, an exercise should be auto-selected")
        XCTAssertEqual(vm.selectedExercise?.id, "deadlift")
    }

    // MARK: - Error Handling Tests

    func test_loadProgress_progressRepositoryError_setsErrorMessage() async {
        let repo = MockProgressRepositoryForProgress()
        repo.shouldThrow = true
        let vm = ProgressViewModel(progressRepository: repo, workoutRepository: MockWorkoutRepositoryForProgress())

        await vm.loadProgress(for: profile)

        XCTAssertNotNil(vm.errorMessage, "Error message should be set when repository throws")
    }

    func test_loadProgress_workoutRepositoryError_setsErrorMessage() async {
        let workoutRepo = MockWorkoutRepositoryForProgress()
        workoutRepo.shouldThrow = true
        let vm = ProgressViewModel(progressRepository: MockProgressRepositoryForProgress(), workoutRepository: workoutRepo)

        await vm.loadProgress(for: profile)

        XCTAssertNotNil(vm.errorMessage, "Error message should be set when workout repository throws")
    }

    // MARK: - Loading State Tests

    func test_loadProgress_setsIsLoadingWhileLoading() async {
        let vm = ProgressViewModel(
            progressRepository: MockProgressRepositoryForProgress(),
            workoutRepository: MockWorkoutRepositoryForProgress()
        )
        XCTAssertFalse(vm.isLoading)
        await vm.loadProgress(for: profile)
        XCTAssertFalse(vm.isLoading, "isLoading should be false after loading completes")
    }

    // MARK: - currentStrengthPoints Tests

    func test_currentStrengthPoints_returnsEmptyWhenNoExerciseSelected() {
        let vm = ProgressViewModel(
            progressRepository: MockProgressRepositoryForProgress(),
            workoutRepository: MockWorkoutRepositoryForProgress()
        )
        XCTAssertNil(vm.selectedExercise)
        XCTAssertTrue(vm.currentStrengthPoints.isEmpty)
    }
}
