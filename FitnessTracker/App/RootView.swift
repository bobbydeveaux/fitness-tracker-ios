import SwiftUI
import SwiftData

// MARK: - AppRoute

/// Top-level navigation destinations for the app.
private enum AppRoute {
    case loading
    case onboarding
    case dashboard
}

// MARK: - RootView

/// The root container view rendered by `FitnessTrackerApp`.
///
/// `RootView` queries SwiftData for an existing `UserProfile` on launch and
/// routes to:
/// - **Onboarding** — when no `UserProfile` exists (first launch).
/// - **Dashboard** — when a `UserProfile` is found.
///
/// A `.loading` intermediate state prevents flashing the wrong destination
/// while the async profile query completes.
struct RootView: View {

    @Environment(AppEnvironment.self) private var env
    @Query private var profiles: [UserProfile]

    @State private var route: AppRoute = .loading

    var body: some View {
        Group {
            switch route {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))

            case .onboarding:
                OnboardingView(
                    viewModel: OnboardingViewModel(
                        repository: env.userProfileRepository,
                        context: env.modelContainer.mainContext
                    ),
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            route = .dashboard
                        }
                    }
                )
                .transition(.opacity)

            case .dashboard:
                DashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: route)
        .task {
            // Trigger HealthKit authorisation on first foreground so the
            // permission prompt appears before the user reaches the dashboard.
            await env.healthKitService.requestAuthorisationIfNeeded()

            // Seed the bundled exercise library on first launch.
            await env.exerciseLibraryService.seedIfNeeded()

            // Route based on whether a profile already exists.
            resolveInitialRoute()
        }
        // Re-evaluate routing whenever the @Query result changes (e.g., after
        // onboarding saves the profile and SwiftData notifies the view).
        .onChange(of: profiles) { _, _ in
            if route == .loading {
                resolveInitialRoute()
            }
        }
    }

    // MARK: - Routing Logic

    private func resolveInitialRoute() {
        route = profiles.isEmpty ? .onboarding : .dashboard
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(AppEnvironment.makeProductionEnvironment())
}
