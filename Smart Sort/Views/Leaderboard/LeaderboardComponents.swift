//
//  LeaderboardComponents.swift
//  Smart Sort
//

import SwiftUI

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let credits: Int
    let achievementIcon: String?
    let isMe: Bool
    private let theme = TrashTheme()

    var body: some View {
        ecoRow
    }

    @ViewBuilder
    func rankViewHelper(rank: Int) -> some View {
        switch rank {
        case 1:
            Image(systemName: "medal.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.medalGold)
                .shadow(color: theme.medalGold.opacity(0.4), radius: 4)
        case 2:
            Image(systemName: "medal.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.medalSilver)
        case 3:
            Image(systemName: "medal.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.medalBronze)
        default:
            Text("#\(rank)")
                .font(theme.typography.caption)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textSecondary)
        }
    }

    private var ecoRow: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            rankViewHelper(rank: rank)
                .frame(width: theme.components.minimumHitTarget)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacing.xs) {
                    Text(username)
                        .font(theme.typography.subheadline)
                        .fontWeight(isMe ? .bold : .semibold)
                        .foregroundColor(theme.palette.textPrimary.opacity(0.95))
                        .lineLimit(1)

                    if let achievementIcon {
                        badgeIcon(achievementIcon)
                    }
                }
                if isMe {
                    Text("You")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.accents.blue.opacity(0.85))
                }
            }

            Spacer()

            Text("\(credits)")
                .font(theme.typography.subheadline)
                .monospacedDigit()
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary.opacity(0.95))
        }
        .padding(.horizontal, theme.components.cardPadding)
        .padding(.vertical, theme.layout.elementSpacing)
        .frame(minHeight: theme.components.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(
                            isMe ? theme.accents.blue.opacity(0.45) : theme.palette.divider,
                            lineWidth: isMe ? 1.8 : 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - My Rank Bar

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    let achievementIcon: String?
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Rank")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                HStack(spacing: 6) {
                    Text("#\(rank)")
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                    Text(username)
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let achievementIcon {
                        badgeIcon(achievementIcon)
                    }
                }
                .foregroundColor(theme.palette.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Credits")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                Text("\(credits)")
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(theme.palette.textPrimary)
            }
        }
        .padding(.horizontal, theme.components.cardPadding)
        .padding(.vertical, theme.layout.elementSpacing)
        .frame(minHeight: theme.components.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, theme.layout.screenInset)
    }
}

private extension LeaderboardRow {
    @ViewBuilder
    func badgeIcon(_ systemName: String) -> some View {
        TrashIcon(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: theme.components.compactControlHeight, height: theme.components.compactControlHeight)
        .foregroundColor(theme.accents.orange)
        .background(theme.accents.orange.opacity(0.12))
        .clipShape(Circle())
    }
}

private extension MyRankBar {
    @ViewBuilder
    func badgeIcon(_ systemName: String) -> some View {
        TrashIcon(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: theme.components.compactControlHeight, height: theme.components.compactControlHeight)
        .foregroundColor(theme.accents.orange)
        .background(theme.accents.orange.opacity(0.12))
        .clipShape(Circle())
    }
}
