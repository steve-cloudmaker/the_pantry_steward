import SwiftUI

struct ShoppingListsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lists: [ShoppingList] = []
    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView(
                        "No shopping lists",
                        systemImage: "cart",
                        description: Text("Create a list and auto-fill from low stock or meal plans.")
                    )
                } else {
                    List {
                        ForEach(lists, id: \.objectID) { list in
                            NavigationLink {
                                ShoppingListDetailView(list: list)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(list.safeName)
                                            .font(.headline)
                                        if list.isShared {
                                            Image(systemName: "person.2.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("\(list.itemList.count) items · $\(list.grandTotal, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteLists)
                    }
                }
            }
            .navigationTitle("Shopping")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewList = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }
                }
            }
            .alert("New shopping list", isPresented: $showingNewList) {
                TextField("Name", text: $newListName)
                Button("Create") { createList() }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        lists = (try? appState.shoppingRepository.fetchLists()) ?? []
    }

    private func createList() {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        _ = try? appState.shoppingRepository.createList(name: newListName)
        newListName = ""
        reload()
    }

    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            try? appState.shoppingRepository.deleteList(lists[index])
        }
        reload()
    }
}
