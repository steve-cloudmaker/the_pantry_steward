import SwiftUI

struct PantryItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var item: PantryItem
    var onUpdate: (() -> Void)?
    @State private var showingEdit = false

    var body: some View {
        List {
            if let photoData = item.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                LabeledContent("Quantity", value: item.displayQuantity)
                if let brand = item.brand, !brand.isEmpty { LabeledContent("Brand", value: brand) }
                if let size = item.size, !size.isEmpty { LabeledContent("Size", value: size) }
                if let location = item.storageLocation, !location.isEmpty {
                    LabeledContent("Storage", value: location)
                }
                if let barcode = item.barcode, !barcode.isEmpty {
                    LabeledContent("Barcode", value: barcode)
                }
            }

            Section("Status") {
                LabeledContent("Stock", value: item.stockStatus.displayName)
                LabeledContent("Expiration", value: item.expirationStatus.displayName)
                if let exp = item.expirationDate {
                    LabeledContent("Expires", value: exp.formatted(date: .abbreviated, time: .omitted))
                }
                if let best = item.bestBeforeDate {
                    LabeledContent("Best before", value: best.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !item.tagNames.isEmpty {
                Section("Tags") {
                    FlowLayout(tags: item.tagNames.map { "#\($0)" })
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
        }
        .pantryListStyle()
        .pantryNavigationBackdrop()
        .navigationTitle(item.safeName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    adjustQuantity(by: -1)
                } label: {
                    Label("Use one", systemImage: "minus.circle")
                }
                Button {
                    adjustQuantity(by: 1)
                } label: {
                    Label("Add one", systemImage: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            PantryItemEditorView(mode: .edit(item)) { onUpdate?() }
        }
    }

    private func adjustQuantity(by delta: Double) {
        guard (try? appState.pantryRepository.adjustQuantity(item, by: delta)) != nil else { return }
        onUpdate?()
    }
}

/// Horizontal wrapping tag chips.
struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}
