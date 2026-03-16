import Foundation
import SwiftData

// MARK: - SessionStatus

enum SessionStatus: String, Codable {
    case active
    case complete
    case abandoned
}

// MARK: - WorkoutSession

/// Records a live or completed gym session, linked to a `WorkoutDay`.
@Model
final class WorkoutSession {

    @Attribute(.unique) var id: UUID

    @Attribute(.indexed) var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int

    var totalVolumeKg: Double
    var status: SessionStatus

    // MARK: - Relationships

    var workoutDay: WorkoutDay?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet] = []

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        durationSeconds: Int = 0,
        totalVolumeKg: Double = 0,
        status: SessionStatus = .active,
        workoutDay: WorkoutDay? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.totalVolumeKg = totalVolumeKg
        self.status = status
        self.workoutDay = workoutDay
    }
}
