import Foundation

// MARK: - StreakEngine

/// Pure, framework-free struct for computing the current and longest activity streaks
/// from a collection of activity dates.
///
/// **Streak rules (FR-003):**
/// - A streak day is any calendar day on which at least one activity (meal log or workout) was recorded.
/// - The current streak counts consecutive days ending on **today** or **yesterday**.
///   - If today has activity → streak includes today and extends backward.
///   - If today has no activity but yesterday does → streak is still "live" (not yet broken).
///   - If neither today nor yesterday has activity → streak is 0.
/// - A gap of more than one calendar day resets the streak to 0.
///
/// All computations are calendar-aware and use the device's current locale by default.
struct StreakEngine {

    // MARK: - Current Streak

    /// Returns the current consecutive-day activity streak.
    ///
    /// - Parameters:
    ///   - activityDates: Dates on which activity was recorded. May contain duplicates or
    ///     multiple entries per day — all are normalised to calendar days internally.
    ///   - today: Reference date for "today". Defaults to `Date.now`; override in tests
    ///     to pin behaviour to a known point in time.
    ///   - calendar: Calendar used for day boundary calculations. Defaults to `.current`.
    /// - Returns: Number of consecutive days of activity ending on today or yesterday.
    ///   Returns 0 if there is no recent activity or the array is empty.
    static func currentStreak(
        activityDates: [Date],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard !activityDates.isEmpty else { return 0 }

        let todayStart = calendar.startOfDay(for: today)

        // Normalise every date to its start-of-day and collect unique days.
        let daySet: Set<Date> = Set(activityDates.map { calendar.startOfDay(for: $0) })

        // Determine the anchor: the most recent day from which to start counting.
        // If today is active, start from today.
        // If today is inactive but yesterday is active, start from yesterday (streak still live).
        // Otherwise the streak has already broken → return 0.
        let anchor: Date
        if daySet.contains(todayStart) {
            anchor = todayStart
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                  daySet.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        // Walk backward one day at a time, counting consecutive active days.
        var count = 0
        var cursor = anchor
        while daySet.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return count
    }

    // MARK: - Longest Streak

    /// Returns the longest consecutive-day activity streak found in the full history.
    ///
    /// Unlike `currentStreak`, this scans the entire date range and is not anchored to today.
    ///
    /// - Parameters:
    ///   - activityDates: Full history of activity dates.
    ///   - calendar: Calendar used for day boundary calculations. Defaults to `.current`.
    /// - Returns: The maximum number of consecutive active days in the history. Returns 0
    ///   if the array is empty.
    static func longestStreak(
        activityDates: [Date],
        calendar: Calendar = .current
    ) -> Int {
        guard !activityDates.isEmpty else { return 0 }

        // Normalise and sort ascending.
        let sortedDays = Set(activityDates.map { calendar.startOfDay(for: $0) })
            .sorted()

        var longest = 0
        var current = 0
        var previous: Date?

        for day in sortedDays {
            if let prev = previous,
               let expectedNext = calendar.date(byAdding: .day, value: 1, to: prev),
               day == expectedNext {
                // Consecutive day — extend the run.
                current += 1
            } else {
                // Gap or first element — start a new run.
                current = 1
            }
            if current > longest { longest = current }
            previous = day
        }

        return longest
    }
}
