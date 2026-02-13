//
//  AchievementsListView.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI

struct AchievementsListView: View {
    var showsNavigationTitle: Bool = true
    @StateObject private var service = AchievementService.shared
    @State private var selectedTab = 0 // 0: Official, 1: Community
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            TrashSegmentedControl(
                options: [
                    TrashSegmentOption(value: 0, title: "Official", icon: "shield.fill"),
                    TrashSegmentOption(value: 1, title: "Community", icon: "person.3.fill")
                ],
                selection: $selectedTab
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if service.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredAchievements.isEmpty {
                Spacer()
                emptyStateView
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAchievements) { achievement in
                            AchievementCard(achievement: achievement) {
                                Task {
                                    if achievement.isEquipped {
                                        await service.unequipAchievement()
                                    } else {
                                        await service.equipAchievement(achievementId: achievement.achievementId)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(theme.palette.background)
        .optionalNavigationTitle(showsNavigationTitle ? "Achievements" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            TrashIcon(systemName: selectedTab == 0 ? "trophy" : "person.3")
                .font(.system(size: 50))
                .foregroundColor(.neuSecondaryText)
            Text("No Achievements Yet")
                .font(.headline)
                .foregroundColor(.neuText)
            Text(selectedTab == 0
                 ? "Start scanning trash to earn\nyour first achievement!"
                 : "Join communities and participate\nto earn community achievements")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
                .multilineTextAlignment(.center)
        }
    }

    var filteredAchievements: [UserAchievement] {
        if selectedTab == 0 {
            return service.myAchievements.filter { $0.isOfficial }
        } else {
            return service.myAchievements.filter { !$0.isOfficial }
        }
    }
}

// MARK: - Achievement Card (Neumorphic)

struct AchievementCard: View {
    let achievement: UserAchievement
    let onToggleEquip: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // 成就图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: achievement.rarity.color.opacity(0.3), radius: 6, x: 0, y: 3)

                TrashIcon(systemName: achievement.iconName)
                    .font(.title2)
                    .trashOnAccentForeground()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.headline)
                        .foregroundColor(.neuText)

                    // 稀有度标签
                    Text(achievement.rarity.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(achievement.rarity.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(achievement.rarity.color.opacity(0.15))
                        .cornerRadius(4)
                }

                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let communityName = achievement.communityName {
                        HStack(spacing: 3) {
                            TrashIcon(systemName: "person.3.fill")
                                .font(.system(size: 8))
                            Text(communityName)
                                .font(.caption2)
                        }
                        .foregroundColor(.neuAccentBlue)
                    }

                    HStack(spacing: 3) {
                        TrashIcon(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(achievement.grantedAt, style: .date)
                            .font(.caption2)
                    }
                    .foregroundColor(.neuSecondaryText)
                }
            }

            Spacer()

            // 装备/取消装备按钮
            TrashTapArea(action: onToggleEquip) {
                if achievement.isEquipped {
                    HStack(spacing: 3) {
                        TrashIcon(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Equipped")
                            .font(.caption2.bold())
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                } else {
                    Text("Equip")
                        .font(.caption2.bold())
                        .foregroundColor(.neuAccentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.neuBackground)
                                .shadow(color: .neuDarkShadow, radius: 2, x: 1, y: 1)
                                .shadow(color: .neuLightShadow, radius: 2, x: -1, y: -1)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    achievement.isEquipped
                    ? LinearGradient(colors: achievement.rarity.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: achievement.isEquipped ? 1.5 : 0
                )
        )
    }
}
