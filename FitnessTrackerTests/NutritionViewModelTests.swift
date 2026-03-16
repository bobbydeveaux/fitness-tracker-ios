import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - MockNutritionRepository

/// In-memory stub for `NutritionRepository` that avoids SwiftData disk I/O.
final class MockNutritionRepository: NutritionRepository, @unchecked Sendable {

    // MARK: - In-memory store

    private(set) var foodItems: [FoodItem] = []
    private(set) var mealLogs: [MealLog] = []

    // MARK: - Error injection

    var shouldThrow: Bool = false

    private func throwIfNeeded() throws {
        if shouldThrow { throw MockNutritionError.operationFailed }
    }

    // MARK: - FoodItem

    func fetchFoodItems() async throws -> [FoodItem] {
        try throwIfNeeded()
        return foodItems.sorted { $0.name < $1.name }
    }

    func fetchFoodItem(byID id: UUID) async throws -> FoodItem? {
        try throwIfNeeded()
        return foodItems.first { $0.id == id }
    }

    func searchFoodItems(query: String) async throws -> [FoodItem] {
        try throwIfNeeded()
        let lowercased = query.lowercased()
        return foodItems.filter { $0.name.lowercased().contains(lowercased) }
    }

    func saveFoodItem(_ item: FoodItem) async throws {
        try throwIfNeeded()
        if !foodItems.contains(where: { $0.id == item.id }) {
            foodItems.append(item)
        }
    }

    func deleteFoodItem(_ item: FoodItem) async throws {
        try throwIfNeeded()
        foodItems.removeAll { $0.id == item.id }
    }

    // MARK: - MealLog

