//
//  ArenaView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Models
struct ArenaTask: Identifiable, Codable {
    let id: UUID
    let imageUrl: String
    let originalAiPrediction: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case originalAiPrediction = "original_ai_prediction"
    }
}

// MARK: - ViewModel
@MainActor
class ArenaViewModel: ObservableObject {
    @Published var tasks: [ArenaTask] = []
    @Published var isLoading = false
    @Published var totalCredits = 0
    @Published var showPointAnimation = false
    
    @Published var imageCache: [UUID: UIImage] = [:]
    
    private let client = SupabaseManager.shared.client
    
    func fetchUserCredits() async {
        guard let userId = client.auth.currentUser?.id else { return }
        do {
            struct ProfileCredits: Decodable {
                let credits: Int
            }
            
            let profile: ProfileCredits = try await client
                .from("profiles")
                .select("credits")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.totalCredits = profile.credits
        } catch {
            print("❌ [Arena] Failed to fetch credits: \(error)")
        }
    }
    
    func fetchTasks() async {
        isLoading = true
        do {
            let fetchedTasks: [ArenaTask] = try await client
                .rpc("get_arena_tasks")
                .execute()
                .value
            
            self.tasks = fetchedTasks
            await fetchUserCredits()
            await preloadImages()
        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
        }
        isLoading = false
    }
    
    private func preloadImages() async {
        for task in tasks {
            if imageCache[task.id] != nil { continue }
            
            if let url = URL(string: task.imageUrl),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                imageCache[task.id] = image
            }
        }
    }
    
    // Submit vote and update credits
    func submitVote(task: ArenaTask, category: String) async {
        // 保存索引和任务对象，以便回滚
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let removedTask = tasks[index]
        
        // 1. 乐观更新 (Optimistic UI): 立即移除
        withAnimation {
            tasks.remove(at: index)
        }
        
        // 本地临时加分反馈
        withAnimation {
            self.totalCredits += 25
            self.showPointAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { self.showPointAnimation = false }
        }
        
        // 2. 后端交互
        do {
            guard let userId = client.auth.currentUser?.id else {
                throw NSError(domain: "Auth", code: 401, userInfo: nil)
            }
            
            struct VoteInsert: Encodable {
                let task_id: UUID
                let user_id: UUID
                let voted_category: String
            }
            
            try await client.from("correction_votes").insert(VoteInsert(
                task_id: task.id,
                user_id: userId,
                voted_category: category
            )).execute()
            
            try await client.rpc("increment_credits", params: ["amount": 25]).execute()
            
        } catch {
            print("❌ [Arena] Vote Submission Error: \(error)")
            
            // 🔥 FIX: 失败回滚逻辑
            withAnimation {
                if index <= self.tasks.count {
                    self.tasks.insert(removedTask, at: index)
                } else {
                    self.tasks.append(removedTask)
                }
                self.totalCredits -= 25 // 回滚分数
            }
        }
    }
}

// MARK: - Main View
struct ArenaView: View {
    @StateObject private var viewModel = ArenaViewModel()
    @StateObject private var authViewModel = AuthViewModel() // 引入 AuthViewModel 检查状态
    
    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if authViewModel.isAnonymous {
                    // 🚫 匿名用户限制视图
                    AnonymousRestrictionView()
                } else {
                    // ✅ 正式用户显示 Arena 内容
                    mainArenaContent
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if !authViewModel.isAnonymous {
                    Task { await viewModel.fetchTasks() }
                }
            }
            // 监听状态变化，如果用户刚刚绑定了账号，自动刷新
            .onChange(of: authViewModel.isAnonymous) { isAnon in
                if !isAnon {
                    Task { await viewModel.fetchTasks() }
                }
            }
        }
    }
    
    // 原有的 Arena 主体内容
    var mainArenaContent: some View {
        VStack(spacing: 0) {
            // --- Header ---
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trash Arena")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                    Text("Validate trash to train the AI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(viewModel.totalCredits)")
                        .font(.title2)
                        .fontWeight(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .overlay(
                    Group {
                        if viewModel.showPointAnimation {
                            Text("+25")
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.green)
                                .offset(y: -40)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                )
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Spacer()
            
            // --- Card stack area ---
            ZStack {
                if viewModel.tasks.isEmpty {
                    if viewModel.isLoading {
                        ProgressView("Loading challenges...")
                    } else {
                        EmptyStateView(onRefresh: {
                            Task { await viewModel.fetchTasks() }
                        })
                    }
                } else {
                    ForEach(Array(viewModel.tasks.enumerated()).reversed(), id: \.element.id) { index, task in
                        ArenaCard(
                            task: task,
                            image: viewModel.imageCache[task.id],
                            categories: categories,
                            isTopCard: index == 0
                        ) { selectedCategory in
                            Task { await viewModel.submitVote(task: task, category: selectedCategory) }
                        }
                        .offset(y: CGFloat(index * 4))
                        .scaleEffect(1.0 - CGFloat(index) * 0.03)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                }
            }
            .frame(height: 520)
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Subviews

// 新增：限制匿名用户的视图
struct AnonymousRestrictionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.bottom, 10)
            
            Text("Access Restricted")
                .font(.title).bold()
            
            Text("Trash Arena is only available for registered users.\n\nPlease link your Email or Phone in the Account tab to participate and earn rewards.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct EmptyStateView: View {
    var onRefresh: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("All Caught Up!")
                .font(.title2).bold()
            Text("You've verified all pending images.\nCheck back later for more points.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: onRefresh) {
                Label("Refresh Arena", systemImage: "arrow.clockwise")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
        }
    }
}

struct ArenaCard: View {
    let task: ArenaTask
    let image: UIImage?
    let categories: [String]
    let isTopCard: Bool
    let onVote: (String) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary))
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("What is this item?")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: { if isTopCard { onVote(category) } }) {
                                Text(category)
                                    .font(.subheadline).fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.95))
                                    .foregroundColor(colorForCategory(category))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            }
            .cornerRadius(24)
        }
        .allowsHitTesting(isTopCard)
    }
    
    func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "Recyclable": return .blue
        case "Compostable": return .green
        case "Hazardous": return .red
        case "Landfill": return .gray
        default: return .primary
        }
    }
}
