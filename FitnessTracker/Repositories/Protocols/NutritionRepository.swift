import Foundation

/// Protocol defining async/throws CRUD and query operations for nutrition data.
/// Consumers must not import SwiftData directly; all access goes through this abstraction.
public protocol NutritionRepository: Sendable {

    // MARK: - FoodItem

    /// Returns all food items ordered by name ascending.
    func fetchFoodItems() async throws -> [FoodItem]

    /// Returns the food item with the given identifier, or nil if not found.
    func fetchFoodItem(byID id: UUID) async throws -> FoodItem?

    /// Searches food items whose name contains the given query string (case-insensitive).
    func searchFoodItems(query: String) async throws -> [FoodItem]

    /// Persists a new or updated FoodItem.
    func saveFoodItem(_ item: FoodItem) async throws

    /// Removes the given FoodItem.
    func deleteFoodItem(_ item: FoodItem) async throws

    // MARK: - MealLog

    /// Returns all MealLogs recorded on the given calendar day.
    func fetchMealLogs(for date: Date) async throws -> [MealLog]

    /// Returns all MealLogs in the given date range (inclusive).
    func fetchMealLogs(from startDate: Date, to endDate: Date) async throws -> [MealLog]

    /// Persists a new or updated MealLog.
    func saveMealLog(_ log: MealLog) async throws

    /// Removes the MealLog and its cascade-deleted MealEntry children.
    func deleteMealLog(_ log: MealLog) async throws

    // MARK: - MealEntry

    /// Adds a MealEntry to the given MealLog and persists both.
    func addMealEntry(_ entry: MealEntry, to log: MealLog) async throws

    /// Removes a MealEntry and persists the change.
    func removeMealEntry(_ entry: MealEntry) async throws
}
