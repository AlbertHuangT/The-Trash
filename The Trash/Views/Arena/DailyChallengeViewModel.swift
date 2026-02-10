//
//  DailyChallengeViewModel.swift
//  The Trash
//
//  Daily Challenge: same 10 questions for everyone, once per day, timed.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class DailyChallengeViewModel: ObservableObject {
    @Published var challengeResponse: DailyChallengeResponse?
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var imageCache: [UUID: UIImage] = [:]

    // Session state
    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false
    @Published var alreadyPlayed = false

    // Timer (total elapsed time)
    @Published var elapsedSeconds: Double = 0
    private var timerCancellable: AnyCancellable?

    // Animation states
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboAnimation = false
    @Published var showComboBreak = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage = ""

    // Result
    @Published var pointsAwarded = 0

    private let client = SupabaseManager.shared.client

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    var formattedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        let tenths = Int((elapsedSeconds * 10).truncatingRemainder(dividingBy: 10))
        if mins > 0 {
            return String(format: "%d:%02d.%d", mins, secs, tenths)
        }
        return String(format: "%d.%d", secs, tenths)
    }

    // MARK: - Data Fetching

    func fetchChallenge() async {
        isLoading = true
        errorMessage = ""
        showError = false
        resetSession()

        do {
            let response: DailyChallengeResponse = try await client
                .rpc("get_daily_challenge")
                .execute()
                .value

            self.challengeResponse = response
            self.alreadyPlayed = response.alreadyPlayed
            self.questions = response.questions

            if !response.alreadyPlayed {
                await preloadImages()
                startTimer()
            }
        } catch {
            errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    // MARK: - Timer

    private func startTimer() {
        elapsedSeconds = 0
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 0.1
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
    }

    // MARK: - Answer Submission

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard let question = currentQuestion else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let isCorrect = selectedCategory == question.correctCategory

        if isCorrect {
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)

            var pointsEarned = 20
            if comboCount >= 3 {
                pointsEarned += (comboCount - 2) * 5
            }
            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }
        } else {
            let hadCombo = comboCount >= 3
            comboCount = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
                if hadCombo {
                    showComboBreak = true
                }
            }
        }

        try? await Task.sleep(nanoseconds: 800_000_000)

        withAnimation(.easeOut(duration: 0.2)) {
            showCorrectFeedback = false
            showWrongFeedback = false
            showComboAnimation = false
            showComboBreak = false
        }

        if currentQuestionIndex + 1 >= questions.count {
            stopTimer()
            await submitResult()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        }
    }

    private func submitResult() async {
        do {
            let params = DailyChallengeSubmitParams(
                p_score: sessionScore,
                p_correct_count: correctCount,
                p_time_seconds: elapsedSeconds,
                p_max_combo: maxCombo
            )
            let response: DailyChallengeSubmitResponse = try await client
                .rpc("submit_daily_challenge", params: params)
                .execute()
                .value

            self.pointsAwarded = response.pointsAwarded
            self.alreadyPlayed = true
        } catch {
            print("❌ [Daily] Failed to submit result: \(error)")
        }
    }

    // MARK: - Session Management

    private func resetSession() {
        currentQuestionIndex = 0
        sessionScore = 0
        comboCount = 0
        maxCombo = 0
        correctCount = 0
        sessionCompleted = false
        alreadyPlayed = false
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboBreak = false
        elapsedSeconds = 0
        pointsAwarded = 0
        imageCache.removeAll()
        questions.removeAll()
        challengeResponse = nil
        stopTimer()
    }

    // MARK: - Image Loading

    private func preloadImages() async {
        // Load all images concurrently (only 10 questions)
        await withTaskGroup(of: Void.self) { group in
            for question in questions {
                group.addTask { [weak self] in
                    await self?.loadImage(for: question)
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
                await MainActor.run {
                    imageCache[question.id] = image
                }
            }
        } catch {
            print("⚠️ [Daily] Failed to load image: \(error.localizedDescription)")
        }
    }
}
