import SwiftUI

struct ShoppingListDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var list: ShoppingList
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemPrice = ""

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Unchecked")
                        Text("$\(list.uncheckedTotal, specifier: "%.2f")")
                            .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Checked")
                        Text("$\(list.checkedTotal, specifier: "%.2f")")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Grand total", value: list.grandTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            }

            Section("Items") {
                ForEach(list.itemList, id: \.objectID) { item in
                    ShoppingListItemRow(item: item) {
                        try? appState.shoppingRepository.toggleChecked(item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle(list.safeName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    Button {
                        populateFromPantry()
                    } label: {
                        Label("Add low stock & meals", systemImage: "arrow.down.circle")
                    }
                    Button {
                        try? appState.shoppingRepository.clearChecked(from: list)
                    } label: {
                        Label("Clear checked", systemImage: "checkmark.circle")
                    }
                    Toggle("Shared (CloudKit)", isOn: Binding(
                        get: { list.isShared },
                        set: { list.isShared = $0; try? appState.shoppingRepository.updateList(list) }
                    ))
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Add item", isPresented: $showingAddItem) {
            TextField("Name", text: $newItemName)
            TextField("Price", text: $newItemPrice)
                .keyboardType(.decimalPad)
            Button("Add") { addItem() }
            Button("Cancel", role: .cancel) {
                newItemName = ""
                newItemPrice = ""
            }
        }
    }

    private func addItem() {
        let price = Double(newItemPrice) ?? 0
        _ = try? appState.shoppingRepository.addItem(to: list, name: newItemName, price: price)
        newItemName = ""
        newItemPrice = ""
    }

    private func populateFromPantry() {
        _ = try? appState.shoppingListBuilder.populateList(list)
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = list.itemList
        for index in offsets {
            try? appState.shoppingRepository.deleteItem(items[index])
        }
    }
}

struct ShoppingListItemRow: View {
    @ObservedObject var item: ShoppingListItem
    var onToggle: () -> Void
    @State private var priceText = ""

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.safeName)
                    .strikethrough(item.isChecked)
                Text(QuantityFormatter.format(quantity: item.quantity, unit: item.safeUnit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            TextField("0.00", text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .onAppear { priceText = String(format: "%.2f", item.price) }
                .onSubmit { commitPrice() }
                .onChange(of: priceText) { _, _ in
                    if let value = Double(priceText) {
                        item.price = value
                    }
                }
        }
    }

    private func commitPrice() {
        item.price = Double(priceText) ?? item.price
        try? item.managedObjectContext?.save()
    }
}
