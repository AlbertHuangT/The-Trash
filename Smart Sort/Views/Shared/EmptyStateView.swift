//
//  EmptyStateView.swift
//  Smart Sort
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.spacing.xl, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.spacing.xl, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: theme.spacing.xxl * 2, height: theme.spacing.xxl * 2)
                
                TrashIcon(systemName: icon)
                    .font(theme.typography.heroIcon)
                    .foregroundColor(theme.accents.blue.opacity(0.9))
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
