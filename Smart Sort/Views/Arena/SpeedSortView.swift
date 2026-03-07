//
//  SpeedSortView.swift
//  Smart Sort
//
//  Speed Sort game mode: 10 questions with 5-second countdown each.
//

import SwiftUI

struct SpeedSortView: View {
    @StateObject private var viewModel = SpeedSortViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    private let theme = TrashTheme()
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.sessionCompleted {
                    speedSortSummary
                } else {
                    gameOrCountdown
                }
            }

            // Countdown overlay
            if let countdown = viewModel.countdownValue {
                SpeedSortCountdownOverlay(value: countdown)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
            }

            // Combo overlays
            if viewModel.showComboAnimation {
                EnhancedComboOverlay(comboCount: viewModel.comboCount)
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.showComboBreak {
                EnhancedComboBreakOverlay()
                    .transition(.opacity)
            }
        }
        .task {
            pulseAnimation = true
            await viewModel.fetchQuestions()
        }
        .navigationTitle("Speed Sort")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Status bar
            ArenaStatusBar(
                progressText: viewModel.progressText,
                comboCount: viewModel.comboCount,
                showProgress: !viewModel.questions.isEmpty,
                pulseAnimation: $pulseAnimation,
                extraContent: AnyView(
                    // Score pill
                    HStack(spacing: 4) {
                        TrashIcon(systemName: "bolt.fill")
                        Text("\(viewModel.sessionScore)")
                            .fontWeight(.black)
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.accents.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusPillBackground)
                )
            )

            if viewModel.showError {
                errorBanner
            }

            Spacer()

            // Quiz card area
            quizCardArea

            Spacer()
        }
    }

    private var quizCardArea: some View {
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
                SharedQuizCard(
                    question: question,
                    image: viewModel.imageCache[question.id],
                    categories: categories,
                    showCorrect: viewModel.showCorrectFeedback,
                    showWrong: viewModel.showWrongFeedback,
                    isSubmitting: viewModel.isSubmitting,
                    onAnswer: { category in
                        Task { await viewModel.submitAnswer(selectedCategory: category) }
                    },
                    timerView: AnyView(
                        TimerBarView(
                            timeRemaining: viewModel.timeRemaining,
                            totalTime: viewModel.timePerQuestion
                        )
                    )
                )
                .id(question.id)
            }
        }
        .frame(height: 540)
        .padding(.horizontal, 16)
    }

    private var errorBanner: some View {
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

    // MARK: - Main Content (conditional on countdown)

    private var gameOrCountdown: some View {
        Group {
            if viewModel.isCountingDown {
                // Show the card area dimmed behind countdown
                mainContent
                    .opacity(0.3)
                    .allowsHitTesting(false)
            } else {
                mainContent
            }
        }
    }

    private var statusPillBackground: some View {
        Capsule(style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
            )
    }

    // MARK: - Summary

    private var speedSortSummary: some View {
        let accuracy =
            viewModel.questions.count > 0
            ? Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100) : 0

        return GenericSessionSummaryView(
            title: "Speed Sort Complete!",
            icon: "bolt.fill",
            isGoodResult: accuracy >= 70,
            stats: [
                (
                    icon: "flame.fill", title: "Total Score", value: "+\(viewModel.sessionScore)",
                    color: theme.accents.orange
                ),
                (
                    icon: "checkmark.circle.fill", title: "Correct",
                    value: "\(viewModel.correctCount)/\(viewModel.questions.count)",
                    color: theme.accents.green
                ),
                (icon: "percent", title: "Accuracy", value: "\(accuracy)%", color: theme.accents.blue),
                (
                    icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x",
                    color: theme.accents.purple
                ),
            ],
            onPlayAgain: {
                Task { await viewModel.startNewSession() }
            }
        )
    }
}

// MARK: - Countdown Overlay

struct SpeedSortCountdownOverlay: View {
    let value: Int
    @State private var scale: CGFloat = 0.3

    var displayText: String {
        value > 0 ? "\(value)" : "GO!"
    }

    var displayColor: Color {
        switch value {
        case 3: return .red
        case 2: return .orange
        case 1: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            Text(displayText)
                .font(.system(size: value > 0 ? 120 : 80, weight: .black, design: .rounded))
                .foregroundStyle(displayColor)
                .shadow(color: displayColor.opacity(0.6), radius: 20)
                .scaleEffect(scale)
        }
        .onAppear {
            scale = 0.3
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
        .onChange(of: value) { _ in
            scale = 0.3
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
    }
}
