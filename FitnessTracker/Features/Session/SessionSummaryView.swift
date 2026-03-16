import SwiftUI

// MARK: - SessionSummaryView

/// Full-screen session completion summary presented after the user taps "Finish".
///
/// Displays:
/// - Total session duration and volume
/// - Personal records achieved this session
/// - A per-exercise breakdown of completed sets
struct SessionSummaryView: View {

    // MARK: - Input

    let summary: SessionSummaryData
    let onDone: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsRow
                    if summary.prCount > 0 {
                        prBanner
                    }
                    exerciseBreakdownSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: true)

            Text("Great work!")
                .font(.title.bold())

            Text("Session logged successfully")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            SummaryStatTile(
                icon: "clock.fill",
                color: .blue,
                value: formattedDuration(summary.durationSeconds),
                label: "Duration"
            )
            SummaryStatTile(
                icon: "scalemass.fill",
                color: .purple,
                value: String(format: "%.0f kg", summary.totalVolumeKg),
                label: "Total Volume"
            )
            SummaryStatTile(
                icon: "trophy.fill",
                color: .yellow,
                value: "\(summary.prCount)",
                label: summary.prCount == 1 ? "PR" : "PRs"
            )
        }
    }

    private var prBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal Record\(summary.prCount > 1 ? "s" : "") Achieved!")
                    .font(.headline)
                Text("You beat your previous best on \(summary.prCount) set\(summary.prCount > 1 ? "s" : "") today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var exerciseBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)

            ForEach(summary.exerciseEntries.indices, id: \.self) { idx in
                let entry = summary.exerciseEntries[idx]
                ExerciseSummaryCard(entry: entry)
            }
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - SummaryStatTile

private struct SummaryStatTile: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - ExerciseSummaryCard

private struct ExerciseSummaryCard: View {
    let entry: ExerciseSessionEntry

    private var completedSets: [LoggedSet] {
        entry.sets.filter(\.isComplete)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.plannedExercise.exercise?.name ?? "Unknown Exercise")
                        .font(.subheadline.bold())
                    if let muscle = entry.plannedExercise.exercise?.muscleGroup {
                        Text(muscle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(completedSets.count)/\(entry.sets.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !completedSets.isEmpty {
                Divider()
                ForEach(completedSets.indices, id: \.self) { i in
                    let set = completedSets[i]
                    HStack {
                        Text("Set \(i + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        Text(String(format: "%.1f kg × %d", set.weightKg, set.reps))
                            .font(.caption.monospacedDigit())
                        if let rpe = set.rpe {
                            Text(String(format: "@ RPE %.0f", rpe))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if set.isPR {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview("SessionSummaryView") {
    let bench = Exercise(
        exerciseID: "bench",
        name: "Barbell Bench Press",
        muscleGroup: "Chest",
        equipment: "Barbell",
        instructions: "",
        imageName: "bench_press"
    )

    let plannedBench = PlannedExercise(targetSets: 3, targetReps: "6-8", targetRPE: 8, sortOrder: 0, exercise: bench)

    let set1 = LoggedSet(setIndex: 0, weightKg: 102.5, reps: 5, sortOrder: 0)
    set1.isComplete = true
    set1.isPR = true
    let set2 = LoggedSet(setIndex: 1, weightKg: 100.0, reps: 5, sortOrder: 1)
    set2.isComplete = true
    let set3 = LoggedSet(setIndex: 2, weightKg: 97.5, reps: 6, sortOrder: 2)
    set3.isComplete = true

    let entry = ExerciseSessionEntry(
        plannedExercise: plannedBench,
        sets: [set1, set2, set3],
        previousBest: (weightKg: 100.0, reps: 5)
    )

    let summary = SessionSummaryData(
        durationSeconds: 2700,
        totalVolumeKg: 1543.0,
        prCount: 1,
        exerciseEntries: [entry]
    )

    return SessionSummaryView(summary: summary, onDone: {})
}
