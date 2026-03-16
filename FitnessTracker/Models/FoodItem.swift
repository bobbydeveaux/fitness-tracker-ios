import Foundation
import SwiftData

// MARK: - FoodItem

/// Represents a food item either bundled as seed data or created by the user.
@Model
final class FoodItem {

    @Attribute(.unique) var id: UUID

    var name: String
    var barcode: String?

    // Nutritional values per 100 g
    var kcalPer100g: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double

    /// `true` for user-created items; `false` for seeded/bundled items.
    var isCustom: Bool

    var createdAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \MealEntry.foodItem)
    var mealEntries: [MealEntry] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        name: String,
        barcode: String? = nil,
        kcalPer100g: Double,
        proteinG: Double,
        carbG: Double,
        fatG: Double,
        isCustom: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.kcalPer100g = kcalPer100g
        self.proteinG = proteinG
        self.carbG = carbG
        self.fatG = fatG
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}
