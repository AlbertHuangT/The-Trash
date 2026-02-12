//
//  LeaderboardComponents.swift
//  The Trash
//
//  Extracted from LeaderboardView.swift
//

import SwiftUI

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let credits: Int
    let isMe: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.lg) {
            rankViewHelper(rank: rank)
                .frame(width: 40) // Slightly wider for shadows

            VStack(alignment: .leading) {
                Text(username)
                    .font(theme.typography.subheadline)
                    .fontWeight(isMe ? .bold : .medium)
                    .foregroundColor(isMe ? theme.accents.blue : theme.palette.textPrimary)
                if isMe {
                    Text("You")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
            }

            Spacer()

            Text("\(credits)")
                .font(theme.typography.body)
                .monospacedDigit()
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
        }
        .padding(theme.spacing.lg)
        .background(Color.neuBackground)
        .cornerRadius(theme.corners.medium)
        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 8, x: -5, y: -5)
        .overlay(
            RoundedRectangle(cornerRadius: theme.corners.medium)
                .stroke(isMe ? Color.neuAccentBlue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .padding(.vertical, theme.spacing.sm) // Spacing between rows
    }

    @ViewBuilder
    func rankViewHelper(rank: Int) -> some View {
        switch rank {
        case 1: 
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
                .font(.title2)
                .shadow(color: .orange.opacity(0.5), radius: 2)
        case 2: 
            Image(systemName: "medal.fill")
                .foregroundColor(.gray)
                .font(.title2)
                .shadow(color: .black.opacity(0.2), radius: 2)
        case 3: 
            Image(systemName: "medal.fill")
                .foregroundColor(.brown)
                .font(.title2)
                .shadow(color: .black.opacity(0.2), radius: 2)
        default: 
            Text("\(rank)")
                .font(.subheadline)
                .bold()
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// MARK: - My Rank Bar

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Rank")
                    .font(theme.typography.caption)
                    .foregroundColor(.white.opacity(0.8))
                HStack {
                    Text("#\(rank)")
                        .font(theme.typography.headline)
                        .bold()
                        .foregroundColor(.white)
                    Text(username)
                        .font(theme.typography.caption)
                        .bold()
                        .foregroundColor(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Credits")
                    .font(theme.typography.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(credits)")
                    .font(theme.typography.headline)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .padding(theme.spacing.lg)
        .background(
            ZStack {
                LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                // Inner glow
                RoundedRectangle(cornerRadius: theme.corners.medium)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
        )
        .cornerRadius(theme.corners.large, corners: [.topLeft, .topRight])
        .shadow(color: .neuAccentBlue.opacity(0.4), radius: 10, y: -5)
        .padding(.horizontal, theme.spacing.lg)
    }
}
