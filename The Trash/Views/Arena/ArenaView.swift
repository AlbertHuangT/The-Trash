//
//  ArenaView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Combine
import Supabase
import SwiftUI

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

    @Published var isSubmitting = false

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

            let profile: ProfileCredits =
                try await client
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
            let fetchedQuestions: [QuizQuestion] =
                try await client
                .rpc("get_quiz_questions")
                .execute()
                .value

            self.questions = fetchedQuestions
            await fetchUserCredits()
            await preloadImages()

        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func preloadImages() async {
        // Load all images concurrently (only 10 questions)
        await withTaskGroup(of: Void.self) { group in
            for question in questions {
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

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad

            let (data, _) = try await URLSession.shared.data(for: request)

            let decodedImage = await Task.detached(priority: .userInitiated) {
                return UIImage(data: data)?.preparingForDisplay()
            }.value

            if let image = decodedImage {
                await MainActor.run {
                    imageCache[question.id] = image
                }
            }
        } catch {
            print(
                "⚠️ [Arena] Failed to load image for \(question.id): \(error.localizedDescription)")
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
        imageCache.removeAll()
    }

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard let question = currentQuestion else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let isCorrect = selectedCategory == question.correctCategory

        if isCorrect {
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)

            var pointsEarned = 20
            if comboCount >= 3 {
                let comboBonus = (comboCount - 2) * 5
                pointsEarned += comboBonus
            }

            sessionScore += pointsEarned
            totalCredits += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                pointAnimationText = "+\(pointsEarned)"
                showPointAnimation = true

                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }

            do {
                try await client.rpc("increment_credits", params: ["amount": pointsEarned])
                    .execute()
            } catch {
                totalCredits -= pointsEarned
                sessionScore -= pointsEarned
                correctCount -= 1
                comboCount = max(0, comboCount - 1)
                print("❌ [Arena] Credit update failed: \(error)")
            }

        } else {
            let hadCombo = comboCount >= 3
            comboCount = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
                if hadCombo {
                    showComboBreak = true
                }
            }
        }

        try? await Task.sleep(nanoseconds: 800_000_000)

        withAnimation(.easeOut(duration: 0.2)) {
            showCorrectFeedback = false
            showWrongFeedback = false
            showPointAnimation = false
            showComboAnimation = false
            showComboBreak = false
        }

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
    @Environment(\.trashTheme) private var theme
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            ThemeBackground()

            VStack(spacing: 0) {
                TrashPageHeader(title: "Arena") {
                    AccountButton()
                        .environmentObject(authViewModel)
                }

                if authViewModel.isAnonymous {
                    EnhancedAnonymousRestrictionView()
                } else {
                    mainArenaContent
                }
            }
        }
        .task {
            pulseAnimation = true
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty
                && !viewModel.sessionCompleted
            {
                await viewModel.fetchQuestions()
            }
        }
        .onReceive(authViewModel.$session) { _ in
            if !authViewModel.isAnonymous && viewModel.questions.isEmpty
                && !viewModel.sessionCompleted
            {
                Task { await viewModel.fetchQuestions() }
            }
        }
    }

    var mainArenaContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Status bar
                statusBar

                // Error banner
                if viewModel.showError, !viewModel.errorMessage.isEmpty {
                    errorBanner
                }

                Spacer()

                // Main content
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

    // Status bar (progress, combo)
    var statusBar: some View {
        HStack(spacing: 12) {
            // Progress pill
            if !viewModel.questions.isEmpty && !viewModel.sessionCompleted {
                HStack(spacing: 6) {
                    TrashIcon(systemName: "number.circle.fill")
                        .font(.caption)
                    Text(viewModel.progressText)
                        .font(.subheadline.bold())
                }
                .foregroundColor(.neuAccentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)
            }

            // Combo pill
            if viewModel.comboCount >= 2 {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "flame.fill")
                    Text("\(viewModel.comboCount)x")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(theme.semanticWarning)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: pulseAnimation)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.comboCount)
    }

    // Error banner
    var errorBanner: some View {
        HStack(spacing: 12) {
            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.semanticWarning)
            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundColor(.neuText)
            Spacer()
            TrashIconButton(icon: "xmark", action: { viewModel.showError = false })
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // Quiz card area
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
                    isSubmitting: viewModel.isSubmitting,
                    pointsText: viewModel.pointAnimationText.isEmpty ? "+20" : viewModel.pointAnimationText
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

// MARK: - Enhanced Subviews

// Anonymous restriction view
struct EnhancedAnonymousRestrictionView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 160, height: 160)
                    .shadow(color: .neuDarkShadow, radius: 12, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 12, x: -6, y: -6)

                TrashIcon(systemName: "lock.shield.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neuAccentBlue, .purple], startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 12) {
                Text("Access Restricted")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.neuText)

                Text(
                    "Trash Arena is only available for registered users.\n\nLink your Email or Phone in Account to participate and earn rewards!"
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.neuSecondaryText)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// Loading view
struct EnhancedLoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 100, height: 100)
                    .shadow(color: .neuDarkShadow, radius: 8, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.neuAccentBlue, .cyan], startPoint: .leading,
                            endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                TrashIcon(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.neuAccentBlue)
            }

            Text("Loading Arena...")
                .font(.headline)
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// Empty state view
struct EnhancedEmptyStateView: View {
    var onRefresh: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)

                TrashIcon(systemName: "trophy.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.semanticWarning, theme.semanticHighlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("All Caught Up!")
                    .font(.title2.bold())
                    .foregroundColor(.neuText)
                Text("No quiz questions available.\nCheck back later for more challenges!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.neuSecondaryText)
            }

            TrashButton(baseColor: theme.semanticInfo, cornerRadius: 999, action: onRefresh) {
                HStack(spacing: 8) {
                    TrashIcon(systemName: "arrow.clockwise")
                    Text("Refresh Quiz")
                }
                .font(.headline)
                .trashOnAccentForeground()
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .neuAccentBlue.opacity(0.4), radius: 10, y: 5)
            }
        }
    }
}

