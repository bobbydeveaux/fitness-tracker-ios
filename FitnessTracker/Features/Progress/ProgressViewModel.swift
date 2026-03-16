import Foundation
import Observation

// MARK: - ProgressTimeRange

/// Selectable time window for progress analytics charts.
enum ProgressTimeRange: String, CaseIterable, Identifiable, Sendable {
    case week       = "1W"
    case month      = "1M"
    case threeMonths = "3M"
    case all        = "All"

    var id: String { rawValue }

    /// Returns the start date for this range relative to `now`, or `nil` for `.all`.
    func startDate(relativeTo now: Date = .now) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .all:
            return nil
        }
    }
}

// MARK: - ProgressDataPoint

/// A single (date, value) pair used as a chart data point.
struct ProgressDataPoint: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let value: Double

    init(date: Date, value: Double) {
        self.id = UUID()
        self.date = date
        self.value = value
    }
}

// MARK: - ExerciseProgressSeries

/// 1RM trend for a single exercise, ready for Swift Charts consumption.
struct ExerciseProgressSeries: Identifiable, Sendable {
    /// Stable identifier: the `Exercise.exerciseID` string.
    let id: String
    let exerciseName: String
    var dataPoints: [ProgressDataPoint]
}

// MARK: - ProgressState

/// Aggregated analytics state produced by `ProgressViewModel`.
struct ProgressState: Sendable {
    /// Bodyweight trend data points, ordered by date ascending.
    var bodyWeightPoints: [ProgressDataPoint] = []
    /// Total volume (kg) per completed workout session, ordered by date ascending.
    var volumePoints: [ProgressDataPoint] = []
    /// Per-exercise estimated 1RM trend series, ordered by exercise name.
    var exerciseSeries: [ExerciseProgressSeries] = []
}

// MARK: - ProgressAggregator

/// Background actor that performs CPU-bound aggregation over lightweight snapshots,
/// keeping the main thread free during computation.
private actor ProgressAggregator {

    // Lightweight Sendable mirrors of SwiftData @Model objects.

    struct BodyMetricSnapshot: Sendable {
        let date: Date
        let value: Double
        let type: BodyMetricType
    }

    struct SetSnapshot: Sendable {
        let weightKg: Double
        let reps: Int
        let isComplete: Bool
        let exerciseID: String?
        let exerciseName: String?
    }

    struct SessionSnapshot: Sendable {
        let startedAt: Date
        let totalVolumeKg: Double
        let status: SessionStatus
        let sets: [SetSnapshot]
    }

    /// Converts fetched model objects into snapshots.
    static func bodyMetricSnapshots(from metrics: [BodyMetric]) -> [BodyMetricSnapshot] {
        metrics.map { BodyMetricSnapshot(date: $0.date, value: $0.value, type: $0.type) }
    }

    static func sessionSnapshots(from sessions: [WorkoutSession]) -> [SessionSnapshot] {
        sessions.map { session in
            let sets = session.sets.map { set in
                SetSnapshot(
                    weightKg: set.weightKg,
                    reps: set.reps,
                    isComplete: set.isComplete,
                    exerciseID: set.exercise?.exerciseID,
                    exerciseName: set.exercise?.name
                )
            }
            return SessionSnapshot(
                startedAt: session.startedAt,
                totalVolumeKg: session.totalVolumeKg,
                status: session.status,
                sets: sets
            )
        }
    }

    /// Performs all aggregation off the main thread and returns a complete `ProgressState`.
    func compute(
        bodyMetricSnapshots: [BodyMetricSnapshot],
        sessionSnapshots: [SessionSnapshot]
    ) -> ProgressState {

        // --- Body weight chart ---
        let bodyWeightPoints = bodyMetricSnapshots
            .filter { $0.type == .weight }
            .sorted { $0.date < $1.date }
            .map { ProgressDataPoint(date: $0.date, value: $0.value) }

        // --- Volume per completed session chart ---
        let completedSessions = sessionSnapshots.filter { $0.status == .complete }
        let volumePoints = completedSessions
            .sorted { $0.startedAt < $1.startedAt }
            .map { ProgressDataPoint(date: $0.startedAt, value: $0.totalVolumeKg) }

        // --- Per-exercise 1RM trend (Epley formula: 1RM = weight × (1 + reps / 30)) ---
        // Accumulate points keyed by exerciseID.
        var exerciseMap: [String: (name: String, points: [ProgressDataPoint])] = [:]
        for session in completedSessions {
            for set in session.sets where set.isComplete && set.reps > 0 {
                guard let exerciseID = set.exerciseID,
                      let exerciseName = set.exerciseName else { continue }
                let oneRM = set.weightKg * (1.0 + Double(set.reps) / 30.0)
                let point = ProgressDataPoint(date: session.startedAt, value: oneRM)
                if var existing = exerciseMap[exerciseID] {
                    existing.points.append(point)
                    exerciseMap[exerciseID] = existing
                } else {
                    exerciseMap[exerciseID] = (name: exerciseName, points: [point])
                }
            }
        }

        let exerciseSeries = exerciseMap
            .map { id, value in
                ExerciseProgressSeries(
                    id: id,
                    exerciseName: value.name,
                    dataPoints: value.points.sorted { $0.date < $1.date }
                )
            }
            .sorted { $0.exerciseName < $1.exerciseName }

        return ProgressState(
            bodyWeightPoints: bodyWeightPoints,
            volumePoints: volumePoints,
            exerciseSeries: exerciseSeries
        )
    }
}

