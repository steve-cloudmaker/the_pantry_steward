import CoreData
import Foundation

/// Defers sample-data seeding until after Core Data (and CloudKit import) has settled.
enum SeedCoordinator {
    private static var didSchedule = false

    @MainActor
    static func scheduleSeedIfNeeded(persistence: PersistenceController) {
        guard !didSchedule else { return }
        didSchedule = true

        let context = persistence.viewContext
        let container = persistence.container

        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil
            else { return }
            SeedDataService.seedIfNeeded(context: context)
        }

        // Fallback for offline / non-iCloud installs after the store is ready.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            SeedDataService.seedIfNeeded(context: context)
        }
    }
}
