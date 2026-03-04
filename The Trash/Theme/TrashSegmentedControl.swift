import SwiftUI

// MARK: - Segmented Control

struct TrashSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String?

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashTabItem<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashSegmentedControl<Value: Hashable>: View {
    let options: [TrashSegmentOption<Value>]
    @Binding var selection: Value

    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(options) { option in
                let isSelected = option.value == selection

                Button {
                    withAnimation(selectionAnimation) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        if let icon = option.icon {
                            if theme.visualStyle == .ecoPaper {
                                StampedIcon(
                                    systemName: icon, size: 13, weight: .semibold,
                                    color: segmentTextColor(isSelected: isSelected))
                            } else {
                                TrashIcon(systemName: icon)
                                    .font(theme.typography.caption)
                                    .foregroundColor(segmentTextColor(isSelected: isSelected))
                            }
                        }

                        Text(option.title)
                            .font(theme.typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(segmentTextColor(isSelected: isSelected))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.sm)
                    .padding(.horizontal, theme.spacing.sm)
                    .background {
                        segmentBackground(isSelected: isSelected)
                    }
                    .overlay {
                        segmentBorder(isSelected: isSelected)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacing.xs)
        .background {
            containerBackground()
        }
        .overlay {
            containerBorder()
        }
    }

    @ViewBuilder
    private func containerBackground() -> some View {
        switch theme.visualStyle {
        case .neumorphic:
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .fill(theme.palette.background)
                .shadow(color: theme.shadows.dark.opacity(0.8), radius: 6, x: 4, y: 4)
                .shadow(color: theme.shadows.light.opacity(0.8), radius: 6, x: -3, y: -3)
        case .vibrantGlass:
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .fill(theme.palette.card.opacity(0.86))
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.accents.blue.opacity(0.14), theme.accents.purple.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous))
                )
        case .ecoPaper:
            ZStack {
                RoundedRectangle(cornerRadius: theme.corners.pill - 2, style: .continuous)
                    .fill(theme.palette.divider.opacity(0.60))
                    .offset(y: 2)

                RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                    .fill(Color(red: 0.90, green: 0.87, blue: 0.82))
                    .overlay(
                        PaperTextureView(baseColor: Color(red: 0.90, green: 0.87, blue: 0.82))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: theme.corners.pill, style: .continuous)
                            )
                            .opacity(0.34)
                    )
                    .shadow(color: theme.shadows.dark.opacity(0.55), radius: 2, x: 0, y: 1)
            }
        }
    }

    @ViewBuilder
    private func containerBorder() -> some View {
        switch theme.visualStyle {
        case .neumorphic:
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.45), lineWidth: 1)
        case .vibrantGlass:
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .stroke(theme.accents.blue.opacity(0.35), lineWidth: 1)
        case .ecoPaper:
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.88), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func segmentBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)

        if !isSelected {
            Color.clear
        } else {
            switch theme.visualStyle {
            case .neumorphic:
                shape
                    .fill(theme.palette.background)
                    .shadow(color: theme.shadows.dark.opacity(0.85), radius: 4, x: 3, y: 3)
                    .shadow(color: theme.shadows.light.opacity(0.8), radius: 4, x: -2, y: -2)
            case .vibrantGlass:
                shape
                    .fill(theme.gradients.primary)
                    .shadow(color: theme.accents.blue.opacity(0.45), radius: 8, x: 0, y: 4)
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
                    .shadow(color: theme.shadows.dark.opacity(0.65), radius: 3, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private func segmentBorder(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)

        if !isSelected {
            switch theme.visualStyle {
            case .vibrantGlass:
                shape.stroke(theme.accents.blue.opacity(0.2), lineWidth: 1)
            case .ecoPaper:
                shape.stroke(theme.palette.divider.opacity(0.7), lineWidth: 1)
            case .neumorphic:
                shape.stroke(Color.clear, lineWidth: 0)
            }
        } else {
            switch theme.visualStyle {
            case .vibrantGlass:
                shape.stroke(theme.accents.blue.opacity(0.45), lineWidth: 1)
            case .ecoPaper:
                shape.stroke(theme.palette.textPrimary.opacity(0.2), lineWidth: 1)
            case .neumorphic:
                shape.stroke(theme.palette.divider.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private func segmentTextColor(isSelected: Bool) -> Color {
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
            return .spring(response: 0.25, dampingFraction: 0.8)
        case .vibrantGlass:
            return .interactiveSpring(response: 0.45, dampingFraction: 0.72, blendDuration: 0.1)
        case .ecoPaper:
            return .easeInOut(duration: 0.18)
        }
    }
}
