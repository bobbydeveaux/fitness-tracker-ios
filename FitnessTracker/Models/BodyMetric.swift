import Foundation
import SwiftData

// MARK: - Supporting Enum

enum BodyMetricType: String, Codable {
    case weight
    case chest
    case waist
    case hip
    case neck
    case thigh
    case arm
}

// MARK: - BodyMetric Model

/// A single body measurement data point captured on a given date.
@Model
final class BodyMetric {
    var id: UUID
    var metricType: BodyMetricType
    /// Measurement value; unit depends on type (kg for weight, cm for circumferences)
    var value: Double
    @Attribute(.index) var recordedAt: Date

    var userProfile: UserProfile?

    init(
        id: UUID = UUID(),
        metricType: BodyMetricType,
        value: Double,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.recordedAt = recordedAt
    }
}
