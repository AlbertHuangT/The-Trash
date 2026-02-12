
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

// MARK: - Neumorphic Shadow Modifier
struct NeumorphicShadow: ViewModifier {
    var isPressed: Bool = false
    var cornerRadius: CGFloat?
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.large
        content
            .background(
                Group {
                    if isPressed {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Color.neuBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(Color.neuBackground, lineWidth: 4)
                                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                                    .clipShape(RoundedRectangle(cornerRadius: radius))
                                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                                    .clipShape(RoundedRectangle(cornerRadius: radius))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Color.neuBackground)
                            .shadow(color: .neuDarkShadow, radius: 10, x: 10, y: 10)
                            .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                    }
                }
            )
    }
}

// MARK: - Neumorphic Concave Modifier (Pressed/Inset Look)
struct NeumorphicConcave: ViewModifier {
    var cornerRadius: CGFloat?
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? theme.corners.medium
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.neuBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(Color.neuBackground, lineWidth: 2)
                            .shadow(color: .neuDarkShadow, radius: 3, x: 3, y: 3)
                            .clipShape(RoundedRectangle(cornerRadius: radius))
                            .shadow(color: .neuLightShadow, radius: 3, x: -3, y: -3)
                            .clipShape(RoundedRectangle(cornerRadius: radius))
                    )
            )
    }
}

// MARK: - Neumorphic Button Style
struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat?
    var color: Color = .neuBackground

    func makeBody(configuration: Configuration) -> some View {
        let radius = cornerRadius ?? ThemeManager.shared.currentTheme.corners.large
        configuration.label
            .padding()
            .background(
                Group {
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(color)
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(color, lineWidth: 4)
                                    .shadow(color: Color.neuDarkShadow, radius: 4, x: 5, y: 5)
                                    .clipShape(RoundedRectangle(cornerRadius: radius))
                                    .shadow(color: Color.neuLightShadow, radius: 4, x: -2, y: -2)
                                    .clipShape(RoundedRectangle(cornerRadius: radius))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(color)
                            .shadow(color: Color.neuDarkShadow, radius: 10, x: 10, y: 10)
                            .shadow(color: Color.neuLightShadow, radius: 10, x: -5, y: -5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
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
            .background(Color.neuBackground)
            .neumorphic()
    }
}
