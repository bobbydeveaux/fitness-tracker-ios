import Foundation
import Observation

// MARK: - WorkoutPlanViewModel

/// `@Observable` view model driving the Workout Plan feature screen.
///
/// Responsible for:
/// - Loading existing `WorkoutPlan` records from `WorkoutRepository`
/// - Generating new plans based on split type, days-per-week, and the
///   user's fitness goal (driving exercise prescription)
/// - Persisting generated and updated plans
/// - Managing the currently-active plan
///
/// Generation pulls exercises from the repository's seeded library and
/// assembles `WorkoutDay` + `PlannedExercise` objects before persisting
/// the whole graph through `WorkoutRepository.saveWorkoutPlan(_:)`.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel: WorkoutPlanViewModel
///
/// init(env: AppEnvironment) {
///     _viewModel = State(initialValue: WorkoutPlanViewModel(
///         repository: env.workoutRepository
///     ))
/// }
/// ```
@Observable
@MainActor
final class WorkoutPlanViewModel {

    // MARK: - State

    /// All workout plans ordered by `generatedAt` descending.
    private(set) var plans: [WorkoutPlan] = []

    /// The currently active plan, or `nil` if none is set.
    private(set) var activePlan: WorkoutPlan?

    /// `true` while the repository is being queried on `loadPlans()`.
    private(set) var isLoading: Bool = false

    /// `true` while a plan is being generated and saved.
    private(set) var isGenerating: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let repository: any WorkoutRepository

    // MARK: - Init

    /// - Parameter repository: Defaults to the app-wide `WorkoutRepository`; inject a
    ///   mock conforming to `WorkoutRepository` in tests or previews.
    init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    // MARK: - Data Loading

    /// Fetches all `WorkoutPlan` records from the repository and identifies the active one.
    ///
    /// Call from the view's `.task {}` modifier so the list is up to date on every appearance.
    func loadPlans() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            plans = try await repository.fetchWorkoutPlans()
            activePlan = try await repository.fetchActiveWorkoutPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Plan Generation

    /// Generates a new `WorkoutPlan` from the exercise library and makes it the active plan.
    ///
    /// Steps performed:
    /// 1. Deactivate any currently active plans.
    /// 2. Fetch the exercise library to source movements.
    /// 3. Build `WorkoutDay` + `PlannedExercise` objects per the chosen split and goal.
    /// 4. Persist the new plan via the repository.
    /// 5. Refresh `plans` and `activePlan`.
    ///
    /// - Parameters:
    ///   - splitType: The training split (Push/Pull/Legs, Full Body, Upper/Lower).
    ///   - daysPerWeek: Number of training days per week (1-6).
    ///   - goal: The user's fitness goal, which determines rep and set prescriptions.
    func generatePlan(
        splitType: SplitType,
        daysPerWeek: Int,
        goal: FitnessGoal = .maintain
    ) async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            // Deactivate existing active plans before creating the new one.
            for plan in plans where plan.isActive {
                plan.isActive = false
                try await repository.saveWorkoutPlan(plan)
            }

            // Fetch exercise library for movement selection.
            let allExercises = try await repository.fetchExercises()

            // Build the plan object graph.
            let newPlan = WorkoutPlan(
                splitType: splitType,
                daysPerWeek: daysPerWeek,
                isActive: true
            )
            let days = buildWorkoutDays(
                splitType: splitType,
                daysPerWeek: daysPerWeek,
                goal: goal,
                exercises: allExercises
            )
            newPlan.days = days
            for day in days { day.workoutPlan = newPlan }

            try await repository.saveWorkoutPlan(newPlan)

            // Prepend so the newest plan appears first in the list.
            plans.insert(newPlan, at: 0)
            activePlan = newPlan
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Plan Management

