import SwiftUI

// MARK: - App Entry Point

/// Root entry point for the Fitness Tracker application.
///
/// `FitnessTrackerApp` creates the single `AppEnvironment` instance and
/// injects it into the SwiftUI environment so every view in the hierarchy
/// can access shared services and repositories via:
/// ```swift
/// @Environment(AppEnvironment.self) private var env
/// ```
///
/// The `ModelContainer` from the environment is also attached to the window
/// group scene so `@Query` macros work out of the box in any view.
@main
struct FitnessTrackerApp: App {

    // MARK: - Dependencies

    /// The single, app-wide dependency container. Created once and never
    /// replaced so all views share the same service and repository instances.
    @State private var appEnvironment: AppEnvironment

    // MARK: - Init

    init() {
        let environment = AppEnvironment.makeProductionEnvironment()
        _appEnvironment = State(initialValue: environment)
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            RootView()
                // Inject environment so any descendant view can resolve services.
                .environment(appEnvironment)
        }
        // Attach the shared ModelContainer to the scene so @Query macros work
        // in all views without extra configuration.
        .modelContainer(appEnvironment.modelContainer)
    }
}
