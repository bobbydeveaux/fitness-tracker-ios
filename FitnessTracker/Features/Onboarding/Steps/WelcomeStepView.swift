import SwiftUI

// MARK: - WelcomeStepView

/// First onboarding step: branding and call-to-action.
///
/// Renders the app logo, name, and a brief value proposition to
/// motivate the user to begin the setup wizard.
struct WelcomeStepView: View {

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon / branding
            Image(systemName: "figure.strengthtraining.traditional")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.tint)
                .padding(24)
                .background(
                    Circle()
                        .fill(.tint.opacity(0.12))
                )

            // Heading
            VStack(spacing: 12) {
                Text("Welcome to\nFitness Tracker")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Your personal coach for training,\nnutrition, and progress tracking.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "chart.bar.fill",
                           color: .blue,
                           title: "Track Workouts",
                           subtitle: "Log sets, reps, and personal records")
                FeatureRow(icon: "fork.knife",
                           color: .green,
                           title: "Monitor Nutrition",
                           subtitle: "Hit your daily macro and calorie goals")
                FeatureRow(icon: "flame.fill",
                           color: .orange,
                           title: "Stay Consistent",
                           subtitle: "Build streaks and crush your goals")
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeStepView()
}
