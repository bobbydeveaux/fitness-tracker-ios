import XCTest
@testable import FitnessTracker

// MARK: - MockHealthKitServiceForDashboard

/// Test double for `HealthKitServiceProtocol` used in `DashboardViewModelAggregationTests`.
final class MockHealthKitServiceForDashboard: HealthKitServiceProtocol {
    var stubbedDailyStats = DailyStats()

    func requestAuthorisationIfNeeded() async {}

    func readDailyStats() async -> DailyStats {
        stubbedDailyStats
    }

    func saveWorkout(duration: TimeInterval) async {}
}

// MARK: - MockProgressRepository

/// In-memory mock for `ProgressRepository` used in `DashboardViewModelTests`.
final class MockProgressRepository: ProgressRepository, @unchecked Sendable {

    // MARK: - Storage

    var bodyMetrics: [BodyMetric] = []
    var streak: Streak?

    // MARK: - Error Injection

    var shouldThrow: Bool = false

    private func maybeThrow() throws {
        if shouldThrow { throw MockProgressError.forced }
    }

    // MARK: - BodyMetric

    func fetchBodyMetrics(for userProfile: UserProfile) async throws -> [BodyMetric] {
        try maybeThrow()
        return bodyMetrics
    }

    func fetchBodyMetrics(type: String, from startDate: Date, to endDate: Date) async throws -> [BodyMetric] {
        try maybeThrow()
        return bodyMetrics.filter { $0.type.rawValue == type && $0.date >= startDate && $0.date <= endDate }
    }

    func fetchLatestBodyMetric(type: String, for userProfile: UserProfile) async throws -> BodyMetric? {
        try maybeThrow()
        return bodyMetrics.filter { $0.type.rawValue == type }.sorted { $0.date > $1.date }.first
    }

    func saveBodyMetric(_ metric: BodyMetric) async throws {
        try maybeThrow()
        if !bodyMetrics.contains(where: { $0.id == metric.id }) {
            bodyMetrics.append(metric)
        }
    }

    func deleteBodyMetric(_ metric: BodyMetric) async throws {
        try maybeThrow()
        bodyMetrics.removeAll { $0.id == metric.id }
    }

    // MARK: - Streak

    func fetchStreak(for userProfile: UserProfile) async throws -> Streak? {
        try maybeThrow()
        return streak
    }

    func saveStreak(_ streak: Streak) async throws {
        try maybeThrow()
        self.streak = streak
    }

    // MARK: - Errors

    enum MockProgressError: Error {
        case forced
    }
}

// MARK: - DashboardViewModelAggregationTests

@MainActor
final class DashboardViewModelAggregationTests: XCTestCase {

    // MARK: - Helpers

    private var mockHealthKit: MockHealthKitServiceForDashboard!
    private var mockNutrition: MockNutritionRepository!
    private var mockProgress: MockProgressRepository!

    override func setUp() {
        super.setUp()
        mockHealthKit = MockHealthKitServiceForDashboard()
        mockNutrition = MockNutritionRepository()
        mockProgress = MockProgressRepository()
    }

    override func tearDown() {
        mockHealthKit = nil
        mockNutrition = nil
        mockProgress = nil
        super.tearDown()
    }

    private func makeViewModel() -> DashboardViewModel {
        DashboardViewModel(
            healthKitService: mockHealthKit,
            nutritionRepository: mockNutrition,
            progressRepository: mockProgress
        )
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
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
    }

    private func makeMealLog(kcal: Double, proteinG: Double, carbG: Double, fatG: Double) -> MealLog {
        let log = MealLog(date: Date(), mealType: .breakfast)
        let entry = MealEntry(
            servingGrams: 100,
            kcal: kcal,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG
        )
        log.entries.append(entry)
        return log
    }

    // MARK: - DashboardState Initial State

