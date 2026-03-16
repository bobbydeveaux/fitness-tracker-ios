import XCTest
@testable import FitnessTracker

// MARK: - MockWorkoutRepository

/// In-memory mock for `WorkoutRepository` used in `WorkoutPlanViewModelTests`.
final class MockWorkoutRepository: WorkoutRepository, @unchecked Sendable {

    // MARK: - Storage

    var exercises: [Exercise] = []
    var plans: [WorkoutPlan] = []
    var sessions: [WorkoutSession] = []

    // MARK: - Error Injection

    var shouldThrow: Bool = false

    private func maybeThrow() throws {
        if shouldThrow { throw MockWorkoutError.forced }
    }

    // MARK: - Exercise Library

    func fetchExercises() async throws -> [Exercise] {
        try maybeThrow()
        return exercises.sorted { $0.name < $1.name }
    }

    func fetchExercise(byID id: UUID) async throws -> Exercise? {
        try maybeThrow()
        return nil
    }

    func saveExercise(_ exercise: Exercise) async throws {
        try maybeThrow()
        if !exercises.contains(where: { $0.id == exercise.id }) {
            exercises.append(exercise)
        }
    }

    // MARK: - WorkoutPlan

    func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        try maybeThrow()
        return plans.sorted { $0.generatedAt > $1.generatedAt }
    }

    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? {
        try maybeThrow()
        return plans.first { $0.isActive }
    }

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        try maybeThrow()
        if !plans.contains(where: { $0.id == plan.id }) {
            plans.append(plan)
        }
    }

    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {
        try maybeThrow()
        plans.removeAll { $0.id == plan.id }
    }

    // MARK: - WorkoutSession

    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        try maybeThrow()
        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        try maybeThrow()
        return sessions.filter { $0.startedAt >= startDate && $0.startedAt <= endDate }
    }

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        try maybeThrow()
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.append(session)
        }
    }

    func deleteWorkoutSession(_ session: WorkoutSession) async throws {
        try maybeThrow()
        sessions.removeAll { $0.id == session.id }
    }

    // MARK: - LoggedSet

    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {
        try maybeThrow()
        session.sets.append(set)
        set.session = session
    }

    // MARK: - Errors

    enum MockWorkoutError: Error {
        case forced
    }
}

// MARK: - WorkoutPlanViewModelTests

@MainActor
final class WorkoutPlanViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(
        repository: MockWorkoutRepository = MockWorkoutRepository()
    ) -> WorkoutPlanViewModel {
        WorkoutPlanViewModel(repository: repository)
    }

    private func makePlan(
        splitType: SplitType = .pushPullLegs,
        daysPerWeek: Int = 6,
        isActive: Bool = true
    ) -> WorkoutPlan {
        WorkoutPlan(splitType: splitType, daysPerWeek: daysPerWeek, isActive: isActive)
    }

    // MARK: - Initial State

    func testInitialActivePlan_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.activePlan)
    }

    func testInitialIsLoading_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    func testInitialErrorMessage_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func testInitialSortedDays_isEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.sortedDays.isEmpty)
    }

    // MARK: - loadActivePlan – success

    func testLoadActivePlan_noActivePlan_activePlanRemainsNil() async {
        let repo = MockWorkoutRepository()
        let vm = makeViewModel(repository: repo)

        await vm.loadActivePlan()

        XCTAssertNil(vm.activePlan)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadActivePlan_withActivePlan_setsActivePlan() async {
        let repo = MockWorkoutRepository()
        let plan = makePlan()
        repo.plans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertNotNil(vm.activePlan)
        XCTAssertEqual(vm.activePlan?.id, plan.id)
    }

    func testLoadActivePlan_inactivePlanIgnored() async {
        let repo = MockWorkoutRepository()
        let inactive = makePlan(isActive: false)
        repo.plans.append(inactive)

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertNil(vm.activePlan)
    }

    func testLoadActivePlan_isLoadingFalseAfterCompletion() async {
        let repo = MockWorkoutRepository()
        let vm = makeViewModel(repository: repo)

        await vm.loadActivePlan()

        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - loadActivePlan – error

    func testLoadActivePlan_onError_setsErrorMessage() async {
        let repo = MockWorkoutRepository()
        repo.shouldThrow = true

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.activePlan)
    }

    func testLoadActivePlan_clearsErrorOnSuccess() async {
        let repo = MockWorkoutRepository()
        repo.shouldThrow = true

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()
        XCTAssertNotNil(vm.errorMessage)

        repo.shouldThrow = false
        await vm.loadActivePlan()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - sortedDays

    func testSortedDays_sortedByWeekdayIndex() async {
        let repo = MockWorkoutRepository()
        let plan = makePlan()

        let day1 = WorkoutDay(dayLabel: "Pull A", weekdayIndex: 3, workoutPlan: plan)
        let day2 = WorkoutDay(dayLabel: "Push A", weekdayIndex: 2, workoutPlan: plan)
        let day3 = WorkoutDay(dayLabel: "Legs A", weekdayIndex: 4, workoutPlan: plan)
        plan.days = [day1, day2, day3]
        repo.plans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        let indices = vm.sortedDays.map(\.weekdayIndex)
        XCTAssertEqual(indices, [2, 3, 4])
    }

    func testSortedDays_emptyWhenNoPlan() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.sortedDays.isEmpty)
    }

    // MARK: - splitLabel

    func testSplitLabel_pushPullLegs() async {
        let repo = MockWorkoutRepository()
        repo.plans.append(makePlan(splitType: .pushPullLegs))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Push / Pull / Legs")
    }

    func testSplitLabel_fullBody() async {
        let repo = MockWorkoutRepository()
        repo.plans.append(makePlan(splitType: .fullBody))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Full Body")
    }

    func testSplitLabel_upperLower() async {
        let repo = MockWorkoutRepository()
        repo.plans.append(makePlan(splitType: .upperLower))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Upper / Lower")
    }

    func testSplitLabel_emptyWhenNoPlan() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.splitLabel, "")
    }
}
