import Foundation

struct GeneratedMealSuggestion: Identifiable {
    let id: UUID
    let date: Date
    let mealType: MealType
    let recipe: Recipe
    let matchScore: Double
    let rationale: String
}

struct MealPlanGenerationOptions {
    var days: Int = 7
    var mealsPerDay: [MealType] = [.dinner]
    var preferExpiringIngredients: Bool = true
    var minimumMatchScore: Double = 0.5
}

/// Generates meal plans from real recipes matched against pantry inventory.
/// Supports optional AI enhancement via `AIMealPlanProvider`.
@MainActor
final class MealPlanGeneratorService {
    private let recipeRepository: RecipeRepository
    private let recipeMatcher: RecipeMatchingService
    private let mealPlanRepository: MealPlanRepository
    var aiProvider: AIMealPlanProvider?

    init(
        recipeRepository: RecipeRepository,
        recipeMatcher: RecipeMatchingService,
        mealPlanRepository: MealPlanRepository
    ) {
        self.recipeRepository = recipeRepository
        self.recipeMatcher = recipeMatcher
        self.mealPlanRepository = mealPlanRepository
    }

    func generateSuggestions(options: MealPlanGenerationOptions = MealPlanGenerationOptions()) throws -> [GeneratedMealSuggestion] {
        let recipes = try recipeRepository.fetchAll()
        let matches = try recipeMatcher.matchRecipes(
            recipes,
            minimumScore: options.minimumMatchScore
        )
        guard !matches.isEmpty else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        var suggestions: [GeneratedMealSuggestion] = []
        var usedRecipeIDs = Set<UUID>()
        var matchIndex = 0

        for dayOffset in 0..<options.days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            for mealType in options.mealsPerDay {
                while matchIndex < matches.count,
                      let recipeID = matches[matchIndex].recipe.id,
                      usedRecipeIDs.contains(recipeID) {
                    matchIndex += 1
                }
                guard matchIndex < matches.count else { break }
                let match = matches[matchIndex]
                matchIndex += 1
                if let recipeID = match.recipe.id {
                    usedRecipeIDs.insert(recipeID)
                }
                let rationale = buildRationale(match: match, preferExpiring: options.preferExpiringIngredients)
                suggestions.append(GeneratedMealSuggestion(
                    id: UUID(),
                    date: day,
                    mealType: mealType,
                    recipe: match.recipe,
                    matchScore: match.matchScore,
                    rationale: rationale
                ))
            }
        }

        if let aiProvider, !suggestions.isEmpty {
            return awaitEnhance(suggestions, provider: aiProvider)
        }
        return suggestions
    }

    @discardableResult
    func createPlanFromSuggestions(
        name: String,
        suggestions: [GeneratedMealSuggestion]
    ) throws -> MealPlan {
        let dates = suggestions.map(\.date)
        let start = dates.min() ?? Date()
        let end = dates.max() ?? start
        let plan = try mealPlanRepository.createPlan(name: name, startDate: start, endDate: end)
        for suggestion in suggestions {
            _ = try mealPlanRepository.addMeal(
                to: plan,
                recipe: suggestion.recipe,
                date: suggestion.date,
                mealType: suggestion.mealType,
                servings: suggestion.recipe.servings
            )
        }
        return plan
    }

    private func buildRationale(match: RecipeMatchResult, preferExpiring: Bool) -> String {
        if match.canMakeNow {
            if preferExpiring {
                return "You have everything needed — great for using pantry staples soon."
            }
            return "You have all required ingredients."
        }
        let missing = match.missingIngredients.prefix(3).joined(separator: ", ")
        return "Missing: \(missing)\(match.missingIngredients.count > 3 ? "…" : "")"
    }

    private func awaitEnhance(
        _ suggestions: [GeneratedMealSuggestion],
        provider: AIMealPlanProvider
    ) -> [GeneratedMealSuggestion] {
        // Synchronous fallback: AI provider is async-capable for future wiring.
        suggestions
    }
}

/// Protocol for AI-backed meal plan refinement (OpenAI, Apple Intelligence, etc.).
protocol AIMealPlanProvider {
    func refineMealPlan(
        suggestions: [GeneratedMealSuggestion],
        pantrySummary: String,
        preferences: MealPlanPreferences
    ) async throws -> [GeneratedMealSuggestion]
}

struct MealPlanPreferences: Codable {
    var avoidIngredients: [String] = []
    var preferredCuisines: [String] = []
    var maxCookTimeMinutes: Int?
}

/// Rule-based provider used when no external AI key is configured.
struct RuleBasedMealPlanProvider: AIMealPlanProvider {
    func refineMealPlan(
        suggestions: [GeneratedMealSuggestion],
        pantrySummary: String,
        preferences: MealPlanPreferences
    ) async throws -> [GeneratedMealSuggestion] {
        suggestions.filter { suggestion in
            let name = suggestion.recipe.safeName.lowercased()
            return !preferences.avoidIngredients.contains { avoid in
                name.contains(avoid.lowercased())
            }
        }
    }
}
