import SwiftUI

// MARK: - ProgressRingView

/// A reusable animated circular progress ring with a centred label.
///
/// Pass a `progress` value in the range `0–1` (values outside this range are
/// clamped). The ring animates from 0 to the target progress when it first
/// appears, giving a satisfying fill-up effect on the Dashboard.
///
/// ```swift
/// ProgressRingView(
///     progress: 0.72,
///     color: .orange,
///     title: "Calories",
///     value: "1 450",
///     unit: "kcal"
/// )
/// .frame(width: 110, height: 110)
/// ```
struct ProgressRingView: View {

    // MARK: - Properties

    /// Progress value in the range 0–1. Values outside this range are clamped.
    let progress: Double

    /// Accent colour of the filled arc.
    let color: Color

    /// Short label shown below the numeric value (e.g. "Calories").
    let title: String

    /// Formatted primary value displayed in the ring centre (e.g. "1 450").
    let value: String

    /// Secondary unit string displayed below `value` (e.g. "kcal").
    let unit: String

    /// Stroke width of the ring in points.
    var lineWidth: CGFloat = 10

    // MARK: - State

    @State private var animatedProgress: Double = 0

    // MARK: - Computed

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(.systemFill), lineWidth: lineWidth)

            // Fill arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Centre label
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(lineWidth + 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = clampedProgress
            }
        }
    }
}

// MARK: - Preview

#Preview("Progress Rings") {
    HStack(spacing: 24) {
        ProgressRingView(
            progress: 0.68,
            color: .orange,
            title: "Calories",
            value: "1 450",
            unit: "kcal"
        )
        .frame(width: 110, height: 110)

        ProgressRingView(
            progress: 0.59,
            color: .red,
            title: "Protein",
            value: "95 g",
            unit: "/ 160 g"
        )
        .frame(width: 110, height: 110)

        ProgressRingView(
            progress: 0.42,
            color: .green,
            title: "Steps",
            value: "4 200",
            unit: "/ 10k"
        )
        .frame(width: 110, height: 110)
    }
    .padding()
}

#Preview("Clamped values") {
    HStack(spacing: 24) {
        ProgressRingView(
            progress: 1.25,
            color: .orange,
            title: "Over target",
            value: "2 700",
            unit: "kcal"
        )
        .frame(width: 110, height: 110)

        ProgressRingView(
            progress: 0,
            color: .blue,
            title: "Empty",
            value: "0",
            unit: "steps"
        )
        .frame(width: 110, height: 110)
    }
    .padding()
}
