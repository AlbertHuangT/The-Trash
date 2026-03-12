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
    let display: Font
    let title: Font
    let headline: Font
    let subheadline: Font
    let body: Font
    let caption: Font
    let button: Font
    let kicker: Font
    let heroIcon: Font
}

struct ThemeSpacing {
    /// 4pt — tightest gaps (icon–label, inner padding)
    let xs: CGFloat
    /// 8pt — compact padding (pill insets, small gaps)
    let sm: CGFloat
    /// 16pt — standard content padding
    let md: CGFloat
    /// 20pt — section gaps, card padding
    let lg: CGFloat
    /// 28pt — major section separation
    let xl: CGFloat
    /// 40pt — hero-level separation
    let xxl: CGFloat
}

// MARK: - Animation Presets

struct ThemeAnimations {
    /// Standard interactive feedback — buttons, toggles, selection changes
    let standard: Animation
    /// Quick micro-interactions — icon changes, state badges
    let quick: Animation
    /// Emphasis transitions — overlays, hero reveals, card entrances
    let emphasis: Animation
    /// Continuous pulse — live indicators, attention grabbers
    let pulse: Animation
}

struct ThemeCornerRadius {
    /// Compact controls, badges, and input chips.
    let small: CGFloat
    /// Standard card, row, and input radius.
    let medium: CGFloat
    /// Large surfaces like hero cards and sheets.
    let large: CGFloat
    /// Fully rounded pill surfaces.
    let pill: CGFloat
}

struct ThemeComponentMetrics {
    /// Apple HIG minimum tappable target.
    let minimumHitTarget: CGFloat
    /// Standard square icon button size.
    let iconButtonSize: CGFloat
    /// Default prominent button height.
    let buttonHeight: CGFloat
    /// Default text input height.
    let inputHeight: CGFloat
    /// Standard list/settings row height.
    let rowHeight: CGFloat
    /// Segmented control minimum height.
    let segmentedControlHeight: CGFloat
    /// Interactive pill height.
    let pillHeight: CGFloat
    /// Compact inline control height for badges and status chips.
    let compactControlHeight: CGFloat
    /// Default card body padding.
    let cardPadding: CGFloat
    /// Default sheet/dialog content padding.
    let sheetPadding: CGFloat
    /// Default horizontal content inset.
    let contentInset: CGFloat
}

struct ThemeLayoutGuides {
    /// Default horizontal inset for full-screen page content.
    let screenInset: CGFloat
    /// Standard vertical gap between major sections on a page.
    let sectionSpacing: CGFloat
    /// Standard gap inside stacked cards and rows.
    let elementSpacing: CGFloat
    /// Standard horizontal gap between icons and labels in interactive rows.
    let rowContentSpacing: CGFloat
    /// Horizontal padding inside text-only inline actions.
    let inlineButtonHorizontalInset: CGFloat
    /// Horizontal padding inside pills and compact controls.
    let compactControlHorizontalInset: CGFloat
    /// Horizontal padding inside text inputs and search fields.
    let inputHorizontalInset: CGFloat
    /// Outer horizontal inset for sheet cards.
    let sheetEdgeInset: CGFloat
    /// Standard spacing between stacked sheet actions.
    let sheetActionSpacing: CGFloat
    /// Minimum hit target for toolbar affordances.
    let toolbarHitTarget: CGFloat
    /// Standard radius for rows and compact surfaced cards.
    let standardCardCornerRadius: CGFloat
    /// Standard radius for prominent surfaces like sheets and hero cards.
    let prominentCardCornerRadius: CGFloat
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

struct TrashTheme {
    let name: String
    let palette: ThemePalette
    let accents: ThemeAccents
    let shadows: ThemeShadowPalette
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let corners: ThemeCornerRadius
    let components: ThemeComponentMetrics
    let layout: ThemeLayoutGuides
    let gradients: ThemeGradients
    let appearance: ThemeAppearance
    let animations: ThemeAnimations

