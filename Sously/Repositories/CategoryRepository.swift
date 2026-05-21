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

    @discardableResult
    func create(name: String, sortOrder: Int16 = 0) throws -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.sortOrder = sortOrder
        try context.save()
        return category
    }

    @discardableResult
    func createSubCategory(name: String, in category: Category, sortOrder: Int16 = 0) throws -> SubCategory {
        let sub = SubCategory(context: context)
        sub.id = UUID()
        sub.name = name
        sub.sortOrder = sortOrder
        sub.category = category
        try context.save()
        return sub
    }
}
