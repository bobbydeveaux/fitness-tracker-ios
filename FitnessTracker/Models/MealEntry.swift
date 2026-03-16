import Foundation
import SwiftData

// MARK: - MealEntry

/// A single food item consumed as part of a `MealLog`.
@Model
final class MealEntry {

    @Attribute(.unique) var id: UUID

    var servingGrams: Double

    // Computed nutritional values for this serving
    var kcal: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double

    // MARK: - Relationships

    var mealLog: MealLog?
    var foodItem: FoodItem?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        servingGrams: Double,
        kcal: Double,
        proteinG: Double,
        carbG: Double,
        fatG: Double,
        mealLog: MealLog? = nil,
        foodItem: FoodItem? = nil
    ) {
        self.id = id
        self.servingGrams = servingGrams
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbG = carbG
        self.fatG = fatG
        self.mealLog = mealLog
        self.foodItem = foodItem
    }
}
