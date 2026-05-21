import CoreData
import Foundation

enum SeedDataService {
    private static let seedKey = "com.sously.didSeed"

    @MainActor
    static func seedIfNeeded(context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }
        let pantry = PantryRepository(context: context)
        let recipes = RecipeRepository(context: context)
        let categories = CategoryRepository(context: context)
        let tags = TagRepository(context: context)
        let shopping = ShoppingRepository(context: context)

        do {
            let produce = try categories.create(name: "Produce", sortOrder: 0)
            let dairy = try categories.create(name: "Dairy", sortOrder: 1)
            let pantryCat = try categories.create(name: "Pantry", sortOrder: 2)
            _ = try categories.createSubCategory(name: "Leafy Greens", in: produce)
            _ = try categories.createSubCategory(name: "Cheese", in: dairy)

            let weeknight = try tags.findOrCreate(name: "weeknight")
            let vegetarian = try tags.findOrCreate(name: "vegetarian")
            let kids = try tags.findOrCreate(name: "kids")

            _ = try pantry.create(
                name: "Eggs",
                quantity: 10,
                unit: "each",
                brand: "Local Farm",
                storageLocation: "Fridge",
                expirationDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                lowStockThreshold: 6,
                category: dairy,
                tags: [weeknight, kids]
            )
            _ = try pantry.create(
                name: "Spinach",
                quantity: 1,
                unit: "bag",
                storageLocation: "Fridge",
                bestBeforeDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
                lowStockThreshold: 1,
                category: produce,
                tags: [vegetarian]
            )
            _ = try pantry.create(
                name: "Pasta",
                quantity: 2,
                unit: "box",
                storageLocation: "Pantry Shelf",
                category: pantryCat,
                tags: [weeknight, kids]
            )
            _ = try pantry.create(
                name: "Olive Oil",
                quantity: 1,
                unit: "bottle",
                storageLocation: "Pantry Shelf",
                category: pantryCat
            )
            _ = try pantry.create(
                name: "Garlic",
                quantity: 5,
                unit: "clove",
                storageLocation: "Counter Bowl",
                category: produce
            )

            _ = try recipes.create(
                name: "Garlic Spinach Pasta",
                summary: "A fast weeknight pasta with pantry staples.",
                servings: 4,
                prepTimeMinutes: 10,
                cookTimeMinutes: 15,
                ingredients: [
                    ("pasta", 12, "oz", false),
                    ("olive oil", 2, "tbsp", false),
                    ("garlic", 4, "clove", false),
                    ("spinach", 4, "cup", false),
                    ("salt", 1, "tsp", true),
                    ("black pepper", 0.5, "tsp", true)
                ],
                steps: [
                    "Boil pasta in salted water until al dente.",
                    "Warm olive oil, sauté minced garlic until fragrant.",
                    "Toss drained pasta with spinach until wilted.",
                    "Season and serve immediately."
                ],
                tags: [weeknight, vegetarian]
            )

            _ = try recipes.create(
                name: "Simple Scrambled Eggs",
                summary: "Soft scrambled eggs for breakfast or dinner.",
                servings: 2,
                prepTimeMinutes: 5,
                cookTimeMinutes: 8,
                ingredients: [
                    ("eggs", 4, "each", false),
                    ("butter", 1, "tbsp", false),
                    ("salt", 0.25, "tsp", true)
                ],
                steps: [
                    "Whisk eggs with a pinch of salt.",
                    "Melt butter in a nonstick pan over medium-low heat.",
                    "Stir gently until just set."
                ],
                tags: [weeknight, kids]
            )

            let list = try shopping.createList(name: "Weekly Groceries")
            _ = try shopping.addItem(to: list, name: "Milk", quantity: 1, unit: "gallon", price: 4.29)
            _ = try shopping.addItem(to: list, name: "Bananas", quantity: 6, unit: "each", price: 1.99)

            UserDefaults.standard.set(true, forKey: seedKey)
        } catch {
            assertionFailure("Seed failed: \(error)")
        }
    }

    /// Resets seed flag for tests.
    static func resetSeedFlag() {
        UserDefaults.standard.removeObject(forKey: seedKey)
    }
}
