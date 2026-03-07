//
//  DailyChallengeView.swift
//  Smart Sort
//
//  Daily Challenge: same questions for everyone, once per day.
//

import SwiftUI

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pulseAnimation = false
    // showAccountSheet managed by ContentView via environment
    @State private var showLeaderboard = false
    private let theme = TrashTheme()

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.alreadyPlayed && !viewModel.sessionCompleted {
                    alreadyPlayedView
                } else if viewModel.sessionCompleted {
                    dailySummary
                } else {
                    mainContent
                }
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
        .sheet(isPresented: $showLeaderboard) {
            DailyLeaderboardView()
        }
        .navigationTitle("Daily Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
        .task {
            pulseAnimation = true
            await viewModel.fetchChallenge()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }

    // MARK: - Already Played View

    private var alreadyPlayedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.surfaceBackground)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )

                TrashIcon(systemName: "checkmark.seal.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.semanticSuccess, theme.accents.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Already Completed!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.palette.textPrimary)

                Text(
                    "You've already completed today's challenge.\nCome back tomorrow for a new one!"
                )
                .multilineTextAlignment(.center)
                .foregroundColor(theme.palette.textSecondary)
                .padding(.horizontal, 40)

                Text("Resets at midnight UTC")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary.opacity(0.7))
            }

            TrashButton(
                baseColor: theme.semanticSuccess, cornerRadius: 999,
                action: { showLeaderboard = true }
            ) {
                HStack(spacing: 10) {
                    TrashIcon(systemName: "chart.bar.fill")
                    Text("View Leaderboard")
                }
                .font(.headline.bold())
                .trashOnAccentForeground()
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [theme.semanticSuccess, theme.accents.blue], startPoint: .leading,
                        endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: theme.semanticSuccess.opacity(0.4), radius: 12, y: 6)
            }

            Spacer()
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
                    // Timer pill
                    HStack(spacing: 4) {
                        TrashIcon(systemName: "timer")
                        Text(viewModel.formattedTime)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.semanticSuccess)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusPillBackground)
                )
            )

            if viewModel.showError {
                errorBanner
            }

            Spacer()

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
                        Task { await viewModel.fetchChallenge() }
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
                    }
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

    // MARK: - Summary

    private var dailySummary: some View {
        let accuracy =
            viewModel.questions.count > 0
            ? Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100) : 0

        return GenericSessionSummaryView(
            title: "Daily Complete!",
            icon: "calendar.circle.fill",
            isGoodResult: accuracy >= 70,
            stats: [
                (
                    icon: "flame.fill", title: "Score", value: "+\(viewModel.sessionScore)",
                    color: theme.accents.orange
                ),
                (
                    icon: "checkmark.circle.fill", title: "Correct",
                    value: "\(viewModel.correctCount)/\(viewModel.questions.count)",
                    color: theme.accents.green
                ),
                (
                    icon: "timer", title: "Time", value: viewModel.formattedTime,
                    color: theme.accents.blue
                ),
                (
                    icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x",
                    color: theme.accents.purple
                ),
            ],
            onPlayAgain: {
                showLeaderboard = true
            },
            onViewLeaderboard: {
                showLeaderboard = true
            }
        )
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
