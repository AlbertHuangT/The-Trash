import SwiftUI

struct ThemeBackgroundView: View {
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            theme.appBackgroundGradient

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
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ThemeBackgroundView())
    }
}

extension View {
    func trashScreenBackground() -> some View {
        modifier(TrashScreenBackgroundModifier())
    }
}
