import XCTest
@testable import Sously

final class RecipeImportParserTests: XCTestCase {
    func testIngredientLineParser() {
        let parsed = IngredientLineParser.parse("2 tbsp olive oil")
        XCTAssertEqual(parsed.quantity, 2, accuracy: 0.01)
        XCTAssertEqual(parsed.unit, "tbsp")
        XCTAssertEqual(parsed.name, "olive oil")
    }

    func testJSONLDRecipeParser() {
        let html = """
        <script type="application/ld+json">
        {
          "@type": "Recipe",
          "name": "Test Soup",
          "recipeIngredient": ["1 cup broth", "2 carrots"],
          "recipeInstructions": ["Simmer broth.", "Add carrots."]
        }
        </script>
        """
        let draft = JSONLDRecipeParser.parse(html: html)
        XCTAssertEqual(draft?.name, "Test Soup")
        XCTAssertEqual(draft?.ingredients.count, 2)
        XCTAssertEqual(draft?.steps.count, 2)
    }
}
