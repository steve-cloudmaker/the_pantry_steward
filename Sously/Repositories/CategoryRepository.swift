import CoreData
import Foundation

@MainActor
final class CategoryRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() throws -> [Category] {
        let request = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
        return try context.fetch(request)
    }

    func fetch(id: UUID) throws -> Category? {
        let request = Category.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    func create(id: UUID? = nil, name: String, sortOrder: Int16 = 0) throws -> Category {
        if let id, let existing = try fetch(id: id) {
            return existing
        }
        let category = Category(context: context)
        category.id = id ?? UUID()
        category.name = name
        category.sortOrder = sortOrder
        try context.save()
        return category
    }

    func fetchSubCategory(id: UUID) throws -> SubCategory? {
        let request = SubCategory.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    func createSubCategory(
        id: UUID? = nil,
        name: String,
        in category: Category,
        sortOrder: Int16 = 0
    ) throws -> SubCategory {
        if let id, let existing = try fetchSubCategory(id: id) {
            return existing
        }
        let sub = SubCategory(context: context)
        sub.id = id ?? UUID()
        sub.name = name
        sub.sortOrder = sortOrder
        sub.category = category
        try context.save()
        return sub
    }
}
