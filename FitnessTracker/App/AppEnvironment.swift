import Foundation
import SwiftData

// MARK: - AppEnvironment

/// A centralised, `@Observable` dependency-injection container that holds all
/// service singletons for the app.
///
/// Inject this at the root SwiftUI entry point via `.environment(appEnvironment)`
/// and access it in child views or ViewModels with `@Environment(AppEnvironment.self)`.
///
/// Dependency graph (no circular references):
/// ```
/// ModelContainer
///   └─ ExerciseLibraryService
///   └─ (Repositories — injected per feature module)
/// KeychainService  (stateless, no SwiftData dependency)
/// ```
@Observable
final class AppEnvironment {

    // MARK: - Persistence

    /// The shared SwiftData `ModelContainer` configured with `AppSchemaV1`.
    ///
    /// All repositories and services that need persistence must use this container.
    let modelContainer: ModelContainer

    // MARK: - Services

    /// Loads and caches the bundled exercise library, seeding SwiftData on first launch.
    let exerciseLibrary: ExerciseLibraryService

    /// Wraps the iOS Keychain for secure storage of API keys and user tokens.
    let keychain: KeychainService

    // MARK: - Initialisation

    /// Designated initialiser — creates the `ModelContainer` and wires all services.
    ///
    /// - Parameter inMemory: When `true` the SwiftData store is kept in RAM only.
    ///   Use this for Xcode Previews and unit tests.
    init(inMemory: Bool = false) {
        let container = AppEnvironment.makeModelContainer(inMemory: inMemory)
        self.modelContainer = container
        self.exerciseLibrary = ExerciseLibraryService(modelContainer: container)
        self.keychain = KeychainService()
    }

    // MARK: - Private factory

    private static func makeModelContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failed ModelContainer is unrecoverable; crash with a clear message.
            fatalError("AppEnvironment: failed to create ModelContainer — \(error.localizedDescription)")
        }
    }
}
