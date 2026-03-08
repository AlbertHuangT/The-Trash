//
//  TrashViewModel.swift
//  Smart Sort
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

// MARK: - 1. Protocol
protocol TrashClassifierService {
    var initializationError: String? { get }
    var isReady: Bool { get }
    func prepare() async
    func classifyImage(image: UIImage) async -> TrashAnalysisResult
}

enum ClassifierPreparationState: Equatable {
    case idle
    case preparing
    case ready
    case failed(String)
}

// MARK: - 2. ViewModel
@MainActor
class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    @Published private(set) var classifierPreparationState: ClassifierPreparationState = .idle
    @Published private(set) var currentPhotoModeration = PhotoModerationResult()
    @Published private(set) var currentScanID: UUID?
    
    private let classifier: TrashClassifierService
    private let client = SupabaseManager.shared.client
    private let feedbackService: FeedbackSubmitting
    private let gamificationService: GamificationServicing
    private let photoModerationService: PhotoModerating
    
    // Require an explicit classifier so tests and previews do not silently use a fake default
    init(classifier: TrashClassifierService) {
        self.classifier = classifier
        self.feedbackService = FeedbackService.shared
        self.gamificationService = GamificationService.shared
        self.photoModerationService = PhotoModerationService.shared
    }

    init(
        classifier: TrashClassifierService,
        feedbackService: FeedbackSubmitting,
        gamificationService: GamificationServicing,
        photoModerationService: PhotoModerating
    ) {
        self.classifier = classifier
        self.feedbackService = feedbackService
        self.gamificationService = gamificationService
        self.photoModerationService = photoModerationService
    }

    func prepareClassifier() async {
        if let initError = classifier.initializationError {
            classifierPreparationState = .failed(initError)
            return
        }

        if classifier.isReady {
            classifierPreparationState = .ready
            return
        }

        guard classifierPreparationState != .preparing else { return }
        classifierPreparationState = .preparing
        await classifier.prepare()

        if let initError = classifier.initializationError {
            classifierPreparationState = .failed(initError)
        } else {
            classifierPreparationState = classifier.isReady ? .ready : .preparing
        }
    }
    
    func analyzeImage(image: UIImage) {
        guard appState != .analyzing else { return }
        
        // Check for initialization errors before starting analysis
        if let initError = classifier.initializationError {
            classifierPreparationState = .failed(initError)
            self.appState = .error(initError)
            return
        }

        self.appState = .analyzing
        self.currentScanID = UUID()

        Task {
            if !self.classifier.isReady {
                await self.prepareClassifier()
            }

            guard self.classifier.isReady else {
                let message =
                    self.classifier.initializationError
                    ?? "AI is still preparing. Please try again in a moment."
                self.appState = .error(message)
                return
            }

            let moderation = await photoModerationService.evaluate(image)
            self.currentPhotoModeration = moderation

            if moderation.isBlurry {
                LogManager.shared.log(
                    "Photo rejected before classification due to blur score \(moderation.blurScore)",
                    level: .info,
                    category: "PhotoModeration"
                )
                self.appState = .error("Photo looks too blurry. Please retake and try again.")
                return
            }

            let result = await classifier.classifyImage(image: image)
            if self.classifier.isReady {
                self.classifierPreparationState = .ready
            }
            if result.representsClassifierFailure {
                self.appState = .error(result.actionTip)
            } else {
                self.appState = .finished(result)
            }
        }
    }
    
    // MARK: - Feedback Logic
    
    func handleCorrectFeedback(image: UIImage?) {
        LogManager.shared.log("User confirmed result", level: .info, category: "Feedback")

        if let image,
           !currentPhotoModeration.containsFace,
           case .finished(let result) = appState
        {
            Task {
                do {
                    try await feedbackService.submitConfirmedQuizCandidate(
                        image: image,
                        predictedLabel: result.itemName,
                        predictedCategory: result.category,
                        userId: client.auth.currentUser?.id
                    )
                } catch {
                    LogManager.shared.log(
                        "Quiz candidate upload failed: \(error)",
                        level: .warning,
                        category: "Feedback"
                    )
                }
            }
        }

        awardVerifyReward(kind: .confirmed)
        self.reset()
    }
    
    func prepareForIncorrectFeedback(wrongResult: TrashAnalysisResult) {
        appState = .collectingFeedback(wrongResult)
    }

    func submitCorrection(
        image: UIImage,
        originalResult: TrashAnalysisResult,
        correctedName: String
    ) async {
        // Prevent duplicate submissions
        guard case .collectingFeedback = appState else { return }
        let trimmedCorrection = correctedName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCorrection.isEmpty else {
            self.appState = .error("Please enter the correct item name before submitting.")
            return
        }

        if currentPhotoModeration.containsFace {
            LogManager.shared.log(
                "Feedback upload blocked because photo contains a face",
                level: .info,
                category: "PhotoModeration"
            )
            self.appState = .error("This photo includes a face, so it can't be uploaded as feedback. Please retake without people in frame.")
            return
        }

        LogManager.shared.log("Submitting report...", level: .info, category: "Feedback")

        // Move into a submitting state to block double taps
        self.appState = .submittingFeedback(originalResult)

        do {
            try await feedbackService.submitFeedback(
                image: image,
                predictedLabel: originalResult.itemName,
                predictedCategory: originalResult.category,
                correctedName: trimmedCorrection,
                userId: client.auth.currentUser?.id
            )
            LogManager.shared.log("Report uploaded successfully", level: .info, category: "Feedback")
            awardVerifyReward(kind: .correction)
            // Reset after a successful submission
            self.reset()
        } catch {
            // Restore state cleanly if the task was cancelled
            if Task.isCancelled {
                self.appState = .collectingFeedback(originalResult)
                return
            }
            LogManager.shared.log("Upload failed: \(error)", level: .error, category: "Feedback")
            // Surface the upload failure to the UI
            self.appState = .error("Failed to submit feedback: \(error.localizedDescription)")
        }
    }
    
    func reset() {
        currentPhotoModeration = PhotoModerationResult()
        currentScanID = nil
        self.appState = .idle
    }
    
    // MARK: - Gamification
    
    private func awardVerifyReward(kind: VerifyRewardKind) {
        guard let user = client.auth.currentUser else { return }
        guard let scanID = currentScanID else { return }
        let isAnonymous = (user.email == nil || user.email?.isEmpty == true) &&
                          (user.phone == nil || user.phone?.isEmpty == true)
        guard !isAnonymous else { return }

        Task {
            do {
                let response = try await gamificationService.awardVerifyReward(scanId: scanID, kind: kind)
                let logMessage = response.awarded
                    ? "Verify reward granted: \(response.creditsAwarded)"
                    : "Verify reward skipped: \(response.reason ?? "unknown")"
                LogManager.shared.log(logMessage, level: .info, category: "Gamification")
            } catch {
                LogManager.shared.log("Gamification error: \(error)", level: .error, category: "Gamification")
            }
        }
    }
}
