import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let storageKey = "selectedThemeOption"

    @Published private(set) var currentTheme: TrashTheme
    @Published private(set) var currentOption: ThemeOption
    @Published private(set) var themeIdentity = UUID()

    private init() {
        let option = ThemeManager.loadSavedOption()
        self.currentOption = option
        let theme = option.makeTheme()
        self.currentTheme = theme
        theme.configureAppearance()
    }

    func apply(_ option: ThemeOption) {
        guard option != currentOption else { return }
        currentOption = option
        let theme = option.makeTheme()
        currentTheme = theme
        theme.configureAppearance()
        themeIdentity = UUID()
        UserDefaults.standard.set(option.rawValue, forKey: Self.storageKey)
    }

    private static func loadSavedOption() -> ThemeOption {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let option = ThemeOption(rawValue: raw) {
            return option
        }
        return .neumorphic
    }
}

private struct TrashThemeKey: EnvironmentKey {
    static let defaultValue: TrashTheme = ThemeManager.shared.currentTheme
}

extension EnvironmentValues {
    var trashTheme: TrashTheme {
        get { self[TrashThemeKey.self] }
        set { self[TrashThemeKey.self] = newValue }
    }
}

extension View {
    func trashTheme(_ theme: TrashTheme) -> some View {
        environment(\.trashTheme, theme)
    }
}
