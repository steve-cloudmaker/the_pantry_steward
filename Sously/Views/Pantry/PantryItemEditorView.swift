import SwiftUI

struct PantryItemEditorView: View {
    enum Mode {
        case create
        case edit(PantryItem)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let mode: Mode
    var onSave: () -> Void

    @State private var name = ""
    @State private var quantity: Double = 1
    @State private var unit = "each"
    @State private var size = ""
    @State private var brand = ""
    @State private var notes = ""
    @State private var barcode = ""
    @State private var storageLocation = ""
    @State private var priority: Int = 0
    @State private var isFavorite = false
    @State private var lowStockThreshold: Double = 1
    @State private var expirationDate = Date()
    @State private var bestBeforeDate = Date()
    @State private var hasExpiration = false
    @State private var hasBestBefore = false
    @State private var photoData: Data?
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var selectedSubCategory: SubCategory?
    @State private var showingScanner = false
    @State private var isLookingUp = false
    @State private var errorMessage: String?

    private let barcodeLookup = BarcodeLookupService()

    var body: some View {
        NavigationStack {
            Form {
                PhotoPickerSection(photoData: $photoData)

                Section("Item") {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Quantity", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Unit", text: $unit)
                    }
                    TextField("Size", text: $size)
                    TextField("Brand", text: $brand)
                }

                Section("Barcode") {
                    HStack {
                        TextField("Barcode", text: $barcode)
                            .keyboardType(.numberPad)
                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                    if isLookingUp {
                        ProgressView("Looking up product…")
                    }
                    Button("Look up product") {
                        Task { await lookupBarcode() }
                    }
                    .disabled(barcode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Storage & dates") {
                    TextField("Storage location", text: $storageLocation)
                    Toggle("Expiration date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                    }
                    Toggle("Best before date", isOn: $hasBestBefore)
                    if hasBestBefore {
                        DatePicker("Best before", selection: $bestBeforeDate, displayedComponents: .date)
                    }
                }

                Section("Organization") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(categories, id: \.objectID) { category in
                            Text(category.safeName).tag(Optional(category))
                        }
                    }
                    if let subs = selectedCategory?.subCategories as? Set<SubCategory>, !subs.isEmpty {
                        Picker("Sub-category", selection: $selectedSubCategory) {
                            Text("None").tag(Optional<SubCategory>.none)
                            ForEach(subs.sorted { $0.safeName < $1.safeName }, id: \.objectID) { sub in
                                Text(sub.safeName).tag(Optional(sub))
                            }
                        }
                    }
                    Stepper("Priority: \(priority)", value: $priority, in: 0...5)
                    Toggle("Favorite", isOn: $isFavorite)
                    TextField("Low stock threshold", value: $lowStockThreshold, format: .number)
                }

                Section("Tags") {
                    HStack {
                        TextField("#tag", text: $tagInput)
                        Button("Add") { addTag() }
                            .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !tags.isEmpty {
                        FlowLayout(tags: tags.map { "#\($0)" })
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    BarcodeScannerView { code in
                        barcode = code
                        showingScanner = false
                        Task { await lookupBarcode() }
                    }
                    .navigationTitle("Scan Barcode")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingScanner = false }
                        }
                    }
                }
            }
            .onAppear {
                loadCategories()
                populateFromMode()
            }
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

    private var modeTitle: String {
        switch mode {
        case .create: "Add Item"
        case .edit: "Edit Item"
        }
    }

    private func loadCategories() {
        categories = (try? appState.categoryRepository.fetchAll()) ?? []
    }

    private func populateFromMode() {
        guard case .edit(let item) = mode else { return }
        name = item.safeName
        quantity = item.quantity
        unit = item.safeUnit
        size = item.size ?? ""
        brand = item.brand ?? ""
        notes = item.notes ?? ""
        barcode = item.barcode ?? ""
        storageLocation = item.storageLocation ?? ""
        priority = Int(item.priority)
        isFavorite = item.isFavorite
        lowStockThreshold = item.lowStockThreshold
        photoData = item.photoData
        selectedCategory = item.category
        selectedSubCategory = item.subCategory
        tags = item.tagNames
        if let exp = item.expirationDate {
            hasExpiration = true
            expirationDate = exp
        }
        if let best = item.bestBeforeDate {
            hasBestBefore = true
            bestBeforeDate = best
        }
    }

    private func addTag() {
        let normalized = Tag.normalizedName(tagInput)
        guard !normalized.isEmpty, !tags.contains(normalized) else { return }
        tags.append(normalized)
        tagInput = ""
    }

    private func lookupBarcode() async {
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            let info = try await barcodeLookup.lookup(barcode: barcode)
            if name.isEmpty { name = info.name }
            if brand.isEmpty, let infoBrand = info.brand { brand = infoBrand }
            if size.isEmpty, let qty = info.quantity { size = qty }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            let tagObjects = try tags.map { try appState.tagRepository.findOrCreate(name: $0) }
            switch mode {
            case .create:
                let item = try appState.pantryRepository.create(
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    size: size.isEmpty ? nil : size,
                    brand: brand.isEmpty ? nil : brand,
                    notes: notes.isEmpty ? nil : notes,
                    barcode: barcode.isEmpty ? nil : barcode,
                    storageLocation: storageLocation.isEmpty ? nil : storageLocation,
                    expirationDate: hasExpiration ? expirationDate : nil,
                    bestBeforeDate: hasBestBefore ? bestBeforeDate : nil,
                    priority: Int16(priority),
                    isFavorite: isFavorite,
                    lowStockThreshold: lowStockThreshold,
                    photoData: photoData,
                    category: selectedCategory,
                    subCategory: selectedSubCategory,
                    tags: tagObjects
                )
                _ = item
            case .edit(let item):
                item.name = name
                item.quantity = quantity
                item.unit = unit
                item.size = size.isEmpty ? nil : size
                item.brand = brand.isEmpty ? nil : brand
                item.notes = notes.isEmpty ? nil : notes
                item.barcode = barcode.isEmpty ? nil : barcode
                item.storageLocation = storageLocation.isEmpty ? nil : storageLocation
                item.expirationDate = hasExpiration ? expirationDate : nil
                item.bestBeforeDate = hasBestBefore ? bestBeforeDate : nil
                item.priority = Int16(priority)
                item.isFavorite = isFavorite
                item.lowStockThreshold = lowStockThreshold
                item.photoData = photoData
                item.category = selectedCategory
                item.subCategory = selectedSubCategory
                item.tags = NSSet(array: tagObjects)
                try appState.pantryRepository.update(item)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
