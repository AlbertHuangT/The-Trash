//
//  AccountComponents.swift
//  Smart Sort
//

import SwiftUI

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                        .frame(width: 44, height: 44)

                TrashIcon(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(spacing: 2) {
                Text(value)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .surfaceCard(cornerRadius: 18)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    let action: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        TrashTapArea(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    TrashIcon(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.accents.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.textPrimary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }

                Spacer()

                if showChevron {
                    TrashIcon(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.palette.textSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .surfaceCard(cornerRadius: 14)
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        TrashSectionTitle(title: title)
            .padding(.leading, 8)
            .padding(.top, 4)
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let content: String
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: 12) {
            TrashIcon(systemName: "info.circle.fill")
                .foregroundColor(theme.accents.blue)
            Text(content)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 18)
    }
}
