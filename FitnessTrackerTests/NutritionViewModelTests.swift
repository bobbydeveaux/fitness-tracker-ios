import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - MockNutritionRepository

/// In-memory mock for `NutritionRepository` used in tests.
final class MockNutritionRepository: NutritionRepository, @unchecked Sendable {

    // MARK: - Storage

    var foodItems: [FoodItem] = []
    var mealLogs: [MealLog] = []

    // MARK: - Error Injection

    var shouldThrow: Bool = false

    private func maybeThrow() throws {
        if shouldThrow { throw MockNutritionError.forced }
    }

    // MARK: - FoodItem

    func fetchFoodItems() async throws -> [FoodItem] {
        try maybeThrow()
        return foodItems.sorted { $0.name < $1.name }
    }

    func fetchFoodItem(byID id: UUID) async throws -> FoodItem? {
        try maybeThrow()
        return foodItems.first { $0.id == id }
    }

    func searchFoodItems(query: String) async throws -> [FoodItem] {
        try maybeThrow()
        let q = query.lowercased()
        return foodItems.filter { $0.name.lowercased().contains(q) }
    }

    func saveFoodItem(_ item: FoodItem) async throws {
        try maybeThrow()
        if !foodItems.contains(where: { $0.id == item.id }) {
            foodItems.append(item)
        }
    }

    func deleteFoodItem(_ item: FoodItem) async throws {
        try maybeThrow()
        foodItems.removeAll { $0.id == item.id }
    }

    // MARK: - MealLog

