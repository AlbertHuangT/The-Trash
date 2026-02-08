//
//  TrashViewModel.swift
//  The Trash
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
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// MARK: - 2. ViewModel
@MainActor
class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    
    private let classifier: TrashClassifierService
    private let client = SupabaseManager.shared.client
    
    // 🔥 修改：移除了默认参数 = nil，强制要求传入 classifier
    // 这样你就永远不会意外用到假服务了
    init(classifier: TrashClassifierService) {
        self.classifier = classifier
    }
    
    func analyzeImage(image: UIImage) {
        guard appState != .analyzing else { return }
        
        // 🔥 Fix: Check for initialization error immediately
        if let initError = classifier.initializationError {
            self.appState = .error(initError)
            return
        }
        
        self.appState = .analyzing
        let startTime = Date()
        
        classifier.classifyImage(image: image) { [weak self] result in
            // Calculate delay on whatever thread we are on
            let elapsedTime = Date().timeIntervalSince(startTime)
            let delay = max(0, 0.5 - elapsedTime)
            
            // Explicitly jump back to MainActor to update UI
            Task { @MainActor [weak self] in
                // 🔥 Fix: Removed artificial delay for snappier UI
                
                self?.appState = .finished(result)
                
                if result.confidence > 0.8 {
                    self?.grantPoints(amount: 10)
                }
            }
        }
    }
    
    // MARK: - Feedback Logic
    
    func handleCorrectFeedback() {
        print("✅ User confirmed result.")
        grantPoints(amount: 5)
        self.reset()
    }
    
    func prepareForIncorrectFeedback(wrongResult: TrashAnalysisResult) {
        appState = .collectingFeedback(wrongResult)
    }

    func submitCorrection(
        image: UIImage,
        originalResult: TrashAnalysisResult,
        correctedCategory: String,
        correctedName: String?
    ) async {
        // 🔥 FIX: 防止重复提交
        guard case .collectingFeedback = appState else { return }
        
        print("--- 📤 SUBMITTING REPORT ---")
        
        // 🔥 FIX: 设置中间状态防止重复提交
        self.appState = .analyzing
        
        do {
            try await FeedbackService.shared.submitFeedback(
                image: image,
                predictedLabel: originalResult.itemName,
                predictedCategory: originalResult.category,
                correctCategory: correctedCategory,
                comment: correctedName ?? "",
                userId: client.auth.currentUser?.id
            )
            print("✅ Report uploaded successfully")
            grantPoints(amount: 20)
            // 🔥 FIX: 成功后重置状态
            self.reset()
        } catch {
            // 🔥 FIX: 检查是否被取消
            if Task.isCancelled {
                self.appState = .collectingFeedback(originalResult)
                return
            }
            print("❌ Upload failed: \(error)")
            // 🔥 设置错误状态让用户知道上传失败
            self.appState = .error("Failed to submit feedback: \(error.localizedDescription)")
        }
    }
    
    func reset() {
        self.appState = .idle
    }
    
    // MARK: - Gamification
    
    func grantPoints(amount: Int) {
        Task {
            do {
                _ = try await client.rpc("increment_credits", params: ["amount": amount]).execute()
                print("🎉 Points granted: \(amount)")
            } catch {
                print("❌ [Gamification] Error: \(error)")
            }
        }
    }
}
