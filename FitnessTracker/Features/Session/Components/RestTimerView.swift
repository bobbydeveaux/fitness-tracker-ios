import SwiftUI

// MARK: - RestTimerView

/// Circular rest-timer overlay displayed between sets.
///
/// Shows a countdown in MM:SS format with an animated progress ring.
/// The user can skip the timer or adjust the duration for the next rest period.
struct RestTimerView: View {

    // MARK: - Input

    let secondsRemaining: Int
    let totalDuration: Int
    let onSkip: () -> Void

    // MARK: - Derived

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalDuration - secondsRemaining) / Double(totalDuration)
    }

    private var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private var timerColor: Color {
        let fraction = Double(secondsRemaining) / Double(max(totalDuration, 1))
        if fraction > 0.5 { return .green }
        if fraction > 0.25 { return .orange }
        return .red
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Text("Rest")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Countdown label
                Text(formattedTime)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: secondsRemaining)
            }

            Button(action: onSkip) {
                Label("Skip", systemImage: "forward.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Preview

#Preview("RestTimerView – mid rest") {
    RestTimerView(secondsRemaining: 67, totalDuration: 90, onSkip: {})
        .padding()
}

#Preview("RestTimerView – almost done") {
    RestTimerView(secondsRemaining: 10, totalDuration: 90, onSkip: {})
        .padding()
}
