//
//  LeaderboardView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/5/26.
//

import Combine
import Contacts
import Supabase
import SwiftUI

// MARK: - Main View

struct LeaderboardView: View {
    @StateObject private var friendService = FriendService()
    @StateObject private var currentUserVM = CurrentUserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    private let theme = TrashTheme()
    @State private var selectedType: LeaderboardType = .friends

    // Community leaderboard state
    @State private var communityUsers: [CommunityLeaderboardUser] = []
    @State private var isCommunityLoading = false
    @State private var selectedCommunity: MyCommunityResponse? = nil
    @State private var myCommunities: [MyCommunityResponse] = []

    var body: some View {
        VStack(spacing: 0) {
            leaderboardTypePicker

            ZStack(alignment: .bottom) {
                if authVM.isAnonymous {
                    anonymousRestrictionView
                } else {
                    switch selectedType {
                    case .friends:
                        friendsLeaderboardContent
                    case .community:
                        communityLeaderboardContent
                    }
                }

                if selectedType == .friends && !authVM.isAnonymous
                    && friendService.permissionStatus == .authorized,
                    let me = currentUserVM.myProfile
                {
                    let myRank = calculateMyRank(
                        friends: friendService.friends, myScore: me.credits ?? 0)
                    VStack {
                        Spacer()
                        MyRankBar(
                            rank: myRank, username: me.username ?? "You", credits: me.credits ?? 0
                        )
                        .padding(.bottom, 0)
                    }
                }
            }
        }
        .trashScreenBackground()
        .task {
            await refreshData()
        }
        .onChange(of: selectedType) { newType in
            if newType == .community {
                Task { await loadMyCommunities() }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
    }

    private func refreshData() async {
        friendService.checkPermission()
        guard !authVM.isAnonymous, friendService.permissionStatus == .authorized else { return }

        async let friendsTask: Void = friendService.fetchContactsAndSync(forceRefresh: true)
        async let scoreTask: Void = currentUserVM.fetchMyScore(forceRefresh: true)
        _ = await (friendsTask, scoreTask)
    }

    private var leaderboardTypePicker: some View {
        TrashSegmentedControl(
            options: LeaderboardType.allCases.map {
                TrashSegmentOption(
                    value: $0,
                    title: $0.rawValue,
                    icon: $0.icon
                )
            },
            selection: $selectedType
        )
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
    }

    // MARK: - Friends Leaderboard Content

    @ViewBuilder
    private var friendsLeaderboardContent: some View {
        VStack(spacing: 0) {
            if friendService.permissionStatus != .authorized {
                permissionRequestView
            } else if friendService.isLoading {
                Spacer()
                ProgressView("Finding your friends...")
                Spacer()
            } else {
                ScrollView {
                    if friendService.friends.isEmpty {
                        noFriendsState
                            .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 16) {
                            let allUsers = mergeCurrentUser(friends: friendService.friends)

                            ForEach(Array(allUsers.enumerated()), id: \.element.id) { index, user in
                                LeaderboardRow(
                                    rank: index + 1,
                                    username: user.username,
                                    credits: user.credits,
                                    isMe: isMe(user.id)
                                )
                                .padding(.horizontal, 16)
                            }

                            Color.clear.frame(height: 100)
                        }
                        .padding(.top, 16)
                    }
                }
                .refreshable {
                    await friendService.fetchContactsAndSync(forceRefresh: true)
                    await currentUserVM.fetchMyScore(forceRefresh: true)
                }
            }
        }
    }

    // MARK: - Community Leaderboard Content

    @ViewBuilder
    private var communityLeaderboardContent: some View {
        VStack(spacing: 0) {
            if !myCommunities.isEmpty {
                communitySelector
            }

            if isCommunityLoading {
                Spacer()
                ProgressView("Loading leaderboard...")
                Spacer()
            } else if myCommunities.isEmpty {
                noCommunityView
            } else if communityUsers.isEmpty {
                emptyCommunityLeaderboardView
            } else {
                communityListView
            }
        }
    }

    private var communitySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(myCommunities) { community in
                    TrashPill(
                        title: community.name,
                        icon: "building.2.fill",
                        color: theme.accents.blue,
                        isSelected: selectedCommunity?.id == community.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedCommunity = community
                        }
                        Task { await loadCommunityLeaderboard(communityId: community.id) }
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.lg)
        }
    }

    private var communityListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let community = selectedCommunity {
                    // Header
                    HStack {
                        TrashIcon(systemName: "building.2.fill")
                        Text(community.name)
                    }
                    .font(theme.typography.headline)
                    .foregroundColor(theme.palette.textSecondary)
                    .padding(.top, theme.spacing.sm)

                    ForEach(Array(communityUsers.enumerated()), id: \.element.id) { index, user in
                        LeaderboardRow(
                            rank: index + 1,
                            username: user.username,
                            credits: user.credits,
                            isMe: isMe(user.id)
                        )
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 50)
                }
            }
            .padding(.top, 10)
        }
        .refreshable {
            if let community = selectedCommunity {
                await loadCommunityLeaderboard(communityId: community.id)
            }
        }
    }

    private var noCommunityView: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            EmptyStateView(
                icon: "building.2.crop.circle",
                title: "No Communities Joined",
                subtitle: "Join a community in the Community tab to see its leaderboard."
            )
            Spacer()
        }
    }

    private var emptyCommunityLeaderboardView: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: "No Data Yet",
                subtitle: "Be the first to earn points in this community."
            )
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadMyCommunities() async {
        do {
            let communities = try await CommunityService.shared.getMyCommunities()
            myCommunities = communities
            if selectedCommunity == nil, let first = communities.first {
                selectedCommunity = first
            }
            if let community = selectedCommunity {
                await loadCommunityLeaderboard(communityId: community.id)
            }
        } catch {
            print("❌ Failed to load communities: \(error)")
        }
    }

    private func loadCommunityLeaderboard(communityId: String) async {
        await MainActor.run { isCommunityLoading = true }

        do {
            let users: [CommunityLeaderboardUser] = try await SupabaseManager.shared.client
                .rpc("get_community_leaderboard", params: ["p_community_id": communityId])
                .execute()
                .value

            await MainActor.run {
                communityUsers = users
                isCommunityLoading = false
            }
        } catch {
            print("❌ Failed to load community leaderboard: \(error)")
            await MainActor.run {
                communityUsers = []
                isCommunityLoading = false
            }
        }
    }

    // MARK: - Logic Helpers

    func isMe(_ id: UUID) -> Bool {
        return SupabaseManager.shared.client.auth.currentUser?.id == id
    }

    func mergeCurrentUser(friends: [FriendUser]) -> [FriendUser] {
        guard let me = currentUserVM.myProfile,
            let myId = SupabaseManager.shared.client.auth.currentUser?.id
        else {
            // 即使没有 myProfile，也要按积分排序
            return friends.sorted { $0.credits > $1.credits }
        }

        var combined = friends
        if let existingIndex = combined.firstIndex(where: { $0.id == myId }) {
            // 当前用户已经在列表中，更新为最新的 credits
            combined[existingIndex] = FriendUser(
                id: myId, username: me.username ?? "Me", credits: me.credits ?? 0,
                email: combined[existingIndex].email, phone: combined[existingIndex].phone
            )
        } else {
            let myEntry = FriendUser(
                id: myId, username: me.username ?? "Me", credits: me.credits ?? 0, email: nil, phone: nil
            )
            combined.append(myEntry)
        }

        return combined.sorted { $0.credits > $1.credits }
    }

    func calculateMyRank(friends: [FriendUser], myScore: Int) -> Int {
        let betterPlayers = friends.filter { $0.credits > myScore && !isMe($0.id) }
        return betterPlayers.count + 1
    }

    // MARK: - Subviews

    var anonymousRestrictionView: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()
            EmptyStateView(
                icon: "lock.shield.fill",
                title: "Access Restricted",
                subtitle: "Leaderboard is only available for registered users. Link your email or phone in Account to unlock it."
            )
            Spacer()
        }
    }

    var permissionRequestView: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()
            EmptyStateView(
                icon: "person.crop.circle.badge.checkmark",
                title: "See Who's Winning",
                subtitle: "Sync your contacts to find friends playing Smart Sort and compete for the top spot."
            )

            TrashButton(
                baseColor: theme.accents.blue,
                action: {
                    Task { await friendService.requestAccessAndFetch() }
                }
            ) {
                Text("Sync Contacts")
                    .font(theme.typography.button)
                    .trashOnAccentForeground()
                    .padding(.horizontal, theme.spacing.xl)
            }
            .padding(.horizontal, theme.spacing.xl * 1.5)

            Spacer()
        }
    }

    var noFriendsState: some View {
        VStack(spacing: theme.spacing.lg) {
            EmptyStateView(
                icon: "hand.wave",
                title: "No Friends Found Yet",
                subtitle: "None of your contacts are playing Smart Sort yet. Invite them to join the challenge."
            )

            if let shareURL = URL(string: "https://apps.apple.com/app/smart-sort") {
                ShareLink(
                    item: shareURL,
                    subject: Text("Join me on Smart Sort!"),
                    message: Text("Come verify trash and earn credits with me!")
                ) {
                    TrashLabel("Invite Friends", icon: "square.and.arrow.up")
                        .font(theme.typography.button)
                        .padding(.horizontal, theme.spacing.xl)
                        .padding(.vertical, theme.spacing.sm)
                        .background(theme.accents.green)
                        .trashOnAccentForeground()
                        .cornerRadius(theme.corners.medium)
                        .shadow(color: theme.accents.green.opacity(0.2), radius: 8, y: 4)
                }
            }
        }
        .padding(.vertical, theme.spacing.xxl)
    }
}
