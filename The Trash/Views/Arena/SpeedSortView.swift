//
//  SpeedSortView.swift
//  The Trash
//
//  Speed Sort game mode: 10 questions with 5-second countdown each.
//

import SwiftUI

struct SpeedSortView: View {
    @StateObject private var viewModel = SpeedSortViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pulseAnimation = false
    @State private var showAccountSheet = false

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            Color.neuBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with back button
                ArenaHeader(
                    title: "Speed Sort",
                    showAccountSheet: $showAccountSheet,
                    showBackButton: true,
                    onBack: { dismiss() }
                )

                if viewModel.sessionCompleted {
                    speedSortSummary
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
        .task {
            pulseAnimation = true
            await viewModel.fetchQuestions()
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
                        Image(systemName: "bolt.fill")
                        Text("\(viewModel.sessionScore)")
                            .fontWeight(.black)
                    }
                    .font(.subheadline)
                    .foregroundColor(.neuAccentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicConcave(cornerRadius: 20)
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

    private var speedSortSummary: some View {
        let accuracy = viewModel.questions.count > 0 ?
            Int(Double(viewModel.correctCount) / Double(viewModel.questions.count) * 100) : 0

        return GenericSessionSummaryView(
            title: "Speed Sort Complete!",
            icon: "bolt.fill",
            isGoodResult: accuracy >= 70,
            stats: [
                (icon: "flame.fill", title: "Total Score", value: "+\(viewModel.sessionScore)", color: .orange),
                (icon: "checkmark.circle.fill", title: "Correct", value: "\(viewModel.correctCount)/\(viewModel.questions.count)", color: .green),
                (icon: "percent", title: "Accuracy", value: "\(accuracy)%", color: .blue),
                (icon: "bolt.fill", title: "Best Combo", value: "\(viewModel.maxCombo)x", color: .purple)
            ],
            onPlayAgain: {
                Task { await viewModel.startNewSession() }
            }
        )
    }
}
