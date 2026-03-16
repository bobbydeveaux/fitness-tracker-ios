import Foundation
import SwiftData

// MARK: - Supporting Enum

enum SplitType: String, Codable {
    case pushPullLegs
    case fullBody
    case upperLower
}

// MARK: - WorkoutPlan Model

/// An AI-generated training split containing ordered workout days.
@Model
final class WorkoutPlan {
    var id: UUID
    var splitType: SplitType
    var daysPerWeek: Int
    /// ISO-8601 timestamp of when the plan was generated via the Claude API
    var generatedAt: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.workoutPlan)
    var days: [WorkoutDay] = []

    init(
        id: UUID = UUID(),
        splitType: SplitType,
        daysPerWeek: Int,
        generatedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.splitType = splitType
        self.daysPerWeek = daysPerWeek
        self.generatedAt = generatedAt
        self.isActive = isActive
    }
}
