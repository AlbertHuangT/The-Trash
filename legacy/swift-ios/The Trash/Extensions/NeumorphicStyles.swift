import SwiftUI

// MARK: - Neumorphic Colors (Theme Driven)
extension Color {
    private static var theme: TrashTheme {
        ThemeManager.shared.currentTheme
    }

    static var neuBackground: Color {
        theme.palette.background
    }

    static var neuLightShadow: Color {
        theme.shadows.light
    }

    static var neuDarkShadow: Color {
        theme.shadows.dark
    }

    static var neuText: Color {
        theme.palette.textPrimary
    }

    static var neuSecondaryText: Color {
        theme.palette.textSecondary
    }

    static var neuAccentBlue: Color {
        theme.accents.blue
    }

    static var neuAccentGreen: Color {
        theme.accents.green
    }

    static var neuAccentOrange: Color {
        theme.accents.orange
    }

    static var neuAccentPurple: Color {
        theme.accents.purple
    }

    static var neuCardBackground: Color {
        theme.palette.card
    }

    static var neuDivider: Color {
        theme.palette.divider
    }
}

// MARK: - Smart Theme Modifiers
// These modifiers now delegate to the theme's rendering engine

struct NeumorphicShadow: ViewModifier {
    var isPressed: Bool = false
    var cornerRadius: CGFloat?
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.large
        
        if theme.visualStyle == .neumorphic {
            // Original Neumorphic Logic
            content
                .background(
                    Group {
                        if isPressed {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(theme.palette.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: radius)
                                        .stroke(theme.palette.background, lineWidth: 4)
                                        .shadow(color: theme.shadows.dark, radius: 10, x: 5, y: 5)
                                        .clipShape(RoundedRectangle(cornerRadius: radius))
                                        .shadow(color: theme.shadows.light, radius: 10, x: -4, y: -4)
                                        .clipShape(RoundedRectangle(cornerRadius: radius))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(theme.palette.background)
                                .shadow(color: theme.shadows.dark, radius: 10, x: 10, y: 10)
                                .shadow(color: theme.shadows.light, radius: 10, x: -6, y: -6)
                        }
                    }
                )
        } else {
            // Delegate to Theme for other styles
            theme.cardSurface(cornerRadius: radius, content: content)
        }
    }
}

// MARK: - Neumorphic Concave Modifier (Pressed/Inset Look)
struct NeumorphicConcave: ViewModifier {
    var cornerRadius: CGFloat?
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.medium
        
        if theme.visualStyle == .neumorphic {
            content
                .background(
                    RoundedRectangle(cornerRadius: radius)
                        .fill(theme.palette.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius)
                                .stroke(theme.palette.background, lineWidth: 2)
                                .shadow(color: theme.shadows.dark, radius: 3, x: 3, y: 3)
                                .clipShape(RoundedRectangle(cornerRadius: radius))
                                .shadow(color: theme.shadows.light, radius: 3, x: -3, y: -3)
                                .clipShape(RoundedRectangle(cornerRadius: radius))
                        )
                )
        } else {
            // For non-neumorphic themes, concave often means a subtle dark overlay or just the card surface
            theme.cardSurface(cornerRadius: radius, content: content)
                .brightness(-0.05)
        }
    }
}

// MARK: - Neumorphic Button Style
struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat?
    var color: Color?

    func makeBody(configuration: Configuration) -> some View {
        // We can't use @Environment in ButtonStyle easily without some tricks, 
        // so we use the singleton as a fallback or pass it in.
        // For simplicity here, we use the singleton for global styles.
        let theme = ThemeManager.shared.currentTheme
        let radius = cornerRadius ?? theme.corners.large
        
        theme.buttonSurface(
            isPressed: configuration.isPressed,
            cornerRadius: radius,
            baseColor: color,
            content: configuration.label
        )
    }
}

// MARK: - View Extensions
extension View {
    func neumorphic(isPressed: Bool = false, cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(NeumorphicShadow(isPressed: isPressed, cornerRadius: cornerRadius))
    }

    func neumorphicConcave(cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(NeumorphicConcave(cornerRadius: cornerRadius))
    }

    func neumorphicCard(padding: CGFloat? = nil) -> some View {
        let paddingValue = padding ?? ThemeManager.shared.currentTheme.spacing.lg
        return self
            .padding(paddingValue)
            .neumorphic()
    }
}
