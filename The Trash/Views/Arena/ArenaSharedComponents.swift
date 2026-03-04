//
//  ArenaSharedComponents.swift
//  The Trash
//
//  Shared UI components extracted from ArenaView for reuse across arena modes.
//

import SwiftUI

// MARK: - Shared Quiz Card (reusable across modes)

struct SharedQuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    let pointsText: String
    let onAnswer: (String) -> Void
    var timerView: AnyView? = nil
    @Environment(\.trashTheme) private var theme

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
                    RoundedRectangle(cornerRadius: 28)
                        .fill(theme.palette.card)
                        .overlay(
                            PaperTextureView(baseColor: theme.palette.card)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                                .opacity(theme.visualStyle == .ecoPaper ? 0.4 : 0)
                        )
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
                    // Optional timer at top
                    if let timerView = timerView {
                        timerView
                    }

                    HStack {
                        TrashIcon(systemName: "questionmark.circle.fill")
                            .font(.title3)
                        Text("What type of trash is this?")
                            .font(.headline)
                        Spacer()
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, 20)

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

                // Correct/Wrong feedback overlays
                if showCorrect {
                    EnhancedCorrectFeedback(pointsText: pointsText)
                }

                if showWrong {
                    EnhancedWrongFeedback(correctAnswer: question.correctCategory)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: cardShadowDark, radius: 15, x: 8, y: 8)
            .shadow(color: cardShadowLight, radius: 10, x: -5, y: -5)
        }
    }

    private var isButtonDisabled: Bool {
        showCorrect || showWrong || isSubmitting || image == nil
    }

    private var cardShadowDark: Color {
        theme.visualStyle == .ecoPaper ? Color.black.opacity(0.2) : theme.shadows.dark
    }

    private var cardShadowLight: Color {
        theme.visualStyle == .ecoPaper ? Color.white.opacity(0.45) : theme.shadows.light
    }
}

// MARK: - Arena Status Bar

struct ArenaStatusBar: View {
    let progressText: String?
    let comboCount: Int
    let showProgress: Bool
    @Binding var pulseAnimation: Bool
    var extraContent: AnyView? = nil
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // Progress pill
            if showProgress, let progressText = progressText {
                HStack(spacing: 6) {
                    TrashIcon(systemName: "number.circle.fill")
                        .font(.caption)
                    Text(progressText)
                        .font(.subheadline.bold())
                }
                .foregroundColor(theme.accents.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)
            }

            // Combo pill
            if comboCount >= 2 {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "flame.fill")
                    Text("\(comboCount)x")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(theme.accents.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseAnimation)
            }

            if let extra = extraContent {
                extra
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: comboCount)
    }
}

// MARK: - Arena Header

struct ArenaHeader: View {
    let title: String
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TrashPageHeader(title: title, leading: {
            if showBackButton {
                TrashIconButton(icon: "chevron.left", action: { onBack?() })
            }
        }) {
            AccountButton()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Generic Session Summary

struct GenericSessionSummaryView: View {
    let title: String
    let icon: String
    let isGoodResult: Bool
    let stats: [(icon: String, title: String, value: String, color: Color)]
    let onPlayAgain: () -> Void
    var onViewLeaderboard: (() -> Void)? = nil

    @State private var showStats = false
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: 28) {
            // Trophy/result icon
            ZStack {
                Circle()
                    .fill(theme.palette.background)
                    .frame(width: 140, height: 140)
                    .shadow(color: theme.shadows.dark, radius: 12, x: 8, y: 8)
                    .shadow(color: theme.shadows.light, radius: 12, x: -6, y: -6)

                TrashIcon(systemName: isGoodResult ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        isGoodResult ?
                        LinearGradient(colors: [theme.accents.green, theme.accents.orange], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.gray, theme.palette.textSecondary], startPoint: .top, endPoint: .bottom)
                    )
            }

            Text(title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(theme.palette.textPrimary)

            // Stats Cards
            VStack(spacing: 14) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    EnhancedStatRow(icon: stat.icon, title: stat.title, value: stat.value, color: stat.color)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.palette.background)
                    .shadow(color: theme.shadows.dark, radius: 10, x: 6, y: 6)
                    .shadow(color: theme.shadows.light, radius: 10, x: -5, y: -5)
            )
            .padding(.horizontal)
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)

            HStack(spacing: 16) {
                // Play Again Button
                TrashButton(baseColor: theme.accents.blue, cornerRadius: 999, action: onPlayAgain) {
                    HStack(spacing: 10) {
                        TrashIcon(systemName: "arrow.clockwise")
                        Text("Play Again")
                    }
                    .font(.headline.bold())
                    .trashOnAccentForeground()
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }

                if let onLeaderboard = onViewLeaderboard {
                    TrashTapArea(action: onLeaderboard) {
                        HStack(spacing: 10) {
                            TrashIcon(systemName: "chart.bar.fill")
                            Text("Ranks")
                        }
                        .font(.headline.bold())
                        .foregroundColor(theme.accents.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(theme.palette.background)
                        .clipShape(Capsule())
                        .shadow(color: theme.shadows.dark, radius: 8, x: 4, y: 4)
                        .shadow(color: theme.shadows.light, radius: 8, x: -3, y: -3)
                    }
                }
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

// MARK: - Timer Bar (for Speed Sort)

struct TimerBarView: View {
    let timeRemaining: Double
    let totalTime: Double
    @Environment(\.trashTheme) private var theme

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return timeRemaining / totalTime
    }

    var timerColor: Color {
        if progress > 0.5 { return .green }
        if progress > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                TrashIcon(systemName: "timer")
                    .font(.caption.bold())
                Text(String(format: "%.1fs", timeRemaining))
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
            }
            .foregroundColor(timerTextColor)
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(timerTrackColor)
                        .frame(height: 6)

                    Capsule()
                        .fill(timerColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
        }
    }

    private var timerTextColor: Color {
        switch theme.visualStyle {
        case .vibrantGlass:
            return .white
        case .neumorphic, .ecoPaper:
            return theme.palette.textPrimary
        }
    }

    private var timerTrackColor: Color {
        switch theme.visualStyle {
        case .vibrantGlass:
            return theme.palette.textSecondary.opacity(0.32)
        case .neumorphic:
            return theme.palette.divider.opacity(0.75)
        case .ecoPaper:
            return theme.palette.divider.opacity(0.9)
        }
    }
}
