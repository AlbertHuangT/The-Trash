//
//  AccountComponents.swift
//  The Trash
//

import SwiftUI

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Color.clear
                    .frame(width: 44, height: 44)
                    .trashCard(cornerRadius: 12)

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
        .trashCard(cornerRadius: 18)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    let action: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TrashTapArea(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Color.clear
                        .frame(width: 36, height: 36)
                        .trashCard(cornerRadius: 10)

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
            .trashCard(cornerRadius: 14)
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
    @Environment(\.trashTheme) private var theme

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
        .trashCard(cornerRadius: 18)
    }
}
