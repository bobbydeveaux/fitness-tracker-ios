import Foundation
import SwiftData

// MARK: - Supporting Enum

enum SessionStatus: String, Codable {
    case idle
    case active
    case paused
    case complete
}

// MARK: - WorkoutSession Model

/// Represents a single gym session, progressing through a state machine: idle → active → paused → complete.
@Model
final class WorkoutSession {
    var id: UUID
    @Attribute(.index) var startedAt: Date
    var endedAt: Date?
    var status: SessionStatus
    /// Total duration in seconds (populated on completion)
    var durationSeconds: Double?
    /// Total volume lifted (kg × reps, summed across all sets)
    var totalVolumeKg: Double?
    var notes: String?

    var workoutDay: WorkoutDay?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var loggedSets: [LoggedSet] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: SessionStatus = .idle,
        durationSeconds: Double? = nil,
        totalVolumeKg: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.durationSeconds = durationSeconds
        self.totalVolumeKg = totalVolumeKg
        self.notes = notes
    }
}
