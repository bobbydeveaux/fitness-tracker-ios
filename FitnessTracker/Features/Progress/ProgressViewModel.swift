import Foundation
import Observation

// MARK: - TimeRange

/// Time range options for progress chart filtering.
enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek    = "1W"
    case oneMonth   = "1M"
    case threeMonths = "3M"
    case allTime    = "All"

    var id: String { rawValue }

    /// Human-readable label shown in the picker.
    var displayTitle: String { rawValue }

    /// The start `Date` for this range, or `nil` for all-time.
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .oneWeek:      return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        case .oneMonth:     return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:  return calendar.date(byAdding: .month, value: -3, to: now)
        case .allTime:      return nil
        }
    }
}

// MARK: - WeightDataPoint

/// A single bodyweight entry for use in a chart.
struct WeightDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let weightKg: Double
}

// MARK: - StrengthDataPoint

/// A single estimated 1RM data point for a specific exercise, for use in a chart.
struct StrengthDataPoint: Identifiable {
    let id: UUID
    let date: Date
    /// Epley-formula estimated 1RM in kg.
    let estimatedOneRMKg: Double
    let exerciseName: String
}

// MARK: - ExerciseInfo

/// Lightweight identifier + name for an exercise, used to populate the exercise picker.
struct ExerciseInfo: Identifiable, Hashable {
    let id: String   // Exercise.exerciseID
    let name: String
}

// MARK: - ProgressViewModel

/// ViewModel for the Progress feature screen.
///
/// Aggregates bodyweight trend data and per-exercise Epley 1RM estimates from
/// the `ProgressRepository` and `WorkoutRepository`. Supports filtering by
/// `TimeRange` (1W, 1M, 3M, All). For all-time data, results are down-sampled
/// to weekly averages to keep aggregation under 300 ms.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = ProgressViewModel(
///     progressRepository: env.progressRepository,
///     workoutRepository: env.workoutRepository
/// )
///
/// var body: some View {
///     ProgressView(viewModel: viewModel)
///         .task { await viewModel.loadProgress(for: profile) }
/// }
/// ```
@Observable
@MainActor
final class ProgressViewModel {

    // MARK: - State

    /// The currently selected time range; changing this triggers a data reload.
    var selectedRange: TimeRange = .oneMonth {
        didSet {
            guard selectedRange != oldValue else { return }
            Task { await reload() }
        }
    }

    /// Bodyweight data points for the selected time range.
    private(set) var weightDataPoints: [WeightDataPoint] = []

    /// Per-exercise Epley 1RM data points keyed by `ExerciseInfo.id`.
    private(set) var strengthDataPoints: [String: [StrengthDataPoint]] = [:]

    /// Exercises that have at least one logged set in the selected range.
    private(set) var availableExercises: [ExerciseInfo] = []

    /// The exercise currently shown in the StrengthChartView.
    var selectedExercise: ExerciseInfo?

    /// `true` while data is being loaded.
    private(set) var isLoading: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    // MARK: - Derived

    /// Strength data points for the currently selected exercise.
    var currentStrengthPoints: [StrengthDataPoint] {
        guard let exercise = selectedExercise else { return [] }
        return strengthDataPoints[exercise.id] ?? []
    }

    // MARK: - Dependencies

    private let progressRepository: any ProgressRepository
    private let workoutRepository: any WorkoutRepository

    /// The user profile used to scope queries; stored on first `loadProgress(for:)` call.
    private var userProfile: UserProfile?

    // MARK: - Init

    /// Creates a `ProgressViewModel` with the required repository dependencies.
    ///
    /// - Parameters:
    ///   - progressRepository: Source of `BodyMetric` records.
    ///   - workoutRepository: Source of `WorkoutSession` and `LoggedSet` records.
    init(
        progressRepository: any ProgressRepository,
        workoutRepository: any WorkoutRepository
    ) {
        self.progressRepository = progressRepository
        self.workoutRepository = workoutRepository
    }

    // MARK: - Public API

    /// Loads all progress data for `userProfile` using the current `selectedRange`.
    ///
    /// This is the primary entry point called from the view's `.task {}` modifier.
    func loadProgress(for userProfile: UserProfile) async {
        self.userProfile = userProfile
        await reload()
    }

