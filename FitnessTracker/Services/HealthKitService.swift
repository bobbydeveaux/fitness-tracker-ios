import Foundation
import HealthKit

// MARK: - HealthKitServiceProtocol

/// Protocol that abstracts HealthKit access so callers and tests can work
/// against a type-erased interface without depending on the concrete singleton.
protocol HealthKitServiceProtocol: AnyObject {

    /// Requests HealthKit authorisation for the 3 quantity types (stepCount,
    /// activeEnergyBurned, heartRate) and write access for workouts.
    func requestAuthorisationIfNeeded() async

    /// Reads today's step count, active energy burned, and average heart rate.
    func readDailyStats() async -> DailyStats

    /// Writes an `HKWorkout` with `.traditionalStrengthTraining` activity type.
    func saveWorkout(duration: TimeInterval) async
}

// MARK: - DailyStats

/// Snapshot of today's HealthKit quantities surfaced on the dashboard.
struct DailyStats {
    var stepCount: Double = 0
    var activeEnergyBurned: Double = 0
    var heartRate: Double = 0
}

// MARK: - HealthKitService

/// Singleton wrapping `HKHealthStore` for reading daily fitness statistics
/// and writing completed workout sessions.
///
/// All HealthKit operations are guarded by `HKHealthStore.isHealthDataAvailable()`
/// so the service degrades gracefully on simulator and iPad targets where
/// HealthKit is not available.
///
/// Usage:
/// ```swift
/// let service = HealthKitService.shared
/// await service.requestAuthorisationIfNeeded()
/// let stats = await service.readDailyStats()
/// ```
final class HealthKitService: HealthKitServiceProtocol {

    // MARK: - Singleton

    /// The shared application-wide instance. Use this instead of creating
    /// additional instances — `init()` is private to enforce the contract.
    static let shared = HealthKitService()

    // MARK: - Properties

    private let store = HKHealthStore()

    // MARK: - Init

    /// Private to enforce the singleton pattern — callers must use `.shared`.
    private init() {}

    // MARK: - Authorization

    /// Requests HealthKit read and write authorisation if not already granted.
    ///
    /// - Read types: `stepCount`, `activeEnergyBurned`, `heartRate`
    /// - Write types: `HKWorkoutType`
    ///
    /// This method is a no-op when HealthKit is unavailable (e.g. on simulator
    /// without a paired watch, or on iPad). Authorization errors are logged but
    /// not propagated because the app degrades gracefully when health data is
    /// unavailable.
    func requestAuthorisationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            print("[HealthKitService] Authorization error: \(error.localizedDescription)")
        }
    }

    // MARK: - Read

    /// Reads today's step count, active energy burned, and average resting heart rate.
    ///
    /// Each quantity type is queried concurrently via `HKStatisticsCollectionQuery`
    /// with a 1-day interval anchored at midnight. Returns a zeroed `DailyStats`
    /// when HealthKit is unavailable or queries return no data.
    func readDailyStats() async -> DailyStats {
        guard HKHealthStore.isHealthDataAvailable() else { return DailyStats() }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        async let steps = queryDailyStat(
            type: HKQuantityType(.stepCount),
            options: .cumulativeSum,
            startOfDay: startOfDay
        )
        async let energy = queryDailyStat(
            type: HKQuantityType(.activeEnergyBurned),
            options: .cumulativeSum,
            startOfDay: startOfDay
        )
        async let hr = queryDailyStat(
            type: HKQuantityType(.heartRate),
            options: .discreteAverage,
            startOfDay: startOfDay
        )

        let (stepStats, energyStats, hrStats) = await (steps, energy, hr)

        let stepCount = stepStats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
        let activeEnergy = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let heartRate = hrStats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0

        return DailyStats(
            stepCount: stepCount,
            activeEnergyBurned: activeEnergy,
            heartRate: heartRate
        )
    }

    // MARK: - Write

    /// Writes a completed workout session to HealthKit as an `HKWorkout` with
    /// `.traditionalStrengthTraining` activity type.
    ///
    /// Uses `HKWorkoutBuilder` which is the recommended API for iOS 16+.
    /// Errors are caught and logged; callers need not handle failures because
    /// a missed workout write is non-fatal for the core app experience.
    ///
    /// - Parameter duration: Total elapsed time of the session in seconds.
    func saveWorkout(duration: TimeInterval) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let end = Date()
        let start = end.addingTimeInterval(-duration)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            print("[HealthKitService] Failed to save workout: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Executes an `HKStatisticsCollectionQuery` for a single quantity type over
    /// today's date range and returns the resulting `HKStatistics`.
    ///
    /// The query uses a 1-day bucket anchored at midnight so that `statistics(for:)`
    /// returns the complete day's aggregation regardless of when it is called.
    ///
    /// - Parameters:
    ///   - type: The `HKQuantityType` to aggregate.
    ///   - options: `.cumulativeSum` for step/energy totals; `.discreteAverage` for heart rate.
    ///   - startOfDay: The start of the current calendar day (midnight).
    /// - Returns: Today's `HKStatistics`, or `nil` if the query returns no data.
    private func queryDailyStat(
        type: HKQuantityType,
        options: HKStatisticsOptions,
        startOfDay: Date
    ) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: Date(),
                options: .strictStartDate
            )

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, _ in
                continuation.resume(returning: results?.statistics(for: startOfDay))
            }

            store.execute(query)
        }
    }
}
