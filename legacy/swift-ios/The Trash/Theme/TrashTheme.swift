import SwiftUI
import UIKit

struct ThemePalette {
    let background: Color
    let card: Color
    let textPrimary: Color
    let textSecondary: Color
    let divider: Color
}

struct ThemeAccents {
    let blue: Color
    let green: Color
    let orange: Color
    let purple: Color
}

struct ThemeShadowPalette {
    let light: Color
    let dark: Color
}

struct ThemeTypography {
    let title: Font
    let headline: Font
    let subheadline: Font
    let body: Font
    let caption: Font
    let button: Font
    let heroIcon: Font
}

struct ThemeSpacing {
    let xs: CGFloat
    let sm: CGFloat
    let md: CGFloat
    let lg: CGFloat
    let xl: CGFloat
    let xxl: CGFloat
}

struct ThemeCornerRadius {
    let small: CGFloat
    let medium: CGFloat
    let large: CGFloat
    let pill: CGFloat
}

struct ThemeGradients {
    let primary: LinearGradient
    let accent: LinearGradient
}

struct ThemeAppearance {
    struct SegmentedControlAppearance {
        let background: UIColor
        let selectedBackground: UIColor
        let text: UIColor
        let selectedText: UIColor
    }

    let tabBarBackground: UIColor
    let tabBarSelectedTint: UIColor
    let tabBarUnselectedTint: UIColor
    let navigationBarBackground: UIColor
    let segmentedControl: SegmentedControlAppearance
    let sheetBackground: Color
}

enum VisualStyle {
    case neumorphic
    case ecoPaper
    case vibrantGlass
}

protocol TrashTheme {
    var name: String { get }
    var visualStyle: VisualStyle { get }
    var palette: ThemePalette { get }
    var accents: ThemeAccents { get }
    var shadows: ThemeShadowPalette { get }
    var typography: ThemeTypography { get }
    var spacing: ThemeSpacing { get }
    var corners: ThemeCornerRadius { get }
    var gradients: ThemeGradients { get }
    var appearance: ThemeAppearance { get }

    // ✨ Component Rendering Methods
    func backgroundView() -> AnyView
    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> AnyView
    func buttonSurface<Content: View>(
        isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content
    ) -> AnyView

    func configureAppearance()
}

extension TrashTheme {
    func backgroundView() -> AnyView {
        AnyView(palette.background.ignoresSafeArea())
    }

    func configureAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = appearance.tabBarBackground
        tabBarAppearance.shadowColor = nil
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = appearance.tabBarUnselectedTint
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: appearance.tabBarUnselectedTint
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = appearance.tabBarSelectedTint
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: appearance.tabBarSelectedTint
        ]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = appearance.tabBarUnselectedTint
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: appearance.tabBarUnselectedTint
        ]
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = appearance.tabBarSelectedTint
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: appearance.tabBarSelectedTint
        ]
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor =
            appearance.tabBarUnselectedTint
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: appearance.tabBarUnselectedTint
        ]
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor =
            appearance.tabBarSelectedTint
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: appearance.tabBarSelectedTint
        ]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = appearance.tabBarSelectedTint
        UITabBar.appearance().unselectedItemTintColor = appearance.tabBarUnselectedTint

        let segmentedAppearance = appearance.segmentedControl

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = appearance.navigationBarBackground
        navAppearance.shadowColor = nil
        navAppearance.titleTextAttributes = [.foregroundColor: segmentedAppearance.selectedText]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: segmentedAppearance.selectedText
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let segmentedControl = UISegmentedControl.appearance()
        segmentedControl.backgroundColor = segmentedAppearance.background
        segmentedControl.selectedSegmentTintColor = segmentedAppearance.selectedBackground
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: segmentedAppearance.text], for: .normal)
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: segmentedAppearance.selectedText], for: .selected)

        // Keep native controls in sync with theme accents so forms/sheets do not fall back to system blue.
        UISwitch.appearance().onTintColor = appearance.tabBarSelectedTint
        UIStepper.appearance().tintColor = appearance.tabBarSelectedTint
        UIDatePicker.appearance().tintColor = appearance.tabBarSelectedTint
        UITextField.appearance().tintColor = appearance.tabBarSelectedTint
        UITextView.appearance().tintColor = appearance.tabBarSelectedTint
        UISlider.appearance().tintColor = appearance.tabBarSelectedTint
        UITableView.appearance().backgroundColor = UIColor(appearance.sheetBackground)
        UICollectionView.appearance().backgroundColor = UIColor(appearance.sheetBackground)
    }

    // Semantic color tokens used by shared components and feature views.
    var onAccentForeground: Color {
        switch visualStyle {
        case .neumorphic:
            return .white
        case .vibrantGlass:
            return Color(red: 0.04, green: 0.08, blue: 0.16)
        case .ecoPaper:
            return Color(red: 0.95, green: 0.92, blue: 0.84)
        }
    }

    var interactiveStroke: Color {
        switch visualStyle {
        case .neumorphic:
            return palette.divider.opacity(0.45)
        case .vibrantGlass:
            return accents.blue.opacity(0.45)
        case .ecoPaper:
            return accents.green.opacity(0.42)
        }
    }

    var semanticSuccess: Color {
        switch visualStyle {
        case .neumorphic, .vibrantGlass:
            return accents.green
        case .ecoPaper:
            return Color(red: 0.23, green: 0.39, blue: 0.21)
        }
    }

    var semanticWarning: Color {
        switch visualStyle {
        case .neumorphic, .vibrantGlass:
            return accents.orange
        case .ecoPaper:
            return Color(red: 0.57, green: 0.37, blue: 0.21)
        }
    }

    var semanticDanger: Color {
        switch visualStyle {
        case .neumorphic, .vibrantGlass:
            return Color(red: 0.82, green: 0.26, blue: 0.30)
        case .ecoPaper:
            return Color(red: 0.58, green: 0.17, blue: 0.15)
        }
    }

    var semanticInfo: Color {
        accents.blue
    }

    var semanticHighlight: Color {
        switch visualStyle {
        case .neumorphic:
            return Color(red: 0.95, green: 0.73, blue: 0.27)
        case .vibrantGlass:
            return Color(red: 0.98, green: 0.77, blue: 0.31)
        case .ecoPaper:
            return Color(red: 0.73, green: 0.52, blue: 0.22)
        }
    }
}

private struct TrashOnAccentForegroundModifier: ViewModifier {
    @Environment(\.trashTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundColor(theme.onAccentForeground)
    }
}

extension View {
    func trashOnAccentForeground() -> some View {
        modifier(TrashOnAccentForegroundModifier())
    }
}
