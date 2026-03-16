import SwiftUI

// MARK: - RestTimerView

/// A circular countdown timer displayed between sets during an active session.
///
/// Renders:
/// - An animated ring that depletes as the rest period counts down.
/// - The remaining time displayed as `mm:ss` in the centre of the ring.
/// - A "Skip" button to clear the timer immediately.
/// - A visual pulse animation when the timer reaches zero (haptic fires in
///   `SessionViewModel`; this view reflects the expired state visually).
///
/// Binds to `SessionViewModel` via closure callbacks to keep the view
/// side-effect-free and easily testable.
struct RestTimerView: View {

    // MARK: - Input

    /// Total rest duration configured by the user (seconds).
    let totalSeconds: Int
    /// Remaining rest seconds provided by `SessionViewModel`.
    let remainingSeconds: Int
    /// Whether the timer is actively counting down.
    let isActive: Bool
    /// Called when the user taps "Skip Rest".
    let onSkip: () -> Void

    // MARK: - Computed

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timeLabel: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var isExpired: Bool { remainingSeconds == 0 && !isActive }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isExpired ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Centre label
                VStack(spacing: 2) {
                    Text(isExpired ? "Go!" : timeLabel)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(isExpired ? .green : .primary)
                        .contentTransition(.numericText())

                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            .scaleEffect(isExpired ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isExpired)

            if isActive {
                Button(action: onSkip) {
                    Label("Skip Rest", systemImage: "forward.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Active") {
    RestTimerView(
        totalSeconds: 90,
        remainingSeconds: 45,
        isActive: true,
        onSkip: {}
    )
}

#Preview("Expired") {
    RestTimerView(
        totalSeconds: 90,
        remainingSeconds: 0,
        isActive: false,
        onSkip: {}
    )
}
