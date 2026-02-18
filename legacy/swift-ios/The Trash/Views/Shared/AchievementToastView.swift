//
//  AchievementToastView.swift
//  The Trash
//
//  成就解锁浮动通知
//

import SwiftUI

struct AchievementToastView: View {
    let result: AchievementGrantResult
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.trashTheme) private var theme

    var rarity: AchievementRarity {
        result.rarity ?? .common
    }

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: theme.spacing.md) {
                    // 成就图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: rarity.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: theme.spacing.xl * 1.1, height: theme.spacing.xl * 1.1)

                        TrashIcon(systemName: result.iconName ?? "trophy.fill")
                            .font(theme.typography.subheadline)
                            .trashOnAccentForeground()
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text("🎉 Achievement Unlocked!")
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.palette.textSecondary)

                        Text(result.name ?? "Unknown")
                            .font(theme.typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(theme.palette.textPrimary)

                        Text(rarity.displayName)
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(rarity.color)
                    }

                    Spacer()

                    TrashTapArea(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }) {
                        TrashIcon(systemName: "xmark.circle.fill")
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }
                .padding(theme.spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .fill(Color.neuBackground)
                        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
                        .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: rarity.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .padding(.horizontal, theme.spacing.xl)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            // 3秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}
