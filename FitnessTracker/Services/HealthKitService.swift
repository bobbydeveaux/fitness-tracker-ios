import Foundation

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-healthkit-1)

/// Singleton wrapping `HKHealthStore` for reading daily fitness statistics
/// and writing completed workout sessions.
///
/// The full implementation — including `HKStatisticsCollectionQuery` for step
/// count, active energy, and heart rate, plus `HKWorkout` writes — is added
/// in task-ios-fitness-tracker-app-feat-healthkit-1 (Sprint 2).
final class HealthKitService {

    // MARK: - Singleton

    static let shared = HealthKitService()

    // MARK: - Types

    struct DailyStats {
        var stepCount: Double = 0
        var activeEnergyBurned: Double = 0
        var heartRate: Double = 0
    }

    // MARK: - Init

    init() {}

    // MARK: - API (stub bodies replaced in healthkit-1)

    /// Requests HealthKit authorisation for stepCount, activeEnergyBurned,
    /// and heartRate on first foreground. Never re-prompts after authorization.
    func requestAuthorisationIfNeeded() async {
        // Implementation added in task-ios-fitness-tracker-app-feat-healthkit-1
    }

    /// Reads today's step count, active energy, and resting heart rate.
    func readDailyStats() async -> DailyStats {
        DailyStats()
    }

    /// Writes an `HKWorkout` with `.traditionalStrengthTraining` activity type.
    func saveWorkout(duration: TimeInterval) async {
        // Implementation added in task-ios-fitness-tracker-app-feat-healthkit-1
    }
}
