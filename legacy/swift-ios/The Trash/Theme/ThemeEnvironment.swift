import SwiftUI

private struct ThemeOptionEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeOption = .neumorphic
}

extension EnvironmentValues {
    var themeOption: ThemeOption {
        get { self[ThemeOptionEnvironmentKey.self] }
        set { self[ThemeOptionEnvironmentKey.self] = newValue }
    }
}

extension View {
    func themeOption(_ option: ThemeOption) -> some View {
        environment(\.themeOption, option)
    }
}
