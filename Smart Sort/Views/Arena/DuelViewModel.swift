//
//  DuelViewModel.swift
//  Smart Sort
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
class DuelViewModel: ObservableObject, ArenaImageManaging {
    @Published var phase: DuelPhase = .loading
    @Published var questions: [QuizQuestion] = []
    @Published var imageCache: [UUID: UIImage] = [:]
    @Published var failedImageIDs: Set<UUID> = []

    // Session state
    @Published var currentQuestionIndex = 0
    @Published var correctCount = 0
    @Published var myScore = 0
    @Published var lastCorrectCategory: String?

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
    @Published private(set) var duelState: DuelStateResponse?
    @Published private(set) var myReady = false
    @Published private(set) var opponentReady = false
    @Published private(set) var bothReady = false
    @Published private(set) var myFinished = false
    @Published private(set) var opponentFinished = false
    @Published private(set) var opponentProgress = 0
    @Published private(set) var opponentCorrect = 0

    // Results
    @Published var result: CompleteChallengeResponse?

    let realtimeManager = DuelRealtimeManager()
    private let arenaService = ArenaService.shared
    private let client = SupabaseManager.shared.client
    private var answerStartTime: Date?
    private var duelStatePollingTask: Task<Void, Never>?
    private var isLoadingQuestions = false
    private var hasMarkedReady = false
    private var isCompletingChallenge = false
    var imageLoadHandles: [UUID: ArenaImageLoadHandle] = [:]
    let imageLogPrefix = "Duel"

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
        hasMarkedReady = false
        myFinished = false
        opponentFinished = false
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

            beginStateMonitoring()
            phase = .lobby
        } catch {
            phase = .error("Failed to create challenge: \(error.localizedDescription)")
        }
    }

    private func loadQuestionsAndMarkReady() async {
        guard let cid = challengeId else { return }
        guard !isLoadingQuestions else { return }
        isLoadingQuestions = true
        defer { isLoadingQuestions = false }

        do {
            let response = try await arenaService.getChallengeQuestions(challengeId: cid)
            self.questions = response.questions
            self.challengerId = response.challengerId
            self.opponentId = response.opponentId

            _ = await primeArenaImages(for: response.questions)
            await markReady()
        } catch {
            phase = .error("Failed to load questions: \(error.localizedDescription)")
        }
    }

    // MARK: - Start as Acceptor

    func acceptChallenge(challengeId: UUID) async {
        phase = .loading
        self.challengeId = challengeId
        hasMarkedReady = false
        myFinished = false
        opponentFinished = false

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

            _ = await primeArenaImages(for: response.questions)
            await markReady()
            beginStateMonitoring()

            phase = .lobby
        } catch {
            phase = .error("Failed to accept challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Join as Challenger (after opponent accepts)

    func joinAsChallenger(challengeId: UUID) async {
        phase = .loading
        self.challengeId = challengeId
        hasMarkedReady = false
        myFinished = false
        opponentFinished = false

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

            _ = await primeArenaImages(for: response.questions)
            await markReady()
            beginStateMonitoring()

            phase = .lobby
        } catch {
            phase = .error("Failed to load challenge: \(error.localizedDescription)")
        }
    }

    private var countdownTask: Task<Void, Never>?

    private func beginStateMonitoring() {
        duelStatePollingTask?.cancel()
        duelStatePollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshDuelState()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func refreshDuelState() async {
        guard let cid = challengeId else { return }

        do {
            let state = try await arenaService.getDuelState(challengeId: cid)
            await applyDuelState(state)
        } catch {
            if case .results = phase {
                return
            }
            if case .error = phase {
                return
            }
            phase = .error("Failed to sync duel state: \(error.localizedDescription)")
        }
    }

    private func applyDuelState(_ state: DuelStateResponse) async {
        duelState = state
        myReady = isChallenger ? state.challengerReady : state.opponentReady
        opponentReady = isChallenger ? state.opponentReady : state.challengerReady
        bothReady = state.bothReady
        myFinished = isChallenger ? state.challengerFinished : state.opponentFinished
        opponentFinished = isChallenger ? state.opponentFinished : state.challengerFinished
        opponentProgress = isChallenger ? state.opponentProgress : state.challengerProgress
        opponentCorrect = isChallenger ? state.opponentCorrect : state.challengerCorrect

        if let stateStartedAt = state.startedAt, !stateStartedAt.isEmpty, case .lobby = phase, bothReady {
            startCountdown()
        }

        if state.status == "accepted" || state.status == "in_progress" {
            if isChallenger && questions.isEmpty {
                await loadQuestionsAndMarkReady()
                return
            }

            if !questions.isEmpty && !hasMarkedReady {
                await markReady()
                return
            }
        }

        if state.status == "completed" {
            await completeChallengeIfNeeded()
            return
        }

        if state.status == "expired" {
            phase = .error("Challenge has expired.")
            return
        }

        if case .waitingResult = phase, myFinished {
            await completeChallengeIfNeeded()
        }
    }

    private func markReady() async {
        guard let cid = challengeId else { return }
        guard !hasMarkedReady else { return }

        do {
            let state = try await arenaService.markDuelReady(challengeId: cid)
            hasMarkedReady = true
            await realtimeManager.sendReady()
            await applyDuelState(state)
        } catch {
            phase = .error("Failed to mark duel ready: \(error.localizedDescription)")
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        guard case .lobby = phase else { return }
        countdownTask?.cancel()
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

            lastCorrectCategory = response.correctCategory

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
                myFinished = true
                await beginResultFinalization()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentQuestionIndex += 1
                }
                scheduleUpcomingArenaImages(for: questions, startingAt: currentQuestionIndex)
            }
        } catch {
            print("❌ [Duel] Submit answer failed: \(error)")
        }
    }

    // MARK: - Complete

    private func beginResultFinalization() async {
        phase = .waitingResult
        await completeChallengeIfNeeded()
    }

    private func completeChallengeIfNeeded() async {
        guard let cid = challengeId else { return }
        guard !isCompletingChallenge else { return }
        isCompletingChallenge = true
        defer { isCompletingChallenge = false }

        do {
            let response = try await arenaService.completeChallenge(challengeId: cid)
            switch response.status {
            case "completed":
                self.result = response
                phase = .results
            case "waiting_for_opponent":
                phase = .waitingResult
            case "expired":
                phase = .error(response.message ?? "Challenge has expired.")
            case "inactive":
                phase = .error(response.message ?? "Challenge is no longer active.")
            default:
                phase = .waitingResult
            }
        } catch {
            phase = .error("Failed to complete challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    func cleanup() async {
        cancelArenaImageLoads()
        countdownTask?.cancel()
        duelStatePollingTask?.cancel()
        await realtimeManager.disconnect()
    }

    func retryCurrentImage() {
        guard let question = currentQuestion else { return }
        scheduleArenaImageLoad(for: question, forceReload: true)
    }
}
