import SwiftUI

// MARK: - Core Primitives

struct TrashCard<Content: View>: View {
    let cornerRadius: CGFloat?
    let content: Content
    @Environment(\.trashTheme) private var theme

    init(cornerRadius: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        theme.cardSurface(cornerRadius: cornerRadius ?? theme.corners.large, content: content)
    }
}

struct TrashButton<Content: View>: View {
    let action: () -> Void
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let content: Content

    @Environment(\.trashTheme) private var theme

    init(
        baseColor: Color? = nil,
        cornerRadius: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.baseColor = baseColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            content
        }
        .buttonStyle(
            ThemeButtonStyle(baseColor: baseColor, cornerRadius: cornerRadius, theme: theme))
    }
}

struct TrashTapArea<Content: View>: View {
    let action: () -> Void
    var haptics: Bool = false
    let content: Content

    init(haptics: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.haptics = haptics
        self.content = content()
    }

    var body: some View {
        Button(action: {
            if haptics {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            action()
        }) {
            content
        }
        .buttonStyle(.plain)
    }
}

struct ThemeButtonStyle: ButtonStyle {
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let theme: TrashTheme

    func makeBody(configuration: Configuration) -> some View {
        theme.buttonSurface(
            isPressed: configuration.isPressed,
            cornerRadius: cornerRadius ?? theme.corners.large,
            baseColor: baseColor,
            content: configuration.label
                .font(theme.typography.button)
                .trashOnAccentForeground()
        )
    }
}

struct ThemeBackground: View {
    @Environment(\.trashTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            theme.backgroundView()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

// MARK: - View Extensions

extension View {
    func trashCard(cornerRadius: CGFloat? = nil) -> some View {
        TrashCard(cornerRadius: cornerRadius) { self }
    }

    func trashInputStyle(cornerRadius: CGFloat? = nil) -> some View {
        modifier(TrashInputSurface(cornerRadius: cornerRadius))
    }
}
