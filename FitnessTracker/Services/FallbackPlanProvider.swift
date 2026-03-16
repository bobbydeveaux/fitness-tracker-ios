import Foundation

// MARK: - FallbackPlanProvider

/// Returns a hard-coded template `WorkoutPlan` when the Claude API is unavailable.
///
/// The fallback plan is a 3-day full-body programme containing sensible defaults
/// for any experience level. It satisfies the `WorkoutPlanGenerating` protocol so
/// `WorkoutPlanViewModel` can call it identically to `ClaudeAPIClient` and fall
/// back transparently on any `ClaudeAPIError`.
///
/// The returned entities are detached (not yet inserted into a `ModelContext`).
/// `PlannedExercise.exercise` is left `nil`; callers may resolve exercise
/// references by name via `ExerciseLibraryService` before persisting.
///
/// No network call is made. The function is non-throwing; `async throws` is
/// declared only to satisfy the `WorkoutPlanGenerating` protocol.
final class FallbackPlanProvider: WorkoutPlanGenerating {

    // MARK: - WorkoutPlanGenerating

    func generatePlan(profile: UserProfile) async throws -> WorkoutPlan {
        makeFullBodyPlan(profile: profile)
    }

    // MARK: - Template plan

    private func makeFullBodyPlan(profile: UserProfile) -> WorkoutPlan {
        let plan = WorkoutPlan(
            splitType: .fullBody,
            daysPerWeek: 3,
            userProfile: profile
        )

        // Spread across Monday (2), Wednesday (4), Friday (6).
        let dayA = makeDay(
            label: "Full Body A",
            weekdayIndex: 2,
            plan: plan,
            exercises: [
                (name: "Barbell Squat",        sets: 4, reps: "5"),
                (name: "Barbell Bench Press",  sets: 4, reps: "6-8"),
                (name: "Barbell Row",          sets: 4, reps: "6-8"),
                (name: "Overhead Press",       sets: 3, reps: "8-10"),
                (name: "Romanian Deadlift",    sets: 3, reps: "10"),
            ]
        )

        let dayB = makeDay(
            label: "Full Body B",
            weekdayIndex: 4,
            plan: plan,
            exercises: [
                (name: "Deadlift",                 sets: 4, reps: "5"),
                (name: "Incline Dumbbell Press",   sets: 4, reps: "8-10"),
                (name: "Pull-Up",                  sets: 4, reps: "6-8"),
                (name: "Dumbbell Lateral Raise",   sets: 3, reps: "12-15"),
                (name: "Leg Press",                sets: 3, reps: "10-12"),
            ]
        )

        let dayC = makeDay(
            label: "Full Body C",
            weekdayIndex: 6,
            plan: plan,
            exercises: [
                (name: "Front Squat",              sets: 4, reps: "6-8"),
                (name: "Dumbbell Bench Press",     sets: 3, reps: "10-12"),
                (name: "Seated Cable Row",         sets: 3, reps: "10-12"),
                (name: "Dumbbell Shoulder Press",  sets: 3, reps: "10-12"),
                (name: "Nordic Hamstring Curl",    sets: 3, reps: "8"),
            ]
        )

        plan.days = [dayA, dayB, dayC]
        return plan
    }

    // MARK: - Private helpers

    private func makeDay(
        label: String,
        weekdayIndex: Int,
        plan: WorkoutPlan,
        exercises: [(name: String, sets: Int, reps: String)]
    ) -> WorkoutDay {
        let day = WorkoutDay(
            dayLabel: label,
            weekdayIndex: weekdayIndex,
            workoutPlan: plan
        )
        day.plannedExercises = exercises.enumerated().map { index, ex in
            PlannedExercise(
                targetSets: ex.sets,
                targetReps: ex.reps,
                sortOrder: index,
                workoutDay: day
            )
        }
        return day
    }
}
