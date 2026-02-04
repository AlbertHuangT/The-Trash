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
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// MARK: - 2. Mock Service
class MockClassifierService: TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockData = [
                TrashAnalysisResult(
                    itemName: "Mock-Soda Can",
                    category: "Recycle (Blue Bin)",
                    confidence: 0.98,
                    actionTip: "Empty liquids. Flatten to save space.",
                    color: .blue
                )
            ]
            completion(mockData.randomElement()!)
        }
    }
}

// MARK: - 3. ViewModel
@MainActor
class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    
    private let classifier: TrashClassifierService
    private let client = SupabaseManager.shared.client
    
    // 🔥 Fix: 确保 init 也是 MainActor，避免初始化并发问题
    init(classifier: TrashClassifierService = MockClassifierService()) {
        self.classifier = classifier
    }
    
    func analyzeImage(image: UIImage) {
        self.appState = .analyzing
        
        classifier.classifyImage(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.appState = .finished(result)
                
                if result.confidence > 0.4 {
                    self?.grantPoints(amount: 20)
                }
            }
        }
    }
    
    // MARK: - Feedback Logic
    
    func handleCorrectFeedback() {
        print("User confirmed result was correct.")
        self.reset()
    }
    
    func prepareForIncorrectFeedback(wrongResult: TrashAnalysisResult) {
        appState = .collectingFeedback(wrongResult)
    }

    func submitCorrection(originalResult: TrashAnalysisResult, correctedCategory: String, correctedName: String?) async {
        print("--- REPORT SUBMITTED ---")
        print("User corrected to: \(correctedCategory)")
        try? await Task.sleep(nanoseconds: 500_000_000)
        self.reset()
    }
    
    func reset() {
        self.appState = .idle
    }
    
    // MARK: - Gamification
    
    func grantPoints(amount: Int) {
        Task {
            do {
                // 🔥 Fix:
                // 1. 添加 .execute() 确保请求真正发送
                // 2. 使用 _ = 消除 "result unused" 警告
                _ = try await client.rpc("increment_credits", params: ["amount": amount]).execute()
            } catch {
                print("❌ [Gamification] Error: \(error)")
            }
        }
    }
}
