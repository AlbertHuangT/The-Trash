import SwiftUI
import UIKit

struct VibrantTheme: TrashTheme {
    let name: String = "Vibrant Night"
    let visualStyle: VisualStyle = .vibrantGlass
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
            background: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 8/255, green: 12/255, blue: 24/255, alpha: 1)
                    : UIColor(red: 12/255, green: 18/255, blue: 34/255, alpha: 1)
            }),
            card: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 0.6)
                    : UIColor(red: 26/255, green: 36/255, blue: 62/255, alpha: 0.6)
            }),
            textPrimary: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 235/255, green: 247/255, blue: 255/255, alpha: 1)
                    : UIColor(red: 237/255, green: 250/255, blue: 255/255, alpha: 1)
            }),
            textSecondary: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 164/255, green: 186/255, blue: 210/255, alpha: 1)
                    : UIColor(red: 180/255, green: 200/255, blue: 220/255, alpha: 1)
            }),
            divider: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.15)
                    : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.2)
            })
        )

        accents = ThemeAccents(
            blue: Color(red: 0.14, green: 0.86, blue: 0.99),
            green: Color(red: 0.16, green: 0.97, blue: 0.72),
            orange: Color(red: 1.0, green: 0.52, blue: 0.26),
            purple: Color(red: 0.92, green: 0.32, blue: 0.95)
        )

        shadows = ThemeShadowPalette(
            light: Color.white.opacity(0.1),
            dark: Color.black.opacity(0.4)
        )

        typography = ThemeTypography(
            title: .system(size: 31, weight: .black, design: .rounded),
            headline: .system(size: 22, weight: .bold, design: .rounded),
            subheadline: .system(size: 17, weight: .semibold, design: .rounded),
            body: .system(size: 16, weight: .regular, design: .monospaced),
            caption: .system(size: 13, weight: .semibold, design: .monospaced),
            button: .system(size: 16, weight: .heavy, design: .rounded),
            heroIcon: .system(size: 52, weight: .black, design: .rounded)
        )

        spacing = ThemeSpacing(xs: 4, sm: 10, md: 14, lg: 18, xl: 26, xxl: 40)
        corners = ThemeCornerRadius(small: 14, medium: 24, large: 34, pill: 44)

        gradients = ThemeGradients(
            primary: LinearGradient(colors: [Color(red: 0.12, green: 0.89, blue: 0.99), Color(red: 0.93, green: 0.29, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing),
            accent: LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.72), Color(red: 0.18, green: 0.97, blue: 0.75)], startPoint: .leading, endPoint: .trailing)
        )

        appearance = ThemeAppearance(
            tabBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 10/255, green: 15/255, blue: 30/255, alpha: 1)
                    : UIColor(red: 12/255, green: 18/255, blue: 34/255, alpha: 1)
            },
            tabBarSelectedTint: UIColor(red: 0.92, green: 0.32, blue: 0.95, alpha: 1),
            tabBarUnselectedTint: UIColor(red: 0.56, green: 0.63, blue: 0.74, alpha: 1),
            navigationBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 12/255, green: 18/255, blue: 32/255, alpha: 1)
                    : UIColor(red: 14/255, green: 20/255, blue: 36/255, alpha: 1)
            },
            segmentedControl: ThemeAppearance.SegmentedControlAppearance(
                background: UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1),
                selectedBackground: UIColor(red: 0.34, green: 0.19, blue: 0.55, alpha: 1),
                text: UIColor.gray,
                selectedText: UIColor.white
            ),
            sheetBackground: Color(red: 0.05, green: 0.08, blue: 0.15)
        )
    }

    func backgroundView() -> AnyView {
        AnyView(
            ZStack {
                palette.background
                // ✨ Glassmorphism background spheres
                Circle()
                    .fill(accents.purple.opacity(0.3))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -150, y: -200)

                Circle()
                    .fill(accents.blue.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 150, y: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped() // ✨ 关键修复
            .ignoresSafeArea()
        )
    }

    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> AnyView {
        AnyView(
            content
                .background(.ultraThinMaterial)
                .background(palette.card.opacity(0.4))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.05), .black.opacity(0.05), .black.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
        )
    }

    func buttonSurface<Content: View>(isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content) -> AnyView {
        let color = baseColor ?? accents.blue
        return AnyView(
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(interactiveStroke, lineWidth: 1)
                )
                .shadow(color: color.opacity(isPressed ? 0.3 : 0.5), radius: isPressed ? 5 : 12, x: 0, y: isPressed ? 2 : 5)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        )
    }
}
