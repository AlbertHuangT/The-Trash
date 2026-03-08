//
//  GrantAchievementToMemberView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/10/26.
//

import SwiftUI

struct GrantAchievementToMemberView: View {
    let achievement: Achievement
    let communityId: String
    @StateObject private var service = AchievementService.shared
    @State private var searchText = ""
    @State private var grantingUserId: UUID?
    @State private var showSuccessAlert = false
    @State private var grantedUsername = ""
    private let theme = TrashTheme()

    var filteredMembers: [CommunityMemberForGrant] {
        if searchText.isEmpty {
            return service.communityMembers
        }
        return service.communityMembers.filter {
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            achievementHeader

            TrashSearchField(placeholder: "Search members...", text: $searchText)
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.elementSpacing)

            if service.isLoading {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            } else if filteredMembers.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Members Found",
                    subtitle: searchText.isEmpty
                        ? "No eligible members are available right now."
                        : "Try a different name or clear your search."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.layout.elementSpacing) {
                        ForEach(filteredMembers) { member in
                            memberRow(member)
                        }
                    }
                    .padding(.horizontal, theme.layout.screenInset)
                    .padding(.top, theme.layout.elementSpacing)
                    .padding(.bottom, theme.layout.sectionSpacing)
                }
            }
        }
        .trashScreenBackground()
        .navigationTitle("Grant Achievement")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await service.fetchCommunityMembersForGrant(
                communityId: communityId,
                achievementId: achievement.id
            )
        }
        .sheet(isPresented: $showSuccessAlert) {
            TrashNoticeSheet(
                title: "Achievement Granted!",
                message: "\(achievement.name) has been granted to \(grantedUsername).",
                onClose: { showSuccessAlert = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.appBackground)
        }
    }

    // MARK: - Achievement Header

    private var achievementHeader: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: achievement.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                TrashIcon(systemName: achievement.iconName)
                    .font(.title2)
                    .trashOnAccentForeground()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(theme.palette.textPrimary)
                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
                Text(achievement.rarity.displayName)
                    .font(.caption2.bold())
                    .foregroundColor(achievement.rarity.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(achievement.rarity.color.opacity(0.15))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.top, theme.layout.screenInset)
    }

    // MARK: - Member Row

    private func memberRow(_ member: CommunityMemberForGrant) -> some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            ZStack {
                Circle()
                    .fill(theme.surfaceBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )

                Text(String(member.username.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(theme.accents.blue)
            }

                Text(member.username)
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
                .lineLimit(1)

            Spacer()

            if member.alreadyHas {
                TrashPill(
                    title: "Granted",
                    icon: "checkmark.circle.fill",
                    color: theme.accents.green,
                    isSelected: false
                )
            } else {
                TrashPill(title: "Grant", icon: "plus.circle.fill", color: theme.accents.blue, isSelected: true, action: {
                    grantingUserId = member.userId
                    Task {
                        let success = await service.grantAchievement(
                            userId: member.userId,
                            achievementId: achievement.id,
                            communityId: communityId
                        )
                        if success {
                            grantedUsername = member.username
                            showSuccessAlert = true
                            // Refresh the list
                            await service.fetchCommunityMembersForGrant(
                                communityId: communityId,
                                achievementId: achievement.id
                            )
                        }
                        grantingUserId = nil
                    }
                })
                .disabled(grantingUserId != nil)
            }
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }
}
