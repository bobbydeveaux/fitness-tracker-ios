import Foundation
import SwiftData

// MARK: - Streak

/// Tracks the user's consecutive-day activity streak.
@Model
final class Streak {

    @Attribute(.unique) var id: UUID

    var currentCount: Int
    var longestCount: Int

    @Attribute(.indexed) var lastActivityDate: Date

    // MARK: - Relationships

    var userProfile: UserProfile?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        currentCount: Int = 0,
        longestCount: Int = 0,
        lastActivityDate: Date = .now,
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.currentCount = currentCount
        self.longestCount = longestCount
        self.lastActivityDate = lastActivityDate
        self.userProfile = userProfile
    }
}
