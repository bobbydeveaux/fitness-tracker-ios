import XCTest
@testable import FitnessTracker

/// Validates the `FoodSearchFilter` FTS prefix-match algorithm used by `FoodSearchView`.
final class FoodSearchViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeItem(name: String) -> FoodItem {
        FoodItem(name: name, kcalPer100g: 100, proteinG: 10, carbG: 10, fatG: 5)
    }

    // MARK: - Single-token prefix match

    func testPrefixMatchSingleTokenStart() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "chi"))
    }

    func testPrefixMatchSingleTokenSecondWord() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "bre"))
    }

    func testPrefixMatchSingleTokenFullWord() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "chicken"))
    }

    func testPrefixMatchSingleTokenNoMatch() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertFalse(FoodSearchFilter.matches(item: item, query: "xyz"))
    }

    func testPrefixMatchDoesNotMatchMidWord() {
        // "hicken" is in the middle of "Chicken", not a prefix
        let item = makeItem(name: "Chicken Breast")
        XCTAssertFalse(FoodSearchFilter.matches(item: item, query: "hicken"))
    }

    // MARK: - Multi-token prefix match

    func testMultiTokenAllMatch() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "chi bre"))
    }

    func testMultiTokenPartialNoMatch() {
        let item = makeItem(name: "Chicken Breast")
        XCTAssertFalse(FoodSearchFilter.matches(item: item, query: "chi xyz"))
    }

    func testMultiTokenBothFullWords() {
        let item = makeItem(name: "Brown Rice")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "brown rice"))
    }

    // MARK: - Case insensitivity

    func testCaseInsensitiveUpperQuery() {
        let item = makeItem(name: "Oat Flakes")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "OAT"))
    }

    func testCaseInsensitiveMixedQuery() {
        let item = makeItem(name: "Greek Yogurt")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "gReEk yO"))
    }

    // MARK: - Empty / whitespace query

    func testEmptyQueryMatchesAll() {
        let item = makeItem(name: "Salmon")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: ""))
    }

    func testWhitespaceOnlyQueryMatchesAll() {
        let item = makeItem(name: "Salmon")
        XCTAssertTrue(FoodSearchFilter.matches(item: item, query: "   "))
    }

    // MARK: - filter(_:query:)

    func testFilterReturnsMatchingSubset() {
        let items = [
            makeItem(name: "Apple"),
            makeItem(name: "Banana"),
            makeItem(name: "Apricot"),
            makeItem(name: "Blueberry"),
        ]
        let results = FoodSearchFilter.filter(items, query: "ap")
        XCTAssertEqual(results.map(\.name).sorted(), ["Apple", "Apricot"])
    }

    func testFilterEmptyQueryReturnsAll() {
        let items = [makeItem(name: "Apple"), makeItem(name: "Banana")]
        let results = FoodSearchFilter.filter(items, query: "")
        XCTAssertEqual(results.count, 2)
    }

    func testFilterNoMatchReturnsEmpty() {
        let items = [makeItem(name: "Apple"), makeItem(name: "Banana")]
        let results = FoodSearchFilter.filter(items, query: "xyz")
        XCTAssertTrue(results.isEmpty)
    }

    func testFilterMultipleTokensNarrowsResults() {
        let items = [
            makeItem(name: "Brown Rice"),
            makeItem(name: "Brown Sugar"),
            makeItem(name: "White Rice"),
        ]
        let results = FoodSearchFilter.filter(items, query: "bro ri")
        XCTAssertEqual(results.map(\.name), ["Brown Rice"])
    }
}
