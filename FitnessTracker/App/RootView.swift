import SwiftUI

// MARK: - RootView

/// The root container view rendered by `FitnessTrackerApp`.
///
/// `RootView` is responsible for deciding which top-level flow to present:
/// - **Onboarding** — when no `UserProfile` exists (first launch).
/// - **Dashboard** — when a `UserProfile` is found.
///
/// The routing logic and the actual feature views are added in subsequent
/// sprint tasks. Until then, this view acts as a launch placeholder that
/// confirms `AppEnvironment` is correctly injected.
struct RootView: View {

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        // Placeholder replaced by the real router in the onboarding and
        // dashboard feature tasks.
        ContentUnavailableView(
            "Fitness Tracker",
            systemImage: "figure.run",
            description: Text("App foundation is ready. Feature modules coming soon.")
        )
        .task {
            // Trigger HealthKit authorisation on first foreground so the
            // permission prompt appears before the user reaches the dashboard.
            await env.healthKitService.requestAuthorisationIfNeeded()

            // Seed the bundled exercise library on first launch.
            await env.exerciseLibraryService.seedIfNeeded()
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(AppEnvironment.makeProductionEnvironment())
}
