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
    let navigationBarBackground: UIColor
    let segmentedControl: SegmentedControlAppearance
    let sheetBackground: Color
}

protocol TrashTheme {
    var name: String { get }
    var palette: ThemePalette { get }
    var accents: ThemeAccents { get }
    var shadows: ThemeShadowPalette { get }
    var typography: ThemeTypography { get }
    var spacing: ThemeSpacing { get }
    var corners: ThemeCornerRadius { get }
    var gradients: ThemeGradients { get }
    var appearance: ThemeAppearance { get }

    func configureAppearance()
}

extension TrashTheme {
    func configureAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = appearance.tabBarBackground
        tabBarAppearance.shadowColor = nil
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = appearance.navigationBarBackground
        navAppearance.shadowColor = nil
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let segmentedAppearance = appearance.segmentedControl
        let segmentedControl = UISegmentedControl.appearance()
        segmentedControl.backgroundColor = segmentedAppearance.background
        segmentedControl.selectedSegmentTintColor = segmentedAppearance.selectedBackground
        segmentedControl.setTitleTextAttributes([.foregroundColor: segmentedAppearance.text], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: segmentedAppearance.selectedText], for: .selected)
    }
}
