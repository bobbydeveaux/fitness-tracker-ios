import XCTest
@testable import FitnessTracker

// MARK: - BarcodeLookupServiceTests

final class BarcodeLookupServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeService() -> BarcodeLookupService {
        BarcodeLookupService()
    }

    private func makeRepository() -> MockNutritionRepository {
        MockNutritionRepository()
    }

    private func makeFoodItem(
        name: String = "Test Food",
        barcode: String? = nil
    ) -> FoodItem {
        FoodItem(
            name: name,
            barcode: barcode,
            kcalPer100g: 200,
            proteinG: 10,
            carbG: 20,
            fatG: 5
        )
    }

    // MARK: - Barcode Found

    func testLookup_matchingBarcode_returnsFoodItem() async throws {
        let repo = makeRepository()
        let food = makeFoodItem(name: "Oat Milk", barcode: "5000159407236")
        repo.foodItems = [food]

        let service = makeService()
        let result = try await service.lookup(barcode: "5000159407236", in: repo)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Oat Milk")
        XCTAssertEqual(result?.barcode, "5000159407236")
    }

    func testLookup_multipleItems_returnsCorrectMatch() async throws {
        let repo = makeRepository()
        let food1 = makeFoodItem(name: "Chicken Breast", barcode: "1234567890123")
        let food2 = makeFoodItem(name: "Brown Rice", barcode: "9876543210987")
        let food3 = makeFoodItem(name: "Olive Oil", barcode: "1111111111111")
        repo.foodItems = [food1, food2, food3]

        let service = makeService()
        let result = try await service.lookup(barcode: "9876543210987", in: repo)

        XCTAssertEqual(result?.name, "Brown Rice")
    }

    func testLookup_ean8Barcode_returnsMatch() async throws {
        let repo = makeRepository()
        let food = makeFoodItem(name: "Compact Snack", barcode: "12345678")
        repo.foodItems = [food]

        let service = makeService()
        let result = try await service.lookup(barcode: "12345678", in: repo)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Compact Snack")
    }

    // MARK: - Barcode Not Found

    func testLookup_unknownBarcode_returnsNil() async throws {
        let repo = makeRepository()
        repo.foodItems = [makeFoodItem(name: "Known Food", barcode: "1111111111111")]

        let service = makeService()
        let result = try await service.lookup(barcode: "9999999999999", in: repo)

        XCTAssertNil(result)
    }

    func testLookup_emptyRepository_returnsNil() async throws {
        let repo = makeRepository()
        repo.foodItems = []

        let service = makeService()
        let result = try await service.lookup(barcode: "5000159407236", in: repo)

        XCTAssertNil(result)
    }

    func testLookup_itemWithoutBarcode_notMatchedByBarcodeQuery() async throws {
        let repo = makeRepository()
        // Food item with no barcode set
        let food = makeFoodItem(name: "Unlabeled Food", barcode: nil)
        repo.foodItems = [food]

        let service = makeService()
        let result = try await service.lookup(barcode: "1234567890123", in: repo)

        XCTAssertNil(result)
    }

    // MARK: - Repository Error Propagation

    func testLookup_repositoryThrows_propagatesError() async {
        let repo = makeRepository()
        repo.shouldThrow = true

        let service = makeService()
        do {
            _ = try await service.lookup(barcode: "1234567890", in: repo)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockNutritionRepository.MockNutritionError)
        }
    }

    // MARK: - Exact Match Semantics

    func testLookup_partialBarcodeString_doesNotMatch() async throws {
        let repo = makeRepository()
        let food = makeFoodItem(name: "Exact Match Food", barcode: "1234567890123")
        repo.foodItems = [food]

        let service = makeService()
        // Query with partial barcode should NOT match
        let result = try await service.lookup(barcode: "123456789", in: repo)

        XCTAssertNil(result)
    }

    func testLookup_caseSensitiveBarcode_exactMatch() async throws {
        // Barcodes are numeric strings; verify exact string equality is used
        let repo = makeRepository()
        let food = makeFoodItem(name: "Brand Product", barcode: "ABC123")
        repo.foodItems = [food]

        let service = makeService()
        let result = try await service.lookup(barcode: "ABC123", in: repo)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.barcode, "ABC123")
    }

    // MARK: - Actor Isolation

    func testLookup_calledConcurrently_returnsCorrectResults() async throws {
        let repo = makeRepository()
        let food1 = makeFoodItem(name: "Apple Juice", barcode: "1000000000001")
        let food2 = makeFoodItem(name: "Orange Juice", barcode: "2000000000002")
        repo.foodItems = [food1, food2]

        let service = makeService()

        // Concurrent lookups should each return their own correct result
        async let result1 = service.lookup(barcode: "1000000000001", in: repo)
        async let result2 = service.lookup(barcode: "2000000000002", in: repo)
        async let result3 = service.lookup(barcode: "9999999999999", in: repo)

        let (r1, r2, r3) = try await (result1, result2, result3)

        XCTAssertEqual(r1?.name, "Apple Juice")
        XCTAssertEqual(r2?.name, "Orange Juice")
        XCTAssertNil(r3)
    }
}
