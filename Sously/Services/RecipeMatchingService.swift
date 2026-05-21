import Foundation

struct RecipeMatchResult: Identifiable, Equatable {
    let id: UUID
    let recipe: Recipe
    let matchScore: Double
    let matchedIngredients: [String]
    let missingIngredients: [String]
    let optionalMissing: [String]

    var matchPercentage: Int {
        Int((matchScore * 100).rounded())
    }

    var canMakeNow: Bool {
        missingIngredients.isEmpty
    }
}

@MainActor
final class RecipeMatchingService {
    private let pantry: PantryRepository

    init(pantry: PantryRepository) {
        self.pantry = pantry
    }

    func matchRecipes(
        _ recipes: [Recipe],
        sort: RecipeMatchSort = .matchScore,
        includePartial: Bool = true,
        minimumScore: Double = 0.35
    ) throws -> [RecipeMatchResult] {
        let pantryItems = try pantry.fetchAll()
        var results: [RecipeMatchResult] = []

        for recipe in recipes {
            guard let recipeID = recipe.id else { continue }
            let analysis = analyze(recipe: recipe, pantryItems: pantryItems)
            if analysis.matchScore >= minimumScore || (includePartial && !analysis.matchedIngredients.isEmpty) {
                results.append(RecipeMatchResult(
                    id: recipeID,
                    recipe: recipe,
                    matchScore: analysis.matchScore,
                    matchedIngredients: analysis.matchedIngredients,
                    missingIngredients: analysis.missingIngredients,
                    optionalMissing: analysis.optionalMissing
                ))
            }
        }

        return sortResults(results, by: sort)
    }

    func analyze(recipe: Recipe, pantryItems: [PantryItem]? = nil) -> (
        matchScore: Double,
        matchedIngredients: [String],
        missingIngredients: [String],
        optionalMissing: [String]
    ) {
        let items: [PantryItem]
        if let pantryItems {
            items = pantryItems
        } else {
            items = (try? pantry.fetchAll()) ?? []
        }

        let required = recipe.ingredientList.filter { !$0.isOptional }
        let optional = recipe.ingredientList.filter(\.isOptional)
        guard !required.isEmpty else {
            return (1, [], [], [])
        }

        var matched: [String] = []
        var missing: [String] = []
        var optionalMissing: [String] = []

        for ingredient in required {
            if pantryHas(ingredient.safeName, in: items) {
                matched.append(ingredient.safeName)
            } else {
                missing.append(ingredient.safeName)
            }
        }

        for ingredient in optional {
            if !pantryHas(ingredient.safeName, in: items) {
                optionalMissing.append(ingredient.safeName)
            }
        }

        let score = Double(matched.count) / Double(required.count)
        return (score, matched, missing, optionalMissing)
    }

    private func pantryHas(_ ingredientName: String, in items: [PantryItem]) -> Bool {
        items.contains { item in
            guard item.quantity > 0 else { return false }
            return IngredientNormalizer.matches(pantryName: item.safeName, recipeName: ingredientName)
        }
    }

    private func sortResults(_ results: [RecipeMatchResult], by sort: RecipeMatchSort) -> [RecipeMatchResult] {
        switch sort {
        case .matchScore:
            results.sorted { $0.matchScore > $1.matchScore }
        case .name:
            results.sorted {
                $0.recipe.safeName.localizedCaseInsensitiveCompare($1.recipe.safeName) == .orderedAscending
            }
        case .cookTime:
            results.sorted { $0.recipe.totalTimeMinutes < $1.recipe.totalTimeMinutes }
        }
    }
}
