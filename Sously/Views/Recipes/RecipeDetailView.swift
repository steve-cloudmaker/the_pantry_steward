import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var recipe: Recipe
    @State private var match: RecipeMatchResult?
    @State private var showingEdit = false
    @State private var showingAddToList = false
    @State private var lists: [ShoppingList] = []

    var body: some View {
        List {
            if let summary = recipe.summary, !summary.isEmpty {
                Section { Text(summary) }
            }

            if let match {
                Section("Pantry match") {
                    LabeledContent("Match", value: "\(match.matchPercentage)%")
                    if !match.matchedIngredients.isEmpty {
                        Text("Have: \(match.matchedIngredients.joined(separator: ", "))")
                            .font(.subheadline)
                    }
                    if !match.missingIngredients.isEmpty {
                        Text("Need: \(match.missingIngredients.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Ingredients") {
                ForEach(recipe.ingredientList, id: \.objectID) { ingredient in
                    HStack {
                        Text(ingredient.safeName)
                        Spacer()
                        Text(QuantityFormatter.format(quantity: ingredient.quantity, unit: ingredient.safeUnit))
                            .foregroundStyle(.secondary)
                        if ingredient.isOptional {
                            Text("opt")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section("Steps") {
                ForEach(Array(recipe.stepList.enumerated()), id: \.element.objectID) { index, step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Step \(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(step.safeInstruction)
                    }
                }
            }

            if let url = recipe.sourceURL, let link = URL(string: url) {
                Section {
                    Link("Source", destination: link)
                }
            }
        }
        .pantryListStyle()
        .navigationTitle(recipe.safeName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Add missing to shopping list") {
                        lists = (try? appState.shoppingRepository.fetchLists()) ?? []
                        showingAddToList = true
                    }
                    Button {
                        recipe.isFavorite.toggle()
                        try? appState.recipeRepository.update(recipe)
                    } label: {
                        Label(
                            recipe.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: recipe.isFavorite ? "star.slash" : "star"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            RecipeEditorView(mode: .edit(recipe)) {}
        }
        .confirmationDialog("Add to list", isPresented: $showingAddToList) {
            ForEach(lists, id: \.objectID) { list in
                Button(list.safeName) {
                    _ = try? appState.shoppingListBuilder.addRecipeIngredientsToList(
                        list,
                        recipe: recipe,
                        onlyMissing: true
                    )
                }
            }
        }
        .onAppear {
            let analysis = appState.recipeMatcher.analyze(recipe: recipe)
            if let id = recipe.id {
                match = RecipeMatchResult(
                    id: id,
                    recipe: recipe,
                    matchScore: analysis.matchScore,
                    matchedIngredients: analysis.matchedIngredients,
                    missingIngredients: analysis.missingIngredients,
                    optionalMissing: analysis.optionalMissing
                )
            }
        }
    }
}
