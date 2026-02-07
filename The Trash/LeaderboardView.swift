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

// MARK: - Leaderboard Type

enum LeaderboardType: String, CaseIterable {
    case friends = "Friends"
    case community = "Community"
    
    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .community: return "building.2.fill"
        }
    }
}

// MARK: - Community Leaderboard User Model

struct CommunityLeaderboardUser: Identifiable, Decodable {
    let id: UUID
    let username: String
    let credits: Int
    let communityName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username, credits
        case communityName = "community_name"
    }
}

// MARK: - Main View

struct LeaderboardView: View {
    @StateObject private var friendService = FriendService()
    @StateObject private var currentUserVM = CurrentUserViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAccountSheet = false
    @State private var selectedType: LeaderboardType = .friends
    
    // Community leaderboard state
    @State private var communityUsers: [CommunityLeaderboardUser] = []
    @State private var isCommunityLoading = false
    @State private var selectedCommunity: MyCommunityResponse? = nil
    @State private var myCommunities: [MyCommunityResponse] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 🎨 App Store 风格头部
            appStoreHeader(title: "Leaderboard")
            
            // 🎨 Segmented Picker for leaderboard type
            leaderboardTypePicker
            
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
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
                    MyRankBar(rank: myRank, username: me.username ?? "You", credits: me.credits)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            // 🚀 优化：只在首次加载时请求数据
            loadDataIfNeeded()
        }
        .onChange(of: selectedType) { newType in
            if newType == .community && myCommunities.isEmpty {
                Task { await loadMyCommunities() }
            }
        }
    }
    
    // 🚀 新增：避免重复请求的数据加载方法
    private func loadDataIfNeeded() {
        friendService.checkPermission()
        
        if !authVM.isAnonymous && friendService.permissionStatus == .authorized {
            // 只在数据为空时请求
            if friendService.friends.isEmpty || currentUserVM.myProfile == nil {
                Task {
                    await friendService.fetchContactsAndSync()
                    await currentUserVM.fetchMyScore()
                }
            }
        }
    }
    
    // MARK: - 🎨 App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
            
            Spacer()
            
            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authVM)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
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
            } else if friendService.friends.isEmpty {
                noFriendsState
            } else {
                List {
                    let allUsers = mergeCurrentUser(friends: friendService.friends)
                    
                    ForEach(Array(allUsers.enumerated()), id: \.element.id) { index, user in
                        LeaderboardRow(
                            rank: index + 1,
                            username: user.username,
                            credits: user.credits,
                            isMe: isMe(user.id)
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await friendService.fetchContactsAndSync()
                    await currentUserVM.fetchMyScore()
                }
            }
        }
        .padding(.bottom, friendService.permissionStatus == .authorized && currentUserVM.myProfile != nil ? 80 : 0)
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
            HStack(spacing: 10) {
                ForEach(myCommunities) { community in
                    Button {
                        selectedCommunity = community
                        Task { await loadCommunityLeaderboard(communityId: community.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                            Text(community.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCommunity?.id == community.id
                                ? Color.blue
                                : Color(.tertiarySystemGroupedBackground)
                        )
                        .foregroundColor(
                            selectedCommunity?.id == community.id
                                ? .white
                                : .primary
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var communityListView: some View {
        List {
            if let community = selectedCommunity {
                Section {
                    ForEach(Array(communityUsers.enumerated()), id: \.element.id) { index, user in
                        HStack {
                            rankView(rank: index + 1)
                                .frame(width: 35)
                            
                            Text(user.username)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(user.credits)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text(community.name)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if let community = selectedCommunity {
                await loadCommunityLeaderboard(communityId: community.id)
            }
        }
    }
    
    private var noCommunityView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Communities Joined")
                .font(.title2).bold()
            Text("Join a community in the Community tab to see its leaderboard!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var emptyCommunityLeaderboardView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Data Yet")
                .font(.title2).bold()
            Text("Be the first to earn points in this community!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadMyCommunities() async {
        let communities = await CommunityService.shared.getMyCommunities()
        await MainActor.run {
            myCommunities = communities
            if let first = communities.first, selectedCommunity == nil {
                selectedCommunity = first
                Task { await loadCommunityLeaderboard(communityId: first.id) }
            }
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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.bottom, 10)
            
            Text("Access Restricted")
                .font(.title).bold()
            
            Text("Leaderboard is only available for registered users.\n\nPlease link your Email or Phone in your Account to access this feature.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 70))
                .foregroundColor(.orange)
            
            Text("See Who's Winning")
                .font(.title2).bold()
            
            Text("Sync your contacts to find friends playing The Trash and compete for the top spot!")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task { await friendService.requestAccessAndFetch() }
            }) {
                Text("Sync Contacts")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
    
    var noFriendsState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.wave")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Friends Found Yet")
                .font(.title3).bold()
            Text("None of your contacts are playing The Trash yet.\nInvite them to join the challenge!")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            ShareLink(item: URL(string: "https://yourappurl.com")!, subject: Text("Join me on The Trash!"), message: Text("Come verify trash and earn credits with me!")) {
                Label("Invite Friends", systemImage: "square.and.arrow.up")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    func rankView(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow).font(.title2)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray).font(.title2)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown).font(.title2)
        default: Text("\(rank)").font(.headline).foregroundColor(.secondary)
        }
    }
}

// MARK: - Row & Bar Components

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let credits: Int
    let isMe: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            rankViewHelper(rank: rank)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(username)
                    .fontWeight(isMe ? .bold : .medium)
                    .foregroundColor(isMe ? .blue : .primary)
                if isMe {
                    Text("You")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(credits)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    func rankViewHelper(rank: Int) -> some View {
        switch rank {
        case 1: Image(systemName: "crown.fill").foregroundColor(.yellow)
        case 2: Image(systemName: "medal.fill").foregroundColor(.gray)
        case 3: Image(systemName: "medal.fill").foregroundColor(.brown)
        default: Text("\(rank)").font(.subheadline).bold().foregroundColor(.secondary)
        }
    }
}

struct MyRankBar: View {
    let rank: Int
    let username: String
    let credits: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Rank")
                    .font(.caption).foregroundColor(.white.opacity(0.8))
                HStack {
                    Text("#\(rank)").font(.title2).bold().foregroundColor(.white)
                    Text(username).font(.caption).bold().foregroundColor(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Credits").font(.caption).foregroundColor(.white.opacity(0.8))
                Text("\(credits)").font(.title2).bold().foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.blue.shadow(radius: 8))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .padding(.horizontal)
        .background(Color.blue.ignoresSafeArea(edges: .bottom))
    }
}

// 辅助 VM：获取自己的分数
@MainActor
class CurrentUserViewModel: ObservableObject {
    @Published var myProfile: UserProfile?
    
    // 🚀 优化：添加缓存
    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30
    
    struct UserProfile: Decodable {
        let username: String?
        let credits: Int
    }
    
    func fetchMyScore(forceRefresh: Bool = false) async {
        // 🚀 优化：检查缓存
        if !forceRefresh,
           myProfile != nil,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }
        
        guard let uid = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        
        do {
            let profile: UserProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select("username, credits")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            
            self.myProfile = profile
            self.lastFetchTime = Date()
        } catch {
            if !Task.isCancelled {
                print("❌ Failed to fetch my score: \(error)")
            }
        }
    }
}
