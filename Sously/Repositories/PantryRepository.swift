import CoreData
import Foundation

struct PantrySearchCriteria {
    var query: String = ""
    var category: Category?
    var subCategory: SubCategory?
    var tag: Tag?
    var favoritesOnly: Bool = false
    var lowStockOnly: Bool = false
    var expiringWithinDays: Int?
    var sort: PantrySort = .name
}

@MainActor
final class PantryRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll(criteria: PantrySearchCriteria = PantrySearchCriteria()) throws -> [PantryItem] {
        let request = PantryItem.fetchRequest()
        var predicates: [NSPredicate] = []

        let trimmed = criteria.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let tagQuery = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
            predicates.append(NSPredicate(
                format: "name CONTAINS[cd] %@ OR brand CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR ANY tags.name CONTAINS[cd] %@",
                trimmed, trimmed, trimmed, tagQuery
            ))
        }
        if let category = criteria.category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        if let subCategory = criteria.subCategory {
            predicates.append(NSPredicate(format: "subCategory == %@", subCategory))
        }
        if let tag = criteria.tag {
            predicates.append(NSPredicate(format: "ANY tags == %@", tag))
        }
        if criteria.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        if criteria.lowStockOnly {
            predicates.append(NSPredicate(format: "quantity <= lowStockThreshold"))
        }
        if let days = criteria.expiringWithinDays,
           let horizon = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
            predicates.append(NSPredicate(
                format: "(expirationDate <= %@ AND expirationDate != nil) OR (bestBeforeDate <= %@ AND bestBeforeDate != nil)",
                horizon as NSDate, horizon as NSDate
            ))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = sortDescriptors(for: criteria.sort)
        return try context.fetch(request)
    }

    func fetch(byID id: UUID) throws -> PantryItem? {
        let request = PantryItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func fetchByBarcode(_ barcode: String) throws -> PantryItem? {
        let request = PantryItem.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func lowStockItems() throws -> [PantryItem] {
        try fetchAll(criteria: PantrySearchCriteria(lowStockOnly: true))
    }

    func expiringSoon(withinDays days: Int = 7) throws -> [PantryItem] {
        try fetchAll(criteria: PantrySearchCriteria(expiringWithinDays: days))
    }

    @discardableResult
    func create(
        name: String,
        quantity: Double = 1,
        unit: String = "each",
        size: String? = nil,
        brand: String? = nil,
        notes: String? = nil,
        barcode: String? = nil,
        storageLocation: String? = nil,
        expirationDate: Date? = nil,
        bestBeforeDate: Date? = nil,
        priority: Int16 = 0,
        isFavorite: Bool = false,
        lowStockThreshold: Double = 1,
        photoData: Data? = nil,
        category: Category? = nil,
        subCategory: SubCategory? = nil,
        tags: [Tag] = []
    ) throws -> PantryItem {
        let item = PantryItem(context: context)
        item.id = UUID()
        item.name = name
        item.quantity = quantity
        item.unit = unit
        item.size = size
        item.brand = brand
        item.notes = notes
        item.barcode = barcode
        item.storageLocation = storageLocation
        item.expirationDate = expirationDate
        item.bestBeforeDate = bestBeforeDate
        item.priority = priority
        item.isFavorite = isFavorite
        item.lowStockThreshold = lowStockThreshold
        item.photoData = photoData
        item.category = category
        item.subCategory = subCategory
        item.tags = NSSet(array: tags)
        let now = Date()
        item.createdAt = now
        item.updatedAt = now
        try context.save()
        return item
    }

    func update(_ item: PantryItem) throws {
        item.updatedAt = Date()
        try context.save()
    }

    func adjustQuantity(_ item: PantryItem, by delta: Double) throws {
        item.quantity = max(0, item.quantity + delta)
        item.updatedAt = Date()
        try context.save()
    }

    func delete(_ item: PantryItem) throws {
        context.delete(item)
        try context.save()
    }

    private func sortDescriptors(for sort: PantrySort) -> [NSSortDescriptor] {
        switch sort {
        case .name:
            [NSSortDescriptor(keyPath: \PantryItem.name, ascending: true)]
        case .expiration:
            [
                NSSortDescriptor(keyPath: \PantryItem.expirationDate, ascending: true),
                NSSortDescriptor(keyPath: \PantryItem.bestBeforeDate, ascending: true)
            ]
        case .quantity:
            [NSSortDescriptor(keyPath: \PantryItem.quantity, ascending: true)]
        case .priority:
            [
                NSSortDescriptor(keyPath: \PantryItem.priority, ascending: false),
                NSSortDescriptor(keyPath: \PantryItem.name, ascending: true)
            ]
        case .recentlyUpdated:
            [NSSortDescriptor(keyPath: \PantryItem.updatedAt, ascending: false)]
        }
    }
}
