import Foundation
import SwiftData

/// Records a single food item consumed within a MealLog, with serving size and computed macros.
@Model
final class MealEntry {
    var id: UUID
    /// Serving size in grams
    var servingGrams: Double
    /// Computed calories for this serving
    var calories: Double
    /// Computed protein in grams for this serving
    var proteinGrams: Double
    /// Computed carbohydrates in grams for this serving
    var carbGrams: Double
    /// Computed fat in grams for this serving
    var fatGrams: Double
    var loggedAt: Date

    var mealLog: MealLog?
    var foodItem: FoodItem?

    init(
        id: UUID = UUID(),
        servingGrams: Double,
        calories: Double,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.loggedAt = loggedAt
    }
}
