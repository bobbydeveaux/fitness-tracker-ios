import Foundation
import SwiftData

// MARK: - BodyMetricType

enum BodyMetricType: String, Codable {
    case weight
    case chest
    case waist
    case hips
    case thigh
    case arm
    case bodyFatPercentage
}

// MARK: - BodyMetric

/// A single body measurement entry (e.g. weight, waist circumference).
@Model
final class BodyMetric {

    @Attribute(.unique) var id: UUID

    @Attribute(.indexed) var date: Date
    var type: BodyMetricType
    var value: Double   // kg for weight; cm for measurements; % for body fat

    // MARK: - Relationships

    var userProfile: UserProfile?

    // MARK: - Initialisation

    init(
        id: UUID = UUID(),
        date: Date = .now,
        type: BodyMetricType,
        value: Double,
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.value = value
        self.userProfile = userProfile
    }
}