    func fetchMealLogs(for date: Date) async throws -> [MealLog] {
        try throwIfNeeded()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return mealLogs
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func fetchMealLogs(from startDate: Date, to endDate: Date) async throws -> [MealLog] {
        try throwIfNeeded()
        return mealLogs.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func saveMealLog(_ log: MealLog) async throws {
        try throwIfNeeded()
        if !mealLogs.contains(where: { $0.id == log.id }) {
            mealLogs.append(log)
        }
    }

    func deleteMealLog(_ log: MealLog) async throws {
        try throwIfNeeded()
        mealLogs.removeAll { $0.id == log.id }
    }

    // MARK: - MealEntry

    func addMealEntry(_ entry: MealEntry, to log: MealLog) async throws {
        try throwIfNeeded()
        log.entries.append(entry)
        entry.mealLog = log
        if !mealLogs.contains(where: { $0.id == log.id }) {
            mealLogs.append(log)
        }
    }

    func removeMealEntry(_ entry: MealEntry) async throws {
        try throwIfNeeded()
        for log in mealLogs {
            log.entries.removeAll { $0.id == entry.id }
        }
    }

    // MARK: - Error

    enum MockNutritionError: Error, LocalizedError {
        case operationFailed
        var errorDescription: String? { "Mock operation failed" }
    }
}

// MARK: - MockUserProfileRepository (local to this test)

/// Lightweight stub returning a fixed `UserProfile` with known macro targets.
private final class MockProfileRepository: UserProfileRepository, @unchecked Sendable {

    var profile: UserProfile? = nil
    var shouldThrow: Bool = false

    func fetch() async throws -> UserProfile? {
        if shouldThrow { throw MockProfileError.fetchFailed }
        return profile
    }

    func save(_ profile: UserProfile) async throws {
        self.profile = profile
    }

    func delete(_ profile: UserProfile) async throws {
        self.profile = nil
    }

    enum MockProfileError: Error, LocalizedError {
        case fetchFailed
        var errorDescription: String? { "Mock profile fetch failed" }
    }
}

// MARK: - Helpers

private func makeContainer() throws -> ModelContainer {
    try AppSchema.makeContainer(inMemory: true)
}

/// Creates a lightweight `FoodItem` and `MealEntry` for a given number of grams.
/// Nutritional values are calculated proportionally from the per-100g values.
private func makeEntry(
    foodName: String = "Test Food",
    kcalPer100g: Double = 100,
    proteinPer100g: Double = 10,
    carbPer100g: Double = 20,
    fatPer100g: Double = 5,
    servingGrams: Double = 100
) -> MealEntry {
    let ratio = servingGrams / 100
    return MealEntry(
        servingGrams: servingGrams,
        kcal: kcalPer100g * ratio,
        proteinG: proteinPer100g * ratio,
        carbG: carbPer100g * ratio,
        fatG: fatPer100g * ratio
    )
}

// MARK: - NutritionViewModelTests

@MainActor
final class NutritionViewModelTests: XCTestCase {

    private var nutritionRepo: MockNutritionRepository!
    private var profileRepo: MockProfileRepository!
    private var viewModel: NutritionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        nutritionRepo = MockNutritionRepository()
        profileRepo = MockProfileRepository()
        viewModel = NutritionViewModel(
            nutritionRepository: nutritionRepo,
            userProfileRepository: profileRepo
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        nutritionRepo = nil
        profileRepo = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_mealLogsEmpty() {
        XCTAssertTrue(viewModel.mealLogs.isEmpty)
    }

    func testInitialState_isLoadingFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }

    func testInitialState_errorMessageNil() {
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInitialState_macroTotalsZero() {
        XCTAssertEqual(viewModel.totalKcal, 0)
        XCTAssertEqual(viewModel.totalProteinG, 0)
        XCTAssertEqual(viewModel.totalCarbG, 0)
        XCTAssertEqual(viewModel.totalFatG, 0)
    }

    func testInitialState_defaultTargetsNonZero() {
        XCTAssertGreaterThan(viewModel.kcalTarget, 0)
        XCTAssertGreaterThan(viewModel.proteinTarget, 0)
        XCTAssertGreaterThan(viewModel.carbTarget, 0)
        XCTAssertGreaterThan(viewModel.fatTarget, 0)
    }

    // MARK: - load()

    func testLoad_emptyRepository_mealLogsRemainEmpty() async throws {
        await viewModel.load()

        XCTAssertTrue(viewModel.mealLogs.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoad_fetchesMealLogsForSelectedDate() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .breakfast)
        try await nutritionRepo.saveMealLog(log)

        await viewModel.load()

        XCTAssertEqual(viewModel.mealLogs.count, 1)
        XCTAssertEqual(viewModel.mealLogs.first?.mealType, .breakfast)
    }

    func testLoad_doesNotFetchLogsFromOtherDates() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate)!
        let log = MealLog(date: yesterday, mealType: .lunch)
        try await nutritionRepo.saveMealLog(log)

        await viewModel.load()

        XCTAssertTrue(viewModel.mealLogs.isEmpty)
    }

    func testLoad_updatesTargetsFromUserProfile() async throws {
        profileRepo.profile = UserProfile(
            name: "Tester",
            age: 30,
            gender: .female,
            heightCm: 165,
            weightKg: 60,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            tdeeKcal: 1900,
            proteinTargetG: 130,
            carbTargetG: 210,
            fatTargetG: 60
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.kcalTarget, 1900, accuracy: 0.1)
        XCTAssertEqual(viewModel.proteinTarget, 130, accuracy: 0.1)
        XCTAssertEqual(viewModel.carbTarget, 210, accuracy: 0.1)
        XCTAssertEqual(viewModel.fatTarget, 60, accuracy: 0.1)
    }

    func testLoad_noUserProfile_keepsDefaultTargets() async throws {
        profileRepo.profile = nil

        let defaultKcal = viewModel.kcalTarget

        await viewModel.load()

        XCTAssertEqual(viewModel.kcalTarget, defaultKcal, accuracy: 0.1)
    }

    func testLoad_onRepositoryError_setsErrorMessage() async throws {
        nutritionRepo.shouldThrow = true

        await viewModel.load()

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoad_setsIsLoadingFalseAfterCompletion() async throws {
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Macro Aggregation

    func testTotalKcal_sumsAllEntriesAcrossLogs() async throws {
        let today = viewModel.selectedDate
        let log1 = MealLog(date: today, mealType: .breakfast)
        let log2 = MealLog(date: today, mealType: .lunch)
        let entry1 = makeEntry(kcalPer100g: 200, servingGrams: 100) // 200 kcal
        let entry2 = makeEntry(kcalPer100g: 150, servingGrams: 200) // 300 kcal

        try await nutritionRepo.saveMealLog(log1)
        try await nutritionRepo.saveMealLog(log2)
        try await nutritionRepo.addMealEntry(entry1, to: log1)
        try await nutritionRepo.addMealEntry(entry2, to: log2)

        await viewModel.load()

        XCTAssertEqual(viewModel.totalKcal, 500, accuracy: 0.1)
    }

    func testTotalProteinG_sumsCorrectly() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .dinner)
        let entry = makeEntry(proteinPer100g: 30, servingGrams: 150) // 45g protein

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)

        await viewModel.load()

        XCTAssertEqual(viewModel.totalProteinG, 45, accuracy: 0.1)
    }

