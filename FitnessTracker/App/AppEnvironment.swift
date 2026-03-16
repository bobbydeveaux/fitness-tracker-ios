import Foundation
import Observation
import SwiftData

// MARK: - AppEnvironment

/// Central dependency-injection container for the Fitness Tracker app.
///
/// `AppEnvironment` is an `@Observable` class that holds typed references to every
/// service singleton and repository. It is created once at the app entry point and
/// injected into the SwiftUI environment so any view can access shared dependencies
/// without prop-drilling or global singletons.
///
/// Usage in views:
/// ```swift
/// @Environment(AppEnvironment.self) private var env
/// ```
///
/// Dependency graph (no circular references):
/// ```
/// FitnessTrackerApp
///   └─ AppEnvironment
///        ├─ ModelContainer              (SwiftData, shared by all repositories)
///        ├─ UserProfileRepository       (protocol → SwiftDataUserProfileRepository)
///        ├─ NutritionRepository         (protocol → SwiftDataNutritionRepository)
///        ├─ WorkoutRepository           (protocol → SwiftDataWorkoutRepository)
///        ├─ ProgressRepository          (protocol → SwiftDataProgressRepository)
///        ├─ ExerciseLibraryService      (in-memory JSON cache)
///        ├─ KeychainService             (Security framework wrapper)
///        ├─ HealthKitService            (HKHealthStore wrapper)
///        └─ NotificationScheduler       (UNUserNotificationCenter wrapper)
/// ```
@Observable
final class AppEnvironment {

    // MARK: - SwiftData

    /// The shared `ModelContainer` configured with CloudKit private DB support.
    /// Injected into the scene via `.modelContainer(env.modelContainer)` so
    /// SwiftUI `@Query` macros work in any view.
    let modelContainer: ModelContainer

    // MARK: - Repositories

    /// Provides CRUD access to the single `UserProfile` record.
    let userProfileRepository: any UserProfileRepository

    /// Provides access to `FoodItem`, `MealLog`, and `MealEntry` records.
    let nutritionRepository: any NutritionRepository

    /// Provides access to `WorkoutPlan`, `WorkoutDay`, and `WorkoutSession` records.
    let workoutRepository: any WorkoutRepository

    /// Provides access to `BodyMetric` and `Streak` records for progress analytics.
    let progressRepository: any ProgressRepository

    // MARK: - Services

    /// Loads and caches the bundled `exercises.json`; seeds SwiftData on first launch.
    let exerciseLibraryService: ExerciseLibraryService

    /// Wraps the iOS Keychain for secure storage of the Claude API key.
    let keychainService: KeychainService

    /// Wraps `HKHealthStore` for HealthKit reads and workout writes.
    let healthKitService: any HealthKitServiceProtocol

    /// Wraps `UNUserNotificationCenter` for scheduling workout-reminder notifications.
    let notificationScheduler: any NotificationSchedulerProtocol

    // MARK: - Init

    /// Memberwise initialiser used for production setup and for injecting test doubles.
    ///
    /// - Parameters:
    ///   - modelContainer: The configured `ModelContainer` instance.
    ///   - userProfileRepository: Repository conforming to `UserProfileRepository`.
    ///   - nutritionRepository: Repository conforming to `NutritionRepository`.
    ///   - workoutRepository: Repository conforming to `WorkoutRepository`.
    ///   - progressRepository: Repository conforming to `ProgressRepository`.
    ///   - exerciseLibraryService: Service for exercise JSON management.
    ///   - keychainService: Service for Keychain access.
    ///   - healthKitService: Service for HealthKit access.
    ///   - notificationScheduler: Service for scheduling workout-reminder notifications.
    init(
        modelContainer: ModelContainer,
        userProfileRepository: any UserProfileRepository,
        nutritionRepository: any NutritionRepository,
        workoutRepository: any WorkoutRepository,
        progressRepository: any ProgressRepository,
        exerciseLibraryService: ExerciseLibraryService = ExerciseLibraryService(),
        keychainService: KeychainService = KeychainService(),
        healthKitService: any HealthKitServiceProtocol = HealthKitService.shared,
        notificationScheduler: any NotificationSchedulerProtocol = NotificationScheduler.shared
    ) {
        self.modelContainer = modelContainer
        self.userProfileRepository = userProfileRepository
        self.nutritionRepository = nutritionRepository
        self.workoutRepository = workoutRepository
        self.progressRepository = progressRepository
        self.exerciseLibraryService = exerciseLibraryService
        self.keychainService = keychainService
        self.healthKitService = healthKitService
        self.notificationScheduler = notificationScheduler
    }
}

// MARK: - Production Factory

extension AppEnvironment {

    /// Builds the production `AppEnvironment` wiring the real SwiftData-backed
    /// repositories to the shared `ModelContainer`.
    ///
    /// The `ModelContainer` schema and CloudKit configuration will be expanded
    /// once all `@Model` types are defined.
    static func makeProductionEnvironment() -> AppEnvironment {
        let container = makeModelContainer()
        let context = container.mainContext
        return AppEnvironment(
            modelContainer: container,
            userProfileRepository: SwiftDataUserProfileRepository(context: context),
            nutritionRepository: SwiftDataNutritionRepository(context: context),
            workoutRepository: SwiftDataWorkoutRepository(context: context),
            progressRepository: SwiftDataProgressRepository(context: context),
            exerciseLibraryService: ExerciseLibraryService(modelContainer: container)
        )
    }

    /// Creates the `ModelContainer` for the app schema.
    ///
    /// The schema list is intentionally empty here and will be populated with
    /// the versioned `AppSchemaV1` types added in subsequent tasks.
    static func makeModelContainer() -> ModelContainer {
        do {
            // Schema types registered here once @Model classes are defined.
            let schema = Schema([])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.fitnessTracker.app")
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A fatal error here means the data store is misconfigured —
            // surface this immediately rather than silently corrupting state.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