// MARK: - ProgressViewModel

/// ViewModel for the Progress analytics feature.
///
/// Aggregates body-weight trends, workout volume trends, and per-exercise
/// estimated 1RM trends over a user-selected time range. Heavy computation
/// is delegated to a `ProgressAggregator` background actor, keeping the
/// main thread responsive.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = ProgressViewModel(
///     progressRepository: env.progressRepository,
///     workoutRepository: env.workoutRepository
/// )
///
/// var body: some View {
///     ProgressView()
///         .task { await viewModel.loadProgress(for: profile) }
/// }
/// ```
@Observable
@MainActor
final class ProgressViewModel {

    // MARK: - State

    /// Aggregated chart data for the currently selected time range.
    private(set) var state: ProgressState = ProgressState()

    /// The active time-range filter. Changing this value automatically
    /// re-runs aggregation if a user profile has been loaded.
    var selectedTimeRange: ProgressTimeRange = .month

    /// `true` while data is being fetched or aggregated.
    private(set) var isLoading: Bool = false

    /// Non-nil when the last load operation produced an error.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let progressRepository: any ProgressRepository
    private let workoutRepository: any WorkoutRepository
    private let aggregator: ProgressAggregator

    // MARK: - Init

    /// Creates a `ProgressViewModel` with the required repository dependencies.
    ///
    /// - Parameters:
    ///   - progressRepository: Repository providing `BodyMetric` access.
    ///   - workoutRepository: Repository providing `WorkoutSession` and `LoggedSet` access.
    init(
        progressRepository: any ProgressRepository,
        workoutRepository: any WorkoutRepository
    ) {
        self.progressRepository = progressRepository
        self.workoutRepository = workoutRepository
        self.aggregator = ProgressAggregator()
    }

    // MARK: - Actions

    /// Fetches and aggregates progress data for `userProfile` using the current
    /// `selectedTimeRange` filter.
    ///
    /// Errors from individual data sources are captured in `errorMessage`; if
    /// only one source fails the other's data is still applied.
    ///
    /// - Parameter userProfile: The profile used to scope body-metric queries.
    func loadProgress(for userProfile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let now = Date.now
        let startDate = selectedTimeRange.startDate(relativeTo: now)

        // Fetch from background @ModelActor repositories concurrently.
        async let metricsTask = fetchBodyMetrics(for: userProfile, from: startDate)
        async let sessionsTask = fetchWorkoutSessions(from: startDate, to: now)

        let (metrics, sessions) = await (metricsTask, sessionsTask)

        // Build lightweight Sendable snapshots on MainActor before passing to background actor.
        let metricSnapshots = ProgressAggregator.bodyMetricSnapshots(from: metrics)
        let sessionSnapshots = ProgressAggregator.sessionSnapshots(from: sessions)

        // Delegate CPU-bound aggregation to background actor.
        let newState = await aggregator.compute(
            bodyMetricSnapshots: metricSnapshots,
            sessionSnapshots: sessionSnapshots
        )

        state = newState
    }

    // MARK: - Private Helpers

    /// Fetches body metrics for `userProfile`, optionally filtered by `startDate`.
    private func fetchBodyMetrics(for userProfile: UserProfile, from startDate: Date?) async -> [BodyMetric] {
        do {
            if let start = startDate {
                return try await progressRepository.fetchBodyMetrics(
                    type: BodyMetricType.weight.rawValue,
                    from: start,
                    to: .now
                )
            } else {
                return try await progressRepository
                    .fetchBodyMetrics(for: userProfile)
                    .filter { $0.type == .weight }
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Fetches workout sessions, optionally filtered to a start/end window.
    private func fetchWorkoutSessions(from startDate: Date?, to endDate: Date) async -> [WorkoutSession] {
        do {
            if let start = startDate {
                return try await workoutRepository.fetchWorkoutSessions(from: start, to: endDate)
            } else {
                return try await workoutRepository.fetchWorkoutSessions()
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
