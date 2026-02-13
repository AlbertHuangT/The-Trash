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
            ZStack {
                Color.clear
                    .trashCard(cornerRadius: theme.spacing.xl)
                    .frame(width: theme.spacing.xxl * 2, height: theme.spacing.xxl * 2)
                
                TrashIcon(systemName: icon)
                    .font(theme.typography.heroIcon)
                    .foregroundColor(theme.palette.textSecondary)
            }
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
