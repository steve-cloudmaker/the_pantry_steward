import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var recipes: [Recipe] = []
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var showingAdd = false
    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No recipes yet",
                        systemImage: "book.closed",
                        description: Text("Import from a URL or add your family favorites.")
                    )
                } else {
                    List {
                        ForEach(recipes, id: \.objectID) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeRowView(recipe: recipe)
                            }
                        }
                        .onDelete(perform: deleteRecipes)
                    }
                    .pantryListStyle()
                }
            }
            .pantryNavigationBackdrop()
            .navigationTitle("Recipes")
            .searchable(text: $query, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAdd = true
                        } label: {
                            Label("New recipe", systemImage: "plus")
                        }
                        Button {
                            showingImport = true
                        } label: {
                            Label("Import from URL", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $favoritesOnly) {
                        Image(systemName: "star")
                    }
                    .toggleStyle(.button)
                }
            }
            .sheet(isPresented: $showingAdd) {
                RecipeEditorView(mode: .create) { reload() }
            }
            .sheet(isPresented: $showingImport) {
                RecipeImportView { reload() }
            }
            .onAppear(perform: reload)
            .onChange(of: query) { _, _ in reload() }
            .onChange(of: favoritesOnly) { _, _ in reload() }
        }
    }

    private func reload() {
        var criteria = RecipeSearchCriteria()
        criteria.query = query
        criteria.favoritesOnly = favoritesOnly
        recipes = (try? appState.recipeRepository.fetchAll(criteria: criteria)) ?? []
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            try? appState.recipeRepository.delete(recipes[index])
        }
        reload()
    }
}

struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.safeName)
                    .font(.headline)
                if recipe.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            if let summary = recipe.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("\(recipe.servings) servings · \(recipe.totalTimeMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
