//
//  DuelViewModel.swift
//  The Trash
//
//  Orchestrates the 1v1 duel flow: lobby → countdown → quiz → results.
//

import Combine
import Supabase
import SwiftUI

enum DuelPhase {
    case loading
    case lobby  // Waiting for opponent
    case countdown  // 3-2-1 countdown
    case playing  // Answering questions
    case waitingResult  // Done answering, waiting for opponent
    case results  // Final results
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

            // When opponent accepts and sends player_ready, fetch questions and get ready
            observeOpponentReadyThenLoad()

            phase = .lobby
        } catch {
            phase = .error("Failed to create challenge: \(error.localizedDescription)")
        }
    }

    /// Challenger waits for opponent to accept and send ready, then fetches questions
    private func observeOpponentReadyThenLoad() {
        _opponentReadyCancellable = realtimeManager.$opponentReady
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadQuestionsAndSendReady()
                }
            }
    }

    /// Challenger fetches questions after opponent accepts, preloads images, and sends ready
    private func loadQuestionsAndSendReady() async {
        guard let cid = challengeId else { return }
        do {
            let response = try await arenaService.getChallengeQuestions(challengeId: cid)
            self.questions = response.questions
            self.challengerId = response.challengerId
            self.opponentId = response.opponentId

            await preloadImages()
            await realtimeManager.sendReady()
            observeBothReady()
        } catch {
            phase = .error("Failed to load questions: \(error.localizedDescription)")
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
    private var _opponentReadyCancellable: AnyCancellable?
    private var _opponentFinishedCancellable: AnyCancellable?
    private var countdownTask: Task<Void, Never>?
    private var finalizeRetryTask: Task<Void, Never>?

    // MARK: - Countdown

    private func startCountdown() {
        phase = .countdown
        countdownValue = 3

        countdownTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                countdownValue = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
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
                await beginResultFinalization()
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

    private func beginResultFinalization() async {
        phase = .waitingResult

        if realtimeManager.opponentFinished {
            await completeChallengeWithRetry()
            return
        }

        _opponentFinishedCancellable?.cancel()
        _opponentFinishedCancellable = realtimeManager.$opponentFinished
            .removeDuplicates()
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.completeChallengeWithRetry()
                }
            }

        finalizeRetryTask?.cancel()
        finalizeRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self else { return }
            guard case .waitingResult = self.phase else { return }
            await self.completeChallengeWithRetry(
                maxAttempts: 45, retryDelayNanoseconds: 1_000_000_000)
        }
    }

    private func completeChallengeWithRetry(
        maxAttempts: Int = 30, retryDelayNanoseconds: UInt64 = 1_200_000_000
    ) async {
        guard let cid = challengeId else { return }

        for attempt in 0..<maxAttempts {
            do {
                let response = try await arenaService.completeChallenge(challengeId: cid)
                self.result = response
                phase = .results
                return
            } catch {
                let isRetryable = isCompletionPendingError(error)
                let hasMoreAttempts = attempt < (maxAttempts - 1)

                if isRetryable && hasMoreAttempts {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                    continue
                }

                phase = .error("Failed to complete challenge: \(error.localizedDescription)")
                return
            }
        }
    }

    private func isCompletionPendingError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not complete yet") || message.contains("not ready for completion")
            || message.contains("challenge is not active")
    }

    // MARK: - Cleanup

    func cleanup() async {
        countdownTask?.cancel()
        finalizeRetryTask?.cancel()
        _bothReadyCancellable?.cancel()
        _opponentReadyCancellable?.cancel()
        _opponentFinishedCancellable?.cancel()
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
