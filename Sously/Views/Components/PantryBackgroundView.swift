import SwiftUI

/// Faint butler's pantry imagery behind app content.
struct PantryBackgroundView: View {
    var opacity: Double = 0.14

    var body: some View {
        Image("PantryHero")
            .resizable()
            .scaledToFill()
            .opacity(opacity)
            .ignoresSafeArea()
    }
}

extension View {
    func pantryBackground(opacity: Double = 0.14) -> some View {
        background {
            PantryBackgroundView(opacity: opacity)
        }
    }

    /// Keeps pantry background visible through scrollable lists.
    func pantryListStyle() -> some View {
        scrollContentBackground(.hidden)
    }
}
