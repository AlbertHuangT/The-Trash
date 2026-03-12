import SwiftUI

struct TrashLabel<Title: View>: View {
    let icon: String
    let spacing: CGFloat
    let iconSize: CGFloat?
    let iconColor: Color?
    @ViewBuilder let title: () -> Title

    init(
        icon: String, spacing: CGFloat = 8, iconSize: CGFloat? = nil, iconColor: Color? = nil,
        @ViewBuilder title: @escaping () -> Title
    ) {
        self.icon = icon
        self.spacing = spacing
        self.iconSize = iconSize
        self.iconColor = iconColor
        self.title = title
    }

    var body: some View {
        HStack(spacing: spacing) {
            iconView
            title()
        }
    }

    @ViewBuilder
    private var iconView: some View {
        StampedIcon(systemName: icon, size: iconSize ?? 12, weight: .semibold, color: iconColor)
    }
}

extension TrashLabel where Title == Text {
    init(
        _ title: String, icon: String, spacing: CGFloat = 8, iconSize: CGFloat? = nil,
        iconColor: Color? = nil
    ) {
        self.init(icon: icon, spacing: spacing, iconSize: iconSize, iconColor: iconColor) {
            Text(title)
        }
    }

    init(
        _ title: LocalizedStringKey, icon: String, spacing: CGFloat = 8, iconSize: CGFloat? = nil,
        iconColor: Color? = nil
    ) {
        self.init(icon: icon, spacing: spacing, iconSize: iconSize, iconColor: iconColor) {
            Text(title)
        }
    }
}
