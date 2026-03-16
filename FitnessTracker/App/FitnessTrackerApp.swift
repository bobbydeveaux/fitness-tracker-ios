import SwiftUI
import SwiftData

@main
struct FitnessTrackerApp: App {

    // MARK: - DI container

    /// The root dependency-injection container, injected into the entire view hierarchy.
    @State private var appEnvironment = AppEnvironment()

    // MARK: - App entry point

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .modelContainer(appEnvironment.modelContainer)
                .task {
                    await performFirstLaunchSetup()
                }
        }
    }

    // MARK: - First-launch setup

    /// Runs once per lifecycle; seeds the exercise library on first install.
    ///
    /// Subsequent launches are no-ops because `ExerciseLibraryService` guards
    /// against re-seeding with a `UserDefaults` flag.
    @MainActor
    private func performFirstLaunchSetup() async {
        do {
            try await appEnvironment.exerciseLibrary.seedIfNeeded()
        } catch {
            // Seeding failure is non-fatal; the library may already be populated
            // from a previous launch or will retry on the next cold start.
            print("[FitnessTrackerApp] Exercise library seeding failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - RootView

/// Decides whether to show the onboarding flow or the main dashboard based on
/// whether a `UserProfile` exists in SwiftData.
struct RootView: View {

    @Environment(AppEnvironment.self) private var appEnvironment
    @Query private var userProfiles: [UserProfile]

    var body: some View {
        if userProfiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}