    func testTotalCarbG_sumsCorrectly() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .snack)
        let entry = makeEntry(carbPer100g: 80, servingGrams: 50) // 40g carbs

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)

        await viewModel.load()

        XCTAssertEqual(viewModel.totalCarbG, 40, accuracy: 0.1)
    }

    func testTotalFatG_sumsCorrectly() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .breakfast)
        let entry = makeEntry(fatPer100g: 20, servingGrams: 50) // 10g fat

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)

        await viewModel.load()

        XCTAssertEqual(viewModel.totalFatG, 10, accuracy: 0.1)
    }

    func testAllEntries_returnsEntriesFromAllLogs() async throws {
        let today = viewModel.selectedDate
        let log1 = MealLog(date: today, mealType: .breakfast)
        let log2 = MealLog(date: today, mealType: .lunch)
        let entry1 = makeEntry(servingGrams: 100)
        let entry2 = makeEntry(servingGrams: 200)

        try await nutritionRepo.saveMealLog(log1)
        try await nutritionRepo.saveMealLog(log2)
        try await nutritionRepo.addMealEntry(entry1, to: log1)
        try await nutritionRepo.addMealEntry(entry2, to: log2)

        await viewModel.load()

        XCTAssertEqual(viewModel.allEntries.count, 2)
    }

    // MARK: - Progress Fractions

    func testKcalProgress_zeroWhenNoEntries() {
        XCTAssertEqual(viewModel.kcalProgress, 0)
    }

    func testKcalProgress_clampedToOne() async throws {
        // Set a very small target so entries exceed it.
        profileRepo.profile = UserProfile(
            name: "A", age: 25, gender: .male,
            heightCm: 175, weightKg: 70,
            activityLevel: .sedentary, goal: .maintain,
            tdeeKcal: 10, proteinTargetG: 1, carbTargetG: 1, fatTargetG: 1
        )
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .breakfast)
        let entry = makeEntry(kcalPer100g: 500, servingGrams: 200) // 1000 kcal > 10 target

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)

        await viewModel.load()

        XCTAssertEqual(viewModel.kcalProgress, 1.0, accuracy: 0.001)
    }

    func testKcalProgress_halfWhenHalfConsumed() async throws {
        profileRepo.profile = UserProfile(
            name: "A", age: 25, gender: .male,
            heightCm: 175, weightKg: 70,
            activityLevel: .sedentary, goal: .maintain,
            tdeeKcal: 2000, proteinTargetG: 150, carbTargetG: 200, fatTargetG: 65
        )
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .lunch)
        let entry = makeEntry(kcalPer100g: 1000, servingGrams: 100) // 1000 kcal = 50% of 2000

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)

        await viewModel.load()

        XCTAssertEqual(viewModel.kcalProgress, 0.5, accuracy: 0.001)
    }

    // MARK: - addEntry(toMealType:)

    func testAddEntry_createsNewMealLogForMealType() async throws {
        let entry = makeEntry(servingGrams: 100)

        await viewModel.addEntry(entry, toMealType: .breakfast)

        XCTAssertEqual(viewModel.mealLogs.count, 1)
        XCTAssertEqual(viewModel.mealLogs.first?.mealType, .breakfast)
    }

    func testAddEntry_reusesExistingMealLogForSameMealType() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .lunch)
        try await nutritionRepo.saveMealLog(log)
        await viewModel.load()

        let entry1 = makeEntry(servingGrams: 100)
        let entry2 = makeEntry(servingGrams: 150)

        await viewModel.addEntry(entry1, toMealType: .lunch)
        await viewModel.addEntry(entry2, toMealType: .lunch)

        // Should still be one MealLog for lunch
        let lunchLogs = viewModel.mealLogs.filter { $0.mealType == .lunch }
        XCTAssertEqual(lunchLogs.count, 1)
        XCTAssertEqual(viewModel.allEntries.count, 2)
    }

    func testAddEntry_differentMealTypes_createsSeparateLogs() async throws {
        let entry1 = makeEntry(servingGrams: 100)
        let entry2 = makeEntry(servingGrams: 200)

        await viewModel.addEntry(entry1, toMealType: .breakfast)
        await viewModel.addEntry(entry2, toMealType: .dinner)

        XCTAssertEqual(viewModel.mealLogs.count, 2)
        XCTAssertEqual(viewModel.allEntries.count, 2)
    }

    func testAddEntry_updatesMacroTotals() async throws {
        let entry = makeEntry(kcalPer100g: 400, proteinPer100g: 30, carbPer100g: 50, fatPer100g: 15, servingGrams: 100)

        await viewModel.addEntry(entry, toMealType: .breakfast)

        XCTAssertEqual(viewModel.totalKcal, 400, accuracy: 0.1)
        XCTAssertEqual(viewModel.totalProteinG, 30, accuracy: 0.1)
        XCTAssertEqual(viewModel.totalCarbG, 50, accuracy: 0.1)
        XCTAssertEqual(viewModel.totalFatG, 15, accuracy: 0.1)
    }

    func testAddEntry_onRepositoryError_setsErrorMessage() async throws {
        nutritionRepo.shouldThrow = true
        let entry = makeEntry(servingGrams: 100)

        await viewModel.addEntry(entry, toMealType: .breakfast)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddEntry_clearsErrorMessageOnSuccess() async throws {
        // Pre-populate an error state.
        nutritionRepo.shouldThrow = true
        await viewModel.load()
        XCTAssertNotNil(viewModel.errorMessage)

        // Now fix the repo and add an entry.
        nutritionRepo.shouldThrow = false
        await viewModel.addEntry(makeEntry(servingGrams: 100), toMealType: .snack)

        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - removeEntry(_:)

    func testRemoveEntry_decrementsMacroTotals() async throws {
        let entry = makeEntry(kcalPer100g: 300, servingGrams: 100) // 300 kcal

        await viewModel.addEntry(entry, toMealType: .breakfast)
        XCTAssertEqual(viewModel.totalKcal, 300, accuracy: 0.1)

        await viewModel.removeEntry(entry)

        XCTAssertEqual(viewModel.totalKcal, 0, accuracy: 0.1)
    }

    func testRemoveEntry_onRepositoryError_setsErrorMessage() async throws {
        let entry = makeEntry(servingGrams: 100)
        await viewModel.addEntry(entry, toMealType: .lunch)

        nutritionRepo.shouldThrow = true
        await viewModel.removeEntry(entry)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - deleteMealLog(_:)

    func testDeleteMealLog_removesLogAndEntries() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .breakfast)
        let entry = makeEntry(servingGrams: 100)

        try await nutritionRepo.saveMealLog(log)
        try await nutritionRepo.addMealEntry(entry, to: log)
        await viewModel.load()
        XCTAssertEqual(viewModel.mealLogs.count, 1)

        await viewModel.deleteMealLog(log)

        XCTAssertTrue(viewModel.mealLogs.isEmpty)
        XCTAssertEqual(viewModel.totalKcal, 0, accuracy: 0.1)
    }

    func testDeleteMealLog_onRepositoryError_setsErrorMessage() async throws {
        let today = viewModel.selectedDate
        let log = MealLog(date: today, mealType: .dinner)
        try await nutritionRepo.saveMealLog(log)
        await viewModel.load()

        nutritionRepo.shouldThrow = true
        await viewModel.deleteMealLog(log)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - selectedDate

    func testSelectedDate_defaultsToToday() {
        let todayStart = Calendar.current.startOfDay(for: .now)
        XCTAssertEqual(viewModel.selectedDate, todayStart)
    }

    func testSelectedDate_changingDateFiltersLogsCorrectly() async throws {
        let today = viewModel.selectedDate
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let todayLog = MealLog(date: today, mealType: .breakfast)
        let yesterdayLog = MealLog(date: yesterday, mealType: .lunch)

        try await nutritionRepo.saveMealLog(todayLog)
        try await nutritionRepo.saveMealLog(yesterdayLog)

        // Load today
        await viewModel.load()
        XCTAssertEqual(viewModel.mealLogs.count, 1)
        XCTAssertEqual(viewModel.mealLogs.first?.mealType, .breakfast)

        // Switch to yesterday
        viewModel.selectedDate = yesterday
        await viewModel.load()
        XCTAssertEqual(viewModel.mealLogs.count, 1)
        XCTAssertEqual(viewModel.mealLogs.first?.mealType, .lunch)
    }
}