    /// Makes `plan` the active plan, deactivating all others.
    func setActivePlan(_ plan: WorkoutPlan) async {
        errorMessage = nil
        do {
            for p in plans where p.isActive {
                p.isActive = false
                try await repository.saveWorkoutPlan(p)
            }
            plan.isActive = true
            try await repository.saveWorkoutPlan(plan)
            activePlan = plan
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes `plan` from the repository and removes it from the in-memory list.
    ///
    /// If the deleted plan was active, `activePlan` is updated to the next
    /// active plan in `plans`, or `nil` if none remains.
    func deletePlan(_ plan: WorkoutPlan) async {
        errorMessage = nil
        do {
            try await repository.deleteWorkoutPlan(plan)
            plans.removeAll { $0.id == plan.id }
            if activePlan?.id == plan.id {
                activePlan = plans.first(where: { $0.isActive })
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private – Plan Generation Helpers

    /// Builds the `WorkoutDay` array for a given split type and days-per-week.
    private func buildWorkoutDays(
        splitType: SplitType,
        daysPerWeek: Int,
        goal: FitnessGoal,
        exercises: [Exercise]
    ) -> [WorkoutDay] {
        let configs = dayConfigurations(for: splitType, daysPerWeek: daysPerWeek)
        let schedule = weekdaySchedule(for: daysPerWeek)

        return configs.enumerated().map { index, config in
            let day = WorkoutDay(
                dayLabel: config.label,
                weekdayIndex: index < schedule.count ? schedule[index] : index + 2
            )
            let plannedExercises = buildPlannedExercises(
                muscleGroups: config.muscleGroups,
                goal: goal,
                exercises: exercises
            )
            day.plannedExercises = plannedExercises
            for pe in plannedExercises { pe.workoutDay = day }
            return day
        }
    }

    /// Returns day label + muscle group pairings for the chosen split,
    /// repeated/cycled to fill `daysPerWeek` training days.
    private func dayConfigurations(
        for splitType: SplitType,
        daysPerWeek: Int
    ) -> [DayConfig] {
        let cycle: [DayConfig]
        switch splitType {
        case .pushPullLegs:
            cycle = [
                DayConfig(label: "Push",  muscleGroups: ["Chest", "Shoulders", "Triceps"]),
                DayConfig(label: "Pull",  muscleGroups: ["Back", "Biceps"]),
                DayConfig(label: "Legs",  muscleGroups: ["Quadriceps", "Hamstrings", "Glutes"])
            ]
        case .upperLower:
            cycle = [
                DayConfig(label: "Upper A", muscleGroups: ["Chest", "Back", "Shoulders"]),
                DayConfig(label: "Lower A", muscleGroups: ["Quadriceps", "Hamstrings", "Glutes"]),
                DayConfig(label: "Upper B", muscleGroups: ["Chest", "Back", "Triceps", "Biceps"]),
                DayConfig(label: "Lower B", muscleGroups: ["Quadriceps", "Hamstrings", "Calves"])
            ]
        case .fullBody:
            let labels = ["A", "B", "C", "D", "E", "F"]
            cycle = labels.map { letter in
                DayConfig(
                    label: "Full Body \(letter)",
                    muscleGroups: ["Chest", "Back", "Quadriceps", "Shoulders"]
                )
            }
        }
        guard !cycle.isEmpty else { return [] }
        return (0..<daysPerWeek).map { cycle[$0 % cycle.count] }
    }

    /// Weekday indices (1 = Sunday … 7 = Saturday) spread evenly across the week,
    /// starting on Monday (index 2).
    private func weekdaySchedule(for daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case 1: return [2]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 5, 6]
        case 6: return [2, 3, 4, 5, 6, 7]
        default: return Array(2...min(daysPerWeek + 1, 7))
        }
    }

    /// Selects up to 2 exercises per muscle group and wraps them in `PlannedExercise`
    /// objects using the rep/set prescription derived from `goal`.
    private func buildPlannedExercises(
        muscleGroups: [String],
        goal: FitnessGoal,
        exercises: [Exercise]
    ) -> [PlannedExercise] {
        let (sets, reps, rpe) = prescription(for: goal)
        var result: [PlannedExercise] = []
        var sortOrder = 0

        for group in muscleGroups {
            let candidates = exercises.filter {
                $0.muscleGroup.lowercased() == group.lowercased()
            }
            let count = min(2, candidates.count)
            for i in 0..<count {
                let pe = PlannedExercise(
                    targetSets: sets,
                    targetReps: reps,
                    targetRPE: rpe,
                    sortOrder: sortOrder,
                    exercise: candidates[i]
                )
                result.append(pe)
                sortOrder += 1
            }
        }
        return result
    }

    /// Returns the recommended (sets, reps range, RPE) based on the user's goal.
    ///
    /// | Goal     | Sets | Reps  | RPE |
    /// |----------|------|-------|-----|
    /// | cut      | 4    | 12–15 | 7.0 |
    /// | maintain | 3    | 8–12  | 7.5 |
    /// | bulk     | 4    | 6–8   | 8.0 |
    private func prescription(for goal: FitnessGoal) -> (sets: Int, reps: String, rpe: Double) {
        switch goal {
        case .cut:      return (4, "12-15", 7.0)
        case .maintain: return (3, "8-12",  7.5)
        case .bulk:     return (4, "6-8",   8.0)
        }
    }
}

// MARK: - DayConfig (private helper)

private struct DayConfig {
    let label: String
    let muscleGroups: [String]
}
