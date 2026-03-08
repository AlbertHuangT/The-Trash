//
//  DuelView.swift
//  Smart Sort
//
//  Main duel view that orchestrates lobby → countdown → game → results.
//

import SwiftUI

struct DuelView: View {
    @StateObject private var viewModel = DuelViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    private let theme = TrashTheme()

    let challengeId: UUID?
    let opponentId: UUID?
    let isAccepting: Bool

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]
    
    private var quizCardHeight: CGFloat {
        min(480, UIScreen.main.bounds.height * 0.54)
    }

    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                switch viewModel.phase {
                case .loading:
                    Spacer()
                    EnhancedLoadingView()
                    Spacer()

                case .lobby:
                    DuelLobbyContent(viewModel: viewModel, challengeId: challengeId)

                case .countdown:
                    countdownView

                case .playing:
                    playingContent

                case .waitingResult:
                    waitingForOpponent

                case .results:
                    resultsContent

                case .error(let message):
                    errorView(message)
                }
            }
        }
        .trashScreenBackground()
        .task {
            if isAccepting, let cid = challengeId {
                await viewModel.acceptChallenge(challengeId: cid)
            } else if let cid = challengeId {
                await viewModel.joinAsChallenger(challengeId: cid)
            } else if let oppId = opponentId {
                await viewModel.createChallenge(opponentId: oppId)
            }
        }
        .onDisappear {
            Task { await viewModel.cleanup() }
        }
        .navigationTitle("1v1 Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            Spacer(minLength: theme.layout.sectionSpacing)
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.semanticDanger, theme.semanticWarning], startPoint: .top,
                        endPoint: .bottom)
                )
                .animation(.spring(response: 0.3), value: viewModel.countdownValue)
            Text("Get Ready!")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    // MARK: - Playing

    private var playingContent: some View {
        VStack(spacing: theme.layout.sectionSpacing) {
            dualProgressBar

            if let question = viewModel.currentQuestion {
                SharedQuizCard(
                    question: question,
                    image: viewModel.imageCache[question.id],
                    imageFailed: viewModel.isArenaImageFailed(for: question),
                    correctAnswer: viewModel.lastCorrectCategory,
                    categories: categories,
                    showCorrect: viewModel.showCorrectFeedback,
                    showWrong: viewModel.showWrongFeedback,
                    isSubmitting: viewModel.isSubmitting,
                    onRetryImage: { viewModel.retryCurrentImage() },
                    onAnswer: { category in
                        Task { await viewModel.submitAnswer(selectedCategory: category) }
                    }
                )
                .id(question.id)
                .frame(height: quizCardHeight)
                .padding(.horizontal, theme.layout.screenInset)
            }

            Spacer()
        }
    }

    private var dualProgressBar: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.caption.bold())
                    .foregroundColor(theme.accents.blue)
                ProgressView(
                    value: Double(viewModel.currentQuestionIndex),
                    total: Double(max(1, viewModel.questions.count))
                )
                .tint(theme.accents.blue)
                Text("\(viewModel.correctCount) correct")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)
            }

            // Opponent
            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.opponentDisplayName)
                    .font(.caption.bold())
                    .foregroundColor(theme.semanticDanger)
                    .lineLimit(1)
                ProgressView(
                    value: Double(viewModel.opponentProgress),
                    total: Double(max(1, viewModel.questions.count))
                )
                .tint(theme.semanticDanger)
                Text("\(viewModel.opponentCorrect) correct")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
        .padding(.horizontal, theme.components.cardPadding)
        .padding(.vertical, theme.layout.elementSpacing)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.top, theme.layout.elementSpacing)
    }

    // MARK: - Waiting

    private var waitingForOpponent: some View {
        VStack(spacing: theme.layout.sectionSpacing) {
            Spacer()
            EnhancedLoadingView()
            Text("Waiting for opponent to finish...")
                .font(.headline)
                .foregroundColor(theme.palette.textSecondary)
                .padding(theme.components.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                )
                .padding(.horizontal, theme.layout.screenInset)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        DuelResultsContent(viewModel: viewModel, onDismiss: { dismiss() })
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: theme.layout.sectionSpacing) {
            Spacer()

            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.semanticWarning)

            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(theme.components.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                )
                .padding(.horizontal, theme.layout.screenInset)

            TrashButton(baseColor: theme.accents.blue, action: { dismiss() }) {
                Text("Go Back")
                    .font(theme.typography.subheadline.weight(.bold))
            }
            .padding(.horizontal, theme.layout.screenInset)

            Spacer()
        }
    }
}