    init() {
        name = "Eco Skeuomorphism"

        palette = ThemePalette(
            background: Color(red: 0.952, green: 0.945, blue: 0.925),
            card: Color(red: 0.965, green: 0.944, blue: 0.897),
            textPrimary: Color(red: 0.239, green: 0.231, blue: 0.196), // #3D3B32
            textSecondary: Color(red: 0.263, green: 0.349, blue: 0.161), // #435928 — WCAG AA ≥ 4.5:1
            divider: Color(red: 0.81, green: 0.78, blue: 0.71)
        )

        accents = ThemeAccents(
            blue: Color(red: 0.310, green: 0.490, blue: 0.471),        // #4F7D78 teal
            green: Color(red: 0.306, green: 0.396, blue: 0.196),       // #4E6532
            orange: Color(red: 0.85, green: 0.45, blue: 0.18),
            purple: Color(red: 0.52, green: 0.28, blue: 0.42)
        )

        shadows = ThemeShadowPalette(
            light: Color.white.opacity(0.12),
            dark: Color.black.opacity(0.08)
        )

        typography = ThemeTypography(
            display: .system(size: 48, weight: .heavy, design: .rounded),
            title: .system(size: 32, weight: .bold, design: .rounded),
            headline: .system(size: 24, weight: .semibold, design: .rounded),
            subheadline: .system(size: 16, weight: .semibold, design: .rounded),
            body: .system(size: 16, weight: .regular, design: .rounded),
            caption: .system(size: 12, weight: .medium, design: .rounded),
            button: .system(size: 16, weight: .semibold, design: .rounded),
            kicker: .system(size: 12, weight: .semibold, design: .rounded),
            heroIcon: .system(size: 48, weight: .semibold, design: .rounded)
        )

        // 8pt primary grid, 4pt secondary grid for compact internals only.
        spacing = ThemeSpacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 40)
        corners = ThemeCornerRadius(small: 12, medium: 16, large: 20, pill: 22)
        components = ThemeComponentMetrics(
            minimumHitTarget: 44,
            iconButtonSize: 44,
            buttonHeight: 52,
            inputHeight: 52,
            rowHeight: 52,
            segmentedControlHeight: 44,
            pillHeight: 44,
            compactControlHeight: 32,
            cardPadding: 16,
            sheetPadding: 24,
            contentInset: 16
        )
        layout = ThemeLayoutGuides(
            screenInset: 16,
            sectionSpacing: 24,
            elementSpacing: 12,
            rowContentSpacing: 12,
            inlineButtonHorizontalInset: 8,
            compactControlHorizontalInset: 12,
            inputHorizontalInset: 16,
            sheetEdgeInset: 16,
            sheetActionSpacing: 12,
            toolbarHitTarget: 44,
            standardCardCornerRadius: 16,
            prominentCardCornerRadius: 20
        )

        // Standardized animation presets for consistency across the app
        animations = ThemeAnimations(
            standard: .spring(response: 0.35, dampingFraction: 0.8),
            quick: .spring(response: 0.2, dampingFraction: 0.7),
            emphasis: .spring(response: 0.5, dampingFraction: 0.65),
            pulse: .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        )

        gradients = ThemeGradients(
            primary: LinearGradient(
                colors: [Color(red: 0.310, green: 0.490, blue: 0.471), Color(red: 0.176, green: 0.478, blue: 0.420)],
                startPoint: .top,
                endPoint: .bottom
            ),
            accent: LinearGradient(
                colors: [accents.orange, accents.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )

        let paperColor = UIColor(red: 0.949, green: 0.941, blue: 0.918, alpha: 1)
        let inkColor = UIColor(red: 0.239, green: 0.231, blue: 0.196, alpha: 1)
        appearance = ThemeAppearance(
            tabBarBackground: paperColor,
            tabBarSelectedTint: UIColor(red: 0.310, green: 0.490, blue: 0.471, alpha: 1),
            tabBarUnselectedTint: inkColor.withAlphaComponent(0.50),
            navigationBarBackground: paperColor,
            segmentedControl: ThemeAppearance.SegmentedControlAppearance(
                background: UIColor(red: 0.94, green: 0.91, blue: 0.85, alpha: 1),
                selectedBackground: UIColor(red: 0.310, green: 0.490, blue: 0.471, alpha: 1),
                text: UIColor(red: 0.263, green: 0.349, blue: 0.161, alpha: 1),
                selectedText: UIColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 1)
            ),
            sheetBackground: Color(red: 0.949, green: 0.941, blue: 0.918)
        )
    }

    // MARK: - Component Rendering Methods

    func backgroundView() -> some View {
        palette.background
            .ignoresSafeArea()
    }

    func cardSurface<Content: View>(cornerRadius: CGFloat, content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(
                shape
                    .fill(palette.card)
                    .overlay(
                        shape.stroke(palette.divider, lineWidth: 1)
                    )
                    .shadow(color: shadows.dark.opacity(0.5), radius: 6, x: 0, y: 3)
            )
    }

    func buttonSurface<Content: View>(isPressed: Bool, cornerRadius: CGFloat, baseColor: Color?, content: Content) -> some View {
        let color = baseColor ?? accents.green
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .foregroundColor(onAccentForeground)
            .background(
                shape
                    .fill(color)
                    .shadow(
                        color: Color.black.opacity(isPressed ? 0.08 : 0.22),
                        radius: isPressed ? 1 : 4,
                        x: 0,
                        y: isPressed ? 0 : 3
                    )
            )
            .offset(y: isPressed ? 2 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
    }

    func configureAppearance() {
        let inkColor = UIColor(red: 0.239, green: 0.231, blue: 0.196, alpha: 1)
        let selectedColor = UIColor(red: 0.310, green: 0.490, blue: 0.471, alpha: 1)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
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
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = UIColor.clear
        navAppearance.titleTextAttributes = [.foregroundColor: inkColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: inkColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let segmentedAppearance = appearance.segmentedControl
        let segmentedControl = UISegmentedControl.appearance()
        segmentedControl.backgroundColor = segmentedAppearance.background
        segmentedControl.selectedSegmentTintColor = segmentedAppearance.selectedBackground
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: segmentedAppearance.text], for: .normal)
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: segmentedAppearance.selectedText], for: .selected)

