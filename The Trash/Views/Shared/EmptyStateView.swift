//
//  EmptyStateView.swift
//  The Trash
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: icon)
                .font(theme.typography.heroIcon)
                .foregroundColor(theme.palette.textSecondary)
            Text(title)
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)
            Text(subtitle)
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.lg)
    }
}
