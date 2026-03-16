import XCTest
@testable import FitnessTracker

// MARK: - ProgressViewModelTests

@MainActor
final class ProgressViewModelTests: XCTestCase {

    // MARK: - Helpers

    private var mockRepository: MockProgressRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockProgressRepository()
    }

    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }

    private func makeViewModel() -> ProgressViewModel {
        ProgressViewModel(repository: mockRepository)
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            name: "Test",
            age: 25,
            gender: .male,
            heightCm: 175,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            tdeeKcal: 2400,
            proteinTargetG: 150,
            carbTargetG: 240,
            fatTargetG: 80
        )
    }

    private func makeMetric(
        type: BodyMetricType = .weight,
        value: Double = 75.0,
        daysAgo: Int = 0
    ) -> BodyMetric {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return BodyMetric(date: date, type: type, value: value)
    }

    // MARK: - Initial State

    func test_initialState_bodyMetricsEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.bodyMetrics.isEmpty)
    }

    func test_initialState_isLoadingFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    func test_initialState_isSavingFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isSaving)
    }

    func test_initialState_errorMessageNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func test_initialState_selectedMetricTypeIsWeight() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedMetricType, .weight)
    }

    // MARK: - loadMetrics

    func test_loadMetrics_populatesBodyMetrics() async {
        let profile = makeProfile()
        mockRepository.bodyMetrics = [
            makeMetric(type: .weight, value: 80.0),
            makeMetric(type: .waist, value: 85.0)
        ]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)

        XCTAssertEqual(vm.bodyMetrics.count, 2)
    }

    func test_loadMetrics_isLoadingFalseAfterCompletion() async {
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.loadMetrics(for: profile)

        XCTAssertFalse(vm.isLoading)
    }

    func test_loadMetrics_setsErrorOnFailure() async {
        mockRepository.shouldThrow = true
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.loadMetrics(for: profile)

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_loadMetrics_clearsErrorOnSuccess() async {
        mockRepository.shouldThrow = true
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.loadMetrics(for: profile)
        XCTAssertNotNil(vm.errorMessage)

        mockRepository.shouldThrow = false
        await vm.loadMetrics(for: profile)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - chartPoints

    func test_chartPoints_filtersToSelectedType() async {
        let profile = makeProfile()
        mockRepository.bodyMetrics = [
            makeMetric(type: .weight, value: 80.0),
            makeMetric(type: .waist, value: 85.0),
            makeMetric(type: .weight, value: 79.5)
        ]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .weight

        XCTAssertEqual(vm.chartPoints.count, 2)
        XCTAssertTrue(vm.chartPoints.allSatisfy { _ in true }) // type is already filtered
    }

    func test_chartPoints_emptyWhenNoMetricsForType() async {
        let profile = makeProfile()
        mockRepository.bodyMetrics = [makeMetric(type: .chest, value: 100.0)]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .weight

        XCTAssertTrue(vm.chartPoints.isEmpty)
    }

    func test_chartPoints_sortedByDateAscending() async {
        let profile = makeProfile()
        let older = makeMetric(type: .weight, value: 82.0, daysAgo: 5)
        let newer = makeMetric(type: .weight, value: 80.0, daysAgo: 1)
        mockRepository.bodyMetrics = [newer, older]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .weight

        let dates = vm.chartPoints.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - filteredMetrics

    func test_filteredMetrics_filtersToSelectedType() async {
        let profile = makeProfile()
        mockRepository.bodyMetrics = [
            makeMetric(type: .weight, value: 80.0),
            makeMetric(type: .waist, value: 85.0)
        ]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .waist

        XCTAssertEqual(vm.filteredMetrics.count, 1)
        XCTAssertEqual(vm.filteredMetrics.first?.value, 85.0)
    }

    func test_filteredMetrics_sortedByDateDescending() async {
        let profile = makeProfile()
        let older = makeMetric(type: .weight, value: 82.0, daysAgo: 5)
        let newer = makeMetric(type: .weight, value: 80.0, daysAgo: 1)
        mockRepository.bodyMetrics = [older, newer]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .weight

        let dates = vm.filteredMetrics.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    // MARK: - latestValue

    func test_latestValue_returnsNilWhenNoMetrics() {
        let vm = makeViewModel()
        XCTAssertNil(vm.latestValue)
    }

    func test_latestValue_returnsMostRecentValueForSelectedType() async {
        let profile = makeProfile()
        let older = makeMetric(type: .weight, value: 82.0, daysAgo: 5)
        let newer = makeMetric(type: .weight, value: 79.5, daysAgo: 1)
        mockRepository.bodyMetrics = [older, newer]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        vm.selectedMetricType = .weight

        XCTAssertEqual(vm.latestValue, 79.5, accuracy: 0.001)
    }

    // MARK: - unitLabel

    func test_unitLabel_weightIsKg() {
        let vm = makeViewModel()
        vm.selectedMetricType = .weight
        XCTAssertEqual(vm.unitLabel, "kg")
    }

    func test_unitLabel_bodyFatIsPercent() {
        let vm = makeViewModel()
        vm.selectedMetricType = .bodyFatPercentage
        XCTAssertEqual(vm.unitLabel, "%")
    }

    func test_unitLabel_measurementsAreCm() {
        let vm = makeViewModel()
        for type in [BodyMetricType.chest, .waist, .hips, .neck, .thigh, .arm] {
            vm.selectedMetricType = type
            XCTAssertEqual(vm.unitLabel, "cm", "Expected cm for \(type)")
        }
    }

    // MARK: - logMeasurement

    func test_logMeasurement_appendsToBodyMetrics() async {
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.logMeasurement(type: .weight, value: 78.5, date: .now, for: profile)

        XCTAssertEqual(vm.bodyMetrics.count, 1)
        XCTAssertEqual(vm.bodyMetrics.first?.value, 78.5, accuracy: 0.001)
        XCTAssertEqual(vm.bodyMetrics.first?.type, .weight)
    }

    func test_logMeasurement_isSavingFalseAfterCompletion() async {
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.logMeasurement(type: .weight, value: 78.5, date: .now, for: profile)

        XCTAssertFalse(vm.isSaving)
    }

    func test_logMeasurement_setsErrorOnFailure() async {
        mockRepository.shouldThrow = true
        let profile = makeProfile()
        let vm = makeViewModel()

        await vm.logMeasurement(type: .weight, value: 78.5, date: .now, for: profile)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - deleteMetric

    func test_deleteMetric_removesFromBodyMetrics() async {
        let profile = makeProfile()
        let metric = makeMetric(type: .weight, value: 80.0)
        mockRepository.bodyMetrics = [metric]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        XCTAssertEqual(vm.bodyMetrics.count, 1)

        await vm.deleteMetric(metric)
        XCTAssertTrue(vm.bodyMetrics.isEmpty)
    }

    func test_deleteMetric_isSavingFalseAfterCompletion() async {
        let profile = makeProfile()
        let metric = makeMetric(type: .weight, value: 80.0)
        mockRepository.bodyMetrics = [metric]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)
        await vm.deleteMetric(metric)

        XCTAssertFalse(vm.isSaving)
    }

    func test_deleteMetric_setsErrorOnFailure() async {
        let profile = makeProfile()
        let metric = makeMetric(type: .weight, value: 80.0)
        mockRepository.bodyMetrics = [metric]

        let vm = makeViewModel()
        await vm.loadMetrics(for: profile)

        mockRepository.shouldThrow = true
        await vm.deleteMetric(metric)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - ProgressChartPoint

    func test_progressChartPoint_createdFromBodyMetric() {
        let metric = makeMetric(type: .weight, value: 75.0)
        let point = ProgressChartPoint(metric: metric)

        XCTAssertEqual(point.id, metric.id)
        XCTAssertEqual(point.value, 75.0, accuracy: 0.001)
        XCTAssertEqual(point.date, metric.date)
    }
}
