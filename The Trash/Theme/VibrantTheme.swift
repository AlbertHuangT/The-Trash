import SwiftUI
import UIKit

struct VibrantTheme: TrashTheme {
    let name: String = "Vibrant Night"
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
                    ? UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
                    : UIColor(red: 26/255, green: 36/255, blue: 62/255, alpha: 1)
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
                    ? UIColor(red: 45/255, green: 60/255, blue: 85/255, alpha: 0.7)
                    : UIColor(red: 60/255, green: 80/255, blue: 110/255, alpha: 0.4)
            })
        )

        accents = ThemeAccents(
            blue: Color(red: 0.29, green: 0.8, blue: 0.98),
            green: Color(red: 0.2, green: 0.95, blue: 0.67),
            orange: Color(red: 0.99, green: 0.56, blue: 0.32),
            purple: Color(red: 0.67, green: 0.39, blue: 0.99)
        )

        shadows = ThemeShadowPalette(
            light: Color.black.opacity(0.4),
            dark: Color.black.opacity(0.8)
        )

        typography = ThemeTypography(
            title: .system(size: 30, weight: .black, design: .rounded),
            headline: .system(size: 22, weight: .semibold, design: .rounded),
            subheadline: .system(size: 17, weight: .medium, design: .rounded),
            body: .system(size: 16, weight: .regular, design: .default),
            caption: .system(size: 13, weight: .medium, design: .rounded),
            button: .system(size: 16, weight: .bold, design: .rounded),
            heroIcon: .system(size: 52, weight: .bold, design: .rounded)
        )

        spacing = ThemeSpacing(
            xs: 4,
            sm: 10,
            md: 14,
            lg: 18,
            xl: 26,
            xxl: 40
        )

        corners = ThemeCornerRadius(
            small: 12,
            medium: 20,
            large: 30,
            pill: 40
        )

        gradients = ThemeGradients(
            primary: LinearGradient(colors: [Color(red: 0.31, green: 0.87, blue: 0.99), Color(red: 0.63, green: 0.35, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing),
            accent: LinearGradient(colors: [Color(red: 0.99, green: 0.36, blue: 0.67), Color(red: 0.2, green: 0.95, blue: 0.67)], startPoint: .leading, endPoint: .trailing)
        )

        let segmentedAppearance = ThemeAppearance.SegmentedControlAppearance(
            background: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 25/255, green: 32/255, blue: 52/255, alpha: 1)
                    : UIColor(red: 32/255, green: 42/255, blue: 62/255, alpha: 1)
            },
            selectedBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 55/255, green: 92/255, blue: 138/255, alpha: 1)
                    : UIColor(red: 68/255, green: 108/255, blue: 158/255, alpha: 1)
            },
            text: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 145/255, green: 162/255, blue: 195/255, alpha: 1)
                    : UIColor(red: 170/255, green: 190/255, blue: 215/255, alpha: 1)
            },
            selectedText: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 235/255, green: 247/255, blue: 255/255, alpha: 1)
                    : UIColor(red: 235/255, green: 247/255, blue: 255/255, alpha: 1)
            }
        )

        appearance = ThemeAppearance(
            tabBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 10/255, green: 15/255, blue: 30/255, alpha: 1)
                    : UIColor(red: 12/255, green: 18/255, blue: 34/255, alpha: 1)
            },
            navigationBarBackground: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 12/255, green: 18/255, blue: 32/255, alpha: 1)
                    : UIColor(red: 14/255, green: 20/255, blue: 36/255, alpha: 1)
            },
            segmentedControl: segmentedAppearance,
            sheetBackground: Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 10/255, green: 15/255, blue: 28/255, alpha: 1)
                    : UIColor(red: 14/255, green: 20/255, blue: 34/255, alpha: 1)
            })
        )
    }
}
