import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    /// Optional barcode (EAN-13 / UPC-A)
    var barcode: String?
    /// Calories per 100 g
    var caloriesPer100g: Double
    /// Protein per 100 g
    var proteinPer100g: Double
    /// Carbohydrates per 100 g
    var carbsPer100g: Double
    /// Fat per 100 g
    var fatPer100g: Double
    /// True when the user created this entry rather than importing from a shared library
    var isCustom: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \MealEntry.foodItem)
    var mealEntries: [MealEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        barcode: String? = nil,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        isCustom: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}
