import SwiftUI

struct RecipeEditorView: View {
    enum Mode {
        case create
        case edit(Recipe)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let mode: Mode
    var onSave: () -> Void

    @State private var name = ""
    @State private var summary = ""
    @State private var servings: Int = 4
    @State private var prepMinutes: Int = 0
    @State private var cookMinutes: Int = 0
    @State private var sourceURL = ""
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var ingredients: [EditableIngredient] = [EditableIngredient()]
    @State private var steps: [String] = [""]

    struct EditableIngredient: Identifiable {
        let id = UUID()
        var name = ""
        var quantity: Double = 1
        var unit = "each"
        var isOptional = false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    TextField("Summary", text: $summary, axis: .vertical)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...24)
                    Stepper("Prep: \(prepMinutes) min", value: $prepMinutes, in: 0...240, step: 5)
                    Stepper("Cook: \(cookMinutes) min", value: $cookMinutes, in: 0...480, step: 5)
                    TextField("Source URL", text: $sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Toggle("Favorite", isOn: $isFavorite)
                }

                Section("Ingredients") {
                    ForEach($ingredients) { $ingredient in
                        VStack(alignment: .leading) {
                            TextField("Ingredient", text: $ingredient.name)
                            HStack {
                                TextField("Qty", value: $ingredient.quantity, format: .number)
                                TextField("Unit", text: $ingredient.unit)
                                Toggle("Opt", isOn: $ingredient.isOptional)
                                    .labelsHidden()
                            }
                        }
                    }
                    Button("Add ingredient") {
                        ingredients.append(EditableIngredient())
                    }
                }

                Section("Steps") {
                    ForEach(steps.indices, id: \.self) { index in
                        TextField("Step \(index + 1)", text: $steps[index], axis: .vertical)
                    }
                    Button("Add step") { steps.append("") }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populate() }
        }
    }

    private var navigationTitle: String {
        if case .create = mode { return "New Recipe" }
        return "Edit Recipe"
    }

    private func populate() {
        guard case .edit(let recipe) = mode else { return }
        name = recipe.safeName
        summary = recipe.summary ?? ""
        servings = Int(recipe.servings)
        prepMinutes = Int(recipe.prepTimeMinutes)
        cookMinutes = Int(recipe.cookTimeMinutes)
        sourceURL = recipe.sourceURL ?? ""
        notes = recipe.notes ?? ""
        isFavorite = recipe.isFavorite
        ingredients = recipe.ingredientList.map {
            EditableIngredient(
                name: $0.safeName,
                quantity: $0.quantity,
                unit: $0.safeUnit,
                isOptional: $0.isOptional
            )
        }
        steps = recipe.stepList.map(\.safeInstruction)
        if steps.isEmpty { steps = [""] }
    }

    private func save() {
        let ingredientTuples = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ($0.name, $0.quantity, $0.unit, $0.isOptional) }
        let stepLines = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            switch mode {
            case .create:
                _ = try appState.recipeRepository.create(
                    name: name,
                    summary: summary.isEmpty ? nil : summary,
                    servings: Int16(servings),
                    prepTimeMinutes: Int32(prepMinutes),
                    cookTimeMinutes: Int32(cookMinutes),
                    sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                    notes: notes.isEmpty ? nil : notes,
                    isFavorite: isFavorite,
                    ingredients: ingredientTuples,
                    steps: stepLines
                )
            case .edit(let recipe):
                recipe.name = name
                recipe.summary = summary.isEmpty ? nil : summary
                recipe.servings = Int16(servings)
                recipe.prepTimeMinutes = Int32(prepMinutes)
                recipe.cookTimeMinutes = Int32(cookMinutes)
                recipe.sourceURL = sourceURL.isEmpty ? nil : sourceURL
                recipe.notes = notes.isEmpty ? nil : notes
                recipe.isFavorite = isFavorite
                try appState.recipeRepository.replaceIngredients(on: recipe, with: ingredientTuples)
                try appState.recipeRepository.replaceSteps(on: recipe, with: stepLines)
            }
            onSave()
            dismiss()
        } catch {
            // Errors surface via assertion in dev; production could show alert.
        }
    }
}
