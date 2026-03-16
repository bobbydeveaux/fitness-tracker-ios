import XCTest
@testable import FitnessTracker

// MARK: - MockHealthKitService

/// Test double for `HealthKitServiceProtocol`.
///
/// Records which methods were called and with what arguments, and allows
/// callers to pre-configure `stubbedDailyStats` to drive assertion-based tests.
/// Because it conforms to `HealthKitServiceProtocol`, it can be injected into
/// any component that depends on the protocol without touching HealthKit or
/// requiring a device entitlement.
private final class MockHealthKitService: HealthKitServiceProtocol {

    // MARK: - Recorded calls

    private(set) var didRequestAuthorization = false
    private(set) var savedWorkoutDurations: [TimeInterval] = []

    // MARK: - Stubbed responses

    var stubbedDailyStats = DailyStats()

    // MARK: - HealthKitServiceProtocol

    func requestAuthorisationIfNeeded() async {
        didRequestAuthorization = true
    }

    func readDailyStats() async -> DailyStats {
        stubbedDailyStats
    }

    func saveWorkout(duration: TimeInterval) async {
        savedWorkoutDurations.append(duration)
    }
}

// MARK: - HealthKitServiceTests

final class HealthKitServiceTests: XCTestCase {

    // MARK: - Singleton contract

    /// `HealthKitService.shared` must always return the identical object instance.
    func test_shared_returnsSameInstance() {
        let instanceA = HealthKitService.shared
        let instanceB = HealthKitService.shared
        XCTAssertTrue(instanceA === instanceB,
                      "HealthKitService.shared must always return the same singleton instance")
    }

    // MARK: - DailyStats defaults

    func test_dailyStats_defaultValuesAreZero() {
        let stats = DailyStats()
        XCTAssertEqual(stats.stepCount, 0)
        XCTAssertEqual(stats.activeEnergyBurned, 0)
        XCTAssertEqual(stats.heartRate, 0)
    }

    func test_dailyStats_memberInitialisationPreservesValues() {
        let stats = DailyStats(stepCount: 8000, activeEnergyBurned: 450, heartRate: 68)
        XCTAssertEqual(stats.stepCount, 8000)
        XCTAssertEqual(stats.activeEnergyBurned, 450)
        XCTAssertEqual(stats.heartRate, 68)
    }
}

// MARK: - DashboardViewModelTests

@MainActor
final class DashboardViewModelTests: XCTestCase {

    // MARK: - Properties

    private var mock: MockHealthKitService!
    private var sut: DashboardViewModel!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mock = MockHealthKitService()
        sut = DashboardViewModel(healthKitService: mock)
    }

    override func tearDown() {
        sut = nil
        mock = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialDailyStats_areZero() {
        XCTAssertEqual(sut.dailyStats.stepCount, 0)
        XCTAssertEqual(sut.dailyStats.activeEnergyBurned, 0)
        XCTAssertEqual(sut.dailyStats.heartRate, 0)
    }

    func test_initialIsLoadingStats_isFalse() {
        XCTAssertFalse(sut.isLoadingStats)
    }

    // MARK: - loadDailyStats

    func test_loadDailyStats_updatesStepCount() async {
        mock.stubbedDailyStats = DailyStats(stepCount: 7_500, activeEnergyBurned: 0, heartRate: 0)
        await sut.loadDailyStats()
        XCTAssertEqual(sut.dailyStats.stepCount, 7_500)
    }

    func test_loadDailyStats_updatesActiveEnergy() async {
        mock.stubbedDailyStats = DailyStats(stepCount: 0, activeEnergyBurned: 320, heartRate: 0)
        await sut.loadDailyStats()
        XCTAssertEqual(sut.dailyStats.activeEnergyBurned, 320)
    }

    func test_loadDailyStats_updatesHeartRate() async {
        mock.stubbedDailyStats = DailyStats(stepCount: 0, activeEnergyBurned: 0, heartRate: 74)
        await sut.loadDailyStats()
        XCTAssertEqual(sut.dailyStats.heartRate, 74)
    }

    func test_loadDailyStats_updatesAllStatsFromMock() async {
        mock.stubbedDailyStats = DailyStats(stepCount: 10_000, activeEnergyBurned: 500, heartRate: 65)
        await sut.loadDailyStats()
        XCTAssertEqual(sut.dailyStats.stepCount, 10_000)
        XCTAssertEqual(sut.dailyStats.activeEnergyBurned, 500)
        XCTAssertEqual(sut.dailyStats.heartRate, 65)
    }

    func test_loadDailyStats_isLoadingStats_isFalseAfterCompletion() async {
        await sut.loadDailyStats()
        XCTAssertFalse(sut.isLoadingStats,
                       "isLoadingStats must be false after loadDailyStats() resolves")
    }

    // MARK: - Mock protocol conformance

    func test_mock_requestAuthorization_recordsCall() async {
        XCTAssertFalse(mock.didRequestAuthorization)
        await mock.requestAuthorisationIfNeeded()
        XCTAssertTrue(mock.didRequestAuthorization)
    }

    func test_mock_saveWorkout_recordsDuration() async {
        await mock.saveWorkout(duration: 1_800)
        XCTAssertEqual(mock.savedWorkoutDurations, [1_800])
    }

    func test_mock_saveWorkout_recordsMultipleCalls() async {
        await mock.saveWorkout(duration: 600)
        await mock.saveWorkout(duration: 3_600)
        XCTAssertEqual(mock.savedWorkoutDurations, [600, 3_600])
    }
}
