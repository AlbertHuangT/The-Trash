//
//  ArenaViewModel.swift
//  Smart Sort
//
//  Extracted from ArenaView.swift
//

import Combine
import Supabase
import SwiftUI

// MARK: - ViewModel

@MainActor
class ArenaViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var totalCredits = 0
    @Published var imageCache: [UUID: UIImage] = [:]

    // Quiz Session State
    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var comboCount = 0
    @Published var maxCombo = 0
    @Published var correctCount = 0
    @Published var sessionCompleted = false

    // Animation States
    @Published var showPointAnimation = false
    @Published var pointAnimationText = ""
    @Published var showComboAnimation = false
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var showComboBreak = false

    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.shared.client
    private let gamificationService: GamificationServicing

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progressText: String {
        guard questions.count > 0 else { return "" }
        return "\(min(currentQuestionIndex + 1, questions.count))/\(questions.count)"
    }

    var isCurrentImageReady: Bool {
        guard let question = currentQuestion else { return false }
        return imageCache[question.id] != nil
    }

    init() {
        self.gamificationService = GamificationService.shared
    }

    init(gamificationService: GamificationServicing) {
        self.gamificationService = gamificationService
    }

    func fetchUserCredits() async {
        guard let userId = client.auth.currentUser?.id else { return }
        do {
            struct ProfileCredits: Decodable {
                let credits: Int
            }

            let profile: ProfileCredits =
                try await client
                .from("profiles")
                .select("credits")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.totalCredits = profile.credits
        } catch {
            print("❌ [Arena] Failed to fetch credits: \(error)")
        }
    }

    func fetchQuestions() async {
        isLoading = true
        errorMessage = nil
        showError = false
        resetSession()

        do {
            let fetchedQuestions: [QuizQuestion] =
                try await client
                .rpc("get_quiz_questions")
                .execute()
                .value

            self.questions = fetchedQuestions
            await fetchUserCredits()
            await preloadImages()

        } catch {
            print("❌ [Arena] Fetch Error: \(error)")
            errorMessage = "Failed to load quiz: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func preloadImages() async {
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
            print("⚠️ [Arena] Failed to load image for \(question.id): \(error.localizedDescription)")
        }
    }

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
        imageCache.removeAll()
    }

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
                let comboBonus = (comboCount - 2) * 5
                pointsEarned += comboBonus
            }

            sessionScore += pointsEarned
            totalCredits += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
                pointAnimationText = "+\(pointsEarned)"
                showPointAnimation = true

                if comboCount >= 3 {
                    showComboAnimation = true
                }
            }

            do {
                try await gamificationService.awardCredits(pointsEarned)
            } catch {
                totalCredits -= pointsEarned
                sessionScore -= pointsEarned
                correctCount -= 1
                comboCount = max(0, comboCount - 1)
                print("❌ [Arena] Credit update failed: \(error)")
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
            showPointAnimation = false
            showComboAnimation = false
            showComboBreak = false
        }

        if currentQuestionIndex + 1 >= questions.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        }
    }

    func startNewSession() async {
        await fetchQuestions()
    }
}
