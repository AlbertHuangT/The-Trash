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
struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let imageUrl: String
    let correctCategory: String
    let itemName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case correctCategory = "correct_category"
        case itemName = "item_name"
    }
}

// MARK: - ViewModel
@MainActor
class ArenaViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var totalCredits = 0
    @Published var imageCache: [UUID: UIImage] = [:]
    
    // Quiz Session State
    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false
    
    // Animation States
    @Published var showPointAnimation = false
    @Published var pointAnimationText = ""
    @Published var showComboAnimation = false
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboBreak = false
    
    // 🔒 防止重复提交
    @Published var isSubmitting = false
    
    // ⚠️ 错误提示
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let client = SupabaseManager.shared.client
    
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }
    
    /// 检查图片是否已预加载完成
    var isCurrentImageReady: Bool {
        guard let question = currentQuestion else { return false }
        return imageCache[question.id] != nil
    }
    
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
    
    func fetchQuestions() async {
        isLoading = true
        errorMessage = ""
        showError = false
        resetSession()
        
        do {
            let fetchedQuestions: [QuizQuestion] = try await client
                .rpc("get_quiz_questions")
                .execute()
                .value
            
            self.questions = fetchedQuestions
            await fetchUserCredits()
            await preloadImages()
            
        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
            // 🔥 向用户显示错误
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
    
    private func preloadImages() async {
        // 🚀 优化：优先加载前3张图片
        let priorityQuestions = Array(questions.prefix(3))
        for question in priorityQuestions {
            await loadImage(for: question)
        }
        
        // 📦 后台并行加载其余图片（限制并发数）
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            let maxConcurrent = 3 // 限制并发数
            
            for question in questions.dropFirst(3) {
                if imageCache[question.id] != nil { continue }
                
                if activeCount >= maxConcurrent {
                    await group.next()
                    activeCount -= 1
                }
                
                activeCount += 1
                group.addTask { [weak self] in
                    await self?.loadImage(for: question)
                }
            }
        }
    }
    
    private func loadImage(for question: QuizQuestion) async {
        guard imageCache[question.id] == nil else { return }
        
        do {
            guard let url = URL(string: question.imageUrl) else { return }
            
            // 🚀 优化：使用缓存策略
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // 🚀 优化：在后台线程解码图片
            let decodedImage = await Task.detached(priority: .userInitiated) {
                return UIImage(data: data)?.preparingForDisplay()
            }.value
            
            if let image = decodedImage {
                await MainActor.run {
                    imageCache[question.id] = image
                }
            }
        } catch {
            print("⚠️ [Arena] Failed to load image for \(question.id): \(error.localizedDescription)")
        }
    }
    
    private func resetSession() {
        currentQuestionIndex = 0
        sessionScore = 0
        comboCount = 0
        maxCombo = 0
        correctCount = 0
        sessionCompleted = false
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboBreak = false
        imageCache.removeAll() // 清理图片缓存，防止内存泄漏
    }
    
    // Submit answer and check correctness locally
    func submitAnswer(selectedCategory: String) async {
        // 🔒 防止重复提交
        guard !isSubmitting else { return }
        guard let question = currentQuestion else { return }
        
        isSubmitting = true
        // 🔥 使用 defer 确保 isSubmitting 在任何情况下都会被重置
        defer { isSubmitting = false }
        
        let isCorrect = selectedCategory == question.correctCategory
        
        if isCorrect {
            // ✅ Correct answer
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)
            
            // Calculate points: base 20 + combo bonus (combo >= 3: +5 per extra combo)
            var pointsEarned = 20
            if comboCount >= 3 {
                let comboBonus = (comboCount - 2) * 5
                pointsEarned += comboBonus
            }
            
            sessionScore += pointsEarned
            
            // 🎯 乐观更新：先加分，失败再回滚
            totalCredits += pointsEarned
            
            // Show feedback
            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                pointAnimationText = "+\(pointsEarned)"
                showPointAnimation = true
                
                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }
            
            // Update credits on server
            do {
                try await client.rpc("increment_credits", params: ["amount": pointsEarned]).execute()
            } catch {
                // ⚠️ 失败时回滚本地状态
                totalCredits -= pointsEarned
                sessionScore -= pointsEarned
                correctCount -= 1
                // 🔥 FIX: 只回滚 comboCount，不回滚 maxCombo（因为maxCombo记录的是最高连击）
                comboCount -= 1
                print("❌ [Arena] Credit update failed: \(error)")
            }
            
        } else {
            // ❌ Wrong answer - no points, break combo
            let hadCombo = comboCount >= 3
            comboCount = 0
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
                if hadCombo {
                    showComboBreak = true
                }
            }
        }
        
        // Wait for feedback animation
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        // Reset feedback states
        withAnimation(.easeOut(duration: 0.2)) {
            showCorrectFeedback = false
            showWrongFeedback = false
            showPointAnimation = false
            showComboAnimation = false
            showComboBreak = false
        }
        
        // Move to next question or complete session
        if currentQuestionIndex + 1 >= questions.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        }
    }
    
    func startNewSession() async {
        await fetchQuestions()
    }
}

