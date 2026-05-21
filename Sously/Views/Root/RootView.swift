import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab? = .pantry

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                SidebarView(selection: $selectedTab)
            } detail: {
                tabDetail
            }
        } else {
            TabView(selection: Binding(
                get: { selectedTab ?? .pantry },
                set: { selectedTab = $0 }
            )) {
                ForEach(AppTab.allCases) { tab in
                    tabContent(tab)
                        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                        .tag(tab)
                }
            }
        }
    }

    @ViewBuilder
    private var tabDetail: some View {
        if let selectedTab {
            tabContent(selectedTab)
        } else {
            ContentUnavailableView("Select a section", systemImage: "square.grid.2x2")
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .pantry: PantryListView()
        case .shopping: ShoppingListsView()
        case .cook: WhatCanIMakeView()
        case .recipes: RecipeListView()
        case .plan: MealPlansView()
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case pantry
    case shopping
    case cook
    case recipes
    case plan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pantry: "Pantry"
        case .shopping: "Shopping"
        case .cook: "Cook"
        case .recipes: "Recipes"
        case .plan: "Plan"
        }
    }

    var systemImage: String {
        switch self {
        case .pantry: "refrigerator"
        case .shopping: "cart"
        case .cook: "frying.pan"
        case .recipes: "book.closed"
        case .plan: "calendar"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: AppTab?

    var body: some View {
        List(AppTab.allCases, selection: $selection) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .tag(tab)
        }
        .navigationTitle("Sously")
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(AppState(persistence: PersistenceController.preview))
}
