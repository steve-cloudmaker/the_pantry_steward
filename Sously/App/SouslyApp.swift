import SwiftUI

@main
struct SouslyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, appState.persistence.viewContext)
                .environmentObject(appState)
        }
    }
}
