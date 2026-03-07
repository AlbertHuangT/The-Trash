import SwiftUI

struct StampedIcon: View {
    let systemName: String
    var size: CGFloat = 30
    var weight: Font.Weight = .regular
    var color: Color? = nil

    private let theme = TrashTheme()

    var body: some View {
        let resolvedName = ThemeIconResolver.resolve(systemName: systemName)
        Image(systemName: resolvedName)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color ?? theme.palette.textSecondary)
    }
}
