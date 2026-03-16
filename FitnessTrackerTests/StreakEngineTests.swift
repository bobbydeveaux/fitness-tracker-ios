import XCTest
@testable import FitnessTracker

// MARK: - StreakEngineTests

/// Unit tests for `StreakEngine`.
///
/// All tests inject a fixed `today` date (2026-03-10) so behaviour is
/// deterministic regardless of when the suite runs.
final class StreakEngineTests: XCTestCase {

    // MARK: - Helpers

    private let calendar = Calendar.current

    /// Returns a `Date` at midnight for the given components relative to the pinned "today".
    /// offset 0 = today, offset -1 = yesterday, offset -2 = two days ago, etc.
    private func day(offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    /// A fixed reference date used as "today" across all tests.
    private var today: Date {
        // 2026-03-10 00:00:00 local time
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 10
        return calendar.date(from: components)!
    }

    // MARK: - currentStreak: Zero-streak cases

    func testCurrentStreak_emptyDates_returnsZero() {
        let result = StreakEngine.currentStreak(activityDates: [], today: today)
        XCTAssertEqual(result, 0)
    }

    func testCurrentStreak_onlyTwoDaysAgo_returnsZero() {
        // Last activity was 2 days ago → streak broken
        let dates = [day(offset: -2, from: today)]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 0)
    }

    func testCurrentStreak_gapThreeDaysAgo_returnsZero() {
        // Activity 3 days ago only
        let dates = [day(offset: -3, from: today)]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 0)
    }

    func testCurrentStreak_futureDate_noTodayOrYesterdayActivity_returnsZero() {
        // Only a future date recorded (e.g. scheduled event) — no streak
        let futureDate = day(offset: 5, from: today)
        let result = StreakEngine.currentStreak(activityDates: [futureDate], today: today)
        XCTAssertEqual(result, 0)
    }

    // MARK: - currentStreak: Single-day streak

    func testCurrentStreak_onlyToday_returnsOne() {
        let dates = [day(offset: 0, from: today)]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 1)
    }

    func testCurrentStreak_onlyYesterday_returnsOne() {
        // Streak is still live — user hasn't logged today yet, but yesterday keeps it going
        let dates = [day(offset: -1, from: today)]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 1)
    }

    func testCurrentStreak_multipleTodayEntries_returnsOne() {
        // Multiple logs on the same day count as a single streak day
        let dates = [
            day(offset: 0, from: today),
            day(offset: 0, from: today),
            day(offset: 0, from: today)
        ]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 1)
    }

    // MARK: - currentStreak: Multi-day streak

    func testCurrentStreak_threeDaysEndingToday_returnsThree() {
        let dates = [
            day(offset: 0,  from: today),
            day(offset: -1, from: today),
            day(offset: -2, from: today)
        ]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 3)
    }

    func testCurrentStreak_fiveDaysEndingYesterday_returnsFive() {
        // User hasn't logged today yet; yesterday was day 5 of an active streak
        let dates = (1...5).map { day(offset: -$0, from: today) }
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 5)
    }

    func testCurrentStreak_sevenConsecutiveDaysIncludingToday_returnsSeven() {
        let dates = (0...6).map { day(offset: -$0, from: today) }
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 7)
    }

    func testCurrentStreak_todayExtendsExistingStreak_incrementsByOne() {
        // Streak of 4 days ending yesterday; today's activity should make it 5
        let datesWithoutToday = (1...4).map { day(offset: -$0, from: today) }
        let streakBefore = StreakEngine.currentStreak(activityDates: datesWithoutToday, today: today)

        let datesWithToday = [day(offset: 0, from: today)] + datesWithoutToday
        let streakAfter = StreakEngine.currentStreak(activityDates: datesWithToday, today: today)

        XCTAssertEqual(streakBefore, 4)
        XCTAssertEqual(streakAfter, 5)
    }

    // MARK: - currentStreak: Gap reset

    func testCurrentStreak_gapTwoDaysAgo_countsOnlyRecentRun() {
        // Consecutive: today + yesterday (2). Then a gap. Then 10 days before the gap.
        // Only the recent 2 consecutive days should count.
        let recentRun = [day(offset: 0, from: today), day(offset: -1, from: today)]
        let olderRun  = (3...12).map { day(offset: -$0, from: today) } // gap at offset -2
        let result = StreakEngine.currentStreak(activityDates: recentRun + olderRun, today: today)
        XCTAssertEqual(result, 2)
    }

    func testCurrentStreak_singleGapYesterdayBreaksStreak_returnsZero() {
        // Activity 0, -2, -3, -4 days → yesterday is missing → anchor = yesterday fails → 0
        let dates = [
            day(offset: 0,  from: today),
            day(offset: -2, from: today),
            day(offset: -3, from: today)
        ]
        // today exists, so anchor = today; yesterday (-1) is absent → streak = 1, not 3
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 1)
    }

    func testCurrentStreak_gapInMiddleOfHistory_returnsCurrentRun() {
        // 2 days active, 3-day gap, 5 days active before gap
        let currentRun = [day(offset: 0, from: today), day(offset: -1, from: today)]
        let olderRun   = (5...9).map { day(offset: -$0, from: today) }
        let result = StreakEngine.currentStreak(activityDates: currentRun + olderRun, today: today)
        XCTAssertEqual(result, 2)
    }

    // MARK: - longestStreak

    func testLongestStreak_emptyDates_returnsZero() {
        XCTAssertEqual(StreakEngine.longestStreak(activityDates: []), 0)
    }

    func testLongestStreak_singleDate_returnsOne() {
        let result = StreakEngine.longestStreak(activityDates: [today])
        XCTAssertEqual(result, 1)
    }

    func testLongestStreak_allConsecutive_returnsTotal() {
        let dates = (0...9).map { day(offset: -$0, from: today) }
        XCTAssertEqual(StreakEngine.longestStreak(activityDates: dates), 10)
    }

    func testLongestStreak_twoRunsPicksLonger() {
        // Run A: 3 days. Run B: 7 days (older, separated by a gap).
        let runA = [day(offset: 0, from: today), day(offset: -1, from: today), day(offset: -2, from: today)]
        let runB = (4...10).map { day(offset: -$0, from: today) }
        let result = StreakEngine.longestStreak(activityDates: runA + runB)
        XCTAssertEqual(result, 7)
    }

    func testLongestStreak_duplicateDates_notDoubleCounted() {
        let dates = [today, today, today]
        XCTAssertEqual(StreakEngine.longestStreak(activityDates: dates), 1)
    }

    // MARK: - currentStreak: unsorted input handled correctly

    func testCurrentStreak_unsortedInput_correctResult() {
        // Pass dates in reverse order; result should be the same
        let dates = [
            day(offset: -2, from: today),
            day(offset: 0,  from: today),
            day(offset: -1, from: today)
        ]
        let result = StreakEngine.currentStreak(activityDates: dates, today: today)
        XCTAssertEqual(result, 3)
    }
}
