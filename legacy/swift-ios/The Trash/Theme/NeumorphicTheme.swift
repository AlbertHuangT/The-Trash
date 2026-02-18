import SwiftUI
import UIKit

struct NeumorphicTheme: TrashTheme {
    let name: String = "Neumorphic"
    let visualStyle: VisualStyle = .neumorphic
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
                    ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                    : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
            }),
            card: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                    : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
            }),
            textPrimary: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 220/255, green: 225/255, blue: 235/255, alpha: 1)
                    : UIColor(red: 77/255, green: 89/255, blue: 102/255, alpha: 1)
            }),
            textSecondary: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 150/255, green: 160/255, blue: 175/255, alpha: 1)
                    : UIColor(red: 128/255, green: 140/255, blue: 153/255, alpha: 1)
            }),
            divider: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 60/255, green: 65/255, blue: 80/255, alpha: 0.5)
                    : UIColor(red: 190/255, green: 197/255, blue: 210/255, alpha: 0.5)
            })
        )

        accents = ThemeAccents(
            blue: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 70/255, green: 130/255, blue: 255/255, alpha: 1)
                    : UIColor(red: 50/255, green: 100/255, blue: 250/255, alpha: 1)
            }),
            green: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 60/255, green: 210/255, blue: 160/255, alpha: 1)
                    : UIColor(red: 50/255, green: 200/255, blue: 150/255, alpha: 1)
            }),
            orange: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 159/255, blue: 60/255, alpha: 1)
                    : UIColor(red: 240/255, green: 140/255, blue: 40/255, alpha: 1)
            }),
            purple: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 160/255, green: 100/255, blue: 255/255, alpha: 1)
                    : UIColor(red: 140/255, green: 80/255, blue: 230/255, alpha: 1)
            })
        )

        shadows = ThemeShadowPalette(
            light: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 58/255, green: 63/255, blue: 78/255, alpha: 0.5)
                    : UIColor.white.withAlphaComponent(0.7)
            }),
            dark: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 25/255, green: 28/255, blue: 36/255, alpha: 0.7)
                    : UIColor(red: 163/255, green: 177/255, blue: 198/255, alpha: 0.6)
            })
        )

        typography = ThemeTypography(
            title: .system(size: 28, weight: .bold, design: .rounded),
            headline: .system(size: 22, weight: .semibold, design: .rounded),
            subheadline: .system(size: 17, weight: .medium, design: .rounded),
            body: .system(size: 16, weight: .regular, design: .default),
            caption: .system(size: 13, weight: .medium, design: .default),
            button: .system(size: 16, weight: .semibold, design: .rounded),
            heroIcon: .system(size: 50, weight: .light, design: .rounded)
        )

        spacing = ThemeSpacing(
            xs: 4,
            sm: 8,
            md: 12,
            lg: 16,
            xl: 24,
            xxl: 36
        )

        corners = ThemeCornerRadius(
            small: 10,
            medium: 16,
            large: 24,
            pill: 32
        )

        gradients = ThemeGradients(
            primary: LinearGradient(colors: [accents.blue, accents.purple], startPoint: .topLeading, endPoint: .bottomTrailing),
            accent: LinearGradient(colors: [accents.green, accents.blue], startPoint: .leading, endPoint: .trailing)
        )

        let segmentedAppearance = ThemeAppearance.SegmentedControlAppearance(
            background: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 38/255, green: 42/255, blue: 54/255, alpha: 1)
                    : UIColor(red: 214/255, green: 219/255, blue: 226/255, alpha: 1)
            },
            selectedBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 54/255, green: 58/255, blue: 72/255, alpha: 1)
                    : UIColor.white
            },
            text: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 150/255, green: 160/255, blue: 175/255, alpha: 1)
                    : UIColor(red: 128/255, green: 140/255, blue: 153/255, alpha: 1)
            },
            selectedText: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 220/255, green: 225/255, blue: 235/255, alpha: 1)
                    : UIColor(red: 77/255, green: 89/255, blue: 102/255, alpha: 1)
            }
        )

        appearance = ThemeAppearance(
            tabBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                    : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
            },
            tabBarSelectedTint: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 70/255, green: 130/255, blue: 255/255, alpha: 1)
                    : UIColor(red: 50/255, green: 100/255, blue: 250/255, alpha: 1)
            },
            tabBarUnselectedTint: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 150/255, green: 160/255, blue: 175/255, alpha: 1)
                    : UIColor(red: 128/255, green: 140/255, blue: 153/255, alpha: 1)
            },
            navigationBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                    : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
            },
            segmentedControl: segmentedAppearance,
            sheetBackground: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                    : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
            })
        )
    }

    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> AnyView {
        AnyView(
            content
                .background(palette.card)
                .cornerRadius(cornerRadius)
                .shadow(color: shadows.dark, radius: 10, x: 10, y: 10)
                .shadow(color: shadows.light, radius: 10, x: -6, y: -6)
        )
    }

    func buttonSurface<Content: View>(isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content) -> AnyView {
        let color = baseColor ?? palette.card
        return AnyView(
            content
                .background(
                    ZStack {
                        if isPressed {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .stroke(color, lineWidth: 4)
                                        .shadow(color: shadows.dark, radius: 10, x: 5, y: 5)
                                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                        .shadow(color: shadows.light, radius: 10, x: -4, y: -4)
                                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(color)
                                .shadow(color: shadows.dark, radius: 10, x: 10, y: 10)
                                .shadow(color: shadows.light, radius: 10, x: -6, y: -6)
                        }
                    }
                )
                .scaleEffect(isPressed ? 0.97 : 1.0)
        )
    }
}
