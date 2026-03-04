import SwiftUI

// MARK: - Page Header

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
