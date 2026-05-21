import SwiftUI

struct WhatCanIMakeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var matches: [RecipeMatchResult] = []
    @State private var sort: RecipeMatchSort = .matchScore
    @State private var minimumScore: Double = 0.5
    @State private var showingGenerator = false
    @State private var suggestions: [GeneratedMealSuggestion] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What can I make?")
                            .font(.title2.bold())
                        Text("Recipes ranked by how well they match your pantry right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Meal plan generator") {
                    Button {
                        generateWeek()
                    } label: {
                        Label("Generate 7-day dinner plan", systemImage: "calendar.badge.plus")
                    }
                    if !suggestions.isEmpty {
                        ForEach(suggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.recipe.safeName)
                                    .font(.headline)
                                Text("\(suggestion.date.formatted(date: .abbreviated, time: .omitted)) · \(suggestion.mealType.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion.rationale)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int((suggestion.matchScore * 100).rounded()))% pantry match")
                                    .font(.caption2)
                            }
                        }
                        Button("Save as meal plan") {
                            saveMealPlan()
                        }
                    }
                }

                Section("Recipes you can make") {
                    Picker("Sort", selection: $sort) {
                        ForEach(RecipeMatchSort.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Slider(value: $minimumScore, in: 0.25...1, step: 0.05) {
                        Text("Minimum match: \(Int(minimumScore * 100))%")
                    }

                    if matches.isEmpty {
                        ContentUnavailableView(
                            "No matches yet",
                            systemImage: "frying.pan",
                            description: Text("Add pantry items and recipes to get suggestions.")
                        )
                    } else {
                        ForEach(matches) { match in
                            NavigationLink {
                                RecipeDetailView(recipe: match.recipe)
                            } label: {
                                RecipeMatchRow(match: match)
                            }
                        }
                    }
                }
            }
            .pantryListStyle()
            .navigationTitle("Cook")
            .onAppear(perform: reload)
            .onChange(of: sort) { _, _ in reload() }
            .onChange(of: minimumScore) { _, _ in reload() }
        }
    }

    private func reload() {
        let recipes = (try? appState.recipeRepository.fetchAll()) ?? []
        matches = (try? appState.recipeMatcher.matchRecipes(
            recipes,
            sort: sort,
            minimumScore: minimumScore
        )) ?? []
    }

    private func generateWeek() {
        var options = MealPlanGenerationOptions()
        options.days = 7
        options.mealsPerDay = [.dinner]
        suggestions = (try? appState.mealPlanGenerator.generateSuggestions(options: options)) ?? []
    }

    private func saveMealPlan() {
        _ = try? appState.mealPlanGenerator.createPlanFromSuggestions(
            name: "Generated \(Date().formatted(date: .abbreviated, time: .omitted))",
            suggestions: suggestions
        )
        suggestions = []
    }
}

struct RecipeMatchRow: View {
    let match: RecipeMatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.recipe.safeName)
                    .font(.headline)
                Spacer()
                Text("\(match.matchPercentage)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(match.canMakeNow ? .green : .orange)
            }
            if match.canMakeNow {
                Label("Ready to cook", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Missing: \(match.missingIngredients.prefix(4).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
