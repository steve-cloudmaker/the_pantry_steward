import CoreData
import Foundation

@MainActor
final class ShoppingRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchLists() throws -> [ShoppingList] {
        let request = ShoppingList.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ShoppingList.updatedAt, ascending: false)
        ]
        return try context.fetch(request)
    }

    func fetchList(id: UUID) throws -> ShoppingList? {
        let request = ShoppingList.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    func createList(name: String, isShared: Bool = false) throws -> ShoppingList {
        let list = ShoppingList(context: context)
        list.id = UUID()
        list.name = name
        list.isShared = isShared
        let now = Date()
        list.createdAt = now
        list.updatedAt = now
        try context.save()
        return list
    }

    func updateList(_ list: ShoppingList) throws {
        list.updatedAt = Date()
        try context.save()
    }

    func deleteList(_ list: ShoppingList) throws {
        context.delete(list)
        try context.save()
    }

    @discardableResult
    func addItem(
        to list: ShoppingList,
        name: String,
        quantity: Double = 1,
        unit: String = "each",
        price: Double = 0,
        notes: String? = nil,
        sourceRecipeID: UUID? = nil
    ) throws -> ShoppingListItem {
        let item = ShoppingListItem(context: context)
        item.id = UUID()
        item.name = name
        item.quantity = quantity
        item.unit = unit
        item.price = price
        item.notes = notes
        item.sourceRecipeID = sourceRecipeID
        item.isChecked = false
        item.sortOrder = Int16(list.itemList.count)
        item.list = list
        list.updatedAt = Date()
        try context.save()
        return item
    }

    func toggleChecked(_ item: ShoppingListItem) throws {
        item.isChecked.toggle()
        item.list?.updatedAt = Date()
        try context.save()
    }

    func updateItem(_ item: ShoppingListItem) throws {
        item.list?.updatedAt = Date()
        try context.save()
    }

    func deleteItem(_ item: ShoppingListItem) throws {
        let list = item.list
        context.delete(item)
        list?.updatedAt = Date()
        try context.save()
    }

    func clearChecked(from list: ShoppingList) throws {
        for item in list.itemList where item.isChecked {
            context.delete(item)
        }
        list.updatedAt = Date()
        try context.save()
    }
}