// MARK: - Main View
struct ArenaView: View {
    @StateObject private var viewModel = ArenaViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var pulseAnimation = false
    @State private var showAccountSheet = false
    
    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]
    
    var body: some View {
        ZStack {
            // 🎨 渐变背景
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.orange.opacity(0.05),
                    Color.red.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 🎨 App Store 风格头部
                appStoreHeader(title: "Arena")
                
                if authViewModel.isAnonymous {
                    EnhancedAnonymousRestrictionView()
                } else {
                    mainArenaContent
                }
            }
        }
        .task {
            pulseAnimation = true
            // 🚀 优化：只在数据为空且未完成 session 时请求
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty && !viewModel.sessionCompleted {
                await viewModel.fetchQuestions()
            }
        }
        .onReceive(authViewModel.$session) { _ in
            // 🚀 优化：只在从匿名变为登录用户时请求
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty && !viewModel.sessionCompleted {
                Task { await viewModel.fetchQuestions() }
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
                .environmentObject(authViewModel)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    var mainArenaContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // 🎨 状态信息栏
                statusBar
                
                // 错误提示
                if viewModel.showError, !viewModel.errorMessage.isEmpty {
                    errorBanner
                }
                
                Spacer()
                
                // 主内容
                if viewModel.sessionCompleted {
                    EnhancedSessionSummaryView(viewModel: viewModel)
                } else {
                    enhancedQuizCardArea
                }
                
                Spacer()
            }
            
            // Combo Animation Overlay
            if viewModel.showComboAnimation {
                EnhancedComboOverlay(comboCount: viewModel.comboCount)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Combo Break Animation
            if viewModel.showComboBreak {
                EnhancedComboBreakOverlay()
                    .transition(.opacity)
            }
        }
    }
    
    // 🎨 状态信息栏（进度、连击）
    var statusBar: some View {
        HStack(spacing: 12) {
            // Progress pill
            if !viewModel.questions.isEmpty && !viewModel.sessionCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption)
                    Text(viewModel.progressText)
                        .font(.subheadline.bold())
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Combo pill
            if viewModel.comboCount >= 2 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(viewModel.comboCount)x")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(20)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.comboCount)
    }
    
    // 错误横幅
    var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(viewModel.errorMessage)
                .font(.subheadline)
            Spacer()
            Button(action: { viewModel.showError = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // 🎨 增强版 Quiz 卡片区域
    var enhancedQuizCardArea: some View {
        ZStack {
            if viewModel.questions.isEmpty {
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else {
                    EnhancedEmptyStateView(onRefresh: {
                        Task { await viewModel.fetchQuestions() }
                    })
                }
            } else if let question = viewModel.currentQuestion {
                EnhancedQuizCard(
                    question: question,
                    image: viewModel.imageCache[question.id],
                    categories: categories,
                    showCorrect: viewModel.showCorrectFeedback,
                    showWrong: viewModel.showWrongFeedback,
                    isSubmitting: viewModel.isSubmitting
                ) { selectedCategory in
                    Task { await viewModel.submitAnswer(selectedCategory: selectedCategory) }
                }
                .id(question.id)
            }
        }
        .frame(height: 540)
        .padding(.horizontal, 16)
    }
}

// MARK: - 🎨 Enhanced Subviews

// 增强版匿名用户限制视图
struct EnhancedAnonymousRestrictionView: View {
    @State private var animateGradient = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.1)],
                            startPoint: animateGradient ? .topLeading : .bottomTrailing,
                            endPoint: animateGradient ? .bottomTrailing : .topLeading
                        )
                    )
                    .frame(width: 160, height: 160)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                            animateGradient.toggle()
                        }
                    }
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            VStack(spacing: 12) {
                Text("Access Restricted")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("Trash Arena is only available for registered users.\n\nLink your Email or Phone in Account to participate and earn rewards!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// 增强版加载视图
struct EnhancedLoadingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
            }
            
            Text("Loading Arena...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// 增强版空状态视图
struct EnhancedEmptyStateView: View {
    var onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            VStack(spacing: 8) {
                Text("All Caught Up!")
                    .font(.title2.bold())
                Text("No quiz questions available.\nCheck back later for more challenges!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Quiz")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
            }
        }
    }
}

