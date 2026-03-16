import SwiftUI

// MARK: - StreakBannerView

/// A compact banner that celebrates the user's consecutive-day activity streak.
///
/// The view is **hidden when `currentStreak` is 0** — it slides in from the
/// top the first time a streak is established, rewarding the user with a
/// satisfying entrance animation.
///
/// ```swift
/// StreakBannerView(currentStreak: 7, longestStreak: 14)
/// ```
struct StreakBannerView: View {

    // MARK: - Properties

    /// The number of consecutive days with recorded activity. Pass `0` to hide the banner.
    let currentStreak: Int

    /// The user's all-time best streak, displayed as a secondary stat.
    let longestStreak: Int

    // MARK: - State

    @State private var isVisible: Bool = false

    // MARK: - Body

    var body: some View {
        if currentStreak > 0 {
            content
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -16)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                }
        }
    }

    // MARK: - Private

    private var content: some View {
        HStack(spacing: 12) {
            // Flame icon
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: currentStreak)

            // Streak count
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text(currentStreak == 1 ? "day streak" : "day streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Best: \(longestStreak) \(longestStreak == 1 ? "day" : "days")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Motivational badge for milestone streaks
            if currentStreak >= 7 {
                milestoneBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(streakGradient)
        )
    }

    private var streakGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.18),
                Color.red.opacity(0.10)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var milestoneBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: milestoneSFSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(milestoneColor)
            Text(milestoneLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(milestoneColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(milestoneColor.opacity(0.15))
        )
    }

    private var milestoneSFSymbol: String {
        switch currentStreak {
        case 30...: return "star.fill"
        case 14...: return "trophy.fill"
        default:    return "bolt.fill"      // 7+
        }
    }

    private var milestoneColor: Color {
        switch currentStreak {
        case 30...: return .yellow
        case 14...: return .purple
        default:    return .orange
        }
    }

    private var milestoneLabel: String {
        switch currentStreak {
        case 30...: return "Legend"
        case 14...: return "On fire!"
        default:    return "Week+"
        }
    }
}

// MARK: - Preview

#Preview("Active streaks") {
    VStack(spacing: 16) {
        StreakBannerView(currentStreak: 1, longestStreak: 14)
        StreakBannerView(currentStreak: 5, longestStreak: 14)
        StreakBannerView(currentStreak: 7, longestStreak: 14)
        StreakBannerView(currentStreak: 14, longestStreak: 14)
        StreakBannerView(currentStreak: 30, longestStreak: 45)
    }
    .padding()
}

#Preview("Zero streak — hidden") {
    VStack {
        Text("No banner should appear below:")
            .font(.caption)
            .foregroundStyle(.secondary)
        StreakBannerView(currentStreak: 0, longestStreak: 5)
        Text("(nothing)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
}
