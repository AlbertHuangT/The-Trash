//
//  GrantAchievementToMemberView.swift
//  The Trash
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
    @Environment(\.trashTheme) private var theme

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
                .trashCard(cornerRadius: 12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // 成员列表
            if service.isLoading {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            } else if filteredMembers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    TrashIcon(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.neuSecondaryText)
                    Text("No members found")
                        .font(.subheadline)
                        .foregroundColor(.neuSecondaryText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
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
        .background(Color.neuBackground)
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
            .presentationBackground(theme.appearance.sheetBackground)
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
                    .foregroundColor(.neuText)
                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
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
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
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
                    .fill(Color.neuBackground)
                    .frame(width: 44, height: 44)
                    .shadow(color: .neuDarkShadow, radius: 3, x: 2, y: 2)
                    .shadow(color: .neuLightShadow, radius: 3, x: -2, y: -2)

                Text(String(member.username.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.neuAccentBlue)
            }

            Text(member.username)
                .font(.subheadline)
                .foregroundColor(.neuText)

            Spacer()

            if member.alreadyHas {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Granted")
                        .font(.caption.bold())
                }
                .foregroundColor(.neuAccentGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 8)
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
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                .shadow(color: .neuLightShadow, radius: 4, x: -2, y: -2)
        )
    }
}