    func test_initialState_allZeros() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.state.dailyStats.stepCount, 0)
        XCTAssertEqual(vm.state.dailyStats.activeEnergyBurned, 0)
        XCTAssertEqual(vm.state.dailyStats.heartRate, 0)
        XCTAssertEqual(vm.state.todayKcal, 0)
        XCTAssertEqual(vm.state.todayProteinG, 0)
        XCTAssertEqual(vm.state.todayCarbG, 0)
        XCTAssertEqual(vm.state.todayFatG, 0)
        XCTAssertEqual(vm.state.currentStreak, 0)
        XCTAssertEqual(vm.state.longestStreak, 0)
    }

    func test_initialIsLoading_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    func test_initialErrorMessage_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - DashboardState Struct

    func test_dashboardState_defaultValues() {
        let state = DashboardState()
        XCTAssertEqual(state.dailyStats.stepCount, 0)
        XCTAssertEqual(state.todayKcal, 0)
        XCTAssertEqual(state.todayProteinG, 0)
        XCTAssertEqual(state.todayCarbG, 0)
        XCTAssertEqual(state.todayFatG, 0)
        XCTAssertEqual(state.currentStreak, 0)
        XCTAssertEqual(state.longestStreak, 0)
    }

    func test_dashboardState_memberInitialisationPreservesValues() {
        let stats = DailyStats(stepCount: 8000, activeEnergyBurned: 400, heartRate: 72)
        let state = DashboardState(
            dailyStats: stats,
            todayKcal: 1800,
            todayProteinG: 150,
            todayCarbG: 200,
            todayFatG: 60,
            currentStreak: 7,
            longestStreak: 14
        )
        XCTAssertEqual(state.dailyStats.stepCount, 8000)
        XCTAssertEqual(state.todayKcal, 1800)
        XCTAssertEqual(state.todayProteinG, 150)
        XCTAssertEqual(state.todayCarbG, 200)
        XCTAssertEqual(state.todayFatG, 60)
        XCTAssertEqual(state.currentStreak, 7)
        XCTAssertEqual(state.longestStreak, 14)
    }

    // MARK: - loadDashboard – HealthKit aggregation

    func test_loadDashboard_aggregatesHealthKitStats() async {
        mockHealthKit.stubbedDailyStats = DailyStats(stepCount: 9_000, activeEnergyBurned: 500, heartRate: 68)
        let vm = makeViewModel()

        await vm.loadDashboard()

        XCTAssertEqual(vm.state.dailyStats.stepCount, 9_000)
        XCTAssertEqual(vm.state.dailyStats.activeEnergyBurned, 500)
        XCTAssertEqual(vm.state.dailyStats.heartRate, 68)
    }

    // MARK: - loadDashboard – Nutrition aggregation

    func test_loadDashboard_aggregatesTodayMacros() async {
        let log = makeMealLog(kcal: 400, proteinG: 30, carbG: 50, fatG: 10)
        mockNutrition.mealLogs.append(log)

        let vm = makeViewModel()
        await vm.loadDashboard()

        XCTAssertEqual(vm.state.todayKcal, 400, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayProteinG, 30, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayCarbG, 50, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayFatG, 10, accuracy: 0.01)
    }

    func test_loadDashboard_sumsMultipleMealLogs() async {
        let log1 = makeMealLog(kcal: 300, proteinG: 25, carbG: 40, fatG: 8)
        let log2 = makeMealLog(kcal: 500, proteinG: 40, carbG: 60, fatG: 15)
        mockNutrition.mealLogs.append(contentsOf: [log1, log2])

        let vm = makeViewModel()
        await vm.loadDashboard()

        XCTAssertEqual(vm.state.todayKcal, 800, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayProteinG, 65, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayCarbG, 100, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayFatG, 23, accuracy: 0.01)
    }

    func test_loadDashboard_macrosZeroWhenNoLogs() async {
        let vm = makeViewModel()
        await vm.loadDashboard()

        XCTAssertEqual(vm.state.todayKcal, 0)
        XCTAssertEqual(vm.state.todayProteinG, 0)
        XCTAssertEqual(vm.state.todayCarbG, 0)
        XCTAssertEqual(vm.state.todayFatG, 0)
    }

    func test_loadDashboard_macrosZeroWhenNoNutritionRepository() async {
        let vm = DashboardViewModel(
            healthKitService: mockHealthKit,
            nutritionRepository: nil,
            progressRepository: nil
        )
        await vm.loadDashboard()

        XCTAssertEqual(vm.state.todayKcal, 0)
        XCTAssertEqual(vm.state.todayProteinG, 0)
    }

    // MARK: - loadDashboard – Streak aggregation

    func test_loadDashboard_aggregatesStreakCounts() async {
        let profile = makeProfile()
        let streak = Streak(currentCount: 5, longestCount: 12, userProfile: profile)
        mockProgress.streak = streak

        let vm = makeViewModel()
        await vm.loadDashboard(for: profile)

        XCTAssertEqual(vm.state.currentStreak, 5)
        XCTAssertEqual(vm.state.longestStreak, 12)
    }

    func test_loadDashboard_streakZeroWhenNoStreak() async {
        let profile = makeProfile()
        mockProgress.streak = nil

        let vm = makeViewModel()
        await vm.loadDashboard(for: profile)

        XCTAssertEqual(vm.state.currentStreak, 0)
        XCTAssertEqual(vm.state.longestStreak, 0)
    }

    func test_loadDashboard_streakZeroWhenNoProfile() async {
        mockProgress.streak = Streak(currentCount: 10, longestCount: 20)
        let vm = makeViewModel()

        await vm.loadDashboard(for: nil)

        XCTAssertEqual(vm.state.currentStreak, 0)
        XCTAssertEqual(vm.state.longestStreak, 0)
    }

    func test_loadDashboard_streakZeroWhenNoProgressRepository() async {
        let profile = makeProfile()
        let vm = DashboardViewModel(
            healthKitService: mockHealthKit,
            nutritionRepository: nil,
            progressRepository: nil
        )

        await vm.loadDashboard(for: profile)

        XCTAssertEqual(vm.state.currentStreak, 0)
        XCTAssertEqual(vm.state.longestStreak, 0)
    }

    // MARK: - loadDashboard – Full aggregation

    func test_loadDashboard_aggregatesAllSourcesTogether() async {
        mockHealthKit.stubbedDailyStats = DailyStats(stepCount: 10_000, activeEnergyBurned: 600, heartRate: 65)

        let log = makeMealLog(kcal: 1200, proteinG: 100, carbG: 150, fatG: 40)
        mockNutrition.mealLogs.append(log)

        let profile = makeProfile()
        let streak = Streak(currentCount: 3, longestCount: 21, userProfile: profile)
        mockProgress.streak = streak

        let vm = makeViewModel()
        await vm.loadDashboard(for: profile)

        XCTAssertEqual(vm.state.dailyStats.stepCount, 10_000)
        XCTAssertEqual(vm.state.todayKcal, 1200, accuracy: 0.01)
        XCTAssertEqual(vm.state.todayProteinG, 100, accuracy: 0.01)
        XCTAssertEqual(vm.state.currentStreak, 3)
        XCTAssertEqual(vm.state.longestStreak, 21)
    }

    // MARK: - loadDashboard – Loading flag

    func test_loadDashboard_isLoadingFalseAfterCompletion() async {
        let vm = makeViewModel()
        await vm.loadDashboard()
        XCTAssertFalse(vm.isLoading)
    }

    func test_isLoadingStats_isFalseAfterLoadDashboard() async {
        let vm = makeViewModel()
        await vm.loadDashboard()
        XCTAssertFalse(vm.isLoadingStats)
    }

    // MARK: - loadDashboard – Error handling

    func test_loadDashboard_nutritionError_setsErrorMessage() async {
        mockNutrition.shouldThrow = true
        let vm = makeViewModel()

        await vm.loadDashboard()

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_loadDashboard_progressError_setsErrorMessage() async {
        mockProgress.shouldThrow = true
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.loadDashboard(for: profile)

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_loadDashboard_clearsErrorOnSuccess() async {
        mockNutrition.shouldThrow = true
        let vm = makeViewModel()

        await vm.loadDashboard()
        XCTAssertNotNil(vm.errorMessage)

        mockNutrition.shouldThrow = false
        await vm.loadDashboard()
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadDashboard_healthKitStillLoadedOnNutritionError() async {
        mockHealthKit.stubbedDailyStats = DailyStats(stepCount: 5_000, activeEnergyBurned: 0, heartRate: 0)
        mockNutrition.shouldThrow = true
        let vm = makeViewModel()

        await vm.loadDashboard()

        XCTAssertEqual(vm.state.dailyStats.stepCount, 5_000)
    }

    // MARK: - Convenience Accessors

    func test_dailyStats_mirrorsDashboardState() async {
        mockHealthKit.stubbedDailyStats = DailyStats(stepCount: 6_000, activeEnergyBurned: 0, heartRate: 0)
        let vm = makeViewModel()

        await vm.loadDashboard()

        XCTAssertEqual(vm.dailyStats.stepCount, vm.state.dailyStats.stepCount)
    }

    func test_isLoadingStats_mirrorsIsLoading() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.isLoadingStats, vm.isLoading)
    }

    // MARK: - loadDailyStats (lightweight refresh)

    func test_loadDailyStats_updatesOnlyHealthKitStats() async {
        let log = makeMealLog(kcal: 800, proteinG: 60, carbG: 80, fatG: 20)
        mockNutrition.mealLogs.append(log)

        let profile = makeProfile()
        let streak = Streak(currentCount: 4, longestCount: 10, userProfile: profile)
        mockProgress.streak = streak

        let vm = makeViewModel()

        // First do a full load
        await vm.loadDashboard(for: profile)
        let initialKcal = vm.state.todayKcal
        let initialStreak = vm.state.currentStreak

        // Now do a lightweight refresh
        mockHealthKit.stubbedDailyStats = DailyStats(stepCount: 12_000, activeEnergyBurned: 0, heartRate: 0)
        await vm.loadDailyStats()

        // HealthKit updated; nutrition and streak unchanged
        XCTAssertEqual(vm.state.dailyStats.stepCount, 12_000)
        XCTAssertEqual(vm.state.todayKcal, initialKcal)
        XCTAssertEqual(vm.state.currentStreak, initialStreak)
    }

    func test_loadDailyStats_isLoadingFalseAfterCompletion() async {
        let vm = makeViewModel()
        await vm.loadDailyStats()
        XCTAssertFalse(vm.isLoadingStats)
    }
}
