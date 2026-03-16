import Foundation
import SwiftData

/// Tracks the user's activity streak (consecutive days with a completed workout or logged meal).
@Model
final class Streak {
    var id: UUID
    var currentCount: Int
    var longestCount: Int
    var lastActivityDate: Date?
    var updatedAt: Date

    var userProfile: UserProfile?

    init(
        id: UUID = UUID(),
        currentCount: Int = 0,
        longestCount: Int = 0,
        lastActivityDate: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.currentCount = currentCount
        self.longestCount = longestCount
        self.lastActivityDate = lastActivityDate
        self.updatedAt = updatedAt
    }
}