    /// Re-fetches data for the current `selectedRange` without changing the user profile.
    ///
    /// Called automatically when `selectedRange` changes.
    func reload() async {
        guard let profile = userProfile else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let weightTask: Void = loadWeightData(for: profile)
        async let strengthTask: Void = loadStrengthData()

        await (weightTask, strengthTask)
    }

    // MARK: - Private – Weight

    private func loadWeightData(for profile: UserProfile) async {
        do {
            let allMetrics = try await progressRepository.fetchBodyMetrics(for: profile)
            let weightMetrics = allMetrics.filter { $0.type == .weight }
            let filtered = filter(metrics: weightMetrics, for: selectedRange)
            let rawPoints = filtered.map { metric in
                WeightDataPoint(id: metric.id, date: metric.date, weightKg: metric.value)
            }
            weightDataPoints = selectedRange == .allTime
                ? downsampleToWeeklyAverages(rawPoints)
                : rawPoints
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private – Strength

    private func loadStrengthData() async {
        do {
            let sessions: [WorkoutSession]
            if let start = selectedRange.startDate {
                sessions = try await workoutRepository.fetchWorkoutSessions(from: start, to: Date())
            } else {
                sessions = try await workoutRepository.fetchWorkoutSessions()
            }

            // Group logged sets by exercise and compute daily best Epley 1RM.
            var pointsByExercise: [String: [StrengthDataPoint]] = [:]
            var exerciseNames: [String: String] = [:]

            for session in sessions {
                let sessionDay = Calendar.current.startOfDay(for: session.startedAt)

                for set in session.sets where set.isComplete && set.reps > 0 {
                    guard let exercise = set.exercise else { continue }
                    let exerciseID = exercise.exerciseID
                    exerciseNames[exerciseID] = exercise.name

                    let oneRM = epleyOneRM(weightKg: set.weightKg, reps: set.reps)
                    let point = StrengthDataPoint(
                        id: set.id,
                        date: sessionDay,
                        estimatedOneRMKg: oneRM,
                        exerciseName: exercise.name
                    )

                    if var existing = pointsByExercise[exerciseID] {
                        // Keep only the best 1RM per day to avoid clutter.
                        if let idx = existing.firstIndex(where: {
                            Calendar.current.isDate($0.date, inSameDayAs: sessionDay)
                        }) {
                            if oneRM > existing[idx].estimatedOneRMKg {
                                existing[idx] = point
                            }
                        } else {
                            existing.append(point)
                        }
                        pointsByExercise[exerciseID] = existing
                    } else {
                        pointsByExercise[exerciseID] = [point]
                    }
                }
            }

            // Sort each exercise's points chronologically.
            for key in pointsByExercise.keys {
                pointsByExercise[key]?.sort { $0.date < $1.date }
            }

            let exercises = exerciseNames.map { id, name in
                ExerciseInfo(id: id, name: name)
            }.sorted { $0.name < $1.name }

            strengthDataPoints = pointsByExercise
            availableExercises = exercises

            // Default-select the first exercise if none selected.
            if selectedExercise == nil || !exercises.contains(where: { $0.id == selectedExercise?.id }) {
                selectedExercise = exercises.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private – Helpers

    /// Filters body metrics so that only entries within the selected range are returned.
    private func filter(metrics: [BodyMetric], for range: TimeRange) -> [BodyMetric] {
        guard let start = range.startDate else { return metrics }
        let end = Date()
        return metrics.filter { $0.date >= start && $0.date <= end }
    }

    /// Epley formula: `1RM = weight × (1 + reps / 30)`.
    private func epleyOneRM(weightKg: Double, reps: Int) -> Double {
        guard reps > 0 else { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    /// Reduces a dense array of `WeightDataPoint`s to one averaged point per ISO calendar week.
    ///
    /// Used for the all-time range to keep chart rendering fast (< 300 ms).
    private func downsampleToWeeklyAverages(_ points: [WeightDataPoint]) -> [WeightDataPoint] {
        let calendar = Calendar(identifier: .iso8601)
        var buckets: [DateComponents: [Double]] = [:]

        for point in points {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
            buckets[components, default: []].append(point.weightKg)
        }

        return buckets.compactMap { components, values -> WeightDataPoint? in
            guard let weekStart = calendar.date(from: components) else { return nil }
            let avg = values.reduce(0, +) / Double(values.count)
            return WeightDataPoint(id: UUID(), date: weekStart, weightKg: avg)
        }.sorted { $0.date < $1.date }
    }
}
