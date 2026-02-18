import SwiftUI

struct ThemeBackgroundView: View {
    @Environment(\.trashTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            theme.backgroundView()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}
