import Foundation

// MARK: - SetRecord

/// A lightweight, framework-free value representing a single logged exercise set.
/// Used by `PRDetector` so callers do not need to pass SwiftData model objects.
struct SetRecord {
    /// Weight lifted in kilograms.
    let weightKg: Double
    /// Number of repetitions performed.
    let reps: Int

    /// 1RM-equivalent volume used for PR comparison: weight × reps.
    var volume: Double { weightKg * Double(reps) }
}

// MARK: - PRResult

/// The outcome of a PR-detection check.
struct PRResult {
    /// Whether the evaluated set constitutes a new personal record.
    let isPR: Bool
    /// The best historical set prior to the new set, or `nil` when no history exists.
    let previousBest: SetRecord?
    /// The new set that was evaluated.
    let newSet: SetRecord
}

// MARK: - PRDetector

/// Pure, framework-free domain service that detects personal records for a given
/// exercise by comparing a new set's 1RM-equivalent volume (weight × reps) against
/// the historical best.
///
/// **PR rule:**
/// A set is a PR when its `volume` (weightKg × reps) **strictly exceeds** the
/// highest `volume` seen in `history`.  When `history` is empty (first-ever set
/// for that exercise) the set is always considered a PR.
///
/// Callers convert `LoggedSet` SwiftData objects to `SetRecord` values before
/// invoking this service, keeping the domain logic decoupled from persistence.
struct PRDetector {

    // MARK: - Check

    /// Evaluates whether `newSet` sets a new personal record.
    ///
    /// - Parameters:
    ///   - newSet: The set just logged by the user.
    ///   - history: All previously completed sets for the **same exercise**, in any order.
    ///     Pass an empty array when this is the athlete's first-ever set for the exercise.
    /// - Returns: A `PRResult` describing whether a PR was achieved, the previous best
    ///   (if any), and the evaluated set.
    static func check(newSet: SetRecord, history: [SetRecord]) -> PRResult {
        guard !history.isEmpty else {
            // No history → first set ever for this exercise is always a PR.
            return PRResult(isPR: true, previousBest: nil, newSet: newSet)
        }

        // Identify the historical set with the highest volume.
        let bestHistorical = history.max(by: { $0.volume < $1.volume })!

        let isPR = newSet.volume > bestHistorical.volume
        return PRResult(isPR: isPR, previousBest: bestHistorical, newSet: newSet)
    }
}
