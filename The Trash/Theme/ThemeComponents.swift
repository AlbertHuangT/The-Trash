import SwiftUI

struct TrashCard<Content: View>: View {
    let cornerRadius: CGFloat?
    let content: Content
    @Environment(\.trashTheme) private var theme

    init(cornerRadius: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        theme.cardSurface(cornerRadius: cornerRadius ?? theme.corners.large, content: content)
    }
}

struct TrashButton<Content: View>: View {
    let action: () -> Void
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let content: Content

    @Environment(\.trashTheme) private var theme

    init(
        baseColor: Color? = nil,
        cornerRadius: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.baseColor = baseColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            content
        }
        .buttonStyle(
            ThemeButtonStyle(baseColor: baseColor, cornerRadius: cornerRadius, theme: theme))
    }
}

struct TrashTapArea<Content: View>: View {
    let action: () -> Void
    var haptics: Bool = false
    let content: Content

    init(haptics: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.haptics = haptics
        self.content = content()
    }

    var body: some View {
        Button(action: {
            if haptics {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            action()
        }) {
            content
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeButtonStyle: ButtonStyle {
    let baseColor: Color?
    let cornerRadius: CGFloat?
    let theme: TrashTheme

    func makeBody(configuration: Configuration) -> some View {
        theme.buttonSurface(
            isPressed: configuration.isPressed,
            cornerRadius: cornerRadius ?? theme.corners.large,
            baseColor: baseColor,
            content: configuration.label
                .font(theme.typography.button)
                .trashOnAccentForeground()
        )
    }
}

struct ThemeBackground: View {
    @Environment(\.trashTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            theme.backgroundView()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

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
                    .fill(theme.palette.divider.opacity(0.55))
                    .offset(y: 2)

                RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                    .fill(theme.palette.card)
                    .overlay(
                        PaperTextureView(baseColor: theme.palette.card)
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
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            .padding(1)
                    )
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
                    .fill(theme.palette.divider.opacity(0.5))
                    .offset(y: 2)

                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                    .fill(theme.palette.card)
                    .overlay(
                        PaperTextureView(baseColor: theme.palette.card)
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
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            .padding(1)
                    )
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

struct TrashPageHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let trailing: Trailing
    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) where Leading == EmptyView {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            leading
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                titleText
                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.sm)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            headerBackground
        }
        .overlay {
            headerBorder
        }
    }

    @ViewBuilder
    private var titleText: some View {
        switch theme.visualStyle {
        case .neumorphic:
            Text(title)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        case .vibrantGlass:
            Text(title)
                .font(theme.typography.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.palette.textPrimary, theme.accents.blue.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        case .ecoPaper:
            Text(title)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        switch theme.visualStyle {
        case .neumorphic:
            theme.palette.background
        case .vibrantGlass:
            Rectangle()
                .fill(theme.palette.card.opacity(0.72))
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.accents.blue.opacity(0.12), theme.accents.purple.opacity(0.12),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        case .ecoPaper:
            ZStack {
                Rectangle()
                    .fill(theme.palette.divider.opacity(0.35))
                    .offset(y: 2)

                Rectangle()
                    .fill(theme.palette.background)
                    .overlay(PaperTextureView(baseColor: theme.palette.background).opacity(0.24))
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private var headerBorder: some View {
        switch theme.visualStyle {
        case .neumorphic:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.palette.divider.opacity(0.35))
                .frame(maxHeight: .infinity, alignment: .bottom)
        case .vibrantGlass:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.accents.blue.opacity(0.28))
                .frame(maxHeight: .infinity, alignment: .bottom)
        case .ecoPaper:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.palette.divider.opacity(0.86))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

extension TrashPageHeader where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }) {
            EmptyView()
        }
    }
}

struct TrashIconButton: View {
    let icon: String
    var isActive: Bool = false
    var activeColor: Color? = nil
    let action: () -> Void

    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(action: action) {
            TrashIcon(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(background)
                }
                .overlay {
                    Circle().stroke(borderColor, lineWidth: borderWidth)
                }
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        isActive ? theme.onAccentForeground : theme.palette.textSecondary
    }

    private var background: Color {
        if isActive {
            return activeColor ?? theme.accents.blue
        }
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.background
        case .vibrantGlass:
            return theme.palette.card.opacity(0.82)
        case .ecoPaper:
            return theme.palette.card.opacity(0.98)
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.35)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.35)
        case .ecoPaper:
            return theme.palette.textPrimary.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        isActive ? 0 : 1
    }
}

struct TrashPill: View {
    let title: String
    let icon: String?
    var color: Color? = nil
    var isSelected: Bool = false
    let action: (() -> Void)?

    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        icon: String? = nil,
        color: Color? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    pillBody
                }
                .buttonStyle(.plain)
            } else {
                pillBody
            }
        }
    }

    private var pillBody: some View {
        HStack(spacing: 6) {
            if let icon {
                if theme.visualStyle == .ecoPaper {
                    StampedIcon(systemName: icon, size: 12, weight: .semibold, color: foreground)
                } else {
                    TrashIcon(systemName: icon)
                        .font(.caption)
                        .foregroundColor(foreground)
                }
            }
            Text(title)
                .font(theme.typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .fill(background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.corners.pill, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
        }
    }

    private var selectedColor: Color {
        color ?? theme.accents.blue
    }

    private var foreground: Color {
        isSelected ? theme.onAccentForeground : (color ?? theme.palette.textSecondary)
    }

    private var background: Color {
        if isSelected {
            return selectedColor
        }
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.background
        case .vibrantGlass:
            return theme.palette.card.opacity(0.8)
        case .ecoPaper:
            return theme.palette.card.opacity(0.98)
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.45)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.32)
        case .ecoPaper:
            return theme.palette.textPrimary.opacity(0.18)
        }
    }
}

