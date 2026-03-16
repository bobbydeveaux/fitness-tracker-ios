import SwiftUI

// MARK: - WelcomeStepView

/// The first step of the onboarding wizard — introduces the app with branding
/// and a single call-to-action button that advances to the biometrics step.
///
/// Accepts an `OnboardingViewModel` binding so the parent `OnboardingView`
/// controls the advance action uniformly through the ViewModel.
struct WelcomeStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: Branding
            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Fitness Tracker")
                    .font(.largeTitle.bold())

                Text("Your personal health companion.\nTrack workouts, nutrition, and progress all in one place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // MARK: Feature highlights
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "dumbbell.fill",
                           title: "Smart Workouts",
                           description: "Log sets, reps, and rest with guided exercise library")

                FeatureRow(icon: "fork.knife",
                           title: "Nutrition Tracking",
                           description: "Hit your macro targets with TDEE-based calorie goals")

                FeatureRow(icon: "chart.line.uptrend.xyaxis",
                           title: "Progress Insights",
                           description: "Visualise body metrics and streak history over time")
            }
            .padding(.horizontal, 32)

            Spacer()

            // MARK: CTA
            Button(action: viewModel.advance) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .accessibilityLabel("Get Started")
        }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeStepView(viewModel: OnboardingViewModel())
}
