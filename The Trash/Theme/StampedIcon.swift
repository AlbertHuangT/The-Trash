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
                    .foregroundColor(Color.white.opacity(0.24))
                    .offset(x: -0.55, y: -0.55)
                    .blendMode(.screen)
            }
        }
        .overlay {
            if theme.visualStyle == .ecoPaper {
                symbol
                    .foregroundColor(Color.black.opacity(0.28))
                    .offset(x: 0.75, y: 0.75)
                    .blendMode(.multiply)
            }
        }
        .overlay {
            if theme.visualStyle == .ecoPaper {
                StampNoiseOverlay()
                    .blendMode(.multiply)
                    .mask(
                        symbol
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

private struct StampNoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let density = Int(size.width * size.height / 250)

            for _ in 0..<density {
                let rectSize = CGSize(
                    width: Double.random(in: 0.4...1.4),
                    height: Double.random(in: 0.4...1.4))
                let point = CGPoint(
                    x: Double.random(in: 0...size.width),
                    y: Double.random(in: 0...size.height))
                let rect = CGRect(origin: point, size: rectSize)
                let opacity = Double.random(in: 0.1...0.35)
                let color = Color.black.opacity(opacity)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}
