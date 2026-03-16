import XCTest
import SwiftData
@testable import FitnessTracker

/// Validates that the SwiftData ModelContainer can be instantiated with the in-memory
/// configuration and that all 12 model types can be inserted and fetched without errors.
final class AppSchemaTests: XCTestCase {

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        try AppSchema.makeContainer(inMemory: true)
    }

    // MARK: - Container Instantiation

    func testContainerInstantiatesWithoutError() throws {
        XCTAssertNoThrow(try makeInMemoryContainer())
    }

    // MARK: - Model Insert & Fetch

    func testInsertAndFetchUserProfile() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let profile = UserProfile(
            age: 30,
            biologicalSex: .male,
            heightCm: 180.0,
            weightKg: 80.0,
            activityLevel: .sedentary,
            goal: .maintain,
            tdee: 2500.0,
            proteinGrams: 160.0,
            carbGrams: 250.0,
            fatGrams: 80.0
        )
        context.insert(profile)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.age, 30)
        XCTAssertEqual(fetched.first?.biologicalSex, .male)
        XCTAssertEqual(fetched.first?.tdee, 2500.0, accuracy: 0.01)
    }

    func testInsertAndFetchFoodItem() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let item = FoodItem(
            name: "Chicken Breast",
            caloriesPer100g: 165.0,
            proteinPer100g: 31.0,
            carbsPer100g: 0.0,
            fatPer100g: 3.6,
            isCustom: false
        )
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Chicken Breast")
        XCTAssertEqual(fetched.first?.proteinPer100g, 31.0, accuracy: 0.01)
    }

    func testInsertAndFetchMealLogWithEntries() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let foodItem = FoodItem(
            name: "Oats",
            caloriesPer100g: 389.0,
            proteinPer100g: 17.0,
            carbsPer100g: 66.0,
            fatPer100g: 7.0
        )
        context.insert(foodItem)

        let log = MealLog(date: Date(), mealType: .breakfast)
        context.insert(log)

        let entry = MealEntry(
            servingGrams: 100.0,
            calories: 389.0,
            proteinGrams: 17.0,
            carbGrams: 66.0,
            fatGrams: 7.0
        )
        entry.mealLog = log
        entry.foodItem = foodItem
        context.insert(entry)

        try context.save()

        let logs = try context.fetch(FetchDescriptor<MealLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.entries.count, 1)
        XCTAssertEqual(logs.first?.mealType, .breakfast)
    }

    func testInsertAndFetchExercise() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let exercise = Exercise(
            name: "Barbell Squat",
            muscleGroup: .legs,
            equipment: .barbell,
            instructions: "Stand with bar on upper back, squat until thighs are parallel."
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Barbell Squat")
        XCTAssertEqual(fetched.first?.muscleGroup, .legs)
    }

    func testInsertAndFetchWorkoutPlanWithDays() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let plan = WorkoutPlan(splitType: .pushPullLegs, daysPerWeek: 6)
        context.insert(plan)

        let day = WorkoutDay(label: "Push A", weekdayIndex: 1)
        day.workoutPlan = plan
        context.insert(day)

        try context.save()

        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.days.count, 1)
        XCTAssertEqual(plans.first?.splitType, .pushPullLegs)
    }

    func testInsertAndFetchWorkoutSessionWithLoggedSets() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let exercise = Exercise(
            name: "Bench Press",
            muscleGroup: .chest,
            equipment: .barbell,
            instructions: "Lie on bench, lower bar to chest, press up."
        )
        context.insert(exercise)

        let session = WorkoutSession(status: .complete, durationSeconds: 3600, totalVolumeKg: 4000)
        context.insert(session)

        let set = LoggedSet(weightKg: 100.0, reps: 5, isPR: true, isComplete: true)
        set.session = session
        set.exercise = exercise
        context.insert(set)

        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.loggedSets.count, 1)
        XCTAssertEqual(sessions.first?.loggedSets.first?.weightKg, 100.0, accuracy: 0.01)
        XCTAssertTrue(sessions.first?.loggedSets.first?.isPR == true)
    }

    func testInsertAndFetchBodyMetric() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let profile = UserProfile(
            age: 25,
            biologicalSex: .female,
            heightCm: 165.0,
            weightKg: 60.0,
            activityLevel: .moderatelyActive,
            goal: .cut,
            tdee: 2000.0,
            proteinGrams: 130.0,
            carbGrams: 200.0,
            fatGrams: 60.0
        )
        context.insert(profile)

        let metric = BodyMetric(metricType: .weight, value: 60.0)
        metric.userProfile = profile
        context.insert(metric)

        try context.save()

        let metrics = try context.fetch(FetchDescriptor<BodyMetric>())
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics.first?.metricType, .weight)
        XCTAssertEqual(metrics.first?.value, 60.0, accuracy: 0.01)
    }

    func testInsertAndFetchStreak() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let streak = Streak(currentCount: 7, longestCount: 14, lastActivityDate: Date())
        context.insert(streak)
        try context.save()

        let streaks = try context.fetch(FetchDescriptor<Streak>())
        XCTAssertEqual(streaks.count, 1)
        XCTAssertEqual(streaks.first?.currentCount, 7)
        XCTAssertEqual(streaks.first?.longestCount, 14)
    }

    // MARK: - Cascade Delete

    func testCascadeDeleteMealLogRemovesEntries() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let log = MealLog(date: Date(), mealType: .lunch)
        context.insert(log)

        let entry = MealEntry(
            servingGrams: 150.0,
            calories: 200.0,
            proteinGrams: 20.0,
            carbGrams: 10.0,
            fatGrams: 5.0
        )
        entry.mealLog = log
        context.insert(entry)
        try context.save()

        context.delete(log)
        try context.save()

        let remainingEntries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(remainingEntries.count, 0, "MealEntry records should be cascade deleted with their MealLog")
    }

    func testCascadeDeleteWorkoutSessionRemovesSets() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let session = WorkoutSession()
        context.insert(session)

        let set = LoggedSet(weightKg: 80.0, reps: 8)
        set.session = session
        context.insert(set)
        try context.save()

        context.delete(session)
        try context.save()

        let remainingSets = try context.fetch(FetchDescriptor<LoggedSet>())
        XCTAssertEqual(remainingSets.count, 0, "LoggedSet records should be cascade deleted with their WorkoutSession")
    }

    // MARK: - All 12 Model Types Covered

    func testAllModelTypesCanBeInserted() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. UserProfile
        let profile = UserProfile(age: 28, biologicalSex: .male, heightCm: 175, weightKg: 75,
                                  activityLevel: .veryActive, goal: .bulk, tdee: 3000,
                                  proteinGrams: 200, carbGrams: 350, fatGrams: 90)
        context.insert(profile)

        // 2. FoodItem
        let food = FoodItem(name: "Rice", caloriesPer100g: 130, proteinPer100g: 2.7,
                            carbsPer100g: 28, fatPer100g: 0.3)
        context.insert(food)

        // 3. MealLog
        let mealLog = MealLog(date: Date(), mealType: .dinner)
        context.insert(mealLog)

        // 4. MealEntry
        let mealEntry = MealEntry(servingGrams: 200, calories: 260, proteinGrams: 5.4,
                                  carbGrams: 56, fatGrams: 0.6)
        mealEntry.mealLog = mealLog
        mealEntry.foodItem = food
        context.insert(mealEntry)

        // 5. Exercise
        let exercise = Exercise(name: "Deadlift", muscleGroup: .back, equipment: .barbell,
                                instructions: "Hip hinge, pull bar from floor.")
        context.insert(exercise)

        // 6. WorkoutPlan
        let plan = WorkoutPlan(splitType: .upperLower, daysPerWeek: 4)
        context.insert(plan)

        // 7. WorkoutDay
        let day = WorkoutDay(label: "Upper A", weekdayIndex: 2)
        day.workoutPlan = plan
        context.insert(day)

        // 8. PlannedExercise
        let planned = PlannedExercise(targetSets: 4, targetReps: 6, targetRPE: 8.0, sortOrder: 1)
        planned.workoutDay = day
        planned.exercise = exercise
        context.insert(planned)

        // 9. WorkoutSession
        let session = WorkoutSession(status: .active)
        session.workoutDay = day
        context.insert(session)

        // 10. LoggedSet
        let loggedSet = LoggedSet(weightKg: 120, reps: 5, rpe: 8.0, isComplete: true, sortOrder: 1)
        loggedSet.session = session
        loggedSet.exercise = exercise
        context.insert(loggedSet)

        // 11. BodyMetric
        let metric = BodyMetric(metricType: .waist, value: 82.0)
        metric.userProfile = profile
        context.insert(metric)

        // 12. Streak
        let streak = Streak(currentCount: 3, longestCount: 21)
        streak.userProfile = profile
        context.insert(streak)

        XCTAssertNoThrow(try context.save())
    }
}
