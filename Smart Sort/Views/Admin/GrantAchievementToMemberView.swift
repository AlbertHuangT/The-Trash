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
            // 成就信息头
            achievementHeader

            // 搜索栏
            TrashSearchField(placeholder: "Search members...", text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            .padding(.top, 12)

            // 成员列表
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
                    LazyVStack(spacing: 10) {
                        ForEach(filteredMembers) { member in
                            memberRow(member)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
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
            .presentationDetents([.fraction(0.3), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.appBackground)
        }
    }

    // MARK: - Achievement Header

    private var achievementHeader: some View {
        HStack(spacing: 16) {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Member Row

    private func memberRow(_ member: CommunityMemberForGrant) -> some View {
        HStack(spacing: 14) {
            // 头像
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
                .font(.subheadline)
                .foregroundColor(theme.palette.textPrimary)

            Spacer()

            if member.alreadyHas {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Granted")
                        .font(.caption.bold())
                }
                .foregroundColor(theme.accents.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                )
            } else {
                TrashButton(baseColor: theme.accents.blue, cornerRadius: 8, action: {
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
                            // 刷新列表
                            await service.fetchCommunityMembersForGrant(
                                communityId: communityId,
                                achievementId: achievement.id
                            )
                        }
                        grantingUserId = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        if grantingUserId == member.userId {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            TrashIcon(systemName: "plus.circle.fill")
                                .font(.caption)
                        }
                        Text("Grant")
                            .font(.caption.bold())
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .disabled(grantingUserId != nil)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }
}
