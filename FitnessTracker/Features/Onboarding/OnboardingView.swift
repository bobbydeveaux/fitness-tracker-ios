import SwiftUI

// MARK: - OnboardingView

/// Root container for the multi-step onboarding wizard.
///
/// `OnboardingView` renders the current step view from `OnboardingViewModel`,
/// animates transitions between steps with a directional horizontal slide,
/// displays a step progress indicator, and triggers dashboard navigation
/// when `viewModel.isComplete` becomes `true`.
///
/// Navigation is surfaced upward via the `onComplete` closure so the caller
/// (`RootView`) can swap the root view to `DashboardView`.
struct OnboardingView: View {

    @State var viewModel: OnboardingViewModel

    /// Called when the user finishes the last step and the profile is saved.
    var onComplete: () -> Void

    /// Tracks the direction of the last step transition for animation.
    @State private var transitionDirection: TransitionDirection = .forward

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Progress Indicator
            ProgressIndicatorView(
                currentStep: viewModel.currentStep.rawValue,
                totalSteps: viewModel.totalSteps
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // MARK: Step Content
            // `id` on the ZStack forces a full view replacement each time the
            // step changes, enabling the slide transition without visual artefacts.
            ZStack {
                stepView(for: viewModel.currentStep)
                    .transition(stepTransition)
            }
            .id(viewModel.currentStep)
            .frame(maxHeight: .infinity)

            // MARK: Navigation Buttons
            NavigationButtonsView(
                viewModel: viewModel,
                transitionDirection: $transitionDirection,
                onComplete: onComplete
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        // Handle error banner
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }

    // MARK: - Step Content Dispatch

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .biometrics:
            BiometricsStepView(viewModel: viewModel)
        case .activityGoal:
            ActivityGoalStepView(viewModel: viewModel)
        case .summary:
            SummaryStepView(viewModel: viewModel)
        }
    }

    // MARK: - Directional Slide Transition

    private var stepTransition: AnyTransition {
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion:  .move(edge: .trailing).combined(with: .opacity),
                removal:    .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion:  .move(edge: .leading).combined(with: .opacity),
                removal:    .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}

// MARK: - TransitionDirection

private enum TransitionDirection {
    case forward
    case backward
}

// MARK: - ProgressIndicatorView

private struct ProgressIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep + 1) / Double(totalSteps)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Step dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }

            // Step label
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(OnboardingStep(rawValue: currentStep)?.title ?? "")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - NavigationButtonsView

private struct NavigationButtonsView: View {
    let viewModel: OnboardingViewModel
    @Binding var transitionDirection: TransitionDirection
    let onComplete: () -> Void

    private var isLastStep: Bool {
        viewModel.currentStep == OnboardingStep.allCases.last
    }

    var body: some View {
        VStack(spacing: 12) {
            // Primary action (Continue / Get Started)
            Button {
                if isLastStep {
                    Task {
                        await viewModel.completeOnboarding()
                        if viewModel.isComplete {
                            onComplete()
                        }
                    }
                } else {
                    transitionDirection = .forward
                    withAnimation(.easeInOut(duration: 0.35)) {
                        viewModel.nextStep()
                    }
                }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(isLastStep ? "Get Started" : "Continue")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceed || viewModel.isSaving)
            .controlSize(.large)

            // Back button (hidden on first step)
            if viewModel.currentStep != .welcome {
                Button {
                    transitionDirection = .backward
                    withAnimation(.easeInOut(duration: 0.35)) {
                        viewModel.previousStep()
                    }
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ErrorBannerView

private struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment.makeProductionEnvironment()
    let vm = OnboardingViewModel(
        repository: env.userProfileRepository,
        context: env.modelContainer.mainContext
    )
    return OnboardingView(viewModel: vm, onComplete: {})
        .environment(env)
}