// MARK: - Enhanced Quiz Card
struct EnhancedQuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let pointsText: String
    let onAnswer: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Image area
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.neuBackground)
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.neuAccentBlue)
                                Text("Loading image...")
                                    .font(.subheadline)
                                    .foregroundColor(.neuSecondaryText)
                            }
                        )
                }

                // Answer buttons area
                VStack(spacing: 16) {
                    HStack {
                        TrashIcon(systemName: "questionmark.circle.fill")
                            .font(.title3)
                        Text("What type of trash is this?")
                            .font(.headline)
                        Spacer()
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12)
                    {
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

                // Correct/Wrong feedback overlays
                if showCorrect {
                    EnhancedCorrectFeedback(pointsText: pointsText)
                }

                if showWrong {
                    EnhancedWrongFeedback(correctAnswer: question.correctCategory)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .neuDarkShadow, radius: 15, x: 8, y: 8)
            .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
        }
    }

    private var isButtonDisabled: Bool {
        showCorrect || showWrong || isSubmitting || image == nil
    }
}

// Category answer button
struct CategoryAnswerButton: View {
    let category: String
    let isDisabled: Bool
    let onTap: () -> Void
    @Environment(\.trashTheme) private var theme

    var categoryColor: Color {
        switch category {
        case "Recyclable": return .blue
        case "Compostable": return .green
        case "Hazardous": return .red
        case "Landfill": return .gray
        default: return .neuText
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
        TrashTapArea(
            haptics: true,
            action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onTap()
            }
        ) {
            HStack(spacing: 8) {
                TrashIcon(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                Text(category)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.palette.card.opacity(isDisabled ? 0.6 : 0.95))
            )
            .foregroundColor(categoryColor)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDisabled)
    }
}

