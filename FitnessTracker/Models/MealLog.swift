import Foundation
import SwiftData

// MARK: - Supporting Enum

enum MealType: String, Codable {
    case breakfast
    case lunch
    case dinner
    case snack
}

// MARK: - MealLog Model

/// Groups all food entries for a single meal occasion on a given day.
@Model
final class MealLog {
    var id: UUID
    /// Calendar date of this meal (time component should be normalised to midnight UTC)
    @Attribute(.index) var date: Date
    var mealType: MealType

    @Relationship(deleteRule: .cascade, inverse: \MealEntry.mealLog)
    var entries: [MealEntry] = []

    init(
        id: UUID = UUID(),
        date: Date,
        mealType: MealType
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
    }
}
