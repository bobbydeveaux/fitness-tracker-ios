import Foundation
import SwiftData

// MARK: - MealTemplate

/// A named collection of food items with serving quantities that can be saved
/// and re-applied to a meal log with a single tap.
@Model
final class MealTemplate {

    @Attribute(.unique) var id: UUID

    var name: String
    var createdAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \MealTemplateItem.template)
    var items: [MealTemplateItem] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
