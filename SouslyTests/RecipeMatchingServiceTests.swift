import CoreData
import XCTest
@testable import Sously

@MainActor
final class RecipeMatchingServiceTests: XCTestCase {
    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!
    private var pantry: PantryRepository!
    private var recipes: RecipeRepository!
    private var matcher: RecipeMatchingService!

    override func setUp() async throws {
        SeedDataService.resetSeedFlag()
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
        pantry = PantryRepository(context: context)
        recipes = RecipeRepository(context: context)
        matcher = RecipeMatchingService(pantry: pantry)
        SeedDataService.seedIfNeeded(context: context)
    }

    func testMatchScoreForGarlicSpinachPasta() throws {
        let allRecipes = try recipes.fetchAll()
        let pasta = try XCTUnwrap(allRecipes.first { $0.safeName == "Garlic Spinach Pasta" })
        let analysis = matcher.analyze(recipe: pasta)
        XCTAssertGreaterThan(analysis.matchScore, 0.5)
        XCTAssertTrue(analysis.matchedIngredients.contains { $0.localizedCaseInsensitiveContains("pasta") })
    }

    func testCanMakeNowWhenAllRequiredPresent() throws {
        _ = try pantry.create(name: "Test Salt", quantity: 1, unit: "tsp")
        let recipe = try recipes.create(
            name: "Salt Only",
            ingredients: [("salt", 1, "tsp", false)],
            steps: ["Add salt."]
        )
        let analysis = matcher.analyze(recipe: recipe)
        XCTAssertEqual(analysis.matchScore, 1, accuracy: 0.01)
        XCTAssertTrue(analysis.missingIngredients.isEmpty)
    }
}
