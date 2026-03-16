import Foundation

// MARK: - Protocol (implemented fully in task-ios-fitness-tracker-app-feat-foundation-3)

/// Provides async CRUD access to `FoodItem`, `MealLog`, and `MealEntry` records.
protocol NutritionRepository: Sendable {
    func fetchMealLogs(for date: Date) async throws -> [MealLog]
    func save(_ mealLog: MealLog) async throws
    func delete(_ mealLog: MealLog) async throws
    func fetchFoodItems(matching query: String) async throws -> [FoodItem]
    func save(_ foodItem: FoodItem) async throws
}
