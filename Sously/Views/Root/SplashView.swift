import SwiftUI

/// Launch splash: pantry hero, "Sously" fade-in, brief pause, then hand off to the app.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var scrimOpacity: Double = 0.35

    private let fadeInDuration: TimeInterval = 1.0
    private let holdDuration: TimeInterval = 1.2
    private let fadeOutDuration: TimeInterval = 0.55

    var body: some View {
        ZStack {
            Image("PantryHero")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(scrimOpacity)
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Sously")
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)

                Text("Know what you have. Cook what you love.")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 32)
            }
            .opacity(titleOpacity)
        }
        .task {
            await runSequence()
        }
    }

    @MainActor
    private func runSequence() async {
        withAnimation(.easeIn(duration: fadeInDuration)) {
            titleOpacity = 1
            scrimOpacity = 0.5
        }
        try? await Task.sleep(for: .seconds(fadeInDuration + holdDuration))
        withAnimation(.easeOut(duration: fadeOutDuration)) {
            titleOpacity = 0
            scrimOpacity = 0.85
        }
        try? await Task.sleep(for: .seconds(fadeOutDuration))
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}
