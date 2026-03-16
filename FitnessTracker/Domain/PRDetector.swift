import Foundation

// MARK: - PRResult

/// The outcome of a personal-record check for a single logged set.
struct PRResult {

    /// `true` if the new set establishes a new 1RM-equivalent personal record
    /// for the given exercise.
    let isPR: Bool

    /// The previous best 1RM-equivalent (weight × reps), or `nil` when this is
    /// the first set ever logged for the exercise.
    let previousBest: Double?

    /// The 1RM-equivalent volume for the newly logged set (weight × reps).
    let newBest: Double
}

// MARK: - PRDetector

/// Framework-free domain service that determines whether a newly logged set
/// constitutes a personal record (PR) for a given exercise.
///
/// The PR metric used is **1RM-equivalent volume** (weight × reps), which
/// provides a simple but effective proxy for absolute strength improvements
/// across varying rep ranges.
///
/// Usage:
/// ```swift
/// let result = PRDetector.check(
///     weightKg: 100,
///     reps: 5,
///     against: previousLoggedSets
/// )
/// if result.isPR {
///     print("New PR! Previous best was \(result.previousBest ?? 0) kg·reps")
/// }
/// ```
enum PRDetector {

    // MARK: - Public API

    /// Checks whether the new set is a personal record compared to the
    /// provided historical sets for the same exercise.
    ///
    /// A set is a PR when its `weightKg × reps` volume strictly exceeds every
    /// previous set's volume. The first set for an exercise is always a PR.
    ///
    /// - Parameters:
    ///   - weightKg: Weight lifted in the new set (kilograms).
    ///   - reps: Repetitions performed in the new set.
    ///   - historicalSets: All previously completed sets for the same exercise.
    ///     Incomplete sets (`isComplete == false`) are excluded from comparison.
    /// - Returns: A `PRResult` containing the PR flag and the previous best volume.
    static func check(
        weightKg: Double,
        reps: Int,
        against historicalSets: [LoggedSet]
    ) -> PRResult {
        let newVolume = weightKg * Double(reps)

        // Filter to completed sets only and compute their 1RM-equivalent volumes.
        let previousVolumes = historicalSets
            .filter { $0.isComplete }
            .map { $0.weightKg * Double($0.reps) }

        let previousBest = previousVolumes.max()

        let isPR: Bool
        if let best = previousBest {
            isPR = newVolume > best
        } else {
            // No history — first set is always a PR.
            isPR = true
        }

        return PRResult(isPR: isPR, previousBest: previousBest, newBest: newVolume)
    }
}
