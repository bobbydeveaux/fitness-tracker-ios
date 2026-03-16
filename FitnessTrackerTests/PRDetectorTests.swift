import XCTest
@testable import FitnessTracker

// MARK: - PRDetectorTests

/// Unit tests for `PRDetector`.
///
/// Tests cover the three acceptance criteria:
/// 1. New PR detected when weight × reps exceeds historical best.
/// 2. No PR returned when the set does not exceed the historical best.
/// 3. Empty history (first-ever set for an exercise) is always a PR.
final class PRDetectorTests: XCTestCase {

    // MARK: - Helpers

    /// Convenience factory for `SetRecord`.
    private func set(weightKg: Double, reps: Int) -> SetRecord {
        SetRecord(weightKg: weightKg, reps: reps)
    }

    // MARK: - Empty history (first-ever set)

    func testCheck_emptyHistory_isPR() {
        let newSet = set(weightKg: 100, reps: 5)
        let result = PRDetector.check(newSet: newSet, history: [])

        XCTAssertTrue(result.isPR, "First-ever set should always be a PR")
    }

    func testCheck_emptyHistory_previousBestIsNil() {
        let newSet = set(weightKg: 80, reps: 8)
        let result = PRDetector.check(newSet: newSet, history: [])

        XCTAssertNil(result.previousBest, "No previous best exists for empty history")
    }

    func testCheck_emptyHistory_newSetIsPreserved() {
        let newSet = set(weightKg: 60, reps: 3)
        let result = PRDetector.check(newSet: newSet, history: [])

        XCTAssertEqual(result.newSet.weightKg, 60)
        XCTAssertEqual(result.newSet.reps, 3)
    }

    // MARK: - PR achieved (volume exceeds history)

    func testCheck_higherVolume_isPR() {
        // History best: 100 kg × 5 reps = 500 kg
        // New set:      100 kg × 6 reps = 600 kg → PR
        let history = [set(weightKg: 100, reps: 5)]
        let newSet  = set(weightKg: 100, reps: 6)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertTrue(result.isPR)
    }

    func testCheck_higherWeightSameReps_isPR() {
        // History best: 80 kg × 5 reps = 400 kg
        // New set:      90 kg × 5 reps = 450 kg → PR
        let history = [set(weightKg: 80, reps: 5)]
        let newSet  = set(weightKg: 90, reps: 5)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertTrue(result.isPR)
    }

    func testCheck_higherVolumeAmongMultipleHistorySets_isPR() {
        // Multiple history records; best is 100 × 10 = 1000
        let history = [
            set(weightKg: 80,  reps: 10),   // 800
            set(weightKg: 100, reps: 10),   // 1000  ← best
            set(weightKg: 90,  reps: 8)     // 720
        ]
        let newSet = set(weightKg: 100, reps: 11) // 1100 → PR
        let result = PRDetector.check(newSet: newSet, history: history)

        XCTAssertTrue(result.isPR)
        XCTAssertEqual(result.previousBest?.weightKg, 100)
        XCTAssertEqual(result.previousBest?.reps, 10)
    }

    func testCheck_previousBestIsPopulatedOnPR() {
        let history = [set(weightKg: 60, reps: 10)]  // 600
        let newSet  = set(weightKg: 70, reps: 10)    // 700 → PR
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertNotNil(result.previousBest)
        XCTAssertEqual(result.previousBest?.weightKg, 60)
        XCTAssertEqual(result.previousBest?.reps, 10)
    }

    // MARK: - No PR (volume does not exceed history)

    func testCheck_equalVolume_isNotPR() {
        // Equal volume is not strictly greater → no PR
        let history = [set(weightKg: 100, reps: 5)]  // 500
        let newSet  = set(weightKg: 100, reps: 5)    // 500 (equal)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertFalse(result.isPR, "Equal volume must not be flagged as a PR")
    }

    func testCheck_lowerVolume_isNotPR() {
        // History best: 100 kg × 10 reps = 1000 kg
        // New set:       90 kg × 10 reps = 900 kg → not a PR
        let history = [set(weightKg: 100, reps: 10)]
        let newSet  = set(weightKg: 90,  reps: 10)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertFalse(result.isPR)
    }

    func testCheck_lowerRepsHigherWeight_belowHistoricalVolume_isNotPR() {
        // History: 60 kg × 12 reps = 720
        // New set: 80 kg × 8  reps = 640 → not a PR
        let history = [set(weightKg: 60, reps: 12)]
        let newSet  = set(weightKg: 80, reps: 8)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertFalse(result.isPR)
    }

    func testCheck_notPR_previousBestIsPopulated() {
        let history = [set(weightKg: 100, reps: 5)]
        let newSet  = set(weightKg: 80,  reps: 5)
        let result  = PRDetector.check(newSet: newSet, history: history)

        XCTAssertFalse(result.isPR)
        XCTAssertNotNil(result.previousBest)
        XCTAssertEqual(result.previousBest?.weightKg, 100)
    }

    // MARK: - previousBest reflects the max-volume historical set

    func testCheck_previousBestIsHighestVolumeNotFirstElement() {
        // History has three records; detector must pick the true best, not the first.
        let history = [
            set(weightKg: 50, reps: 10),   // 500
            set(weightKg: 80, reps: 10),   // 800  ← true best
            set(weightKg: 70, reps: 8)     // 560
        ]
        let newSet = set(weightKg: 90, reps: 10) // 900 → PR
        let result = PRDetector.check(newSet: newSet, history: history)

        XCTAssertEqual(result.previousBest?.weightKg, 80)
        XCTAssertEqual(result.previousBest?.reps, 10)
    }

    // MARK: - Volume computation

    func testSetRecord_volume_isWeightTimesReps() {
        let record = SetRecord(weightKg: 75, reps: 8)
        XCTAssertEqual(record.volume, 600, accuracy: 0.001)
    }

    func testSetRecord_zeroReps_volumeIsZero() {
        let record = SetRecord(weightKg: 100, reps: 0)
        XCTAssertEqual(record.volume, 0, accuracy: 0.001)
    }
}
