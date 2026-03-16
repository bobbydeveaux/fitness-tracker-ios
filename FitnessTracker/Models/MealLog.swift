import Foundation
import SwiftData

// MARK: - MealType

enum MealType: String, Codable {
    case breakfast
    case lunch
    case dinner
    case snack
}

// MARK: - MealLog

/// A daily meal container grouping one or more `MealEntry` items by meal type.
@Model
final class MealLog {

    @Attribute(.unique) var id: UUID

    @Attribute(.indexed) var date: Date
    var mealType: MealType

    // MARK: - Relationships

    var userProfile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \MealEntry.mealLog)
    var entries: [MealEntry] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        date: Date,
        mealType: MealType,
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.userProfile = userProfile
    }
}
