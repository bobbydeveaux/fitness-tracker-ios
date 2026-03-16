import Foundation
import Observation

// MARK: - WorkoutPlanViewModel

/// `@Observable` view model driving `WorkoutPlanView`.
///
/// Loads the currently active `WorkoutPlan` from the repository and exposes the
/// plan's days sorted by `weekdayIndex` for display in `WorkoutPlanView`.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel: WorkoutPlanViewModel
///
/// init(repository: any WorkoutRepository) {
///     _viewModel = State(initialValue: WorkoutPlanViewModel(repository: repository))
/// }
/// ```
@Observable
@MainActor
final class WorkoutPlanViewModel {

    // MARK: - State

    /// The currently active workout plan, or `nil` if none exists.
    private(set) var activePlan: WorkoutPlan?

    /// `true` while the repository query is in flight.
    private(set) var isLoading: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    // MARK: - Derived

    /// Workout days sorted by weekday index (Sunday = 1 … Saturday = 7).
    var sortedDays: [WorkoutDay] {
        (activePlan?.days ?? []).sorted { $0.weekdayIndex < $1.weekdayIndex }
    }

    /// Human-readable split label, e.g. "Push / Pull / Legs".
    var splitLabel: String {
        guard let plan = activePlan else { return "" }
        switch plan.splitType {
        case .pushPullLegs:  return "Push / Pull / Legs"
        case .fullBody:      return "Full Body"
        case .upperLower:    return "Upper / Lower"
        }
    }

    // MARK: - Dependencies

    private let repository: any WorkoutRepository

    // MARK: - Init

    init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    // MARK: - Data Loading

    /// Fetches the active workout plan from the repository.
    func loadActivePlan() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            activePlan = try await repository.fetchActiveWorkoutPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
