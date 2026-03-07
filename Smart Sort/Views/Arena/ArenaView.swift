//
//  ArenaView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import Combine
import Supabase
import SwiftUI

// MARK: - Main View
struct ArenaView: View {
    @StateObject private var viewModel = ArenaViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    private let theme = TrashTheme()
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                if authViewModel.isAnonymous {
                    EnhancedAnonymousRestrictionView()
                } else {
                    mainArenaContent
                }
            }
        }
        .navigationTitle("Classic Arena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
                    .environmentObject(authViewModel)
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
                if viewModel.showError, viewModel.errorMessage != nil {
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
                .foregroundColor(theme.accents.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusPillBackground)
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
                .background(statusPillBackground)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(theme.animations.pulse, value: pulseAnimation)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.comboCount)
    }

    private var statusPillBackground: some View {
        Capsule(style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
            )
    }

    // Error banner
    var errorBanner: some View {
        HStack(spacing: 12) {
            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.semanticWarning)
            Text(viewModel.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(theme.palette.textPrimary)
            Spacer()
            TrashIconButton(icon: "xmark", action: { viewModel.showError = false })
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
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
        EmptyStateView(
            icon: "lock.shield.fill",
            title: "Access Restricted",
            subtitle: "Trash Arena is only available for registered users. Link your email or phone in Account to participate and earn rewards."
        )
    }
}

// Loading view
struct EnhancedLoadingView: View {
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.accents.blue)

            Text("Loading Arena...")
                .font(.headline)
                .foregroundColor(theme.palette.textSecondary)
        }
    }
}

// Empty state view
struct EnhancedEmptyStateView: View {
    var onRefresh: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "trophy.circle.fill",
                title: "All Caught Up",
                subtitle: "No quiz questions available right now. Check back later for more challenges."
            )

            TrashButton(baseColor: theme.accents.blue, action: onRefresh) {
                HStack(spacing: 8) {
                    TrashIcon(systemName: "arrow.clockwise")
                    Text("Refresh Quiz")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
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
    private let theme = TrashTheme()

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
                        .fill(theme.surfaceBackground)
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(theme.accents.blue)
                                Text("Loading image...")
                                    .font(.subheadline)
                                    .foregroundColor(theme.palette.textSecondary)
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
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
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
    private let theme = TrashTheme()

    var categoryColor: Color {
        switch category {
        case "Recyclable": return theme.categoryRecyclable
        case "Compostable": return theme.categoryCompostable
        case "Hazardous": return theme.categoryHazardous
        case "Landfill": return theme.categoryLandfill
        default: return theme.palette.textPrimary
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
            action: onTap
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
                    .fill(theme.palette.card.opacity(isDisabled ? 0.5 : 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(categoryColor.opacity(isDisabled ? 0.2 : 0.4), lineWidth: 1.5)
            )
            .foregroundColor(categoryColor)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDisabled)
        .accessibilityLabel("Category: \(category)")
        .accessibilityHint("Tap to select \(category) as your answer")
    }
}

// Correct feedback
struct EnhancedCorrectFeedback: View {
    let pointsText: String
    @State private var animate = false

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
                    .compatibleBounceEffect(value: animate)
                Text("Correct!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text(pointsText)
                    .font(.headline)
                    .opacity(0.8)
            }
            .trashOnAccentForeground()
            .onAppear { animate = true }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .transition(.opacity)
    }
}

// Wrong feedback
struct EnhancedWrongFeedback: View {
    let correctAnswer: String
    @State private var animate = false

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
                    .compatibleWiggleEffect(value: animate)
                Text("Wrong!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("Correct: \(correctAnswer)")
                    .font(.headline)
                    .opacity(0.9)
            }
            .trashOnAccentForeground()
            .onAppear { animate = true }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .transition(.opacity)
    }
}

// Combo overlay
struct EnhancedComboOverlay: View {
    let comboCount: Int
    @State private var scale: CGFloat = 0.5
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 72, weight: .bold))
                .compatibleVariableColorEffect(isActive: true)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .yellow],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .scaleEffect(scale)
                .shadow(color: .orange.opacity(0.6), radius: 12)
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
                .fill(theme.surfaceBackground.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
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
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(theme.semanticDanger)
                .compatibleBounceEffect(value: opacity)
            Text("Combo Lost!")
                .font(.title.bold())
                .foregroundColor(theme.semanticDanger)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.surfaceBackground.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
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
    private let theme = TrashTheme()

    var accuracy: Int {
        guard viewModel.questions.count > 0 else { return 0 }
        return Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100)
    }

    var body: some View {
        VStack(spacing: 28) {
            // Trophy
            ZStack {
                Circle()
                    .fill(theme.surfaceBackground)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )

                TrashIcon(systemName: accuracy >= 70 ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        accuracy >= 70
                            ? LinearGradient(
                                colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(
                                colors: [.gray, theme.palette.textSecondary], startPoint: .top,
                                endPoint: .bottom)
                    )
            }

            Text("Quiz Complete!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(theme.palette.textPrimary)

            // Stats Cards
            VStack(spacing: 14) {
                EnhancedStatRow(
                    icon: "flame.fill", title: "Points Earned", value: "+\(viewModel.sessionScore)",
                    color: theme.accents.orange)
                EnhancedStatRow(
                    icon: "checkmark.circle.fill", title: "Correct Answers",
                    value: "\(viewModel.correctCount)/\(viewModel.questions.count)",
                    color: theme.accents.green)
                EnhancedStatRow(
                    icon: "percent", title: "Accuracy", value: "\(accuracy)%",
                    color: theme.accents.blue)
                EnhancedStatRow(
                    icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x",
                    color: theme.accents.purple)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)

            // Play Again Button
            TrashButton(
                baseColor: theme.accents.blue, cornerRadius: 999,
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
    private let theme = TrashTheme()

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