// MARK: - Lobby Content

struct DuelLobbyContent: View {
    @ObservedObject var viewModel: DuelViewModel
    let challengeId: UUID?
    private let theme = TrashTheme()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: theme.layout.sectionSpacing) {
                badgeCircle(icon: "person.2.fill", iconColor: theme.semanticWarning)

                VStack(spacing: theme.spacing.sm) {
                    Text("Waiting for opponent...")
                        .font(theme.typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textPrimary)

                    if viewModel.opponentReady {
                        Text("Opponent is ready!")
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.accents.green)
                    }

                    if !viewModel.myReady {
                        Text("Loading questions...")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
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

                if let cid = challengeId ?? viewModel.challengeId {
                    let shareURL = URL(string: "smartsort://challenge/\(cid.uuidString)")!
                    ShareLink(
                        item: shareURL,
                        subject: Text("Trash Arena Challenge"),
                        message: Text("I challenge you to a 1v1 Trash Arena duel! Tap to accept:")
                    ) {
                        HStack(spacing: 8) {
                            TrashIcon(systemName: "square.and.arrow.up")
                            Text("Share Challenge Link")
                        }
                        .font(theme.typography.subheadline.weight(.bold))
                        .trashOnAccentForeground()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: theme.components.buttonHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.accents.blue)
                        )
                    }
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.sectionSpacing)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func badgeCircle(icon: String, iconColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(width: 104, height: 104)
                .overlay(
                    Circle()
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )

            StampedIcon(systemName: icon, size: 42, weight: .semibold, color: iconColor)
        }
    }
}

// MARK: - Results Content

struct DuelResultsContent: View {
    @ObservedObject var viewModel: DuelViewModel
    let onDismiss: () -> Void

    @State private var showStats = false
    private let theme = TrashTheme()

    var iWon: Bool {
        viewModel.result?.winnerId == viewModel.myUserId
    }

    var isTie: Bool {
        viewModel.result?.winnerId == nil
    }

    var myFinalScore: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger ? (result.challengerScore ?? 0) : (result.opponentScore ?? 0)
    }

    var opponentFinalScore: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger ? (result.opponentScore ?? 0) : (result.challengerScore ?? 0)
    }

    var myPoints: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger
            ? (result.challengerPoints ?? 0) : (result.opponentPoints ?? 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: theme.layout.sectionSpacing) {
                resultBadge

                Text(isTie ? "It's a Tie!" : (iWon ? "You Win!" : "You Lose"))
                    .font(theme.typography.title)
                    .fontWeight(.heavy)
                    .foregroundColor(theme.palette.textPrimary)

                HStack(spacing: theme.layout.sectionSpacing) {
                    VStack(spacing: 4) {
                        Text("You")
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.palette.textSecondary)
                        Text("\(myFinalScore)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(theme.accents.blue)
                    }

                    Text("vs")
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textSecondary)

                    VStack(spacing: 4) {
                        Text(viewModel.opponentDisplayName)
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.palette.textSecondary)
                            .lineLimit(1)
                        Text("\(opponentFinalScore)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(theme.semanticDanger)
                    }
                }
                .padding(theme.components.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                        )
                )
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)

                Text("+\(myPoints) points earned")
                    .font(theme.typography.headline)
                    .foregroundColor(theme.accents.green)
                    .opacity(showStats ? 1 : 0)

                TrashButton(baseColor: theme.accents.blue, action: onDismiss) {
                    HStack(spacing: 8) {
                        TrashIcon(systemName: "arrow.left")
                        Text("Back to Arena")
                    }
                    .font(theme.typography.subheadline.weight(.bold))
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.sectionSpacing)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showStats = true
            }
        }
    }

    @ViewBuilder
    private var resultBadge: some View {
        ZStack {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(width: 104, height: 104)
                .overlay(
                    Circle()
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )

            if isTie {
                StampedIcon(
                    systemName: "equal.circle.fill", size: 48, weight: .semibold,
                    color: theme.semanticWarning)
            } else if iWon {
                StampedIcon(
                    systemName: "crown.fill", size: 48, weight: .semibold,
                    color: theme.semanticHighlight)
            } else {
                StampedIcon(
                    systemName: "flag.checkered", size: 48, weight: .semibold,
                    color: theme.palette.textSecondary)
            }
        }
    }
}
