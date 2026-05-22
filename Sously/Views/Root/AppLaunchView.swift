import SwiftUI

struct AppLaunchView: View {
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootView()
                .environment(\.managedObjectContext, appState.persistence.viewContext)
                .environmentObject(appState)
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            SeedCoordinator.scheduleSeedIfNeeded(persistence: appState.persistence)
        }
    }
}

#Preview {
    AppLaunchView()
}
