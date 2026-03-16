import SwiftUI

// MARK: - SessionView

/// The primary view for conducting a live workout session.
///
/// Hosts:
/// - A scrollable list of `ActiveExercise` sections, each containing `ExerciseSetRow`
///   items populated from the `WorkoutDay`'s `PlannedExercise` list.
/// - An inline `RestTimerView` pinned below the exercise list that counts down
///   between sets.
/// - Navigation to `SessionSummaryView` on session completion.
/// - A confirmation alert when the user attempts to leave an active session.
///
/// Data flow:
/// 1. On `.task`, previous-session sets are fetched from the `WorkoutRepository`
///    and `SessionViewModel.startSession(day:exercises:previousSetsMap:)` is called.
/// 2. User interactions (logging sets, pausing, finishing) are forwarded to
///    `SessionViewModel`, which mutates its `@Observable` state.
/// 3. SwiftUI re-renders reactively — no manual `objectWillChange` calls needed.
///
/// Persistence:
/// - On finish, `SessionViewModel.finishSession()` persists the `WorkoutSession`
///   to SwiftData via `WorkoutRepository` and writes an `HKWorkout` via
///   `HealthKitService`.
///
/// Usage:
/// ```swift
/// SessionView(
///     workoutDay: day,
///     repository: env.workoutRepository,
///     healthKitService: env.healthKitService
/// )
/// ```
struct SessionView: View {

    // MARK: - Dependencies

    let workoutDay: WorkoutDay
    let repository: any WorkoutRepository
    let healthKitService: any HealthKitServiceProtocol

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: SessionViewModel
    @State private var showAbandonAlert = false
    @State private var showSummary = false

    // MARK: - Init

    init(
        workoutDay: WorkoutDay,
        repository: any WorkoutRepository,
        healthKitService: any HealthKitServiceProtocol = HealthKitService.shared
    ) {
        self.workoutDay = workoutDay
        self.repository = repository
        self.healthKitService = healthKitService
        _viewModel = State(initialValue: SessionViewModel(
            workoutRepository: repository,
            healthKitService: healthKitService
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                exerciseScrollView

                if viewModel.restTimerActive || viewModel.restSecondsRemaining > 0 {
                    restTimerBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: viewModel.restTimerActive)
                }
            }
            .navigationTitle(workoutDay.dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await startSession() }
            .alert("Abandon Session?", isPresented: $showAbandonAlert) {
                abandonAlertButtons
            } message: {
                Text("Your progress for this session will be discarded.")
            }
            .sheet(isPresented: $showSummary) {
                if let summary = viewModel.summary {
                    SessionSummaryView(summary: summary) {
                        showSummary = false
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.phase) { _, newPhase in
                if newPhase == .complete {
                    showSummary = true
                }
            }
        }
        .interactiveDismissDisabled(viewModel.phase == .active || viewModel.phase == .paused)
    }

    // MARK: - Exercise List

    private var exerciseScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.activeExercises.isEmpty {
                    loadingOrEmptyState
                } else {
                    ForEach(viewModel.activeExercises.indices, id: \.self) { exIdx in
                        exerciseSection(index: exIdx)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, viewModel.restTimerActive ? 160 : 32)
        }
    }

    @ViewBuilder
    private var loadingOrEmptyState: some View {
        if viewModel.phase == .idle {
            ProgressView("Starting session…")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            ContentUnavailableView(
                "No Exercises",
                systemImage: "dumbbell",
                description: Text("This workout day has no planned exercises.")
            )
        }
    }

