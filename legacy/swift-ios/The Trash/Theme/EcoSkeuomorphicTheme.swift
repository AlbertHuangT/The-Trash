import SwiftUI
import UIKit

struct EcoSkeuomorphicTheme: TrashTheme {
    let name: String = "Eco Skeuomorphism"
    let visualStyle: VisualStyle = .ecoPaper
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
            background: Color(red: 0.95, green: 0.93, blue: 0.88),
            card: Color(red: 0.98, green: 0.96, blue: 0.92),
            textPrimary: Color(red: 0.15, green: 0.13, blue: 0.10),
            textSecondary: Color(red: 0.42, green: 0.38, blue: 0.32),
            divider: Color(red: 0.78, green: 0.74, blue: 0.68)
        )

        accents = ThemeAccents(
            blue: Color(red: 0.12, green: 0.42, blue: 0.58),
            green: Color(red: 0.18, green: 0.52, blue: 0.32),
            orange: Color(red: 0.85, green: 0.45, blue: 0.18),
            purple: Color(red: 0.52, green: 0.28, blue: 0.42)
        )

        shadows = ThemeShadowPalette(
            light: Color.white.opacity(0.22),
            dark: Color(red: 0.10, green: 0.12, blue: 0.07).opacity(0.35)
        )

        typography = ThemeTypography(
            title: .system(size: 34, weight: .bold, design: .rounded),
            headline: .system(size: 24, weight: .semibold, design: .rounded),
            subheadline: .system(size: 17, weight: .semibold, design: .rounded),
            body: .system(size: 17, weight: .regular, design: .rounded),
            caption: .system(size: 13, weight: .medium, design: .rounded),
            button: .system(size: 17, weight: .semibold, design: .rounded),
            heroIcon: .system(size: 48, weight: .semibold, design: .rounded)
        )

        spacing = ThemeSpacing(xs: 4, sm: 9, md: 14, lg: 18, xl: 26, xxl: 38)
        corners = ThemeCornerRadius(small: 8, medium: 14, large: 22, pill: 30)

        gradients = ThemeGradients(
            primary: LinearGradient(
                colors: [Color(red: 0.24, green: 0.58, blue: 0.38), Color(red: 0.16, green: 0.46, blue: 0.28)],
                startPoint: .top,
                endPoint: .bottom
            ),
            accent: LinearGradient(
                colors: [accents.orange, accents.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )

        let paperColor = UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1)
        let inkColor = UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 1)
        appearance = ThemeAppearance(
            tabBarBackground: paperColor,
            tabBarSelectedTint: UIColor(red: 0.18, green: 0.52, blue: 0.32, alpha: 1),
            tabBarUnselectedTint: inkColor.withAlphaComponent(0.50),
            navigationBarBackground: paperColor,
            segmentedControl: ThemeAppearance.SegmentedControlAppearance(
                background: UIColor(red: 0.85, green: 0.82, blue: 0.76, alpha: 1),
                selectedBackground: UIColor(red: 0.18, green: 0.52, blue: 0.32, alpha: 1),
                text: UIColor(red: 0.42, green: 0.38, blue: 0.32, alpha: 1),
                selectedText: UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
            ),
            sheetBackground: Color(red: 0.96, green: 0.94, blue: 0.90)
        )
    }

    func backgroundView() -> AnyView {
        AnyView(
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    PaperTextureView(baseColor: palette.background)

                    RadialGradient(
                        colors: [accents.green.opacity(0.18), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: max(width, height) * 0.7
                    )

                    RadialGradient(
                        colors: [accents.orange.opacity(0.14), Color.clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: max(width, height) * 0.65
                    )

                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.06)],
                        center: .center,
                        startRadius: min(width, height) * 0.3,
                        endRadius: max(width, height) * 0.8
                    )
                }
                .frame(width: width, height: height)
                .clipped()
            }
            .ignoresSafeArea()
        )
    }

    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> AnyView {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let underLayerShape = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 6), style: .continuous)
        return AnyView(
            content
                .background(
                    ZStack {
                        underLayerShape
                            .fill(Color(red: 0.68, green: 0.64, blue: 0.58))
                            .offset(y: 5)
                            .blur(radius: 2)

                        shape
                            .fill(palette.card)
                            .overlay(
                                PaperTextureView(baseColor: palette.card)
                                    .clipShape(shape)
                                    .opacity(0.50)
                            )
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.clear],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.15)
                                )
                                .clipShape(shape)
                            )
                            .overlay(
                                shape
                                    .stroke(palette.divider.opacity(0.92), lineWidth: 1)
                            )
                            .overlay(
                                shape
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    .padding(1)
                            )
                            .shadow(color: shadows.dark.opacity(0.9), radius: 12, x: 0, y: 6)
                    }
                )
        )
    }

    func buttonSurface<Content: View>(isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content) -> AnyView {
        let color = baseColor ?? accents.green
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let underLayerShape = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 6), style: .continuous)
        return AnyView(
            content
                .trashOnAccentForeground()
                .background(
                    ZStack {
                        if !isPressed {
                            underLayerShape
                                .fill(color.opacity(0.75))
                                .offset(y: 4)
                        }

                        shape
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(1.0), color.opacity(0.88)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                PaperTextureView(baseColor: color)
                                    .clipShape(shape)
                                    .opacity(0.22)
                            )
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(isPressed ? 0.08 : 0.25), Color.clear],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.4)
                                )
                                .clipShape(shape)
                            )
                            .overlay(
                                shape
                                    .stroke(palette.textPrimary.opacity(0.22), lineWidth: 1)
                            )
                            .overlay(
                                shape
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    .padding(1)
                            )
                            .shadow(
                                color: Color.black.opacity(isPressed ? 0.08 : 0.28),
                                radius: isPressed ? 1 : 6,
                                x: 0,
                                y: isPressed ? 0 : 4
                            )
                    }
                )
                .offset(y: isPressed ? 2 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        )
    }

    func configureAppearance() {
        let paperColor = UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1)
        let inkColor = UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 1)
        let selectedColor = UIColor(red: 0.18, green: 0.52, blue: 0.32, alpha: 1)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = paperColor
        tabBarAppearance.shadowColor = UIColor.clear
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.50)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.50)]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.50)
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.50)]
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = inkColor.withAlphaComponent(0.50)
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inkColor.withAlphaComponent(0.50)]
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = inkColor.withAlphaComponent(0.50)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = paperColor
        navAppearance.shadowColor = UIColor.clear
        navAppearance.titleTextAttributes = [.foregroundColor: inkColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: inkColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}