// MARK: - 🎨 Enhanced Quiz Card
struct EnhancedQuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let onAnswer: (String) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 图片区域
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray5), Color(.systemGray6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.orange)
                                Text("Loading image...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
                
                // 答案按钮区域
                VStack(spacing: 16) {
                    // 问题标题
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                        Text("What type of trash is this?")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    
                    // 分类按钮
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryAnswerButton(
                                category: category,
                                isDisabled: isButtonDisabled,
                                onTap: { onAnswer(category) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .padding(.top, 20)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // 正确/错误反馈遮罩
                if showCorrect {
                    EnhancedCorrectFeedback()
                }
                
                if showWrong {
                    EnhancedWrongFeedback(correctAnswer: question.correctCategory)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
    }
    
    private var isButtonDisabled: Bool {
        showCorrect || showWrong || isSubmitting || image == nil
    }
}

// 分类答案按钮
struct CategoryAnswerButton: View {
    let category: String
    let isDisabled: Bool
    let onTap: () -> Void
    
    var categoryColor: Color {
        switch category {
        case "Recyclable": return .blue
        case "Compostable": return .green
        case "Hazardous": return .red
        case "Landfill": return .gray
        default: return .primary
        }
    }
    
    var categoryIcon: String {
        switch category {
        case "Recyclable": return "arrow.3.trianglepath"
        case "Compostable": return "leaf.fill"
        case "Hazardous": return "exclamationmark.triangle.fill"
        case "Landfill": return "trash.fill"
        default: return "circle.fill"
        }
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                Text(category)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isDisabled ? 0.6 : 0.95))
            )
            .foregroundColor(categoryColor)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDisabled)
    }
}

// 增强版正确反馈
struct EnhancedCorrectFeedback: View {
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.green.opacity(0.9), .mint.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .scaleEffect(scale)
                Text("Correct!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("+20 points")
                    .font(.headline)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .transition(.opacity)
    }
}

// 增强版错误反馈
struct EnhancedWrongFeedback: View {
    let correctAnswer: String
    @State private var shake = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.red.opacity(0.9), .orange.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 70))
                    .offset(x: shake ? -10 : 0)
                Text("Wrong!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("Correct: \(correctAnswer)")
                    .font(.headline)
                    .opacity(0.9)
            }
            .foregroundColor(.white)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true)) {
                    shake = true
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .transition(.opacity)
    }
}

