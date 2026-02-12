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
    
    var body: some View {
        VStack(spacing: 0) {
            // 类型切换
            HStack(spacing: 0) {
                tabButton(title: "Official", tag: 0, icon: "shield.fill")
                tabButton(title: "Community", tag: 1, icon: "person.3.fill")
            }
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
        .background(Color.neuBackground)
        .optionalNavigationTitle(showsNavigationTitle ? "Achievements" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }
    
    // MARK: - Tab Button
    
    private func tabButton(title: String, tag: Int, icon: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.bold())
            }
            .foregroundColor(selectedTab == tag ? .white : .neuText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if selectedTab == tag {
                        LinearGradient(
                            colors: [.neuAccentBlue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.neuBackground
                    }
                }
            )
            .cornerRadius(12)
            .shadow(color: selectedTab == tag ? .neuDarkShadow : .clear, radius: 4, x: 2, y: 2)
            .shadow(color: selectedTab == tag ? .neuLightShadow : .clear, radius: 4, x: -2, y: -2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == 0 ? "trophy" : "person.3")
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
                
                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
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
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 8))
                            Text(communityName)
                                .font(.caption2)
                        }
                        .foregroundColor(.neuAccentBlue)
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(achievement.grantedAt, style: .date)
                            .font(.caption2)
                    }
                    .foregroundColor(.neuSecondaryText)
                }
            }
            
            Spacer()
            
            // 装备/取消装备按钮
            Button(action: onToggleEquip) {
                if achievement.isEquipped {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Equipped")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.white)
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
            .buttonStyle(.plain)
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
