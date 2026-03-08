import SwiftUI

private struct TrashPrimaryButtonStyle: ButtonStyle {
    let theme: TrashTheme
    let baseColor: Color?
    let cornerRadius: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.onAccentForeground)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius ?? theme.layout.standardCardCornerRadius,
                    style: .continuous
                )
                .fill(baseColor ?? theme.accents.green)
                .shadow(
                    color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.18),
                    radius: configuration.isPressed ? 1 : 4,
                    x: 0,
                    y: configuration.isPressed ? 0 : 3
                )
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(theme.animations.quick, value: configuration.isPressed)
    }
}

struct TrashCard<Content: View>: View {
    let cornerRadius: CGFloat?
    let content: Content
    private let theme = TrashTheme()

    init(cornerRadius: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.components.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius ?? theme.layout.standardCardCornerRadius, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius ?? theme.layout.standardCardCornerRadius, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
    }
}

struct TrashButton<Content: View>: View {
    let action: () -> Void
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let content: Content
    private let theme = TrashTheme()

    @State private var hapticTrigger = false

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
            hapticTrigger.toggle()
            action()
        }) {
            content
                .font(theme.typography.button)
                .frame(maxWidth: .infinity)
                .frame(minHeight: theme.components.buttonHeight, alignment: .center)
                .padding(.horizontal, theme.layout.compactControlHorizontalInset)
        }
        .buttonStyle(
            TrashPrimaryButtonStyle(
                theme: theme,
                baseColor: baseColor,
                cornerRadius: cornerRadius
            )
        )
        .compatibleSensoryFeedback(.impactSolid(intensity: 0.6), trigger: hapticTrigger)
    }
}

struct TrashTapArea<Content: View>: View {
    let action: () -> Void
    var haptics: Bool = false
    let content: Content
    private let theme = TrashTheme()

    @State private var hapticTrigger = false

    init(haptics: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.haptics = haptics
        self.content = content()
    }

    var body: some View {
        Button(action: {
            if haptics { hapticTrigger.toggle() }
            action()
        }) {
            content
                .frame(
                    minWidth: theme.components.minimumHitTarget,
                    minHeight: theme.components.minimumHitTarget,
                    alignment: .center
                )
        }
        .buttonStyle(.plain)
        .compatibleSensoryFeedback(.impactSoft(intensity: 0.4), trigger: hapticTrigger)
    }
}

/// Consolidated: ThemeBackground is an alias for ThemeBackgroundView (defined in ThemeBackgroundView.swift).
/// Both names are supported for backward compatibility.
typealias ThemeBackground = ThemeBackgroundView

// MARK: - View Extensions

extension View {
    func surfaceCard(cornerRadius: CGFloat? = nil) -> some View {
        TrashCard(cornerRadius: cornerRadius) { self }
    }

    func trashInputStyle(cornerRadius: CGFloat? = nil) -> some View {
        modifier(TrashInputSurface(cornerRadius: cornerRadius))
    }
}
