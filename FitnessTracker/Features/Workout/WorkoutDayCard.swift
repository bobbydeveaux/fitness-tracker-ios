import SwiftUI

// MARK: - WorkoutDayCard

/// A card that renders a single `WorkoutDay` within `WorkoutPlanView`.
///
/// Displays:
/// - The day label (e.g. "Push A") and weekday name (e.g. "Monday")
/// - A list of `PlannedExercise` rows showing exercise name, sets × reps, and
///   an optional RPE badge.
///
/// The card is read-only — it shows prescribed values from the plan but does
/// not allow inline editing. Tapping the card has no action; navigation to a
/// session is handled at the parent level.
struct WorkoutDayCard: View {

    // MARK: - Input

    let day: WorkoutDay

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            Divider()
            exerciseList
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.dayLabel)
                    .font(.headline)
                Text(weekdayName(for: day.weekdayIndex))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            exerciseCountBadge
        }
    }

    private var exerciseCountBadge: some View {
        let count = day.plannedExercises.count
        return Text("\(count) exercise\(count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemBackground))
            )
    }

    @ViewBuilder
    private var exerciseList: some View {
        let sorted = day.plannedExercises.sorted { $0.sortOrder < $1.sortOrder }
        if sorted.isEmpty {
            Text("No exercises planned")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 8) {
                ForEach(sorted, id: \.id) { planned in
                    PlannedExerciseRow(planned: planned)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Converts an ISO weekday index (1 = Sunday … 7 = Saturday) to a short name.
    private func weekdayName(for index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols // ["Sunday", "Monday", …]
        let clamped = max(1, min(index, 7))
        return symbols[clamped - 1]
    }
}

// MARK: - PlannedExerciseRow

/// A single row within `WorkoutDayCard` displaying one `PlannedExercise`.
private struct PlannedExerciseRow: View {

    let planned: PlannedExercise

    var body: some View {
        HStack(spacing: 8) {
            // Muscle-group colour accent dot
            Circle()
                .fill(muscleGroupColor(for: planned.exercise?.muscleGroup))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(planned.exercise?.name ?? "Unknown Exercise")
                    .font(.subheadline)
                    .lineLimit(1)
                if let muscleGroup = planned.exercise?.muscleGroup {
                    Text(muscleGroup)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Sets × reps
            Text("\(planned.targetSets) × \(planned.targetReps)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)

            // Optional RPE badge
            if let rpe = planned.targetRPE {
                Text(String(format: "@%.0f", rpe))
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(rpeColor(rpe))
                    )
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Colour helpers

    private func muscleGroupColor(for muscleGroup: String?) -> Color {
        switch muscleGroup?.lowercased() {
        case "chest":         return .red
        case "back":          return .blue
        case "shoulders":     return .purple
        case "quadriceps", "legs": return .green
        case "hamstrings":    return .mint
        case "glutes":        return .indigo
        case "biceps":        return .orange
        case "triceps":       return .yellow
        case "core", "abs":   return .cyan
        default:              return .gray
        }
    }

    /// Returns a colour representing effort level (green → orange → red).
    private func rpeColor(_ rpe: Double) -> Color {
        switch rpe {
        case ..<7:   return .green
        case 7..<9:  return .orange
        default:     return .red
        }
    }
}

// MARK: - Preview

#Preview("WorkoutDayCard – with exercises") {
    let day = WorkoutDay(dayLabel: "Push A", weekdayIndex: 2) // Monday

    let bench = Exercise(
        exerciseID: "bench",
        name: "Barbell Bench Press",
        muscleGroup: "Chest",
        equipment: "Barbell",
        instructions: "",
        imageName: "bench_press"
    )
    let ohp = Exercise(
        exerciseID: "ohp",
        name: "Overhead Press",
        muscleGroup: "Shoulders",
        equipment: "Barbell",
        instructions: "",
        imageName: "ohp"
    )
    let tricep = Exercise(
        exerciseID: "tricep",
        name: "Tricep Pushdown",
        muscleGroup: "Triceps",
        equipment: "Cable",
        instructions: "",
        imageName: "tricep_pushdown"
    )

    let e1 = PlannedExercise(targetSets: 4, targetReps: "6-8", targetRPE: 8, sortOrder: 0, exercise: bench)
    let e2 = PlannedExercise(targetSets: 3, targetReps: "8-10", targetRPE: 7, sortOrder: 1, exercise: ohp)
    let e3 = PlannedExercise(targetSets: 3, targetReps: "12", sortOrder: 2, exercise: tricep)
    day.plannedExercises = [e1, e2, e3]

    return WorkoutDayCard(day: day)
        .padding()
}

#Preview("WorkoutDayCard – empty") {
    WorkoutDayCard(day: WorkoutDay(dayLabel: "Rest Day", weekdayIndex: 1))
        .padding()
}
