import Foundation
import Observation
import SwiftData

// MARK: - NutritionViewModel

/// `@Observable` view model driving the Nutrition feature screen.
///
/// Loads today's `MealLog` records (grouped by meal type), aggregates macro
/// totals in real time, and exposes add/remove actions that update both the
/// persistent store and the in-memory state atomically.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel: NutritionViewModel
///
/// init(env: AppEnvironment) {
///     _viewModel = State(initialValue: NutritionViewModel(
///         repository: env.nutritionRepository
///     ))
/// }
/// ```
@Observable
@MainActor
final class NutritionViewModel {

    // MARK: - State

    /// Meal logs for the currently selected date, sorted by meal type order.
    private(set) var mealLogs: [MealLog] = []

    /// `true` while the repository query is in flight.
    private(set) var isLoading: Bool = false

    /// Non-nil when an error occurred during the last async operation.
    private(set) var errorMessage: String?

    /// The date whose nutrition data is displayed. Defaults to today.
    var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    // MARK: - Macro Aggregates (live, derived from mealLogs)

    var totalKcal: Double {
        mealLogs.flatMap(\.entries).reduce(0) { $0 + $1.kcal }
    }

    var totalProteinG: Double {
        mealLogs.flatMap(\.entries).reduce(0) { $0 + $1.proteinG }
    }

    var totalCarbG: Double {
        mealLogs.flatMap(\.entries).reduce(0) { $0 + $1.carbG }
    }

    var totalFatG: Double {
        mealLogs.flatMap(\.entries).reduce(0) { $0 + $1.fatG }
    }

    // MARK: - Dependencies

    private let repository: any NutritionRepository

    // MARK: - Init

    init(repository: any NutritionRepository) {
        self.repository = repository
    }

    // MARK: - Data Loading

    /// Fetches meal logs for `selectedDate` and refreshes `mealLogs`.
    func loadTodaysLogs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            mealLogs = try await repository.fetchMealLogs(for: selectedDate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Meal Log Management

    /// Returns the `MealLog` for the given `MealType` on `selectedDate`,
    /// creating and persisting a new one if it does not yet exist.
    func getOrCreateMealLog(for mealType: MealType) async throws -> MealLog {
        if let existing = mealLogs.first(where: { $0.mealType == mealType }) {
            return existing
        }
        let log = MealLog(date: selectedDate, mealType: mealType)
        try await repository.saveMealLog(log)
        mealLogs.append(log)
        return log
    }

    // MARK: - Entry Management

    /// Creates a `MealEntry` for the given food item / serving size,
    /// appends it to the appropriate `MealLog`, and persists the change.
    ///
    /// - Parameters:
    ///   - foodItem: The food item to log.
    ///   - servingGrams: Serving size in grams.
    ///   - mealType: The meal type (breakfast, lunch, etc.) to add it to.
    func addEntry(
        foodItem: FoodItem,
        servingGrams: Double,
        mealType: MealType
    ) async {
        errorMessage = nil
        do {
            let log = try await getOrCreateMealLog(for: mealType)

            let factor = servingGrams / 100.0
            let entry = MealEntry(
                servingGrams: servingGrams,
                kcal: foodItem.kcalPer100g * factor,
                proteinG: foodItem.proteinG * factor,
                carbG: foodItem.carbG * factor,
                fatG: foodItem.fatG * factor,
                foodItem: foodItem
            )
            try await repository.addMealEntry(entry, to: log)

            // Refresh in-memory state
            await loadTodaysLogs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes a `MealEntry` from its parent log and persists the deletion.
    func removeEntry(_ entry: MealEntry) async {
        errorMessage = nil
        do {
            try await repository.removeMealEntry(entry)
            await loadTodaysLogs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an entire `MealLog` (and its cascade-deleted entries).
    func deleteMealLog(_ log: MealLog) async {
        errorMessage = nil
        do {
            try await repository.deleteMealLog(log)
            mealLogs.removeAll { $0.id == log.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
