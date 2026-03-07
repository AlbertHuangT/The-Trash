import SwiftUI

struct ThemeBackgroundView: View {
    private let theme = TrashTheme()

    var body: some View {
        ZStack {
            theme.appBackground

            LinearGradient(
                colors: [
                    theme.surfaceBackground.opacity(0.95),
                    theme.appBackground.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    theme.accents.blue.opacity(0.08),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    theme.accents.orange.opacity(0.05),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 280
            )
        }
            .ignoresSafeArea()
    }
}

private struct TrashScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

extension View {
    func trashScreenBackground() -> some View {
        modifier(TrashScreenBackgroundModifier())
    }
}
