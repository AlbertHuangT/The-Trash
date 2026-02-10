//
//  DuelView.swift
//  The Trash
//
//  Main duel view that orchestrates lobby → countdown → game → results.
//

import SwiftUI

struct DuelView: View {
    @StateObject private var viewModel = DuelViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAccountSheet = false

    let challengeId: UUID?
    let opponentId: UUID?
    let isAccepting: Bool

    let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        ZStack {
            Color.neuBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ArenaHeader(
                    title: "1v1 Duel",
                    showAccountSheet: $showAccountSheet,
                    showBackButton: true,
                    onBack: {
                        Task { await viewModel.cleanup() }
                        dismiss()
                    }
                )

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
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(1.2)
                .animation(.spring(response: 0.3), value: viewModel.countdownValue)
            Text("Get Ready!")
                .font(.title2.bold())
                .foregroundColor(.neuSecondaryText)
            Spacer()
        }
    }

    // MARK: - Playing

    private var playingContent: some View {
        VStack(spacing: 0) {
            // Dual progress bar
            dualProgressBar

            Spacer()

            // Quiz card
            if let question = viewModel.currentQuestion {
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
                .frame(height: 480)
                .padding(.horizontal, 16)
            }

            Spacer()
        }
    }

    private var dualProgressBar: some View {
        HStack(spacing: 16) {
            // Me
            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.caption.bold())
                    .foregroundColor(.neuAccentBlue)
                ProgressView(value: Double(viewModel.currentQuestionIndex), total: Double(max(1, viewModel.questions.count)))
                    .tint(.neuAccentBlue)
                Text("\(viewModel.correctCount) correct")
                    .font(.caption2)
                    .foregroundColor(.neuSecondaryText)
            }

            // Opponent
            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.opponentDisplayName)
                    .font(.caption.bold())
                    .foregroundColor(.red)
                ProgressView(value: Double(viewModel.realtimeManager.opponentProgress), total: Double(max(1, viewModel.questions.count)))
                    .tint(.red)
                Text("\(viewModel.realtimeManager.opponentCorrect) correct")
                    .font(.caption2)
                    .foregroundColor(.neuSecondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Waiting

    private var waitingForOpponent: some View {
        VStack(spacing: 24) {
            Spacer()
            EnhancedLoadingView()
            Text("Waiting for opponent to finish...")
                .font(.headline)
                .foregroundColor(.neuSecondaryText)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        DuelResultsContent(viewModel: viewModel, onDismiss: { dismiss() })
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { dismiss() }) {
                Text("Go Back")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - Lobby Content

struct DuelLobbyContent: View {
    @ObservedObject var viewModel: DuelViewModel
    let challengeId: UUID?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 10, x: -4, y: -4)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text("Waiting for opponent...")
                    .font(.title2.bold())
                    .foregroundColor(.neuText)

                if viewModel.realtimeManager.opponentReady {
                    Text("Opponent is ready!")
                        .font(.subheadline)
                        .foregroundColor(.neuAccentGreen)
                }

                if !viewModel.realtimeManager.myReady {
                    Text("Loading questions...")
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                }
            }

            // Share link
            if let cid = challengeId ?? viewModel.challengeId {
                let shareURL = URL(string: "thetrash://challenge/\(cid.uuidString)")!
                ShareLink(item: shareURL, subject: Text("Trash Arena Challenge"), message: Text("I challenge you to a 1v1 Trash Arena duel! Tap to accept:")) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Challenge Link")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .red.opacity(0.4), radius: 12, y: 6)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Results Content

struct DuelResultsContent: View {
    @ObservedObject var viewModel: DuelViewModel
    let onDismiss: () -> Void

    @State private var showStats = false

    var iWon: Bool {
        viewModel.result?.winnerId == viewModel.myUserId
    }

    var isTie: Bool {
        viewModel.result?.winnerId == nil
    }

    var myFinalScore: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger ? result.challengerScore : result.opponentScore
    }

    var opponentFinalScore: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger ? result.opponentScore : result.challengerScore
    }

    var myPoints: Int {
        guard let result = viewModel.result else { return 0 }
        return viewModel.isChallenger ? (result.challengerPoints ?? 0) : (result.opponentPoints ?? 0)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Crown or tie icon
            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 10, x: -4, y: -4)

                if isTie {
                    Image(systemName: "equal.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                } else if iWon {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                } else {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(.neuSecondaryText)
                }
            }

            Text(isTie ? "It's a Tie!" : (iWon ? "You Win!" : "You Lose"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.neuText)

            // Score comparison
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("You")
                        .font(.caption.bold())
                        .foregroundColor(.neuSecondaryText)
                    Text("\(myFinalScore)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.neuAccentBlue)
                }

                Text("vs")
                    .font(.title3.bold())
                    .foregroundColor(.neuSecondaryText)

                VStack(spacing: 4) {
                    Text(viewModel.opponentDisplayName)
                        .font(.caption.bold())
                        .foregroundColor(.neuSecondaryText)
                    Text("\(opponentFinalScore)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
                    .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
            )
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)

            Text("+\(myPoints) points earned")
                .font(.headline)
                .foregroundColor(.neuAccentGreen)
                .opacity(showStats ? 1 : 0)

            Button(action: onDismiss) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left")
                    Text("Back to Arena")
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

            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showStats = true
            }
        }
    }
}
