import SwiftUI

struct StampedIcon: View {
    let systemName: String
    var size: CGFloat = 30
    var weight: Font.Weight = .regular
    var color: Color? = nil

    @Environment(\.trashTheme) private var theme

    var body: some View {
        let resolvedName = ThemeIconResolver.resolve(
            systemName: systemName, style: theme.visualStyle)
        let symbol = Image(systemName: resolvedName)
            .font(.system(size: size, weight: weight))

        Group {
            if let color {
                symbol.foregroundColor(color)
            } else {
                symbol
            }
        }
        .overlay {
            if theme.visualStyle == .ecoPaper {
                symbol
                    .foregroundColor(Color.white.opacity(0.30))
                    .offset(x: -0.8, y: -0.8)
                    .blendMode(.screen)
            }
        }
        .overlay {
            if theme.visualStyle == .ecoPaper {
                symbol
                    .foregroundColor(Color.black.opacity(0.32))
                    .offset(x: 1.2, y: 1.2)
                    .blendMode(.multiply)
            }
        }
    }
}