    func fetchMealLogs(for date: Date) async throws -> [MealLog] {
        try maybeThrow()
        let calendar = Calendar.current
        return mealLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchMealLogs(from startDate: Date, to endDate: Date) async throws -> [MealLog] {
        try maybeThrow()
        return mealLogs.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func saveMealLog(_ log: MealLog) async throws {
        try maybeThrow()
        if !mealLogs.contains(where: { $0.id == log.id }) {
            mealLogs.append(log)
        }
    }

    func deleteMealLog(_ log: MealLog) async throws {
        try maybeThrow()
        mealLogs.removeAll { $0.id == log.id }
    }

    // MARK: - MealEntry

    func addMealEntry(_ entry: MealEntry, to log: MealLog) async throws {
        try maybeThrow()
        log.entries.append(entry)
        entry.mealLog = log
    }

    func removeMealEntry(_ entry: MealEntry) async throws {
        try maybeThrow()
        entry.mealLog?.entries.removeAll { $0.id == entry.id }
    }

    // MARK: - Errors

    enum MockNutritionError: Error {
        case forced
    }
}

// MARK: - NutritionViewModelTests

@MainActor
final class NutritionViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(
        repository: MockNutritionRepository = MockNutritionRepository()
    ) -> NutritionViewModel {
        NutritionViewModel(repository: repository)
    }

    private func makeFoodItem(
        name: String = "Test Food",
        kcalPer100g: Double = 200,
        proteinG: Double = 20,
        carbG: Double = 15,
        fatG: Double = 8
    ) -> FoodItem {
        FoodItem(
            name: name,
            kcalPer100g: kcalPer100g,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG
        )
    }

    private func makeMealLog(mealType: MealType = .breakfast) -> MealLog {
        MealLog(date: Date(), mealType: mealType)
    }

    private func makeMealEntry(
        servingGrams: Double = 100,
        kcal: Double = 200,
        proteinG: Double = 20,
        carbG: Double = 15,
        fatG: Double = 8
    ) -> MealEntry {
        MealEntry(
            servingGrams: servingGrams,
            kcal: kcal,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG
        )
    }

    // MARK: - Initial State

    func testInitialMealLogs_isEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.mealLogs.isEmpty)
    }

    func testInitialMacros_areZero() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.totalKcal, 0)
        XCTAssertEqual(vm.totalProteinG, 0)
        XCTAssertEqual(vm.totalCarbG, 0)
        XCTAssertEqual(vm.totalFatG, 0)
    }

    func testInitialLoadingState_isFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - loadTodaysLogs

    func testLoadTodaysLogs_emptyRepository_mealLogsRemainsEmpty() async {
        let vm = makeViewModel()
        await vm.loadTodaysLogs()
        XCTAssertTrue(vm.mealLogs.isEmpty)
    }

    func testLoadTodaysLogs_populatesFromRepository() async {
        let repo = MockNutritionRepository()
        let log = makeMealLog(mealType: .breakfast)
        repo.mealLogs.append(log)

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.mealLogs.count, 1)
        XCTAssertEqual(vm.mealLogs.first?.mealType, .breakfast)
    }

    func testLoadTodaysLogs_onError_setsErrorMessage() async {
        let repo = MockNutritionRepository()
        repo.shouldThrow = true

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.mealLogs.isEmpty)
    }

    func testLoadTodaysLogs_clearsErrorMessageOnSuccess() async {
        let repo = MockNutritionRepository()
        repo.shouldThrow = true
        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()
        XCTAssertNotNil(vm.errorMessage)

        repo.shouldThrow = false
        await vm.loadTodaysLogs()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Macro Aggregation

    func testTotalKcal_sumOfAllEntries() async {
        let repo = MockNutritionRepository()
        let log = makeMealLog()
        let entry1 = makeMealEntry(kcal: 300)
        let entry2 = makeMealEntry(kcal: 200)
        log.entries = [entry1, entry2]
        repo.mealLogs.append(log)

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.totalKcal, 500, accuracy: 0.01)
    }

    func testTotalProteinG_sumOfAllEntries() async {
        let repo = MockNutritionRepository()
        let log = makeMealLog()
        let entry1 = makeMealEntry(proteinG: 30)
        let entry2 = makeMealEntry(proteinG: 25)
        log.entries = [entry1, entry2]
        repo.mealLogs.append(log)

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.totalProteinG, 55, accuracy: 0.01)
    }

    func testTotalCarbG_sumOfAllEntries() async {
        let repo = MockNutritionRepository()
        let log = makeMealLog()
        let entry1 = makeMealEntry(carbG: 40)
        let entry2 = makeMealEntry(carbG: 50)
        log.entries = [entry1, entry2]
        repo.mealLogs.append(log)

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.totalCarbG, 90, accuracy: 0.01)
    }

    func testTotalFatG_sumOfAllEntries() async {
        let repo = MockNutritionRepository()
        let log = makeMealLog()
        let entry1 = makeMealEntry(fatG: 10)
        let entry2 = makeMealEntry(fatG: 15)
        log.entries = [entry1, entry2]
        repo.mealLogs.append(log)

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.totalFatG, 25, accuracy: 0.01)
    }

    func testMacros_aggregateAcrossMultipleLogs() async {
        let repo = MockNutritionRepository()
        let breakfastLog = makeMealLog(mealType: .breakfast)
        let lunchLog = makeMealLog(mealType: .lunch)

        breakfastLog.entries = [makeMealEntry(kcal: 400, proteinG: 30)]
        lunchLog.entries = [makeMealEntry(kcal: 600, proteinG: 45)]
        repo.mealLogs = [breakfastLog, lunchLog]

        let vm = makeViewModel(repository: repo)
        await vm.loadTodaysLogs()

        XCTAssertEqual(vm.totalKcal, 1000, accuracy: 0.01)
        XCTAssertEqual(vm.totalProteinG, 75, accuracy: 0.01)
    }

    // MARK: - addEntry

    func testAddEntry_createsEntryWithCorrectMacros() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        // 200 kcal per 100g, serve 50g → 100 kcal
        let food = makeFoodItem(kcalPer100g: 200, proteinG: 20, carbG: 10, fatG: 8)
        await vm.addEntry(foodItem: food, servingGrams: 50, mealType: .breakfast)

        XCTAssertEqual(vm.totalKcal, 100, accuracy: 0.01)
        XCTAssertEqual(vm.totalProteinG, 10, accuracy: 0.01)
        XCTAssertEqual(vm.totalCarbG, 5, accuracy: 0.01)
        XCTAssertEqual(vm.totalFatG, 4, accuracy: 0.01)
    }

    func testAddEntry_createsNewMealLogIfNoneExists() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem()
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .lunch)

        let todayLogs = try? await repo.fetchMealLogs(for: vm.selectedDate)
        XCTAssertEqual(todayLogs?.count ?? 0, 1)
        XCTAssertEqual(todayLogs?.first?.mealType, .lunch)
    }

    func testAddEntry_reusesExistingMealLog() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem()
        // Add two entries to the same meal type
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .dinner)
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .dinner)

        let todayLogs = try? await repo.fetchMealLogs(for: vm.selectedDate)
        XCTAssertEqual(todayLogs?.count ?? 0, 1, "Should reuse the existing dinner log")
        XCTAssertEqual(todayLogs?.first?.entries.count ?? 0, 2)
    }

    func testAddEntry_onError_setsErrorMessage() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)
        repo.shouldThrow = true

        let food = makeFoodItem()
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .breakfast)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - removeEntry

    func testRemoveEntry_decrementsMacroTotals() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem(kcalPer100g: 200, proteinG: 20, carbG: 10, fatG: 8)
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .breakfast)

        // Confirm macros are present
        XCTAssertEqual(vm.totalKcal, 200, accuracy: 0.01)

        // Remove the entry
        guard let entry = vm.mealLogs.first?.entries.first else {
            XCTFail("Expected an entry after addEntry")
            return
        }
        await vm.removeEntry(entry)

        XCTAssertEqual(vm.totalKcal, 0, accuracy: 0.01)
        XCTAssertEqual(vm.totalProteinG, 0, accuracy: 0.01)
    }

    func testRemoveEntry_onError_setsErrorMessage() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem()
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .snack)

        guard let entry = vm.mealLogs.first?.entries.first else {
            XCTFail("Expected an entry")
            return
        }

        repo.shouldThrow = true
        await vm.removeEntry(entry)

        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - deleteMealLog

    func testDeleteMealLog_removesLogFromMealLogs() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem()
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .breakfast)
        XCTAssertFalse(vm.mealLogs.isEmpty)

        let log = vm.mealLogs.first!
        await vm.deleteMealLog(log)

        XCTAssertTrue(vm.mealLogs.isEmpty)
    }

    func testDeleteMealLog_resetsMacrosToZero() async {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let food = makeFoodItem(kcalPer100g: 300)
        await vm.addEntry(foodItem: food, servingGrams: 100, mealType: .lunch)
        XCTAssertGreaterThan(vm.totalKcal, 0)

        let log = vm.mealLogs.first!
        await vm.deleteMealLog(log)

        XCTAssertEqual(vm.totalKcal, 0, accuracy: 0.01)
    }

    // MARK: - getOrCreateMealLog

    func testGetOrCreateMealLog_createsNewLog() async throws {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let log = try await vm.getOrCreateMealLog(for: .dinner)
        XCTAssertEqual(log.mealType, .dinner)
        XCTAssertEqual(vm.mealLogs.count, 1)
    }

    func testGetOrCreateMealLog_returnsExistingLog() async throws {
        let repo = MockNutritionRepository()
        let vm = makeViewModel(repository: repo)

        let first = try await vm.getOrCreateMealLog(for: .breakfast)
        let second = try await vm.getOrCreateMealLog(for: .breakfast)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(vm.mealLogs.count, 1)
    }
}
