//
//  LeaderboardView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine
import Contacts

// MARK: - Main View

struct LeaderboardView: View {
    @StateObject private var friendService = FriendService()
    @StateObject private var currentUserVM = CurrentUserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme
    // showAccountSheet managed by ContentView via environment
    @Binding var selectedTab: Int
    @State private var selectedType: LeaderboardType = .friends
    
    // Community leaderboard state
    @State private var communityUsers: [CommunityLeaderboardUser] = []
    @State private var isCommunityLoading = false
    @State private var selectedCommunity: MyCommunityResponse? = nil
    @State private var myCommunities: [MyCommunityResponse] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 🎨 App Store Style Header
            appStoreHeader(title: "Leaderboard")
            
            // 🎨 Segmented Picker for leaderboard type
            leaderboardTypePicker
            
            ZStack(alignment: .bottom) {
                Color.neuBackground.ignoresSafeArea()
                
                // 匿名用户限制
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
                
                // 底部悬浮：显示自己的实时排名 (仅在 Friends 模式)
                if selectedType == .friends && !authVM.isAnonymous && friendService.permissionStatus == .authorized,
                   let me = currentUserVM.myProfile {
                    let myRank = calculateMyRank(friends: friendService.friends, myScore: me.credits)
                    // Offset to ensure it sits nicely
                    VStack {
                        Spacer()
                        MyRankBar(rank: myRank, username: me.username ?? "You", credits: me.credits)
                            .padding(.bottom, 0)
                    }
                }
            }
        }
        .background(Color.neuBackground)
        .task {
            await refreshData()
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 2 {
                Task { await refreshData() }
            }
        }
        .onChange(of: selectedType) { newType in
            if newType == .community {
                Task { await loadMyCommunities() }
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
    
    // MARK: - 🎨 App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)
            
            Spacer()
            
            AccountButton()
                .environmentObject(authVM)
        }
        .padding(.leading, theme.spacing.lg)
        .padding(.trailing, theme.spacing.xl)
        .padding(.vertical, theme.spacing.sm)
    }
    
    // MARK: - Leaderboard Type Picker
    
    private var leaderboardTypePicker: some View {
        Picker("Leaderboard Type", selection: $selectedType) {
            ForEach(LeaderboardType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.icon)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .background(Color.neuBackground)
        // Note: Standard segmented picker looks okay on neuBackground,
        // but could be improved with custom style later.
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
            // Community Selector
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
                    Button {
                        selectedCommunity = community
                        Task { await loadCommunityLeaderboard(communityId: community.id) }
                    } label: {
                        HStack(spacing: theme.spacing.xs) {
                            Image(systemName: "building.2.fill")
                                .font(theme.typography.caption)
                            Text(community.name)
                                .font(theme.typography.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, theme.spacing.lg)
                        .padding(.vertical, theme.spacing.sm)
                        // Neumorphic Toggle State
                        .background(
                            selectedCommunity?.id == community.id
                                ? AnyView(
                                    Capsule()
                                        .fill(Color.neuBackground)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.neuBackground, lineWidth: 2)
                                                .shadow(color: .neuDarkShadow, radius: 2, x: 2, y: 2)
                                                .clipShape(Capsule())
                                                .shadow(color: .neuLightShadow, radius: 2, x: -2, y: -2)
                                                .clipShape(Capsule())
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.neuAccentBlue.opacity(0.5), lineWidth: 1)
                                        )
                                )
                                : AnyView(
                                    Capsule()
                                        .fill(Color.neuBackground)
                                        .shadow(color: .neuDarkShadow, radius: 3, x: 2, y: 2)
                                        .shadow(color: .neuLightShadow, radius: 3, x: -2, y: -2)
                                )
                        )
                        .foregroundColor(
                            selectedCommunity?.id == community.id
                                ? .neuAccentBlue
                                : .neuSecondaryText
                        )
                        .scaleEffect(selectedCommunity?.id == community.id ? 0.97 : 1.0)
                        .animation(.spring(response: 0.3), value: selectedCommunity?.id)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.lg)
        }
        .background(Color.neuBackground)
    }
    
    private var communityListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let community = selectedCommunity {
                    // Header
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text(community.name)
                    }
                    .font(theme.typography.headline)
                    .foregroundColor(theme.palette.textSecondary)
                    .padding(.top, theme.spacing.sm)
                    
                    ForEach(Array(communityUsers.enumerated()), id: \.element.id) { index, user in
                        // Using LeaderboardRow for community users too, adapting slightly?
                        // LeaderboardRow expects username/credits/isMe/rank.
                        // CommunityLeaderboardUser has username etc.
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
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: theme.spacing.xxl * 1.2, height: theme.spacing.xxl * 1.2)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.neuSecondaryText)
            }
            Text("No Communities Joined")
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
            Text("Join a community in the Community tab to see its leaderboard!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }
    
    private var emptyCommunityLeaderboardView: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: theme.spacing.xxl * 1.2, height: theme.spacing.xxl * 1.2)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.neuSecondaryText)
            }
            Text("No Data Yet")
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
            Text("Be the first to earn points in this community!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(theme.palette.textSecondary)
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
        guard let me = currentUserVM.myProfile, let myId = SupabaseManager.shared.client.auth.currentUser?.id else {
            return friends
        }
        
        var combined = friends
        if !combined.contains(where: { $0.id == myId }) {
            let myEntry = FriendUser(id: myId, username: me.username ?? "Me", credits: me.credits, email: nil, phone: nil)
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
            
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: theme.spacing.xxl * 1.4, height: theme.spacing.xxl * 1.4)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                
                Image(systemName: "lock.shield.fill")
                    .font(theme.typography.title)
                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            Text("Access Restricted")
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)

            Text("Leaderboard is only available for registered users.\n\nPlease link your Email or Phone in your Account to access this feature.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
                .foregroundColor(theme.palette.textSecondary)
            
            Spacer()
        }
    }
    
    var permissionRequestView: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: theme.spacing.xxl * 1.2, height: theme.spacing.xxl * 1.2)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                
                Image(systemName: "lock.shield.fill")
                    .font(theme.typography.title)
                    .foregroundColor(.orange)
            }
            
            Text("See Who's Winning")
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
            
            Text("Sync your contacts to find friends playing The Trash and compete for the top spot!")
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
                .foregroundColor(theme.palette.textSecondary)
            
            Button(action: {
                Task { await friendService.requestAccessAndFetch() }
            }) {
                Text("Sync Contacts")
                    .font(theme.typography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.neuAccentBlue)
                    .cornerRadius(theme.corners.medium)
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 8, y: 4)
                    .padding(.horizontal, theme.spacing.xl * 1.2)
            }
            Spacer()
        }
    }
    
    var noFriendsState: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: theme.spacing.xxl * 1.2, height: theme.spacing.xxl * 1.2)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                
                Image(systemName: "hand.wave")
                    .font(.system(size: 60))
                    .foregroundColor(.neuSecondaryText)
            }
            
            Text("No Friends Found Yet")
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
            Text("None of your contacts are playing The Trash yet.\nInvite them to join the challenge!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(theme.palette.textSecondary)
            
            ShareLink(item: URL(string: "https://yourappurl.com")!, subject: Text("Join me on The Trash!"), message: Text("Come verify trash and earn credits with me!")) {
                Label("Invite Friends", systemImage: "square.and.arrow.up")
                    .font(theme.typography.button)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.vertical, theme.spacing.sm)
                    .background(Color.neuAccentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(theme.corners.medium)
                    .shadow(color: .neuAccentGreen.opacity(0.4), radius: 8, y: 4)
            }
        }
        .padding(.vertical, theme.spacing.xxl)
    }
    
    @ViewBuilder
    func rankView(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow).font(.title2)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray).font(.title2)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown).font(.title2)
        default: Text("\(rank)").font(.headline).foregroundColor(.neuSecondaryText)
        }
    }
}
