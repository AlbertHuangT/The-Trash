import SwiftUI

// MARK: - Bottom Tab Bar

struct TrashBottomTabBar<Value: Hashable>: View {
    let items: [TrashTabItem<Value>]
    @Binding var selection: Value

    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            ForEach(items) { item in
                tabItemButton(item)
            }
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.sm)
        .background {
            barBackground
        }
        .overlay {
            barBorder
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.xs)
    }

    private func tabItemButton(_ item: TrashTabItem<Value>) -> some View {
        let isSelected = item.value == selection

        return Button {
            withAnimation(selectionAnimation) {
                selection = item.value
            }
        } label: {
            VStack(spacing: 4) {
                if theme.visualStyle == .ecoPaper {
                    StampedIcon(
                        systemName: item.icon,
                        size: isSelected ? 15 : 14,
                        weight: .semibold,
                        color: tabForeground(isSelected: isSelected)
                    )
                } else {
                    TrashIcon(systemName: item.icon)
                        .font(.system(size: isSelected ? 17 : 16, weight: .semibold))
                        .foregroundColor(tabForeground(isSelected: isSelected))
                }

                Text(item.title)
                    .font(
                        .system(
                            size: 11, weight: isSelected ? .semibold : .medium, design: .rounded)
                    )
                    .foregroundColor(tabForeground(isSelected: isSelected))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.sm)
            .background {
                tabBackground(isSelected: isSelected)
            }
            .overlay {
                tabBorder(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var barBackground: some View {
        switch theme.visualStyle {
        case .neumorphic:
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .fill(theme.palette.card)
                .shadow(color: theme.shadows.dark.opacity(0.7), radius: 10, x: 6, y: 6)
                .shadow(color: theme.shadows.light.opacity(0.8), radius: 8, x: -5, y: -5)
        case .vibrantGlass:
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .fill(theme.palette.card.opacity(0.84))
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.accents.purple.opacity(0.12), theme.accents.blue.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous))
                )
        case .ecoPaper:
            ZStack {
                RoundedRectangle(cornerRadius: theme.corners.large - 2, style: .continuous)
                    .fill(theme.palette.divider.opacity(0.55))
                    .offset(y: 2)

                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                    .fill(Color(red: 0.90, green: 0.87, blue: 0.82))
                    .overlay(
                        PaperTextureView(baseColor: Color(red: 0.90, green: 0.87, blue: 0.82))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: theme.corners.large, style: .continuous)
                            )
                            .opacity(0.28)
                    )
                    .shadow(color: theme.shadows.dark.opacity(0.5), radius: 3, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private var barBorder: some View {
        switch theme.visualStyle {
        case .neumorphic:
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.35), lineWidth: 1)
        case .vibrantGlass:
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .stroke(theme.accents.purple.opacity(0.35), lineWidth: 1)
        case .ecoPaper:
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.9), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func tabBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)

        if !isSelected {
            Color.clear
        } else {
            switch theme.visualStyle {
            case .neumorphic:
                shape
                    .fill(theme.palette.background)
                    .shadow(color: theme.shadows.dark.opacity(0.65), radius: 5, x: 3, y: 3)
                    .shadow(color: theme.shadows.light.opacity(0.7), radius: 4, x: -3, y: -3)
            case .vibrantGlass:
                shape
                    .fill(theme.gradients.primary)
                    .shadow(color: theme.accents.blue.opacity(0.35), radius: 8, x: 0, y: 4)
            case .ecoPaper:
                shape
                    .fill(theme.gradients.primary)
                    .overlay(
                        PaperTextureView(baseColor: theme.accents.green)
                            .clipShape(shape)
                            .opacity(0.1)
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            .padding(1)
                    )
                    .shadow(color: theme.accents.green.opacity(0.35), radius: 6, x: 0, y: 2)
                    .shadow(color: theme.shadows.dark.opacity(0.55), radius: 2, x: 0, y: 1)
            }
        }
    }

    @ViewBuilder
    private func tabBorder(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)

        if !isSelected {
            switch theme.visualStyle {
            case .vibrantGlass:
                shape.stroke(theme.accents.blue.opacity(0.25), lineWidth: 1)
            case .ecoPaper:
                shape.stroke(theme.palette.divider.opacity(0.6), lineWidth: 1)
            case .neumorphic:
                shape.stroke(Color.clear, lineWidth: 0)
            }
        } else {
            switch theme.visualStyle {
            case .neumorphic:
                shape.stroke(theme.palette.divider.opacity(0.35), lineWidth: 1)
            case .vibrantGlass:
                shape.stroke(theme.accents.blue.opacity(0.45), lineWidth: 1)
            case .ecoPaper:
                shape.stroke(theme.palette.textPrimary.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func tabForeground(isSelected: Bool) -> Color {
        if isSelected {
            switch theme.visualStyle {
            case .neumorphic:
                return theme.accents.blue
            case .vibrantGlass, .ecoPaper:
                return theme.onAccentForeground
            }
        }
        return theme.palette.textSecondary
    }

    private var selectionAnimation: Animation {
        switch theme.visualStyle {
        case .neumorphic:
            return .spring(response: 0.25, dampingFraction: 0.85)
        case .vibrantGlass:
            return .interactiveSpring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.1)
        case .ecoPaper:
            return .easeInOut(duration: 0.18)
        }
    }
}