struct TrashSearchField: View {
    let placeholder: String
    @Binding var text: String
    var showClearButton: Bool = true

    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            TrashIcon(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.palette.textSecondary)

            TextField(placeholder, text: $text)
                .foregroundColor(theme.palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if showClearButton && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    TrashIcon(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .trashInputStyle()
    }
}

struct TrashInputSurface: ViewModifier {
    @Environment(\.trashTheme) private var theme
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                background
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var radius: CGFloat { cornerRadius ?? theme.corners.medium }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch theme.visualStyle {
        case .neumorphic:
            shape
                .fill(theme.palette.background)
                .shadow(color: theme.shadows.dark.opacity(0.5), radius: 4, x: 2, y: 2)
                .shadow(color: theme.shadows.light.opacity(0.6), radius: 3, x: -2, y: -2)
        case .vibrantGlass:
            shape
                .fill(theme.palette.card.opacity(0.82))
                .overlay(
                    LinearGradient(
                        colors: [
                            theme.accents.blue.opacity(0.1), theme.accents.purple.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
        case .ecoPaper:
            shape
                .fill(theme.palette.card)
                .overlay(
                    PaperTextureView(baseColor: theme.palette.card).clipShape(shape).opacity(0.2)
                )
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .padding(1)
                )
        }
    }

    private var borderColor: Color {
        switch theme.visualStyle {
        case .neumorphic:
            return theme.palette.divider.opacity(0.35)
        case .vibrantGlass:
            return theme.accents.blue.opacity(0.32)
        case .ecoPaper:
            return theme.palette.divider.opacity(0.85)
        }
    }
}

struct TrashSectionTitle: View {
    let title: String
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Text(title)
            .font(theme.typography.caption)
            .fontWeight(.bold)
            .foregroundColor(theme.palette.textSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
}

enum TrashTextButtonVariant {
    case normal
    case destructive
    case accent
}

struct TrashTextButton: View {
    let title: String
    var role: ButtonRole? = nil
    var variant: TrashTextButtonVariant = .normal
    let action: () -> Void

    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(theme.typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(foregroundColor)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .normal:
            return theme.palette.textPrimary
        case .destructive:
            return .red
        case .accent:
            return theme.accents.blue
        }
    }
}

struct TrashFormTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(textInputAutocapitalization)
            .autocorrectionDisabled()
            .trashInputStyle()
    }
}

struct TrashFormSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .trashInputStyle()
    }
}

