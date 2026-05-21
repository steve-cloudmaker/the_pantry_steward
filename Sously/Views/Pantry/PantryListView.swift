import SwiftUI

struct PantryListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var items: [PantryItem] = []
    @State private var categories: [Category] = []
    @State private var criteria = PantrySearchCriteria()
    @State private var showingAdd = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your pantry is empty",
                        systemImage: "refrigerator",
                        description: Text("Add ingredients by photo, barcode, or manual entry.")
                    )
                } else {
                    List {
                        ForEach(items, id: \.objectID) { item in
                            NavigationLink {
                                PantryItemDetailView(item: item)
                            } label: {
                                PantryRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Pantry")
            .searchable(text: $criteria.query, prompt: "Item, category, or #tag")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $criteria.sort) {
                            ForEach(PantrySort.allCases) { sort in
                                Text(sort.displayName).tag(sort)
                            }
                        }
                        Toggle("Favorites only", isOn: $criteria.favoritesOnly)
                        Toggle("Low stock only", isOn: $criteria.lowStockOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PantryItemEditorView(mode: .create) { reload() }
            }
            .onAppear(perform: reload)
            .onChange(of: criteria.query) { _, _ in reload() }
            .onChange(of: criteria.sort) { _, _ in reload() }
            .onChange(of: criteria.favoritesOnly) { _, _ in reload() }
            .onChange(of: criteria.lowStockOnly) { _, _ in reload() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func reload() {
        do {
            items = try appState.pantryRepository.fetchAll(criteria: criteria)
            categories = try appState.categoryRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            try? appState.pantryRepository.delete(item)
        }
        reload()
    }
}

struct PantryRowView: View {
    let item: PantryItem

    var body: some View {
        HStack(spacing: 12) {
            PantryThumbnail(photoData: item.photoData)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.safeName)
                        .font(.headline)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                Text(item.displayQuantity)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    StatusBadge(text: item.stockStatus.displayName, color: item.stockStatus.color)
                    if item.expirationStatus != .fresh {
                        StatusBadge(text: item.expirationStatus.displayName, color: item.expirationStatus.color)
                    }
                    if let location = item.storageLocation, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct PantryThumbnail: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "leaf")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
