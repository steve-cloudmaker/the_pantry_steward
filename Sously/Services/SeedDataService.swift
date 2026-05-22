import CoreData
import Foundation

enum SeedDataService {
    private static let seedKey = "com.sously.didSeed"
    private static var isSeeding = false

    /// Stable IDs so CloudKit merges sample rows across devices instead of duplicating them.
    private enum SeedID {
        static let categoryProduce = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!
        static let categoryDairy = UUID(uuidString: "A1000001-0000-4000-8000-000000000002")!
        static let categoryPantry = UUID(uuidString: "A1000001-0000-4000-8000-000000000003")!
        static let subLeafyGreens = UUID(uuidString: "A1000001-0000-4000-8000-000000000011")!
        static let subCheese = UUID(uuidString: "A1000001-0000-4000-8000-000000000012")!
        static let tagWeeknight = UUID(uuidString: "A1000001-0000-4000-8000-000000000021")!
        static let tagVegetarian = UUID(uuidString: "A1000001-0000-4000-8000-000000000022")!
        static let tagKids = UUID(uuidString: "A1000001-0000-4000-8000-000000000023")!
        static let itemEggs = UUID(uuidString: "A1000002-0000-4000-8000-000000000001")!
        static let itemSpinach = UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!
        static let itemPasta = UUID(uuidString: "A1000002-0000-4000-8000-000000000003")!
        static let itemOliveOil = UUID(uuidString: "A1000002-0000-4000-8000-000000000004")!
        static let itemGarlic = UUID(uuidString: "A1000002-0000-4000-8000-000000000005")!
        static let recipePasta = UUID(uuidString: "A1000003-0000-4000-8000-000000000001")!
        static let recipeEggs = UUID(uuidString: "A1000003-0000-4000-8000-000000000002")!
        static let listWeekly = UUID(uuidString: "A1000004-0000-4000-8000-000000000001")!
    }

    @MainActor
    static func seedIfNeeded(context: NSManagedObjectContext) {
        guard !isSeeding else { return }

        if UserDefaults.standard.bool(forKey: seedKey) {
            return
        }

        if hasExistingSampleData(in: context) {
            markSeeded()
            return
        }

        isSeeding = true
        defer { isSeeding = false }

        let pantry = PantryRepository(context: context)
        let recipes = RecipeRepository(context: context)
        let categories = CategoryRepository(context: context)
        let tags = TagRepository(context: context)
        let shopping = ShoppingRepository(context: context)

        do {
            let produce = try categories.create(
                id: SeedID.categoryProduce,
                name: "Produce",
                sortOrder: 0
            )
            let dairy = try categories.create(
                id: SeedID.categoryDairy,
                name: "Dairy",
                sortOrder: 1
            )
            let pantryCat = try categories.create(
                id: SeedID.categoryPantry,
                name: "Pantry",
                sortOrder: 2
            )
            _ = try categories.createSubCategory(
                id: SeedID.subLeafyGreens,
                name: "Leafy Greens",
                in: produce
            )
            _ = try categories.createSubCategory(
                id: SeedID.subCheese,
                name: "Cheese",
                in: dairy
            )

            let weeknight = try tags.findOrCreate(id: SeedID.tagWeeknight, name: "weeknight")
            let vegetarian = try tags.findOrCreate(id: SeedID.tagVegetarian, name: "vegetarian")
            let kids = try tags.findOrCreate(id: SeedID.tagKids, name: "kids")

            _ = try pantry.create(
                id: SeedID.itemEggs,
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
                id: SeedID.itemSpinach,
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
                id: SeedID.itemPasta,
                name: "Pasta",
                quantity: 2,
                unit: "box",
                storageLocation: "Pantry Shelf",
                category: pantryCat,
                tags: [weeknight, kids]
            )
            _ = try pantry.create(
                id: SeedID.itemOliveOil,
                name: "Olive Oil",
                quantity: 1,
                unit: "bottle",
                storageLocation: "Pantry Shelf",
                category: pantryCat
            )
            _ = try pantry.create(
                id: SeedID.itemGarlic,
                name: "Garlic",
                quantity: 5,
                unit: "clove",
                storageLocation: "Counter Bowl",
                category: produce
            )

            _ = try recipes.create(
                id: SeedID.recipePasta,
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
                id: SeedID.recipeEggs,
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

            let list = try shopping.createList(id: SeedID.listWeekly, name: "Weekly Groceries")
            _ = try shopping.addItem(to: list, name: "Milk", quantity: 1, unit: "gallon", price: 4.29)
            _ = try shopping.addItem(to: list, name: "Bananas", quantity: 6, unit: "each", price: 1.99)

            markSeeded()
        } catch {
            context.rollback()
            assertionFailure("Seed failed: \(error)")
        }
    }

    @MainActor
    private static func hasExistingSampleData(in context: NSManagedObjectContext) -> Bool {
        let pantryRequest = PantryItem.fetchRequest()
        pantryRequest.fetchLimit = 1
        let pantryCount = (try? context.count(for: pantryRequest)) ?? 0
        if pantryCount > 0 { return true }

        let recipeRequest = Recipe.fetchRequest()
        recipeRequest.fetchLimit = 1
        let recipeCount = (try? context.count(for: recipeRequest)) ?? 0
        return recipeCount > 0
    }

    private static func markSeeded() {
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    /// Resets seed flag for tests.
    static func resetSeedFlag() {
        UserDefaults.standard.removeObject(forKey: seedKey)
        isSeeding = false
    }
}
