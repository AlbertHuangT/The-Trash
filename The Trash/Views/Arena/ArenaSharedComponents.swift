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
    let onAnswer: (String) -> Void
    var timerView: AnyView? = nil

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
                    // Optional timer at top
                    if let timerView = timerView {
                        timerView
                    }

                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                        Text("What type of trash is this?")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
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
                    EnhancedCorrectFeedback()
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

// MARK: - Arena Status Bar

struct ArenaStatusBar: View {
    let progressText: String?
    let comboCount: Int
    let showProgress: Bool
    @Binding var pulseAnimation: Bool
    var extraContent: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Progress pill
            if showProgress, let progressText = progressText {
                HStack(spacing: 6) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption)
                    Text(progressText)
                        .font(.subheadline.bold())
                }
                .foregroundColor(.neuAccentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicConcave(cornerRadius: 20)
            }

            // Combo pill
            if comboCount >= 2 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(comboCount)x")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(.orange)
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
    @Binding var showAccountSheet: Bool
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        HStack(alignment: .center) {
            if showBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .foregroundColor(.neuText)
                }
            }

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(.neuText)

            Spacer()

            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authViewModel)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

    var body: some View {
        VStack(spacing: 28) {
            // Trophy/result icon
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 140, height: 140)
                    .shadow(color: .neuDarkShadow, radius: 12, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 12, x: -6, y: -6)

                Image(systemName: isGoodResult ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        isGoodResult ?
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.gray, .neuSecondaryText], startPoint: .top, endPoint: .bottom)
                    )
            }

            Text(title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.neuText)

            // Stats Cards
            VStack(spacing: 14) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    EnhancedStatRow(icon: stat.icon, title: stat.title, value: stat.value, color: stat.color)
                }
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

            HStack(spacing: 16) {
                // Play Again Button
                Button(action: onPlayAgain) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                        Text("Play Again")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .neuAccentBlue.opacity(0.4), radius: 12, y: 6)
                }

                if let onLeaderboard = onViewLeaderboard {
                    Button(action: onLeaderboard) {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.fill")
                            Text("Ranks")
                        }
                        .font(.headline.bold())
                        .foregroundColor(.neuAccentBlue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.neuBackground)
                        .clipShape(Capsule())
                        .shadow(color: .neuDarkShadow, radius: 8, x: 4, y: 4)
                        .shadow(color: .neuLightShadow, radius: 8, x: -3, y: -3)
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
                Image(systemName: "timer")
                    .font(.caption.bold())
                Text(String(format: "%.1fs", timeRemaining))
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
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
}
