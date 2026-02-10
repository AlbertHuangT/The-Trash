//
//  DailyChallengeView.swift
//  The Trash
//
//  Daily Challenge: same questions for everyone, once per day.
//

import SwiftUI

struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pulseAnimation = false
    @State private var showAccountSheet = false
    @State private var showLeaderboard = false

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            Color.neuBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ArenaHeader(
                    title: "Daily Challenge",
                    showAccountSheet: $showAccountSheet,
                    showBackButton: true,
                    onBack: { dismiss() }
                )

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
        .task {
            pulseAnimation = true
            await viewModel.fetchChallenge()
        }
    }

    // MARK: - Already Played View

    private var alreadyPlayedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 140, height: 140)
                    .shadow(color: .neuDarkShadow, radius: 12, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 12, x: -6, y: -6)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 12) {
                Text("Already Completed!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.neuText)

                Text("You've already completed today's challenge.\nCome back tomorrow for a new one!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.neuSecondaryText)
                    .padding(.horizontal, 40)

                Text("Resets at midnight UTC")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText.opacity(0.7))
            }

            Button(action: { showLeaderboard = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                    Text("View Leaderboard")
                }
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
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
                        Image(systemName: "timer")
                        Text(viewModel.formattedTime)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicConcave(cornerRadius: 20)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundColor(.neuText)
            Spacer()
            Button(action: { viewModel.showError = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.neuSecondaryText)
            }
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

    // MARK: - Summary

    private var dailySummary: some View {
        let accuracy = viewModel.questions.count > 0 ?
            Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100) : 0

        return GenericSessionSummaryView(
            title: "Daily Complete!",
            icon: "calendar.circle.fill",
            isGoodResult: accuracy >= 70,
            stats: [
                (icon: "flame.fill", title: "Score", value: "+\(viewModel.sessionScore)", color: .orange),
                (icon: "checkmark.circle.fill", title: "Correct", value: "\(viewModel.correctCount)/\(viewModel.questions.count)", color: .green),
                (icon: "timer", title: "Time", value: viewModel.formattedTime, color: .blue),
                (icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x", color: .purple)
            ],
            onPlayAgain: {
                // Can't play again — show leaderboard instead
                showLeaderboard = true
            },
            onViewLeaderboard: {
                showLeaderboard = true
            }
        )
    }
}
