import Foundation
import Observation

// MARK: - NutritionViewModel

/// `@Observable` view model driving the Nutrition feature screen.
///
/// Loads today's (or any selected day's) meal logs from `NutritionRepository`
/// and computes running macro totals (kcal, protein, carbs, fat) across all
/// logged entries. Macro targets are sourced from the persisted `UserProfile`
/// so progress rings and the dashboard can always reflect the latest goal.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = NutritionViewModel(
///     nutritionRepository: env.nutritionRepository,
///     userProfileRepository: env.userProfileRepository
/// )
///
/// var body: some View {
///     NutritionView()
///         .task { await viewModel.load() }
/// }
/// ```
@Observable
@MainActor
final class NutritionViewModel {

    // MARK: - Date Selection

    /// The calendar day currently displayed. Defaults to today.
    /// After changing this property call `load()` to refresh the meal data.
    var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    // MARK: - Meal State

    /// All `MealLog` records fetched for `selectedDate`, ordered by time ascending.
    private(set) var mealLogs: [MealLog] = []

    /// `true` while a repository fetch or write is in flight.
    private(set) var isLoading: Bool = false

    /// Non-nil when a repository operation fails. Reset to `nil` at the start of
    /// each new operation.
    private(set) var errorMessage: String? = nil

    // MARK: - Macro Targets (from UserProfile)

    /// Daily calorie target in kcal (sourced from `UserProfile.tdeeKcal`).
    private(set) var kcalTarget: Double = 2000

    /// Daily protein target in grams (sourced from `UserProfile.proteinTargetG`).
    private(set) var proteinTarget: Double = 150

    /// Daily carbohydrate target in grams (sourced from `UserProfile.carbTargetG`).
    private(set) var carbTarget: Double = 200

    /// Daily fat target in grams (sourced from `UserProfile.fatTargetG`).
    private(set) var fatTarget: Double = 65

    // MARK: - Computed Macro Totals

    /// All `MealEntry` records from every `MealLog` for the selected day.
    var allEntries: [MealEntry] {
        mealLogs.flatMap(\.entries)
    }

    /// Total kilocalories consumed across all meal entries for `selectedDate`.
    var totalKcal: Double {
        allEntries.reduce(0) { $0 + $1.kcal }
    }

    /// Total protein consumed in grams for `selectedDate`.
    var totalProteinG: Double {
        allEntries.reduce(0) { $0 + $1.proteinG }
    }

    /// Total carbohydrates consumed in grams for `selectedDate`.
    var totalCarbG: Double {
        allEntries.reduce(0) { $0 + $1.carbG }
    }

    /// Total fat consumed in grams for `selectedDate`.
    var totalFatG: Double {
        allEntries.reduce(0) { $0 + $1.fatG }
    }

    /// Progress fraction (0–1) for calories relative to the daily target.
    var kcalProgress: Double {
        guard kcalTarget > 0 else { return 0 }
        return min(totalKcal / kcalTarget, 1)
    }

    /// Progress fraction (0–1) for protein relative to the daily target.
    var proteinProgress: Double {
        guard proteinTarget > 0 else { return 0 }
        return min(totalProteinG / proteinTarget, 1)
    }

    /// Progress fraction (0–1) for carbohydrates relative to the daily target.
    var carbProgress: Double {
        guard carbTarget > 0 else { return 0 }
        return min(totalCarbG / carbTarget, 1)
    }

    /// Progress fraction (0–1) for fat relative to the daily target.
    var fatProgress: Double {
        guard fatTarget > 0 else { return 0 }
        return min(totalFatG / fatTarget, 1)
    }

    // MARK: - Dependencies

    private let nutritionRepository: any NutritionRepository
    private let userProfileRepository: any UserProfileRepository

    // MARK: - Init

    /// - Parameters:
    ///   - nutritionRepository: Source of `MealLog` / `MealEntry` persistence.
    ///   - userProfileRepository: Source of macro targets from the user's profile.
    init(
        nutritionRepository: any NutritionRepository,
        userProfileRepository: any UserProfileRepository
    ) {
        self.nutritionRepository = nutritionRepository
        self.userProfileRepository = userProfileRepository
    }

    // MARK: - Data Loading

    /// Fetches meal logs and macro targets for `selectedDate`.
    ///
    /// Call this from a SwiftUI `.task` modifier when the view appears, and
    /// whenever `selectedDate` changes. Concurrent calls are allowed; each
    /// replaces the in-flight state.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let logs = nutritionRepository.fetchMealLogs(for: selectedDate)
            async let profile = userProfileRepository.fetch()

            let (fetchedLogs, fetchedProfile) = try await (logs, profile)
            mealLogs = fetchedLogs

            if let profile = fetchedProfile {
                kcalTarget = profile.tdeeKcal
                proteinTarget = profile.proteinTargetG
                carbTarget = profile.carbTargetG
                fatTarget = profile.fatTargetG
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Meal Entry Management

    /// Adds a `MealEntry` to the log for the given meal type on `selectedDate`.
    ///
    /// If a `MealLog` already exists for that meal type on the selected day it is
    /// reused; otherwise a new one is created and persisted first. The macro totals
    /// update immediately after the entry is saved.
    ///
    /// - Parameters:
    ///   - entry: The pre-constructed `MealEntry` to persist.
    ///   - mealType: The meal slot (breakfast, lunch, dinner, or snack) to add the entry to.
    func addEntry(_ entry: MealEntry, toMealType mealType: MealType) async {
        errorMessage = nil

        do {
            // Reuse an existing MealLog for this slot or create a new one.
            let log: MealLog
            if let existing = mealLogs.first(where: { $0.mealType == mealType }) {
                log = existing
            } else {
                let newLog = MealLog(date: selectedDate, mealType: mealType)
                try await nutritionRepository.saveMealLog(newLog)
                log = newLog
            }

            try await nutritionRepository.addMealEntry(entry, to: log)
            // Reload to pick up the persisted state (including any relationship hydration).
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes a `MealEntry` from its parent `MealLog` and refreshes totals.
    ///
    /// - Parameter entry: The entry to delete.
    func removeEntry(_ entry: MealEntry) async {
        errorMessage = nil

        do {
            try await nutritionRepository.removeMealEntry(entry)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an entire `MealLog` (and its cascade-deleted entries) for `selectedDate`.
    ///
    /// - Parameter log: The meal log to delete.
    func deleteMealLog(_ log: MealLog) async {
        errorMessage = nil

        do {
            try await nutritionRepository.deleteMealLog(log)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
