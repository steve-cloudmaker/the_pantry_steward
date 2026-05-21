import CoreData
import Foundation

@MainActor
final class TagRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() throws -> [Tag] {
        let request = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return try context.fetch(request)
    }

    func findOrCreate(name raw: String) throws -> Tag {
        let name = Tag.normalizedName(raw)
        let request = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            return existing
        }
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        try context.save()
        return tag
    }

    func assign(tags rawNames: [String], to item: PantryItem) throws {
        let tags = try rawNames.map { try findOrCreate(name: $0) }
        item.tags = NSSet(array: tags)
        try context.save()
    }

    func assign(tags rawNames: [String], to recipe: Recipe) throws {
        let tags = try rawNames.map { try findOrCreate(name: $0) }
        recipe.tags = NSSet(array: tags)
        try context.save()
    }
}
