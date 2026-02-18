//
//  StreakModeViewModel.swift
//  The Trash
//
//  Streak Mode: infinite questions until you get one wrong.
//  Batch-fetches 20 questions at a time, deduplicates, pre-fetches when 5 remain.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class StreakModeViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var isLoading = false
    @Published var imageCache: [UUID: UIImage] = [:]

    // Session state
    @Published var currentQuestionIndex = 0
    @Published var sessionScore = 0
    @Published var streakCount = 0
    @Published var sessionCompleted = false

    // Animation states
    @Published var showCorrectFeedback = false
    @Published var showWrongFeedback = false
    @Published var isSubmitting = false

    @Published var showError = false
    @Published var errorMessage = ""

    // Deduplication
    private var seenQuestionIds: Set<UUID> = []
    private var isFetchingMore = false

    private let batchSize = 20
    private let prefetchThreshold = 5

    private let client = SupabaseManager.shared.client

    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var questionsRemaining: Int {
        max(0, questions.count - currentQuestionIndex)
    }

    // MARK: - Data Fetching

    func fetchInitialQuestions() async {
        isLoading = true
        errorMessage = ""
        showError = false
        resetSession()

        do {
            let fetched: [QuizQuestion] = try await client
                .rpc("get_quiz_questions_batch", params: ["p_limit": batchSize])
                .execute()
                .value

            let newQuestions = fetched.filter { !seenQuestionIds.contains($0.id) }
            for q in newQuestions {
                seenQuestionIds.insert(q.id)
            }
            self.questions = newQuestions
            await preloadImages(for: newQuestions)
        } catch {
            errorMessage = "Failed to load questions: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func fetchMoreQuestions() async {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }

        do {
            let fetched: [QuizQuestion] = try await client
                .rpc("get_quiz_questions_batch", params: ["p_limit": batchSize])
                .execute()
                .value

            let newQuestions = fetched.filter { !seenQuestionIds.contains($0.id) }
            for q in newQuestions {
                seenQuestionIds.insert(q.id)
            }

            if !newQuestions.isEmpty {
                self.questions.append(contentsOf: newQuestions)
                await preloadImages(for: newQuestions)
            }
        } catch {
            print("⚠️ [Streak] Failed to fetch more questions: \(error)")
        }
    }

    // MARK: - Answer Submission

    func submitAnswer(selectedCategory: String) async {
        guard !isSubmitting else { return }
        guard let question = currentQuestion else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let isCorrect = selectedCategory == question.correctCategory

        if isCorrect {
            streakCount += 1
            let pointsEarned = 5

            sessionScore += pointsEarned

            withAnimation(.easeInOut(duration: 0.3)) {
                showCorrectFeedback = true
            }

            do {
                try await client.rpc("increment_credits", params: ["amount": pointsEarned]).execute()
            } catch {
                sessionScore -= pointsEarned
                streakCount -= 1
                print("❌ [Streak] Credit update failed: \(error)")
            }

            try? await Task.sleep(nanoseconds: 600_000_000)

            withAnimation(.easeOut(duration: 0.2)) {
                showCorrectFeedback = false
            }

            // Advance
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }

            // Pre-fetch if running low
            if questionsRemaining <= prefetchThreshold {
                Task { await fetchMoreQuestions() }
            }

        } else {
            // Wrong — streak over
            withAnimation(.easeInOut(duration: 0.3)) {
                showWrongFeedback = true
            }

            // Submit streak record
            if streakCount > 0 {
                await submitStreakRecord()
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)

            withAnimation(.easeOut(duration: 0.2)) {
                showWrongFeedback = false
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                sessionCompleted = true
            }
        }
    }

    private func submitStreakRecord() async {
        do {
            let _: UUID = try await client
                .rpc("submit_streak_record", params: ["p_streak_count": streakCount])
                .execute()
                .value
        } catch {
            print("❌ [Streak] Failed to submit streak record: \(error)")
        }
    }

    // MARK: - Session Management

    private func resetSession() {
        currentQuestionIndex = 0
        sessionScore = 0
        streakCount = 0
        sessionCompleted = false
        showCorrectFeedback = false
        showWrongFeedback = false
        seenQuestionIds.removeAll()
        imageCache.removeAll()
        questions.removeAll()
    }

    func startNewSession() async {
        await fetchInitialQuestions()
    }

    // MARK: - Image Loading

    private func preloadImages(for questionList: [QuizQuestion]) async {
        // Load all images in the batch concurrently
        await withTaskGroup(of: Void.self) { group in
            for q in questionList {
                if imageCache[q.id] != nil { continue }
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
                await MainActor.run {
                    imageCache[question.id] = image
                }
            }
        } catch {
            print("⚠️ [Streak] Failed to load image: \(error.localizedDescription)")
        }
    }
}
