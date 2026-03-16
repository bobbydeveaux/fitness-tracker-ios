import XCTest
@testable import FitnessTracker

// MARK: - MockWorkoutRepository

/// In-memory mock for `WorkoutRepository` used in tests.
final class MockWorkoutRepository: WorkoutRepository, @unchecked Sendable {

    // MARK: - Storage

    var exercises: [Exercise] = []
    var workoutPlans: [WorkoutPlan] = []
    var workoutSessions: [WorkoutSession] = []

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
        return nil  // unused in WorkoutPlanViewModel tests
    }

    func saveExercise(_ exercise: Exercise) async throws {
        try maybeThrow()
        if !exercises.contains(where: { $0.exerciseID == exercise.exerciseID }) {
            exercises.append(exercise)
        }
    }

    // MARK: - WorkoutPlan

    func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        try maybeThrow()
        return workoutPlans.sorted { $0.generatedAt > $1.generatedAt }
    }

    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? {
        try maybeThrow()
        return workoutPlans.first { $0.isActive }
    }

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        try maybeThrow()
        if !workoutPlans.contains(where: { $0.id == plan.id }) {
            workoutPlans.append(plan)
        }
    }

    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {
        try maybeThrow()
        workoutPlans.removeAll { $0.id == plan.id }
    }

    // MARK: - WorkoutSession

    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        try maybeThrow()
        return workoutSessions.sorted { $0.startedAt > $1.startedAt }
    }

    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        try maybeThrow()
        return workoutSessions.filter { $0.startedAt >= startDate && $0.startedAt <= endDate }
    }

    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        try maybeThrow()
        if !workoutSessions.contains(where: { $0.id == session.id }) {
            workoutSessions.append(session)
        }
    }

    func deleteWorkoutSession(_ session: WorkoutSession) async throws {
        try maybeThrow()
        workoutSessions.removeAll { $0.id == session.id }
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

// MARK: - Helpers

private func makeExercise(
    id: String,
    name: String,
    muscleGroup: String,
    equipment: String = "Barbell"
) -> Exercise {
    Exercise(
        exerciseID: id,
        name: name,
        muscleGroup: muscleGroup,
        equipment: equipment,
        instructions: "Perform correctly.",
        imageName: name.lowercased().replacingOccurrences(of: " ", with: "_")
    )
}

private func makeStubExerciseLibrary() -> [Exercise] {
    [
        makeExercise(id: "bench_press",     name: "Bench Press",     muscleGroup: "Chest"),
        makeExercise(id: "incline_press",   name: "Incline Press",   muscleGroup: "Chest"),
        makeExercise(id: "ohp",             name: "OHP",             muscleGroup: "Shoulders"),
        makeExercise(id: "lateral_raise",   name: "Lateral Raise",   muscleGroup: "Shoulders"),
        makeExercise(id: "tricep_pushdown", name: "Tricep Pushdown", muscleGroup: "Triceps"),
        makeExercise(id: "barbell_row",     name: "Barbell Row",     muscleGroup: "Back"),
        makeExercise(id: "pull_up",         name: "Pull Up",         muscleGroup: "Back"),
        makeExercise(id: "barbell_curl",    name: "Barbell Curl",    muscleGroup: "Biceps"),
        makeExercise(id: "squat",           name: "Squat",           muscleGroup: "Quadriceps"),
        makeExercise(id: "leg_press",       name: "Leg Press",       muscleGroup: "Quadriceps"),
        makeExercise(id: "rdl",             name: "RDL",             muscleGroup: "Hamstrings"),
        makeExercise(id: "hip_thrust",      name: "Hip Thrust",      muscleGroup: "Glutes")
    ]
}

// MARK: - WorkoutPlanViewModelTests

@MainActor
final class WorkoutPlanViewModelTests: XCTestCase {

    // MARK: - Convenience factory

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

    func testInitialPlans_isEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.plans.isEmpty)
    }

    func testInitialActivePlan_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.activePlan)
    }

    func testInitialLoadingState_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    func testInitialGeneratingState_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isGenerating)
    }

    func testInitialErrorMessage_isNil() {
        let vm = makeViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func testInitialSortedDays_isEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.sortedDays.isEmpty)
    }

    // MARK: - loadPlans

    func testLoadPlans_emptyRepository_plansRemainsEmpty() async {
        let vm = makeViewModel()
        await vm.loadPlans()
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertNil(vm.activePlan)
    }

    func testLoadPlans_populatesFromRepository() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        XCTAssertEqual(vm.plans.count, 1)
        XCTAssertEqual(vm.plans.first?.splitType, .fullBody)
    }

    func testLoadPlans_identifiesActivePlan() async {
        let repo = MockWorkoutRepository()
        let activePlan = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 6, isActive: true)
        let inactivePlan = WorkoutPlan(splitType: .upperLower, daysPerWeek: 4, isActive: false)
        repo.workoutPlans = [activePlan, inactivePlan]

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        XCTAssertEqual(vm.activePlan?.id, activePlan.id)
    }

    func testLoadPlans_onError_setsErrorMessage() async {
        let repo = MockWorkoutRepository()
        repo.shouldThrow = true

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.plans.isEmpty)
    }

    func testLoadPlans_clearsErrorMessageOnSuccess() async {
        let repo = MockWorkoutRepository()
        repo.shouldThrow = true
        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        XCTAssertNotNil(vm.errorMessage)

        repo.shouldThrow = false
        await vm.loadPlans()
        XCTAssertNil(vm.errorMessage)
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
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertNotNil(vm.activePlan)
        XCTAssertEqual(vm.activePlan?.id, plan.id)
    }

    func testLoadActivePlan_inactivePlanIgnored() async {
        let repo = MockWorkoutRepository()
        let inactive = makePlan(isActive: false)
        repo.workoutPlans.append(inactive)

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
        repo.workoutPlans.append(plan)

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
        repo.workoutPlans.append(makePlan(splitType: .pushPullLegs))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Push / Pull / Legs")
    }

    func testSplitLabel_fullBody() async {
        let repo = MockWorkoutRepository()
        repo.workoutPlans.append(makePlan(splitType: .fullBody))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Full Body")
    }

    func testSplitLabel_upperLower() async {
        let repo = MockWorkoutRepository()
        repo.workoutPlans.append(makePlan(splitType: .upperLower))

        let vm = makeViewModel(repository: repo)
        await vm.loadActivePlan()

        XCTAssertEqual(vm.splitLabel, "Upper / Lower")
    }

    func testSplitLabel_emptyWhenNoPlan() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.splitLabel, "")
    }

    // MARK: - generatePlan

    func testGeneratePlan_createsNewPlan() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        XCTAssertEqual(vm.plans.count, 1)
        XCTAssertEqual(vm.plans.first?.splitType, .fullBody)
        XCTAssertEqual(vm.plans.first?.daysPerWeek, 3)
    }

    func testGeneratePlan_newPlanIsActive() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .pushPullLegs, daysPerWeek: 3, goal: .bulk)

        XCTAssertNotNil(vm.activePlan)
        XCTAssertEqual(vm.activePlan?.splitType, .pushPullLegs)
        XCTAssertTrue(vm.activePlan?.isActive ?? false)
    }

    func testGeneratePlan_persistsPlanToRepository() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .upperLower, daysPerWeek: 4, goal: .cut)

        XCTAssertEqual(repo.workoutPlans.count, 1)
        XCTAssertEqual(repo.workoutPlans.first?.splitType, .upperLower)
    }

    func testGeneratePlan_createsCorrectNumberOfWorkoutDays() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 4, goal: .maintain)

        XCTAssertEqual(vm.activePlan?.days.count, 4)
    }

    func testGeneratePlan_pplSplit_correctDayLabels() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .pushPullLegs, daysPerWeek: 3, goal: .maintain)

        let labels = vm.activePlan?.days.map(\.dayLabel) ?? []
        XCTAssertTrue(labels.contains("Push"), "PPL plan should include a Push day")
        XCTAssertTrue(labels.contains("Pull"), "PPL plan should include a Pull day")
        XCTAssertTrue(labels.contains("Legs"), "PPL plan should include a Legs day")
    }

    func testGeneratePlan_upperLowerSplit_correctDayLabels() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .upperLower, daysPerWeek: 4, goal: .maintain)

        let labels = Set(vm.activePlan?.days.map(\.dayLabel) ?? [])
        XCTAssertTrue(labels.contains("Upper A"))
        XCTAssertTrue(labels.contains("Lower A"))
        XCTAssertTrue(labels.contains("Upper B"))
        XCTAssertTrue(labels.contains("Lower B"))
    }

    func testGeneratePlan_fullBodySplit_allDaysLabeled() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        let labels = vm.activePlan?.days.map(\.dayLabel) ?? []
        XCTAssertTrue(labels.allSatisfy { $0.hasPrefix("Full Body") })
    }

    func testGeneratePlan_bulkGoal_setsHighRepAndSetPrescription() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .pushPullLegs, daysPerWeek: 3, goal: .bulk)

        let plannedExercises = vm.activePlan?.days.flatMap(\.plannedExercises) ?? []
        XCTAssertFalse(plannedExercises.isEmpty, "Should have planned exercises")
        // bulk: 4 sets, 6-8 reps
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetSets == 4 })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetReps == "6-8" })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetRPE == 8.0 })
    }

    func testGeneratePlan_cutGoal_setsHighRepPrescription() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .cut)

        let plannedExercises = vm.activePlan?.days.flatMap(\.plannedExercises) ?? []
        XCTAssertFalse(plannedExercises.isEmpty)
        // cut: 4 sets, 12-15 reps
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetSets == 4 })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetReps == "12-15" })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetRPE == 7.0 })
    }

    func testGeneratePlan_maintainGoal_setsModeratePrescription() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        let plannedExercises = vm.activePlan?.days.flatMap(\.plannedExercises) ?? []
        XCTAssertFalse(plannedExercises.isEmpty)
        // maintain: 3 sets, 8-12 reps
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetSets == 3 })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetReps == "8-12" })
        XCTAssertTrue(plannedExercises.allSatisfy { $0.targetRPE == 7.5 })
    }

    func testGeneratePlan_deactivatesPreviousActivePlan() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()
        let oldPlan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3, isActive: true)
        repo.workoutPlans.append(oldPlan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        // Generate a new plan — should deactivate oldPlan
        await vm.generatePlan(splitType: .upperLower, daysPerWeek: 4, goal: .maintain)

        XCTAssertFalse(oldPlan.isActive, "Old plan should be deactivated after generating a new one")
        XCTAssertNotEqual(vm.activePlan?.id, oldPlan.id)
    }

    func testGeneratePlan_withNoExercisesInLibrary_createsPlanWithEmptyDays() async {
        let repo = MockWorkoutRepository()
        // No exercises seeded

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        // Plan should still be created but days will have no planned exercises
        XCTAssertNotNil(vm.activePlan)
        XCTAssertEqual(vm.activePlan?.days.count, 3)
        let allPlannedExercises = vm.activePlan?.days.flatMap(\.plannedExercises) ?? []
        XCTAssertTrue(allPlannedExercises.isEmpty)
    }

    func testGeneratePlan_onError_setsErrorMessage() async {
        let repo = MockWorkoutRepository()
        repo.shouldThrow = true

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.activePlan)
    }

    func testGeneratePlan_weekdayIndicesAssigned() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        let days = vm.activePlan?.days ?? []
        XCTAssertEqual(days.count, 3)
        // 3-day schedule: Mon=2, Wed=4, Fri=6
        XCTAssertEqual(days[0].weekdayIndex, 2)
        XCTAssertEqual(days[1].weekdayIndex, 4)
        XCTAssertEqual(days[2].weekdayIndex, 6)
    }

    // MARK: - setActivePlan

    func testSetActivePlan_updatesActivePlan() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3, isActive: false)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        await vm.setActivePlan(plan)

        XCTAssertEqual(vm.activePlan?.id, plan.id)
        XCTAssertTrue(plan.isActive)
    }

    func testSetActivePlan_deactivatesPreviousActivePlan() async {
        let repo = MockWorkoutRepository()
        let oldPlan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3, isActive: true)
        let newPlan = WorkoutPlan(splitType: .upperLower, daysPerWeek: 4, isActive: false)
        repo.workoutPlans = [oldPlan, newPlan]

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        await vm.setActivePlan(newPlan)

        XCTAssertFalse(oldPlan.isActive)
        XCTAssertTrue(newPlan.isActive)
        XCTAssertEqual(vm.activePlan?.id, newPlan.id)
    }

    func testSetActivePlan_onError_setsErrorMessage() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        repo.shouldThrow = true
        await vm.setActivePlan(plan)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - deletePlan

    func testDeletePlan_removesPlanFromList() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        XCTAssertEqual(vm.plans.count, 1)

        await vm.deletePlan(plan)
        XCTAssertTrue(vm.plans.isEmpty)
    }

    func testDeletePlan_removesFromRepository() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        await vm.deletePlan(plan)

        XCTAssertTrue(repo.workoutPlans.isEmpty)
    }

    func testDeletePlan_clearsActivePlanWhenActiveIsDeleted() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3, isActive: true)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        XCTAssertNotNil(vm.activePlan)

        await vm.deletePlan(plan)
        XCTAssertNil(vm.activePlan)
    }

    func testDeletePlan_doesNotClearActivePlan_whenNonActiveIsDeleted() async {
        let repo = MockWorkoutRepository()
        let activePlan  = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 6, isActive: true)
        let inactivePlan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3, isActive: false)
        repo.workoutPlans = [activePlan, inactivePlan]

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()
        await vm.deletePlan(inactivePlan)

        XCTAssertEqual(vm.activePlan?.id, activePlan.id)
        XCTAssertEqual(vm.plans.count, 1)
    }

    func testDeletePlan_onError_setsErrorMessage() async {
        let repo = MockWorkoutRepository()
        let plan = WorkoutPlan(splitType: .fullBody, daysPerWeek: 3)
        repo.workoutPlans.append(plan)

        let vm = makeViewModel(repository: repo)
        await vm.loadPlans()

        repo.shouldThrow = true
        await vm.deletePlan(plan)

        XCTAssertNotNil(vm.errorMessage)
        // Plan should still be in the in-memory list (deletion failed)
        XCTAssertEqual(vm.plans.count, 1)
    }

    // MARK: - PPL Day-cycle edge cases

    func testGeneratePlan_ppl6Days_cyclesCorrectly() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .pushPullLegs, daysPerWeek: 6, goal: .maintain)

        let labels = vm.activePlan?.days.map(\.dayLabel) ?? []
        XCTAssertEqual(labels.count, 6)
        // PPL cycles: Push, Pull, Legs, Push, Pull, Legs
        XCTAssertEqual(labels[0], "Push")
        XCTAssertEqual(labels[1], "Pull")
        XCTAssertEqual(labels[2], "Legs")
        XCTAssertEqual(labels[3], "Push")
        XCTAssertEqual(labels[4], "Pull")
        XCTAssertEqual(labels[5], "Legs")
    }

    func testGeneratePlan_upperLower2Days_cyclesCorrectly() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .upperLower, daysPerWeek: 2, goal: .maintain)

        let labels = vm.activePlan?.days.map(\.dayLabel) ?? []
        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0], "Upper A")
        XCTAssertEqual(labels[1], "Lower A")
    }

    // MARK: - Planned exercise exercise references

    func testGeneratePlan_plannedExercises_haveExerciseReference() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .fullBody, daysPerWeek: 3, goal: .maintain)

        let allPlannedExercises = vm.activePlan?.days.flatMap(\.plannedExercises) ?? []
        XCTAssertFalse(allPlannedExercises.isEmpty)
        XCTAssertTrue(allPlannedExercises.allSatisfy { $0.exercise != nil })
    }

    func testGeneratePlan_plannedExercises_sortOrderIsSequential() async {
        let repo = MockWorkoutRepository()
        repo.exercises = makeStubExerciseLibrary()

        let vm = makeViewModel(repository: repo)
        await vm.generatePlan(splitType: .pushPullLegs, daysPerWeek: 3, goal: .maintain)

        for day in vm.activePlan?.days ?? [] {
            let sortOrders = day.plannedExercises.map(\.sortOrder)
            XCTAssertEqual(sortOrders, sortOrders.sorted(), "Sort orders within a day should be non-decreasing")
        }
    }
}
