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
    let isMe: Bool
    private let theme = TrashTheme()

    var body: some View {
        ecoRow
            .padding(.vertical, theme.spacing.sm)
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
        HStack(spacing: theme.spacing.lg) {
            rankViewHelper(rank: rank)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(theme.typography.subheadline)
                    .fontWeight(isMe ? .bold : .semibold)
                    .foregroundColor(theme.palette.textPrimary.opacity(0.95))
                if isMe {
                    Text("You")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.accents.blue.opacity(0.85))
                }
            }

            Spacer()

            Text("\(credits)")
                .font(theme.typography.body)
                .monospacedDigit()
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary.opacity(0.95))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isMe ? theme.accents.blue.opacity(0.45) : theme.palette.divider, lineWidth: isMe ? 1.8 : 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - My Rank Bar

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    private let theme = TrashTheme()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Rank")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                HStack(spacing: 6) {
                    Text("#\(rank)")
                        .font(theme.typography.headline)
                        .fontWeight(.bold)
                    Text(username)
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(theme.palette.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Credits")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                Text("\(credits)")
                    .font(theme.typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, theme.spacing.lg)
    }
}