// 增强版 Combo 动画
struct EnhancedComboOverlay: View {
    let comboCount: Int
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 90))
                .scaleEffect(scale)
            Text("\(comboCount)x COMBO!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(50)
        .background(.ultraThinMaterial)
        .cornerRadius(36)
        .shadow(color: .orange.opacity(0.5), radius: 30)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.2
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6).delay(0.15)) {
                scale = 1.0
            }
        }
    }
}

// 增强版 Combo Break 动画
struct EnhancedComboBreakOverlay: View {
    @State private var opacity: Double = 1
    
    var body: some View {
        VStack(spacing: 12) {
            Text("💔")
                .font(.system(size: 70))
            Text("Combo Lost!")
                .font(.title.bold())
                .foregroundColor(.red)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                opacity = 0
            }
        }
    }
}

// 增强版 Session Summary
struct EnhancedSessionSummaryView: View {
    @ObservedObject var viewModel: ArenaViewModel
    @State private var showStats = false
    
    var accuracy: Int {
        guard viewModel.questions.count > 0 else { return 0 }
        return Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100)
    }
    
    var body: some View {
        VStack(spacing: 28) {
            // Trophy
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: accuracy >= 70 ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        accuracy >= 70 ?
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.gray, .secondary], startPoint: .top, endPoint: .bottom)
                    )
            }
            
            Text("Quiz Complete!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            
            // Stats Cards
            VStack(spacing: 14) {
                EnhancedStatRow(icon: "flame.fill", title: "Points Earned", value: "+\(viewModel.sessionScore)", color: .orange)
                EnhancedStatRow(icon: "checkmark.circle.fill", title: "Correct Answers", value: "\(viewModel.correctCount)/\(viewModel.questions.count)", color: .green)
                EnhancedStatRow(icon: "percent", title: "Accuracy", value: "\(accuracy)%", color: .blue)
                EnhancedStatRow(icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x", color: .purple)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal)
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)
            
            // Play Again Button
            Button(action: {
                Task { await viewModel.startNewSession() }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text("Play Again")
                }
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
            }
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showStats = true
            }
        }
    }
}

struct EnhancedStatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .cornerRadius(10)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.primary)
        }
    }
}

// 保留旧组件以确保兼容性
struct AnonymousRestrictionView: View {
    var body: some View {
        EnhancedAnonymousRestrictionView()
    }
}

struct EmptyStateView: View {
    var onRefresh: () -> Void
    var body: some View {
        EnhancedEmptyStateView(onRefresh: onRefresh)
    }
}

// 保留旧组件接口以确保兼容性（已重定向到增强版）
struct QuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let onAnswer: (String) -> Void
    
    var body: some View {
        EnhancedQuizCard(
            question: question,
            image: image,
            categories: categories,
            showCorrect: showCorrect,
            showWrong: showWrong,
            isSubmitting: isSubmitting,
            onAnswer: onAnswer
        )
    }
}

struct CorrectFeedbackOverlay: View {
    var body: some View {
        EnhancedCorrectFeedback()
    }
}

struct WrongFeedbackOverlay: View {
    let correctAnswer: String
    var body: some View {
        EnhancedWrongFeedback(correctAnswer: correctAnswer)
    }
}

struct ComboOverlay: View {
    let comboCount: Int
    var body: some View {
        EnhancedComboOverlay(comboCount: comboCount)
    }
}

struct ComboBreakOverlay: View {
    var body: some View {
        EnhancedComboBreakOverlay()
    }
}

struct SessionSummaryView: View {
    @ObservedObject var viewModel: ArenaViewModel
    var body: some View {
        EnhancedSessionSummaryView(viewModel: viewModel)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        EnhancedStatRow(icon: icon, title: title, value: value, color: color)
    }
}
