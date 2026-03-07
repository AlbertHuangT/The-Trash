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
    
    private let classifier: TrashClassifierService
    private let client = SupabaseManager.shared.client
    private let feedbackService: FeedbackSubmitting
    private let gamificationService: GamificationServicing
    
    // 🔥 修改：移除了默认参数 = nil，强制要求传入 classifier
    // 这样你就永远不会意外用到假服务了
    init(classifier: TrashClassifierService) {
        self.classifier = classifier
        self.feedbackService = FeedbackService.shared
        self.gamificationService = GamificationService.shared
    }

    init(
        classifier: TrashClassifierService,
        feedbackService: FeedbackSubmitting,
        gamificationService: GamificationServicing
    ) {
        self.classifier = classifier
        self.feedbackService = feedbackService
        self.gamificationService = gamificationService
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
        
        // 🔥 Fix: Check for initialization error immediately
        if let initError = classifier.initializationError {
            classifierPreparationState = .failed(initError)
            self.appState = .error(initError)
            return
        }

        if !classifier.isReady {
            Task {
                await prepareClassifier()
            }
        }
        
        self.appState = .analyzing

        Task {
            let result = await classifier.classifyImage(image: image)
            if self.classifier.isReady {
                self.classifierPreparationState = .ready
            }
            self.appState = .finished(result)
        }
    }
    
    // MARK: - Feedback Logic
    
    func handleCorrectFeedback() {
        LogManager.shared.log("User confirmed result", level: .info, category: "Feedback")
        grantPoints(amount: 10)
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
        // 🔥 FIX: 防止重复提交
        guard case .collectingFeedback = appState else { return }

        LogManager.shared.log("Submitting report...", level: .info, category: "Feedback")

        // 🔥 FIX: 设置中间状态防止重复提交
        self.appState = .analyzing

        do {
            try await feedbackService.submitFeedback(
                image: image,
                predictedLabel: originalResult.itemName,
                predictedCategory: originalResult.category,
                correctedName: correctedName,
                userId: client.auth.currentUser?.id
            )
            LogManager.shared.log("Report uploaded successfully", level: .info, category: "Feedback")
            grantPoints(amount: 20)
            // 🔥 FIX: 成功后重置状态
            self.reset()
        } catch {
            // 🔥 FIX: 检查是否被取消
            if Task.isCancelled {
                self.appState = .collectingFeedback(originalResult)
                return
            }
            LogManager.shared.log("Upload failed: \(error)", level: .error, category: "Feedback")
            // 🔥 设置错误状态让用户知道上传失败
            self.appState = .error("Failed to submit feedback: \(error.localizedDescription)")
        }
    }
    
    func reset() {
        self.appState = .idle
    }
    
    // MARK: - Gamification
    
    func grantPoints(amount: Int) {
        guard let user = client.auth.currentUser else { return }
        let isAnonymous = (user.email == nil || user.email?.isEmpty == true) &&
                          (user.phone == nil || user.phone?.isEmpty == true)
        guard !isAnonymous else { return }

        Task {
            do {
                try await gamificationService.awardVerifyCredits(amount)
                LogManager.shared.log("Points granted: \(amount)", level: .info, category: "Gamification")
            } catch {
                LogManager.shared.log("Gamification error: \(error)", level: .error, category: "Gamification")
            }
        }
    }
}
