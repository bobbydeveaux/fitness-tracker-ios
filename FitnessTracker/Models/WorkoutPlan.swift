import Foundation
import SwiftData

// MARK: - SplitType

enum SplitType: String, Codable {
    case pushPullLegs = "PPL"
    case fullBody = "FullBody"
    case upperLower = "UpperLower"
}

// MARK: - WorkoutPlan

/// An AI-generated or custom training programme belonging to a `UserProfile`.
@Model
final class WorkoutPlan {

    @Attribute(.unique) var id: UUID

    var splitType: SplitType
    var daysPerWeek: Int
    var generatedAt: Date
    var isActive: Bool

    // MARK: - Relationships

    var userProfile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.workoutPlan)
    var days: [WorkoutDay] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        splitType: SplitType,
        daysPerWeek: Int,
        generatedAt: Date = .now,
        isActive: Bool = true,
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.splitType = splitType
        self.daysPerWeek = daysPerWeek
        self.generatedAt = generatedAt
        self.isActive = isActive
        self.userProfile = userProfile
    }
}