    private func exerciseSection(index: Int) -> some View {
        let exercise = viewModel.activeExercises[index]
        return VStack(alignment: .leading, spacing: 8) {
            exerciseHeader(exercise: exercise)

            VStack(spacing: 4) {
                // Column header
                HStack(spacing: 12) {
                    Text("Set")
                        .frame(width: 24)
                    Text("kg")
                        .frame(width: 72, alignment: .leading)
                    Text("Reps")
                        .frame(width: 56, alignment: .leading)
                    Spacer()
                }
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                ForEach(exercise.setRows.indices, id: \.self) { rowIdx in
                    ExerciseSetRow(
                        row: Binding(
                            get: { viewModel.activeExercises[index].setRows[rowIdx] },
                            set: { viewModel.activeExercises[index].setRows[rowIdx] = $0 }
                        ),
                        setNumber: rowIdx + 1,
                        previousWeight: exercise.previousSets.indices.contains(rowIdx)
                            ? exercise.previousSets[rowIdx].weightKg : nil,
                        previousReps: exercise.previousSets.indices.contains(rowIdx)
                            ? exercise.previousSets[rowIdx].reps : nil,
                        onComplete: {
                            let row = viewModel.activeExercises[index].setRows[rowIdx]
                            Task { await viewModel.logSet(row, exerciseID: exercise.id) }
                        }
                    )
                    .padding(.horizontal, 4)
                }
            }

            addSetButton(exerciseID: exercise.id)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func exerciseHeader(exercise: ActiveExercise) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(exercise.targetSets) × \(exercise.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let rpe = exercise.targetRPE {
                        Text("@ RPE \(Int(rpe))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            completedSetsLabel(exercise: exercise)
        }
    }

    private func completedSetsLabel(exercise: ActiveExercise) -> some View {
        let completed = exercise.setRows.filter(\.isComplete).count
        let total = exercise.setRows.count
        return Text("\(completed)/\(total)")
            .font(.caption.bold())
            .foregroundStyle(completed == total && total > 0 ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemBackground))
            )
    }

    private func addSetButton(exerciseID: UUID) -> some View {
        Button {
            viewModel.addSet(to: exerciseID)
        } label: {
            Label("Add Set", systemImage: "plus.circle")
                .font(.caption.bold())
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Rest Timer Bar

    private var restTimerBar: some View {
        RestTimerView(
            totalSeconds: viewModel.restDurationSeconds,
            remainingSeconds: viewModel.restSecondsRemaining,
            isActive: viewModel.restTimerActive,
            onSkip: { viewModel.skipRest() }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            elapsedTimeLabel
        }
        ToolbarItem(placement: .topBarTrailing) {
            pauseResumeButton
        }
        ToolbarItem(placement: .bottomBar) {
            finishButton
        }
    }

    private var elapsedTimeLabel: some View {
        Label(formattedElapsed, systemImage: "timer")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var formattedElapsed: String {
        let h = viewModel.elapsedSeconds / 3600
        let m = (viewModel.elapsedSeconds % 3600) / 60
        let s = viewModel.elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var pauseResumeButton: some View {
        Button {
            if viewModel.phase == .active {
                viewModel.pauseSession()
            } else if viewModel.phase == .paused {
                viewModel.resumeSession()
            }
        } label: {
            Image(systemName: viewModel.phase == .paused ? "play.fill" : "pause.fill")
        }
        .disabled(viewModel.phase == .idle || viewModel.phase == .complete)
    }

    private var finishButton: some View {
        Button {
            Task { await viewModel.finishSession() }
        } label: {
            Text("Finish Workout")
                .bold()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.phase != .active && viewModel.phase != .paused)
    }

    // MARK: - Alert Buttons

    @ViewBuilder
    private var abandonAlertButtons: some View {
        Button("Abandon", role: .destructive) {
            Task {
                await viewModel.abandonSession()
                dismiss()
            }
        }
        Button("Keep Training", role: .cancel) {}
    }

    // MARK: - Session Start Helper

    private func startSession() async {
        guard viewModel.phase == .idle else { return }
        let exercises = workoutDay.plannedExercises.sorted { $0.sortOrder < $1.sortOrder }
        guard !exercises.isEmpty else {
            // Still allow opening an empty session.
            let newSession = WorkoutSession(startedAt: .now, status: .active, workoutDay: workoutDay)
            try? await repository.saveWorkoutSession(newSession)
            return
        }

        // Build previous-sets map: fetch all historical sessions for this day.
        // Key by Exercise.exerciseID (String) so the lookup survives object identity changes.
        var previousSetsMap: [String: [LoggedSet]] = [:]
        if let allSessions = try? await repository.fetchWorkoutSessions(),
           let lastSession = allSessions
            .filter({ $0.workoutDay?.id == workoutDay.id && $0.status == .complete })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first {
            for set in lastSession.sets {
                guard let exerciseID = set.exercise?.exerciseID else { continue }
                previousSetsMap[exerciseID, default: []].append(set)
            }
        }

        await viewModel.startSession(
            day: workoutDay,
            exercises: exercises,
            previousSetsMap: previousSetsMap
        )
    }
}

// MARK: - Preview

#Preview {
    let plan = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 6)
    let day = WorkoutDay(dayLabel: "Push A", weekdayIndex: 2, workoutPlan: plan)

    let bench = Exercise(exerciseID: "bench", name: "Barbell Bench Press",
                         muscleGroup: "Chest", equipment: "Barbell",
                         instructions: "Lie on bench…", imageName: "bench_press")
    let ohp = Exercise(exerciseID: "ohp", name: "Overhead Press",
                       muscleGroup: "Shoulders", equipment: "Barbell",
                       instructions: "Stand and press…", imageName: "ohp")

    let e1 = PlannedExercise(targetSets: 4, targetReps: "6-8", targetRPE: 8, sortOrder: 0,
                              workoutDay: day, exercise: bench)
    let e2 = PlannedExercise(targetSets: 3, targetReps: "10-12", sortOrder: 1,
                              workoutDay: day, exercise: ohp)
    day.plannedExercises = [e1, e2]

    return SessionView(
        workoutDay: day,
        repository: PreviewSessionRepository()
    )
}

// MARK: - PreviewSessionRepository

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
