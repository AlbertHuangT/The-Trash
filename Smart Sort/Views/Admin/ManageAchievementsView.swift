//
//  ManageAchievementsView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/8/26.
//

import SwiftUI
import Combine

struct ManageAchievementsView: View {
    let communityId: String
    @StateObject private var service = AchievementService.shared
    @State private var showingCreateSheet = false
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 0) {
            if service.isLoading && service.communityAchievements.isEmpty {
                Spacer(minLength: 0)
                ProgressView()
                Spacer(minLength: 0)
            } else if service.communityAchievements.isEmpty {
                EmptyStateView(
                    icon: "trophy.fill",
                    title: "No Achievements Yet",
                    subtitle: "Create achievements to reward your community members."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                        Text("Community Achievements")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.palette.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        ForEach(service.communityAchievements) { achievement in
                            NavigationLink(destination: GrantAchievementToMemberView(
                                achievement: achievement,
                                communityId: communityId
                            )) {
                                achievementCard(achievement)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, theme.layout.screenInset)
                    .padding(.top, theme.layout.elementSpacing)
                    .padding(.bottom, theme.spacing.xxl)
                }
            }
        }
        .trashScreenBackground()
        .navigationTitle("Manage Achievements")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TrashIconButton(icon: "plus", action: { showingCreateSheet = true })
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAchievementView(communityId: communityId, isPresented: $showingCreateSheet)
        }
        .onAppear {
            Task {
                await service.fetchCommunityAchievements(communityId: communityId)
            }
        }
    }

    // MARK: - Achievement Card

    private func achievementCard(_ achievement: Achievement) -> some View {
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
                    .frame(width: 48, height: 48)

                TrashIcon(systemName: achievement.iconName)
                    .font(.title3)
                    .trashOnAccentForeground()
            }
            .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(achievement.name)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                if let desc = achievement.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(2)
                }
                TrashPill(
                    title: achievement.rarity.displayName,
                    color: achievement.rarity.color,
                    isSelected: false
                )
            }

            Spacer()

            TrashIcon(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(theme.components.cardPadding)
        .frame(minHeight: theme.components.rowHeight)
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

private struct CreateAchievementView: View {
    let communityId: String
    @Binding var isPresented: Bool
    @StateObject private var service = AchievementService.shared
    private let theme = TrashTheme()

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedRarity: AchievementRarity = .common

    let icons = ["star.fill", "trophy.fill", "medal.fill", "rosette", "flame.fill", "bolt.fill", "leaf.fill", "drop.fill", "globe", "heart.fill", "sparkles", "crown.fill", "flag.fill", "hand.thumbsup.fill"]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Details")
                        TrashFormTextField(title: "Achievement Name", text: $name, textInputAutocapitalization: .words)
                        TrashFormTextField(title: "Description", text: $description, textInputAutocapitalization: .sentences)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Rarity")
                        TrashFormPicker(
                            title: "Rarity",
                            selection: $selectedRarity,
                            options: AchievementRarity.allCases.map {
                                TrashPickerOption(value: $0, title: $0.displayName, icon: nil)
                            }
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Icon")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: theme.layout.elementSpacing)], spacing: theme.layout.elementSpacing) {
                            ForEach(icons, id: \.self) { icon in
                                TrashTapArea(action: { selectedIcon = icon }) {
                                    TrashIcon(systemName: icon)
                                        .font(.title3)
                                        .foregroundColor(selectedIcon == icon ? selectedRarity.color : theme.palette.textPrimary)
                                        .frame(width: 48, height: 48)
                                        .background(selectedIcon == icon ? selectedRarity.color.opacity(0.18) : theme.palette.card.opacity(0.24))
                                        .clipShape(RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("New Achievement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    TrashTextButton(title: "Create", variant: .accent) {
                        Task {
                            let success = await service.createAchievement(
                                communityId: communityId,
                                name: name,
                                description: description,
                                iconName: selectedIcon,
                                rarity: selectedRarity
                            )
                            if success {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