// Correct feedback
struct EnhancedCorrectFeedback: View {
    let pointsText: String
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.green.opacity(0.9), .mint.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                TrashIcon(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .scaleEffect(scale)
                Text("Correct!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text(pointsText)
                    .font(.headline)
                    .opacity(0.8)
            }
            .trashOnAccentForeground()
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

// Wrong feedback
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
                TrashIcon(systemName: "xmark.circle.fill")
                    .font(.system(size: 70))
                    .offset(x: shake ? -10 : 0)
                Text("Wrong!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("Correct: \(correctAnswer)")
                    .font(.headline)
                    .opacity(0.9)
            }
            .trashOnAccentForeground()
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

// Combo overlay
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
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.neuBackground.opacity(0.95))
                .shadow(color: .neuDarkShadow, radius: 20, x: 10, y: 10)
                .shadow(color: .neuLightShadow, radius: 20, x: -8, y: -8)
        )
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

// Combo break overlay
struct EnhancedComboBreakOverlay: View {
    @State private var opacity: Double = 1
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Text("💔")
                .font(.system(size: 70))
            Text("Combo Lost!")
                .font(.title.bold())
                .foregroundColor(theme.semanticDanger)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.neuBackground.opacity(0.95))
                .shadow(color: .neuDarkShadow, radius: 15, x: 8, y: 8)
                .shadow(color: .neuLightShadow, radius: 15, x: -6, y: -6)
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                opacity = 0
            }
        }
    }
}

// Session summary
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
                    .fill(Color.neuBackground)
                    .frame(width: 140, height: 140)
                    .shadow(color: .neuDarkShadow, radius: 12, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 12, x: -6, y: -6)

                TrashIcon(systemName: accuracy >= 70 ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        accuracy >= 70
                            ? LinearGradient(
                                colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(
                                colors: [.gray, .neuSecondaryText], startPoint: .top,
                                endPoint: .bottom)
                    )
            }

            Text("Quiz Complete!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.neuText)

            // Stats Cards
            VStack(spacing: 14) {
                EnhancedStatRow(
                    icon: "flame.fill", title: "Points Earned", value: "+\(viewModel.sessionScore)",
                    color: .neuAccentOrange)
                EnhancedStatRow(
                    icon: "checkmark.circle.fill", title: "Correct Answers",
                    value: "\(viewModel.correctCount)/\(viewModel.questions.count)",
                    color: .neuAccentGreen)
                EnhancedStatRow(
                    icon: "percent", title: "Accuracy", value: "\(accuracy)%", color: .neuAccentBlue
                )
                EnhancedStatRow(
                    icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x",
                    color: .neuAccentPurple)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
            )
            .padding(.horizontal)
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)

            // Play Again Button
            TrashButton(
                baseColor: .neuAccentBlue, cornerRadius: 999,
                action: {
                    Task { await viewModel.startNewSession() }
                }
            ) {
                HStack(spacing: 10) {
                    TrashIcon(systemName: "arrow.clockwise")
                    Text("Play Again")
                }
                .font(.headline.bold())
                .trashOnAccentForeground()
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
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
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            TrashIcon(systemName: icon)
                .font(theme.typography.subheadline)
                .trashOnAccentForeground()
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(color)
                .cornerRadius(theme.corners.small)

            Text(title)
                .font(theme.typography.body)
                .foregroundColor(theme.palette.textSecondary)

            Spacer()

            Text(value)
                .font(theme.typography.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textPrimary)
        }
    }
}

// Backward compatibility wrappers
struct AnonymousRestrictionView: View {
    var body: some View {
        EnhancedAnonymousRestrictionView()
    }
}

private struct ArenaEmptyStateView: View {
    var onRefresh: () -> Void
    var body: some View {
        EnhancedEmptyStateView(onRefresh: onRefresh)
    }
}

struct QuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let pointsText: String
    let onAnswer: (String) -> Void

    var body: some View {
        EnhancedQuizCard(
            question: question,
            image: image,
            categories: categories,
            showCorrect: showCorrect,
            showWrong: showWrong,
            isSubmitting: isSubmitting,
            pointsText: pointsText,
            onAnswer: onAnswer
        )
    }
}

struct CorrectFeedbackOverlay: View {
    let pointsText: String
    var body: some View {
        EnhancedCorrectFeedback(pointsText: pointsText)
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
