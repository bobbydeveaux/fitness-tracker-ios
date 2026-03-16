import SwiftUI

// MARK: - WorkoutPlanView

/// Displays the user's active `WorkoutPlan` as a scrollable list of
/// `WorkoutDayCard` components — one card per training day in the plan.
///
/// States handled:
/// - **Loading** — `ProgressView` centred on screen while the repository query
///   is in flight.
/// - **No active plan** — `ContentUnavailableView` prompting the user to
///   generate a plan via the Claude AI integration (future feature).
/// - **Active plan** — plan header followed by `WorkoutDayCard` rows sorted by
///   `weekdayIndex`.
/// - **Error** — inline error banner with the localised error description.
///
/// The view is driven by `WorkoutPlanViewModel` which is created once and
/// stored as `@State` so SwiftUI can observe `@Observable` mutations.
struct WorkoutPlanView: View {

    // MARK: - Dependencies

    @Environment(AppEnvironment.self) private var env

    // MARK: - State

    @State private var viewModel: WorkoutPlanViewModel

    // MARK: - Init

    init(repository: any WorkoutRepository) {
        _viewModel = State(initialValue: WorkoutPlanViewModel(repository: repository))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Workout Plan")
                .navigationBarTitleDisplayMode(.large)
                .task { await viewModel.loadActivePlan() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            errorBanner(message: errorMessage)
        } else if let plan = viewModel.activePlan {
            planScrollView(plan: plan)
        } else {
            emptyState
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView(
            "No Active Plan",
            systemImage: "dumbbell",
            description: Text("Generate a personalised workout plan using the AI coach to get started.")
        )
    }

    private func errorBanner(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Failed to load plan")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.loadActivePlan() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func planScrollView(plan: WorkoutPlan) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PlanHeaderCard(
                    splitLabel: viewModel.splitLabel,
                    daysPerWeek: plan.daysPerWeek,
                    generatedAt: plan.generatedAt
                )

                if viewModel.sortedDays.isEmpty {
                    Text("No training days have been added to this plan yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                } else {
                    ForEach(viewModel.sortedDays, id: \.id) { day in
                        WorkoutDayCard(day: day)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - PlanHeaderCard

/// A summary card shown at the top of `WorkoutPlanView` with plan-level metadata.
private struct PlanHeaderCard: View {

    let splitLabel: String
    let daysPerWeek: Int
    let generatedAt: Date

    private var generatedAtLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Generated \(formatter.string(from: generatedAt))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Active Plan", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(splitLabel)
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.tint)
            }

            HStack(spacing: 16) {
                StatPill(
                    value: "\(daysPerWeek)",
                    label: "days / week",
                    icon: "calendar",
                    color: .blue
                )
                StatPill(
                    value: generatedAtLabel,
                    label: "",
                    icon: "clock",
                    color: .secondary
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - StatPill

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.bold())
                if !label.isEmpty {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("WorkoutPlanView – active plan") {
    let plan = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 6)

    let days: [(String, Int)] = [
        ("Push A", 2), ("Pull A", 3), ("Legs A", 4),
        ("Push B", 5), ("Pull B", 6), ("Legs B", 7)
    ]
    let bench = Exercise(exerciseID: "bench", name: "Barbell Bench Press",
                         muscleGroup: "Chest", equipment: "Barbell",
                         instructions: "", imageName: "bench_press")
    let squat = Exercise(exerciseID: "squat", name: "Back Squat",
                         muscleGroup: "Quadriceps", equipment: "Barbell",
                         instructions: "", imageName: "squat")

    for (label, idx) in days {
        let day = WorkoutDay(dayLabel: label, weekdayIndex: idx, workoutPlan: plan)
        let e1 = PlannedExercise(targetSets: 4, targetReps: "6-8", targetRPE: 8, sortOrder: 0, exercise: bench)
        let e2 = PlannedExercise(targetSets: 3, targetReps: "10", sortOrder: 1, exercise: squat)
        day.plannedExercises = [e1, e2]
        plan.days.append(day)
    }

    let repo = PreviewWorkoutRepository(plan: plan)
    return WorkoutPlanView(repository: repo)
        .environment(AppEnvironment.makeProductionEnvironment())
}

#Preview("WorkoutPlanView – no plan") {
    WorkoutPlanView(repository: PreviewWorkoutRepository(plan: nil))
        .environment(AppEnvironment.makeProductionEnvironment())
}

// MARK: - PreviewWorkoutRepository

private final class PreviewWorkoutRepository: WorkoutRepository, @unchecked Sendable {
    private let plan: WorkoutPlan?
    init(plan: WorkoutPlan?) { self.plan = plan }

    func fetchExercises() async throws -> [Exercise] { [] }
    func fetchExercise(byID id: UUID) async throws -> Exercise? { nil }
    func saveExercise(_ exercise: Exercise) async throws {}
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] { plan.map { [$0] } ?? [] }
    func fetchActiveWorkoutPlan() async throws -> WorkoutPlan? { plan }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func deleteWorkoutPlan(_ plan: WorkoutPlan) async throws {}
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }
    func fetchWorkoutSessions(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] { [] }
    func saveWorkoutSession(_ session: WorkoutSession) async throws {}
    func deleteWorkoutSession(_ session: WorkoutSession) async throws {}
    func logSet(_ set: LoggedSet, for session: WorkoutSession) async throws {}
}
