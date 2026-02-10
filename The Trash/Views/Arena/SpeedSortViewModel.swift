//
//  SpeedSortViewModel.swift
//  The Trash
//
//  Speed Sort: 10 questions with 5-second countdown per question.
//  Time bonus: max(0, timeRemaining) × 4 extra points.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class SpeedSortViewModel: ObservableObject {
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

    // Timer
    @Published var timeRemaining: Double = 5.0
    let timePerQuestion: Double = 5.0
    private var timerCancellable: AnyCancellable?

    // Animation states
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboAnimation = false
    @Published var showComboBreak = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage = ""

    // Time bonus tracking
    @Published var lastTimeBonus = 0

    private let client = SupabaseManager.shared.client

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    // MARK: - Data Fetching

    func fetchQuestions() async {
        isLoading = true
        errorMessage = ""
        showError = false
        resetSession()

        do {
            let fetched: [QuizQuestion] = try await client
                .rpc("get_quiz_questions")
                .execute()
                .value

            self.questions = fetched
            await preloadImages()
            startTimer()
        } catch {
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    // MARK: - Timer

    func startTimer() {
        timeRemaining = timePerQuestion
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 0.1
                    if self.timeRemaining < 0 { self.timeRemaining = 0 }
                } else {
                    // Time's up — treat as wrong answer
                    self.timerCancellable?.cancel()
                    Task { await self.handleTimeout() }
                }
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
    }

    // MARK: - Answer Submission

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard let question = currentQuestion else { return }

        isSubmitting = true
        stopTimer()
        defer { isSubmitting = false }

        let isCorrect = selectedCategory == question.correctCategory

        if isCorrect {
            comboCount += 1
            correctCount += 1
            maxCombo = max(maxCombo, comboCount)

            // Base points
            var pointsEarned = 20

            // Combo bonus
            if comboCount >= 3 {
                pointsEarned += (comboCount - 2) * 5
            }

            // Time bonus: remaining seconds × 4
            let timeBonus = Int(max(0, timeRemaining) * 4)
            pointsEarned += timeBonus
            lastTimeBonus = timeBonus

            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }

            do {
                try await client.rpc("increment_credits", params: ["amount": pointsEarned]).execute()
            } catch {
                sessionScore -= pointsEarned
                correctCount -= 1
                comboCount -= 1
                print("❌ [SpeedSort] Credit update failed: \(error)")
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

        advanceToNext()
    }

    private func handleTimeout() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let hadCombo = comboCount >= 3
        comboCount = 0

        withAnimation(.easeInOut(duration: 0.3)) {
            showWrongFeedback = true
            if hadCombo {
                showComboBreak = true
            }
        }

        try? await Task.sleep(nanoseconds: 800_000_000)

        withAnimation(.easeOut(duration: 0.2)) {
            showWrongFeedback = false
            showComboBreak = false
        }

        advanceToNext()
    }

    private func advanceToNext() {
        if currentQuestionIndex + 1 >= questions.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
            startTimer()
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
        showCorrectFeedback = false
        showWrongFeedback = false
        showComboBreak = false
        timeRemaining = timePerQuestion
        lastTimeBonus = 0
        imageCache.removeAll()
        stopTimer()
    }

    func startNewSession() async {
        await fetchQuestions()
    }

    // MARK: - Image Loading

    private func preloadImages() async {
        let priorityQuestions = Array(questions.prefix(3))
        for question in priorityQuestions {
            await loadImage(for: question)
        }

        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            let maxConcurrent = 3

            for question in questions.dropFirst(3) {
                if imageCache[question.id] != nil { continue }

                if activeCount >= maxConcurrent {
                    await group.next()
                    activeCount -= 1
                }

                activeCount += 1
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
            print("⚠️ [SpeedSort] Failed to load image: \(error.localizedDescription)")
        }
    }
}