        UISwitch.appearance().onTintColor = appearance.tabBarSelectedTint
        UIStepper.appearance().tintColor = appearance.tabBarSelectedTint
        UIDatePicker.appearance().tintColor = appearance.tabBarSelectedTint
        UITextField.appearance().tintColor = appearance.tabBarSelectedTint
        UITextView.appearance().tintColor = appearance.tabBarSelectedTint
        UISlider.appearance().tintColor = appearance.tabBarSelectedTint
        UITableView.appearance().backgroundColor = UIColor(appearance.sheetBackground)
        UICollectionView.appearance().backgroundColor = UIColor(appearance.sheetBackground)
    }

    // MARK: - Semantic Color Tokens

    var onAccentForeground: Color {
        Color(red: 0.95, green: 0.92, blue: 0.84)
    }

    var interactiveStroke: Color {
        accents.green.opacity(0.42)
    }

    var appBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                appBackground,
                surfaceBackground.opacity(0.96),
                appBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var overlayScrim: LinearGradient {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var cardShadow: Color {
        Color.black.opacity(0.08)
    }

    var raisedShadow: Color {
        Color.black.opacity(0.18)
    }

    var semanticSuccess: Color {
        Color(red: 0.23, green: 0.39, blue: 0.21)
    }

    var semanticWarning: Color {
        Color(red: 0.57, green: 0.37, blue: 0.21)
    }

    var semanticDanger: Color {
        Color(red: 0.58, green: 0.17, blue: 0.15)
    }

    var semanticInfo: Color {
        accents.blue
    }

    var semanticHighlight: Color {
        Color(red: 0.73, green: 0.52, blue: 0.22)
    }

    // MARK: - Category Colors (Arena)

    var categoryRecyclable: Color { accents.blue }
    var categoryCompostable: Color { accents.green }
    var categoryHazardous: Color { semanticDanger }
    var categoryLandfill: Color { Color(red: 0.45, green: 0.43, blue: 0.40) }

    // MARK: - Medal Colors (Leaderboard)

    var medalGold: Color { Color(red: 0.85, green: 0.65, blue: 0.13) }
    var medalSilver: Color { Color(red: 0.56, green: 0.56, blue: 0.58) }
    var medalBronze: Color { Color(red: 0.72, green: 0.45, blue: 0.20) }

    // MARK: - Unified Light Surface Tokens

    var appBackground: Color {
        Color(red: 0.952, green: 0.945, blue: 0.925)
    }

    var surfaceBackground: Color {
        Color(red: 0.979, green: 0.969, blue: 0.944)
    }

    var cardBackground: Color {
        Color(red: 0.965, green: 0.944, blue: 0.897)
    }

    var cameraViewportBackground: Color {
        Color(red: 0.987, green: 0.983, blue: 0.972)
    }

    var cameraViewportBorder: Color {
        Color(red: 0.83, green: 0.82, blue: 0.79)
    }
}

private struct TrashThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = TrashTheme()
}

extension EnvironmentValues {
    var trashTheme: TrashTheme {
        get { self[TrashThemeEnvironmentKey.self] }
        set { self[TrashThemeEnvironmentKey.self] = newValue }
    }
}

enum TrashTextRole {
    case display
    case title
    case headline
    case subheadline
    case body
    case caption
    case button
    case kicker
}

private struct TrashTextRoleModifier: ViewModifier {
    @Environment(\.trashTheme) private var theme
    let role: TrashTextRole
    let color: Color?
    let compact: Bool

    func body(content: Content) -> some View {
        let resolvedColor = color ?? defaultColor

        content
            .font(font)
            .foregroundColor(resolvedColor)
            .lineLimit(lineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .textCase(role == .kicker ? .uppercase : nil)
            .tracking(role == .kicker ? 0.6 : 0)
    }

    private var font: Font {
        switch role {
        case .display:
            return theme.typography.display
        case .title:
            return theme.typography.title
        case .headline:
            return theme.typography.headline
        case .subheadline:
            return theme.typography.subheadline
        case .body:
            return theme.typography.body
        case .caption:
            return theme.typography.caption
        case .button:
            return theme.typography.button
        case .kicker:
            return theme.typography.kicker
        }
    }

    private var defaultColor: Color {
        switch role {
        case .caption, .kicker:
            return theme.palette.textSecondary
        default:
            return theme.palette.textPrimary
        }
    }

    private var lineLimit: Int? {
        switch role {
        case .display:
            return 1
        case .title, .headline:
            return 2
        case .subheadline:
            return compact ? 1 : 2
        case .body:
            return compact ? 2 : nil
        case .caption:
            return compact ? 1 : 2
        case .button, .kicker:
            return 1
        }
    }

    private var minimumScaleFactor: CGFloat {
        switch role {
        case .display:
            return 0.95
        case .title, .headline:
            return 0.92
        case .subheadline, .body, .caption:
            return 0.9
        case .button, .kicker:
            return 0.88
        }
    }
}

// MARK: - Accent Foreground Modifier

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

    func trashTextRole(_ role: TrashTextRole, color: Color? = nil, compact: Bool = false) -> some View {
        modifier(TrashTextRoleModifier(role: role, color: color, compact: compact))
    }
}
