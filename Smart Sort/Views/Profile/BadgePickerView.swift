//
//  BadgePickerView.swift
//  Smart Sort
//

import SwiftUI

struct BadgePickerView: View {
    var showsNavigationTitle: Bool = true
    @StateObject private var service = AchievementService.shared
    private let theme = TrashTheme()

    private var equippedBadge: UserAchievement? {
        service.myAchievements.first(where: { $0.isEquipped })
    }

    var body: some View {
        VStack(spacing: 16) {
            if service.isLoading {
                Spacer(minLength: 0)
                ProgressView("Loading badges...")
                Spacer(minLength: 0)
            } else if service.myAchievements.isEmpty {
                EmptyStateView(
                    icon: "shield.fill",
                    title: "No Badges Yet",
                    subtitle: "Earn achievements to unlock badges."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let equipped = equippedBadge {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader("Currently Equipped")

                                AchievementCard(achievement: equipped) {
                                    Task { await service.unequipAchievement() }
                                }
                            }
                        }

                        sectionHeader("All Badges")

                        LazyVStack(spacing: 12) {
                            ForEach(service.myAchievements) { achievement in
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .optionalNavigationTitle(showsNavigationTitle ? "Badges" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(theme.palette.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
