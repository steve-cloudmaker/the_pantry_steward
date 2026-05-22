import SwiftUI

/// Faint butler's pantry imagery behind app content.
struct PantryBackgroundView: View {
    var opacity: Double = 0.28

    var body: some View {
        Image("PantryHero")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .opacity(opacity)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Clears the navigation stack's default opaque plate on iOS 18+ (no-op on iOS 17).
private struct ClearNavigationContainerBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
    }
}

extension View {
    /// Pantry image behind screen content with transparent navigation chrome (SwiftUI-only).
    @ViewBuilder
    func pantryNavigationBackdrop(opacity: Double = 0.28) -> some View {
        ZStack {
            PantryBackgroundView(opacity: opacity)
            self
        }
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .modifier(ClearNavigationContainerBackground())
    }

    /// Translucent list rows so the pantry image shows between cells.
    func pantryListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .listRowSeparatorTint(.primary.opacity(0.15))
    }
}
