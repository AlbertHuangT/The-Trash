//
//  BadgePickerView.swift
//  The Trash
//

import SwiftUI

struct BadgePickerView: View {
    var showsNavigationTitle: Bool = true
    @StateObject private var service = AchievementService.shared

    private var equippedBadge: UserAchievement? {
        service.myAchievements.first(where: { $0.isEquipped })
    }

    var body: some View {
        VStack(spacing: 0) {
            if service.isLoading {
                Spacer()
                ProgressView("Loading badges...")
                Spacer()
            } else if service.myAchievements.isEmpty {
                Spacer()
                Text("No badges yet. Earn achievements to unlock badges!")
                    .font(.subheadline)
                    .foregroundColor(.neuSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let equipped = equippedBadge {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Currently Equipped")
                                    .font(.headline)
                                    .foregroundColor(.neuText)

                                AchievementCard(achievement: equipped) {
                                    Task { await service.unequipAchievement() }
                                }
                            }
                        }

                        Text("All Badges")
                            .font(.headline)
                            .foregroundColor(.neuText)

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
        .background(Color.neuBackground.ignoresSafeArea())
        .optionalNavigationTitle(showsNavigationTitle ? "Badges" : nil)
        .onAppear {
            Task {
                await service.fetchMyAchievements()
            }
        }
    }
}
