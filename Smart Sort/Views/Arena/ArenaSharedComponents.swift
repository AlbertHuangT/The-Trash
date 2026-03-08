//
//  ArenaSharedComponents.swift
//  Smart Sort
//
//  Shared UI components extracted from ArenaView for reuse across arena modes.
//

import SwiftUI

// MARK: - Shared Quiz Card (reusable across modes)

struct ArenaImagePlaceholder: View {
    let failed: Bool
    let onRetry: (() -> Void)?
    private let theme = TrashTheme()

    var body: some View {
        RoundedRectangle(cornerRadius: theme.corners.large + 4)
            .fill(theme.palette.card)
            .overlay {
                VStack(spacing: theme.spacing.md) {
                    if failed {
                        TrashIcon(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(theme.semanticWarning)
                        Text("Image unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.palette.textPrimary)
                        if let onRetry {
                            TrashPill(
                                title: "Retry",
                                icon: "arrow.clockwise",
                                color: theme.accents.blue,
                                isSelected: true,
                                action: onRetry
                            )
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(theme.accents.blue)
                        Text("Loading image...")
                            .font(.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .multilineTextAlignment(.center)
            }
    }
}

struct SharedQuizCard: View {
    let question: QuizQuestion
    let image: UIImage?
    let imageFailed: Bool
    let correctAnswer: String?
    let categories: [String]
    let showCorrect: Bool
    let showWrong: Bool
    let isSubmitting: Bool
    var pointsText: String = "+10 pts"
    var onRetryImage: (() -> Void)? = nil
    let onAnswer: (String) -> Void
    var timerView: AnyView? = nil
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
                        .accessibilityLabel("Quiz item photo")
                } else {
                    ArenaImagePlaceholder(failed: imageFailed, onRetry: onRetryImage)
                }

                // Answer buttons area
                VStack(spacing: theme.layout.elementSpacing) {
                    // Optional timer at top
                    if let timerView = timerView {
                        timerView
                    }

                    HStack {
                        TrashIcon(systemName: "questionmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("What type of trash is this?")
                            .font(theme.typography.subheadline)
                            .lineLimit(2)
                        Spacer()
                    }
                    .trashOnAccentForeground()
                    .padding(.horizontal, theme.layout.screenInset)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: theme.layout.elementSpacing
                    ) {
                        ForEach(categories, id: \.self) { category in
                            CategoryAnswerButton(
                                category: category,
                                isDisabled: isButtonDisabled,
                                onTap: { onAnswer(category) }
                            )
                        }
                    }
                    .padding(.horizontal, theme.components.contentInset)
                    .padding(.bottom, theme.layout.sectionSpacing)
                }
                .padding(.top, theme.layout.elementSpacing)
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
                    EnhancedWrongFeedback(correctAnswer: correctAnswer ?? "Unknown")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.corners.large + 4))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
    }

    private var isButtonDisabled: Bool {
        showCorrect || showWrong || isSubmitting || image == nil
    }

}

// MARK: - Arena Status Bar

struct ArenaStatusBar: View {
    let progressText: String?
    let comboCount: Int
    let showProgress: Bool
    @Binding var pulseAnimation: Bool
    var extraContent: AnyView? = nil
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: theme.layout.elementSpacing) {
            // Progress pill
            if showProgress, let progressText = progressText {
                HStack(spacing: 6) {
                    TrashIcon(systemName: "number.circle.fill")
                        .font(.caption)
                    Text(progressText)
                        .font(.subheadline.bold())
                }
                .foregroundColor(theme.accents.blue)
                .padding(.horizontal, theme.layout.compactControlHorizontalInset)
                .frame(minHeight: 32)
                .background(statusPillBackground)
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
                .padding(.horizontal, theme.layout.compactControlHorizontalInset)
                .frame(minHeight: 32)
                .background(statusPillBackground)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(theme.animations.pulse, value: pulseAnimation)
            }

            if let extra = extraContent {
                extra
            }

            Spacer()
        }
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.bottom, theme.layout.elementSpacing)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: comboCount)
    }

    private var statusPillBackground: some View {
        Capsule(style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
            )
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
    private let theme = TrashTheme()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: theme.layout.sectionSpacing) {
                ZStack {
                    Circle()
                        .fill(theme.surfaceBackground)
                        .frame(width: 112, height: 112)
                        .overlay(
                            Circle()
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )

                    TrashIcon(systemName: icon)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(
                            isGoodResult
                                ? LinearGradient(
                                    colors: [theme.accents.green, theme.accents.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [.gray, theme.palette.textSecondary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                }

                Text(title)
                    .font(theme.typography.title.weight(.heavy))
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: theme.layout.elementSpacing) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        EnhancedStatRow(
                            icon: stat.icon,
                            title: stat.title,
                            value: stat.value,
                            color: stat.color
                        )
                    }
                }
                .padding(theme.components.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                )
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.layout.sheetActionSpacing) {
                        TrashButton(baseColor: theme.accents.blue, cornerRadius: 999, action: onPlayAgain) {
                            HStack(spacing: 10) {
                                TrashIcon(systemName: "arrow.clockwise")
                                Text("Play Again")
                            }
                            .font(theme.typography.subheadline.weight(.bold))
                            .trashOnAccentForeground()
                        }

                        if let onLeaderboard = onViewLeaderboard {
                            leaderboardActionButton(action: onLeaderboard)
                        }
                    }

                    VStack(spacing: theme.layout.sheetActionSpacing) {
                        TrashButton(baseColor: theme.accents.blue, cornerRadius: 999, action: onPlayAgain) {
                            HStack(spacing: 10) {
                                TrashIcon(systemName: "arrow.clockwise")
                                Text("Play Again")
                            }
                            .font(theme.typography.subheadline.weight(.bold))
                            .trashOnAccentForeground()
                        }

                        if let onLeaderboard = onViewLeaderboard {
                            leaderboardActionButton(action: onLeaderboard)
                        }
                    }
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.sectionSpacing)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showStats = true
            }
        }
    }

    private func leaderboardActionButton(action: @escaping () -> Void) -> some View {
        TrashTapArea(action: action) {
            HStack(spacing: 8) {
                TrashIcon(systemName: "chart.bar.fill")
                Text("Ranks")
            }
            .font(theme.typography.subheadline.weight(.bold))
            .foregroundColor(theme.accents.blue)
            .padding(.horizontal, theme.layout.compactControlHorizontalInset)
            .frame(minHeight: theme.components.buttonHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Timer Bar (for Speed Sort)

struct TimerBarView: View {
    let timeRemaining: Double
    let totalTime: Double
    private let theme = TrashTheme()
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return timeRemaining / totalTime
    }
    
    var timerColor: Color {
        if progress > 0.5 { return theme.semanticSuccess }
        if progress > 0.25 { return theme.semanticWarning }
        return theme.semanticDanger
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
            .padding(.horizontal, theme.layout.screenInset)
            
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
            .padding(.horizontal, theme.layout.screenInset)
        }
    }
    
    private var timerTextColor: Color {
        theme.palette.textPrimary
    }
    
    private var timerTrackColor: Color {
        theme.palette.divider.opacity(0.9)
    }
}