struct TrashIconInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            TrashIcon(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? theme.accents.blue : theme.palette.textSecondary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(theme.palette.textPrimary)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .foregroundColor(theme.palette.textPrimary)
                    .focused($isFocused)
            }
        }
        .padding(16)
        .trashInputStyle(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isFocused ? theme.accents.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct TrashFormTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 80
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .padding(2)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .foregroundColor(theme.palette.textPrimary)
            .trashInputStyle()
    }
}

struct TrashFormToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

struct TrashFormStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            Text("\(title): \(value)")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

struct TrashFormDatePicker: View {
    let title: String
    @Binding var selection: Date
    var range: PartialRangeFrom<Date> = Date()...
    @Environment(\.trashTheme) private var theme

    var body: some View {
        DatePicker(title, selection: $selection, in: range)
            .font(theme.typography.subheadline)
            .foregroundColor(theme.palette.textPrimary)
    }
}

struct TrashPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: String?

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashFormPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [TrashPickerOption<Value>]
    var style: PickerStyleKind = .menu
    @Environment(\.trashTheme) private var theme

    enum PickerStyleKind {
        case menu
        case wheel
    }

    var body: some View {
        Group {
            if style == .wheel {
                Picker(title, selection: $selection) {
                    pickerOptions
                }
                .pickerStyle(.wheel)
            } else {
                Picker(title, selection: $selection) {
                    pickerOptions
                }
                .pickerStyle(.menu)
            }
        }
        .tint(theme.accents.blue)
        .font(theme.typography.subheadline)
        .foregroundColor(theme.palette.textPrimary)
    }

    @ViewBuilder
    private var pickerOptions: some View {
        ForEach(options) { option in
            if let icon = option.icon {
                TrashLabel(option.title, icon: icon).tag(option.value)
            } else {
                Text(option.title).tag(option.value)
            }
        }
    }
}

struct TrashOptionalPickerOption<Value: Hashable>: Identifiable {
    let value: Value?
    let title: String

    var id: AnyHashable { AnyHashable(value) }
}

struct TrashOptionalFormPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value?
    let options: [TrashOptionalPickerOption<Value>]
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.menu)
        .tint(theme.accents.blue)
        .font(theme.typography.subheadline)
        .foregroundColor(theme.palette.textPrimary)
    }
}

struct TrashNoticeSheet: View {
    let title: String
    let message: String
    var buttonTitle: String = "OK"
    var buttonColor: Color? = nil
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        message: String,
        buttonTitle: String = "OK",
        buttonColor: Color? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonColor = buttonColor
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashButton(
                    baseColor: buttonColor ?? theme.accents.blue,
                    action: {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }
                ) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}

struct TrashConfirmSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color? = nil
    let onConfirm: () -> Void
    var cancelTitle: String = "Cancel"
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    init(
        title: String,
        message: String,
        confirmTitle: String,
        confirmColor: Color? = nil,
        onConfirm: @escaping () -> Void,
        cancelTitle: String = "Cancel",
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmColor = confirmColor
        self.onConfirm = onConfirm
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashButton(baseColor: confirmColor ?? theme.accents.blue, action: onConfirm) {
                    Text(confirmTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                TrashTextButton(title: cancelTitle) {
                    if let onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}

struct TrashTextInputSheet: View {
    let title: String
    let message: String
    let placeholder: String
    @Binding var text: String
    var confirmTitle: String = "Save"
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashFormTextField(
                    title: placeholder,
                    text: $text,
                    textInputAutocapitalization: .words
                )

                HStack(spacing: 10) {
                    TrashTextButton(title: "Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    TrashButton(
                        baseColor: theme.accents.blue,
                        action: {
                            onConfirm(text)
                        }
                    ) {
                        Text(confirmTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(22)
            .trashCard(cornerRadius: 20)
            .padding(.horizontal, 20)
        }
    }
}

extension View {
    func trashCard(cornerRadius: CGFloat? = nil) -> some View {
        TrashCard(cornerRadius: cornerRadius) { self }
    }

    func trashInputStyle(cornerRadius: CGFloat? = nil) -> some View {
        modifier(TrashInputSurface(cornerRadius: cornerRadius))
    }
}
