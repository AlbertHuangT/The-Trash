//
//  LeaderboardComponents.swift
//  The Trash
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
        Group {
            if theme.visualStyle == .ecoPaper {
                ecoRow
            } else {
                standardRow
            }
        }
        .padding(.vertical, theme.spacing.sm)
    }

    @ViewBuilder
    func rankViewHelper(rank: Int) -> some View {
        if theme.visualStyle == .ecoPaper {
            switch rank {
            case 1:
                WaxSealBadge()
            case 2:
                StampedIcon(
                    systemName: "rosette", size: 24, weight: .bold,
                    color: theme.palette.textSecondary)
            case 3:
                StampedIcon(
                    systemName: "seal", size: 24, weight: .bold, color: theme.palette.textSecondary)
            default:
                Text("#\(rank)")
                    .font(theme.typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textSecondary)
            }
        } else {
            switch rank {
            case 1:
                TrashIcon(systemName: "crown.fill")
                    .foregroundColor(theme.semanticHighlight)
                    .font(.title2)
                    .shadow(color: theme.semanticWarning.opacity(0.5), radius: 2)
            case 2:
                TrashIcon(systemName: "medal.fill")
                    .foregroundColor(theme.palette.textSecondary)
                    .font(.title2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
            case 3:
                TrashIcon(systemName: "medal.fill")
                    .foregroundColor(theme.semanticWarning.opacity(0.82))
                    .font(.title2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
            default:
                Text("\(rank)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
    }

    private var standardRow: some View {
        HStack(spacing: theme.spacing.lg) {
            rankViewHelper(rank: rank)
                .frame(width: 40)

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
        .trashCard(cornerRadius: theme.corners.medium)
        .overlay(
            RoundedRectangle(cornerRadius: theme.corners.medium)
                .stroke(isMe ? theme.accents.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
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
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.palette.divider.opacity(0.56))
                    .offset(y: 2)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.palette.card)
                    .overlay(
                        PaperTextureView(baseColor: theme.palette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .opacity(0.36)
                    )
                    .overlay(
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundColor(theme.palette.divider.opacity(0.75))
                            .padding(.vertical, 7)
                    )
            }
        }
        .clipShape(TornPaperStripShape(seed: Double(rank) * 1.37))
        .overlay {
            TornPaperStripShape(seed: Double(rank) * 1.37)
                .stroke(
                    isMe ? theme.accents.blue.opacity(0.45) : theme.palette.divider.opacity(0.85),
                    lineWidth: isMe ? 1.8 : 1)
        }
        .shadow(color: theme.shadows.dark.opacity(0.45), radius: 6, x: 0, y: 3)
    }
}

// MARK: - My Rank Bar

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    @Environment(\.trashTheme) private var theme

    var body: some View {
        Group {
            if theme.visualStyle == .ecoPaper {
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
                .background {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.palette.divider.opacity(0.56))
                            .offset(y: 3)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.palette.card)
                            .overlay(
                                PaperTextureView(baseColor: theme.palette.card)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .opacity(0.4)
                            )
                            .overlay(
                                TornPaperStripShape(seed: 88)
                                    .stroke(theme.palette.divider.opacity(0.82), lineWidth: 1)
                            )

                        Circle()
                            .fill(theme.palette.divider.opacity(0.8))
                            .frame(width: 13, height: 13)
                            .padding(.top, 8)
                            .padding(.leading, 10)
                    }
                }
                .clipShape(TornPaperStripShape(seed: 88))
                .shadow(color: theme.shadows.dark.opacity(0.45), radius: 7, x: 0, y: 4)
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Your Rank")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.onAccentForeground.opacity(0.82))
                        HStack {
                            Text("#\(rank)")
                                .font(theme.typography.headline)
                                .bold()
                                .trashOnAccentForeground()
                            Text(username)
                                .font(theme.typography.caption)
                                .bold()
                                .trashOnAccentForeground()
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Credits")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.onAccentForeground.opacity(0.82))
                        Text("\(credits)")
                            .font(theme.typography.headline)
                            .bold()
                            .trashOnAccentForeground()
                    }
                }
                .padding(theme.spacing.lg)
                .background(
                    ZStack {
                        if theme.visualStyle == .ecoPaper {
                            theme.cardSurface(
                                cornerRadius: theme.corners.large, content: Color.clear
                            )
                            .brightness(-0.1)
                        } else {
                            LinearGradient(
                                colors: [theme.accents.blue, .cyan], startPoint: .leading,
                                endPoint: .trailing)
                        }
                    }
                )
                .cornerRadius(theme.corners.large, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: -5)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
    }
}

private struct WaxSealBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.86, green: 0.23, blue: 0.20),
                            Color(red: 0.60, green: 0.09, blue: 0.10),
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 22
                    )
                )
                .frame(width: 32, height: 32)
                .shadow(color: Color.black.opacity(0.26), radius: 3, x: 0, y: 2)

            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                .frame(width: 26, height: 26)

            Text("1st")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 0.98, green: 0.93, blue: 0.86))
        }
    }
}

private struct TornPaperStripShape: Shape {
    let seed: Double

    func path(in rect: CGRect) -> Path {
        let topBase = rect.minY + 1.8
        let bottomBase = rect.maxY - 1.8
        let step: CGFloat = 11

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: topBase + edgeOffset(x: 0, phase: seed)))

        var x: CGFloat = 0
        while x <= rect.width {
            let y = topBase + edgeOffset(x: x, phase: seed)
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x += step
        }

        path.addLine(
            to: CGPoint(x: rect.maxX, y: bottomBase - edgeOffset(x: rect.width, phase: seed + 99)))

        x = rect.width
        while x >= 0 {
            let y = bottomBase - edgeOffset(x: x, phase: seed + 99)
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x -= step
        }

        path.closeSubpath()
        return path
    }

    private func edgeOffset(x: CGFloat, phase: Double) -> CGFloat {
        let a = sin(Double(x) / 18.0 + phase) * 1.05
        let b = cos(Double(x) / 10.0 + phase * 0.7) * 0.7
        return CGFloat(abs(a + b))
    }
}
