import XCTest
@testable import Sously

final class IngredientNormalizerTests: XCTestCase {
    func testNormalizeRemovesStopWords() {
        let result = IngredientNormalizer.normalize("2 cups fresh chopped spinach")
        XCTAssertTrue(result.contains("spinach"))
        XCTAssertFalse(result.contains("fresh"))
        XCTAssertFalse(result.contains("chopped"))
    }

    func testMatchesSynonymsAndSubstrings() {
        XCTAssertTrue(IngredientNormalizer.matches(pantryName: "Eggs", recipeName: "large eggs"))
        XCTAssertTrue(IngredientNormalizer.matches(pantryName: "Olive Oil", recipeName: "extra virgin olive oil"))
        XCTAssertFalse(IngredientNormalizer.matches(pantryName: "Milk", recipeName: "garlic"))
    }
}
