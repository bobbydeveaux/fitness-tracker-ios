import SwiftUI

// MARK: - ActiveSessionView

/// The primary view shown during a live gym session.
///
/// Displays a session header with elapsed time and running volume, followed
/// by a card per exercise in the day's plan. Each card contains an
/// `ExerciseSetRow` for every planned set. A `RestTimerView` banner slides in
/// between sets when the rest timer is running.
///
/// State machine flow:
/// ```
/// Appear → startSession() → logs sets → finishSession() → SessionSummaryView
///                                                        ↘ dismiss (abandon)
/// ```
struct ActiveSessionView: View {

    // MARK: - Dependencies

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: SessionViewModel
    @State private var showingAbandonAlert: Bool = false
    @State private var showingTimerSettings: Bool = false

    // MARK: - Init

    init(workoutDay: WorkoutDay, repository: any WorkoutRepository, healthKitService: any HealthKitServiceProtocol) {
        _viewModel = State(initialValue: SessionViewModel(
            workoutDay: workoutDay,
            repository: repository,
            healthKitService: healthKitService
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        sessionHeaderCard
                        exerciseList
                        finishButton
                            .padding(.bottom, viewModel.restTimerSecondsRemaining != nil ? 180 : 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Rest timer banner slides in from the bottom
                if let remaining = viewModel.restTimerSecondsRemaining {
                    restTimerBanner(remaining: remaining)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: remaining)
                }
            }
            .navigationTitle(viewModel.workoutDay.dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Abandon Session?", isPresented: $showingAbandonAlert) {
                Button("Abandon", role: .destructive) {
                    Task {
                        await viewModel.abandonSession()
                        dismiss()
                    }
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your progress so far will be discarded.")
            }
            .sheet(isPresented: $showingTimerSettings) {
                RestTimerSettingsView(duration: $viewModel.restTimerDuration)
            }
            // Navigation to summary on completion
            .navigationDestination(
                isPresented: Binding(
                    get: { viewModel.state == .complete },
                    set: { _ in }
                )
            ) {
                if let summary = viewModel.summaryData {
                    SessionSummaryView(summary: summary) {
                        dismiss()
                    }
                    .navigationBarBackButtonHidden()
                }
            }
            .task {
                await viewModel.startSession()
                await viewModel.loadPreviousBests()
            }
        }
    }

    // MARK: - Session Header Card

    private var sessionHeaderCard: some View {
        HStack(spacing: 0) {
            HeaderStat(
                value: viewModel.elapsedFormatted,
                label: "Elapsed",
                icon: "clock.fill",
                color: .blue
            )

            Divider().frame(height: 40)

            HeaderStat(
                value: String(format: "%.0f kg", viewModel.totalVolumeKg),
                label: "Volume",
                icon: "scalemass.fill",
                color: .purple
            )

            Divider().frame(height: 40)

            HeaderStat(
                value: "\(viewModel.prCount)",
                label: viewModel.prCount == 1 ? "PR" : "PRs",
                icon: "trophy.fill",
                color: .yellow
            )
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ForEach(viewModel.exerciseEntries.indices, id: \.self) { exIdx in
            ExerciseCard(
                entry: viewModel.exerciseEntries[exIdx],
                onCompleteSet: { setIdx, weight, reps, rpe in
                    Task {
                        await viewModel.completeSet(
                            exerciseIndex: exIdx,
                            setIndex: setIdx,
                            weightKg: weight,
                            reps: reps,
                            rpe: rpe
                        )
                    }
                }
            )
        }
    }

    // MARK: - Finish Button

    private var finishButton: some View {
        Button(action: {
            Task { await viewModel.finishSession() }
        }) {
            Label("Finish Session", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rest Timer Banner

    private func restTimerBanner(remaining: Int) -> some View {
        RestTimerView(
            secondsRemaining: remaining,
            totalDuration: viewModel.restTimerDuration,
            onSkip: { viewModel.cancelRestTimer() }
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingAbandonAlert = true
            } label: {
                Label("Abandon", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingTimerSettings = true
            } label: {
                Label("Timer", systemImage: "timer")
            }
        }
    }

}

// MARK: - ExerciseCard

/// A card within `ActiveSessionView` representing one exercise and its set rows.
private struct ExerciseCard: View {

    let entry: ExerciseSessionEntry
    let onCompleteSet: (Int, Double, Int, Double?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader
            Divider().padding(.vertical, 8)
            setsTable
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var exerciseHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(muscleGroupColor(for: entry.plannedExercise.exercise?.muscleGroup))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.plannedExercise.exercise?.name ?? "Unknown Exercise")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(entry.plannedExercise.targetSets) sets × \(entry.plannedExercise.targetReps) reps"
                     + (entry.plannedExercise.targetRPE.map { " @ RPE \(Int($0))" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            let completed = entry.sets.filter(\.isComplete).count
            Text("\(completed)/\(entry.sets.count)")
                .font(.caption.bold())
                .foregroundStyle(completed == entry.sets.count ? .green : .secondary)
        }
    }

    private var setsTable: some View {
        VStack(spacing: 4) {
            // Column headers
            HStack(spacing: 12) {
                Text("#")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text("Weight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 64)
                Text("Reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                Text("RPE")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(entry.sets.indices, id: \.self) { setIdx in
                ExerciseSetRow(
                    setIndex: setIdx,
                    set: entry.sets[setIdx],
                    previousBest: entry.previousBest,
                    onComplete: { weight, reps, rpe in
                        onCompleteSet(setIdx, weight, reps, rpe)
                    }
                )
            }
        }
    }

    // MARK: - Colour helper

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
}

// MARK: - HeaderStat

private struct HeaderStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RestTimerSettingsView

/// A simple sheet that lets the user configure the rest timer duration.
private struct RestTimerSettingsView: View {

    @Binding var duration: Int
    @Environment(\.dismiss) private var dismiss

    private let options = [30, 60, 90, 120, 180, 240, 300]

    var body: some View {
        NavigationStack {
            List {
                Section("Rest Duration") {
                    ForEach(options, id: \.self) { seconds in
                        HStack {
                            Text(formattedOption(seconds))
                            Spacer()
                            if duration == seconds {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            duration = seconds
                        }
                    }
                }
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formattedOption(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) seconds"
        }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m) minute\(m == 1 ? "" : "s")" : "\(m) min \(s) sec"
    }
}

// MARK: - Preview

#Preview("ActiveSessionView") {
    let bench = Exercise(
        exerciseID: "bench",
        name: "Barbell Bench Press",
        muscleGroup: "Chest",
        equipment: "Barbell",
        instructions: "",
        imageName: "bench_press"
    )
    let squat = Exercise(
        exerciseID: "squat",
        name: "Back Squat",
        muscleGroup: "Quadriceps",
        equipment: "Barbell",
        instructions: "",
        imageName: "squat"
    )

    let day = WorkoutDay(dayLabel: "Push A", weekdayIndex: 2)
    let e1 = PlannedExercise(targetSets: 4, targetReps: "6-8", targetRPE: 8, sortOrder: 0, exercise: bench)
    let e2 = PlannedExercise(targetSets: 3, targetReps: "8-10", sortOrder: 1, exercise: squat)
    e1.workoutDay = day
    e2.workoutDay = day
    day.plannedExercises = [e1, e2]

    let repo = PreviewSessionRepository()
    let hk = MockHealthKitService()
    return ActiveSessionView(workoutDay: day, repository: repo, healthKitService: hk)
        .environment(AppEnvironment.makeProductionEnvironment())
}

// MARK: - Preview helpers

private final class PreviewSessionRepository: WorkoutRepository, @unchecked Sendable {
    func fetchExercises() async throws -> [Exercise] { [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { nil }
    func saveExercise(_ exercise: Exercise) async throws {}
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { nil }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] { [] }
    func saveWorkoutSession(_ session: WorkoutSession) async throws {}
    func deleteWorkoutSession(_ session: WorkoutSession) async throws {}
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {}
}

private final class MockHealthKitService: HealthKitServiceProtocol {
    func requestAuthorisationIfNeeded() async {}
    func readDailyStats() async -> DailyStats { DailyStats() }
    func saveWorkout(duration: TimeInterval) async {}
}
