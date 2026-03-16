import Foundation
import SwiftData

// MARK: - MealTemplateItem

/// A single food item with a serving quantity stored inside a `MealTemplate`.
@Model
final class MealTemplateItem {

    @Attribute(.unique) var id: UUID

    /// Serving size in grams for this template item.
    var servingGrams: Double

    // MARK: - Relationships

    var template: MealTemplate?

    @Relationship(deleteRule: .nullify)
    var foodItem: FoodItem?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        servingGrams: Double,
        template: MealTemplate? = nil,
        foodItem: FoodItem? = nil
    ) {
        self.id = id
        self.servingGrams = servingGrams
        self.template = template
        self.foodItem = foodItem
    }
}
