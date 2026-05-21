import SwiftUI

struct RecipeImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    var onImport: () -> Void

    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe URL") {
                    TextField("https://…", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Sously extracts recipes from JSON-LD and schema.org markup used by most recipe blogs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import Recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        Task { await importRecipe() }
                    }
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading { ProgressView("Importing…") }
            }
            .alert("Import failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importRecipe() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let draft = try await appState.recipeImporter.importFromURL(urlString)
            _ = try appState.recipeRepository.create(
                name: draft.name,
                summary: draft.summary,
                servings: draft.servings,
                prepTimeMinutes: draft.prepTimeMinutes,
                cookTimeMinutes: draft.cookTimeMinutes,
                sourceURL: draft.sourceURL ?? urlString,
                ingredients: draft.ingredients,
                steps: draft.steps
            )
            onImport()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
