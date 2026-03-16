import Foundation
import SwiftData

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-3)

/// SwiftData-backed implementation of `NutritionRepository`.
final class SwiftDataNutritionRepository: NutritionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchMealLogs(for date: Date) async throws -> [MealLog] { [] }
    func save(_ mealLog: MealLog) async throws {}
    func delete(_ mealLog: MealLog) async throws {}
    func fetchFoodItems(matching query: String) async throws -> [FoodItem] { [] }
    func save(_ foodItem: FoodItem) async throws {}
}
