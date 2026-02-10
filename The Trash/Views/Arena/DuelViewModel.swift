//
//  DuelViewModel.swift
//  The Trash
//
//  Orchestrates the 1v1 duel flow: lobby → countdown → quiz → results.
//

import SwiftUI
import Combine
import Supabase

enum DuelPhase {
    case loading
    case lobby          // Waiting for opponent
    case countdown      // 3-2-1 countdown
    case playing        // Answering questions
    case waitingResult  // Done answering, waiting for opponent
    case results        // Final results
    case error(String)
}

@MainActor
class DuelViewModel: ObservableObject {
    @Published var phase: DuelPhase = .loading
    @Published var questions: [QuizQuestion] = []
    @Published var imageCache: [UUID: UIImage] = [:]

    // Session state
    @Published var currentQuestionIndex = 0
    @Published var correctCount = 0
    @Published var myScore = 0

    // Animation states
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var isSubmitting = false

    // Countdown
    @Published var countdownValue = 3

    // Challenge info
    @Published var challengeId: UUID?
    @Published var channelName: String?
    @Published var challengerId: UUID?
    @Published var opponentId: UUID?
    @Published var challengerName: String?
    @Published var opponentName: String?

    // Results
    @Published var result: CompleteChallengeResponse?

    let realtimeManager = DuelRealtimeManager()
    private let arenaService = ArenaService.shared
    private let client = SupabaseManager.shared.client
    private var answerStartTime: Date?

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    var myUserId: UUID? {
        client.auth.currentUser?.id
    }

    var isChallenger: Bool {
        myUserId == challengerId
    }

    var myDisplayName: String {
        if isChallenger { return challengerName ?? "You" }
        return opponentName ?? "You"
    }

    var opponentDisplayName: String {
        if isChallenger { return opponentName ?? "Opponent" }
        return challengerName ?? "Opponent"
    }

    // MARK: - Start as Challenger (create challenge)

    func createChallenge(opponentId: UUID) async {
        phase = .loading
        do {
            let response = try await arenaService.createChallenge(opponentId: opponentId)
            self.challengeId = response.challengeId
            self.channelName = response.channelName
            self.challengerId = myUserId
            self.opponentId = opponentId

            // Connect to realtime
            if let myId = myUserId {
                await realtimeManager.connect(
                    channelName: response.channelName,
                    myId: myId,
                    opponentId: opponentId
                )
            }

            phase = .lobby
        } catch {
            phase = .error("Failed to create challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Start as Acceptor

    func acceptChallenge(challengeId: UUID) async {
        phase = .loading
        self.challengeId = challengeId

        do {
            let response = try await arenaService.acceptChallenge(challengeId: challengeId)
            self.channelName = response.channelName
            self.challengerId = response.challengerId
            self.opponentId = response.opponentId
            self.questions = response.questions

            // Connect to realtime
            if let myId = myUserId {
                let oppId = isChallenger ? response.opponentId : response.challengerId
                await realtimeManager.connect(
                    channelName: response.channelName,
                    myId: myId,
                    opponentId: oppId
                )
            }

            await preloadImages()
            await realtimeManager.sendReady()

            // Watch for both ready
            observeBothReady()

            phase = .lobby
        } catch {
            phase = .error("Failed to accept challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Join as Challenger (after opponent accepts)

    func joinAsChallenger(challengeId: UUID) async {
        phase = .loading
        self.challengeId = challengeId

        do {
            let response = try await arenaService.getChallengeQuestions(challengeId: challengeId)
            self.channelName = response.channelName
            self.challengerId = response.challengerId
            self.opponentId = response.opponentId
            self.questions = response.questions

            if let myId = myUserId {
                let oppId = isChallenger ? response.opponentId : response.challengerId
                await realtimeManager.connect(
                    channelName: response.channelName,
                    myId: myId,
                    opponentId: oppId
                )
            }

            await preloadImages()
            await realtimeManager.sendReady()

            observeBothReady()

            phase = .lobby
        } catch {
            phase = .error("Failed to load challenge: \(error.localizedDescription)")
        }
    }

    private func observeBothReady() {
        // Watch for both ready to trigger countdown
        let cancellable = realtimeManager.$bothReady
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.startCountdown()
                }
            }
        // Keep reference alive
        _bothReadyCancellable = cancellable
    }

    private var _bothReadyCancellable: AnyCancellable?

    // MARK: - Countdown

    private func startCountdown() {
        phase = .countdown
        countdownValue = 3

        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                countdownValue = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            answerStartTime = Date()
            phase = .playing
        }
    }

    // MARK: - Answer Submission

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard let cid = challengeId else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let answerTime = Int((Date().timeIntervalSince(answerStartTime ?? Date())) * 1000)

        do {
            let response = try await arenaService.submitDuelAnswer(
                challengeId: cid,
                questionIndex: currentQuestionIndex,
                selectedCategory: selectedCategory,
                answerTimeMs: answerTime
            )

            if response.isCorrect {
                correctCount += 1
                myScore += 20

                withAnimation(.easeInOut(duration: 0.3)) {
                    showCorrectFeedback = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWrongFeedback = true
                }
            }

            // Broadcast answer to opponent
            await realtimeManager.sendAnswerSubmitted(
                questionIndex: currentQuestionIndex,
                isCorrect: response.isCorrect
            )

            try? await Task.sleep(nanoseconds: 600_000_000)

            withAnimation(.easeOut(duration: 0.2)) {
                showCorrectFeedback = false
                showWrongFeedback = false
            }

            answerStartTime = Date()

            if currentQuestionIndex + 1 >= questions.count {
                // Done answering
                await realtimeManager.sendFinished(totalCorrect: correctCount, totalScore: myScore)
                await completeAndShowResults()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentQuestionIndex += 1
                }
            }
        } catch {
            print("❌ [Duel] Submit answer failed: \(error)")
        }
    }

    // MARK: - Complete

    private func completeAndShowResults() async {
        phase = .waitingResult

        guard let cid = challengeId else { return }

        do {
            let response = try await arenaService.completeChallenge(challengeId: cid)
            self.result = response
            phase = .results
        } catch {
            phase = .error("Failed to complete challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    func cleanup() async {
        _bothReadyCancellable?.cancel()
        await realtimeManager.disconnect()
    }

    // MARK: - Image Loading

    private func preloadImages() async {
        let priority = Array(questions.prefix(3))
        for q in priority {
            await loadImage(for: q)
        }

        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            let maxConcurrent = 3

            for q in questions.dropFirst(3) {
                if imageCache[q.id] != nil { continue }
                if activeCount >= maxConcurrent {
                    await group.next()
                    activeCount -= 1
                }
                activeCount += 1
                group.addTask { [weak self] in
                    await self?.loadImage(for: q)
                }
            }
        }
    }

    private func loadImage(for question: QuizQuestion) async {
        guard imageCache[question.id] == nil else { return }
        do {
            guard let url = URL(string: question.imageUrl) else { return }
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedImage = await Task.detached(priority: .userInitiated) {
                return UIImage(data: data)?.preparingForDisplay()
            }.value
            if let image = decodedImage {
                await MainActor.run { imageCache[question.id] = image }
            }
        } catch {
            print("⚠️ [Duel] Failed to load image: \(error)")
        }
    }
}
