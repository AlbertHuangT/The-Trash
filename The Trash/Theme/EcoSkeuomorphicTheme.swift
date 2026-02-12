import SwiftUI
import UIKit

struct EcoSkeuomorphicTheme: TrashTheme {
    let name: String = "Eco-Skeuomorphism"
    let palette: ThemePalette
    let accents: ThemeAccents
    let shadows: ThemeShadowPalette
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let corners: ThemeCornerRadius
    let gradients: ThemeGradients
    let appearance: ThemeAppearance

    init() {
        palette = ThemePalette(
            background: Color(red: 0.95, green: 0.92, blue: 0.85),
            card: Color(red: 0.97, green: 0.94, blue: 0.88),
            textPrimary: Color(red: 0.23, green: 0.19, blue: 0.14),
            textSecondary: Color(red: 0.42, green: 0.36, blue: 0.29),
            divider: Color(red: 0.74, green: 0.68, blue: 0.58)
        )

        accents = ThemeAccents(
            blue: Color(red: 0.22, green: 0.42, blue: 0.35),
            green: Color(red: 0.33, green: 0.48, blue: 0.27),
            orange: Color(red: 0.76, green: 0.42, blue: 0.27),
            purple: Color(red: 0.53, green: 0.33, blue: 0.24)
        )

        shadows = ThemeShadowPalette(
            light: Color.black.opacity(0.18),
            dark: Color.black.opacity(0.35)
        )

        typography = ThemeTypography(
            title: .system(size: 30, weight: .bold, design: .serif),
            headline: .system(size: 22, weight: .semibold, design: .serif),
            subheadline: .system(size: 17, weight: .medium, design: .serif),
            body: .system(size: 16, weight: .regular, design: .serif),
            caption: .system(size: 13, weight: .medium, design: .serif),
            button: .system(size: 16, weight: .bold, design: .serif),
            heroIcon: .system(size: 54, weight: .medium, design: .serif)
        )

        spacing = ThemeSpacing(
            xs: 4,
            sm: 10,
            md: 14,
            lg: 20,
            xl: 28,
            xxl: 42
        )

        corners = ThemeCornerRadius(
            small: 8,
            medium: 14,
            large: 20,
            pill: 28
        )

        gradients = ThemeGradients(
            primary: LinearGradient(colors: [Color(red: 0.93, green: 0.83, blue: 0.69), Color(red: 0.81, green: 0.71, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing),
            accent: LinearGradient(colors: [Color(red: 0.32, green: 0.48, blue: 0.32), Color(red: 0.68, green: 0.43, blue: 0.28)], startPoint: .leading, endPoint: .trailing)
        )

        let segmentedAppearance = ThemeAppearance.SegmentedControlAppearance(
            background: UIColor(red: 0.92, green: 0.88, blue: 0.81, alpha: 1),
            selectedBackground: UIColor(red: 0.79, green: 0.68, blue: 0.54, alpha: 1),
            text: UIColor(red: 0.46, green: 0.39, blue: 0.31, alpha: 1),
            selectedText: UIColor(red: 0.24, green: 0.19, blue: 0.14, alpha: 1)
        )

        appearance = ThemeAppearance(
            tabBarBackground: UIColor(red: 0.93, green: 0.89, blue: 0.82, alpha: 1),
            navigationBarBackground: UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1),
            segmentedControl: segmentedAppearance,
            sheetBackground: Color(red: 0.95, green: 0.92, blue: 0.85)
        )
    }
}
