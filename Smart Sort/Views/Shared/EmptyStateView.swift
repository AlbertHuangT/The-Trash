//
//  EmptyStateView.swift
//  Smart Sort
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
                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: 112, height: 112)
                
                TrashIcon(systemName: icon)
                    .font(theme.typography.heroIcon)
                    .foregroundColor(theme.accents.blue.opacity(0.9))
            }
            Text(title)
                .trashTextRole(.headline)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.lg)
    }
}
