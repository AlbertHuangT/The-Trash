//
//  TrashViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase // 引入 Supabase

// MARK: - 1. 分类服务协议 (Protocol)
protocol TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// MARK: - 2. 模拟服务 (Mock Service)
class MockClassifierService: TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let mockData = [
                TrashAnalysisResult(
                    itemName: "Mock-Soda Can",
                    category: "Recycle (Blue Bin)",
                    confidence: 0.98,
                    actionTip: "Empty liquids. Flatten to save space.",
                    color: .blue
                ),
                TrashAnalysisResult(
                    itemName: "Mock-Pizza Box",
                    category: "Compost (Green Bin)",
                    confidence: 0.85,
                    actionTip: "Greasy paper cannot be recycled. Compost it.",
                    color: .green
                )
            ]
            completion(mockData.randomElement()!)
        }
    }
}

// MARK: - 3. 视图模型 (ViewModel)
class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    private let classifier: TrashClassifierService
    
    // 🔥 新增：Supabase 客户端引用
    private let client = SupabaseManager.shared.client
    
    init(classifier: TrashClassifierService = MockClassifierService()) {
        self.classifier = classifier
    }
    
    /// 核心方法：处理图片并更新状态
    func analyzeImage(image: UIImage) {
        // 1. 设置状态
        self.appState = .analyzing
        
        // 2. 调用服务
        classifier.classifyImage(image: image) { [weak self] result in
            // 3. 确保 UI 更新发生在主线程
            DispatchQueue.main.async {
                self?.appState = .finished(result)
                
                // 🔥 游戏化逻辑：识别成功且置信度不错，则加分
                if result.confidence > 0.4 {
                    self?.grantPoints(amount: 20)
                }
            }
        }
    }
    
    /// 重置回初始状态
    func reset() {
        self.appState = .idle
    }
    
    // MARK: - Gamification (RPC Call)
    
    /// 调用数据库函数增加积分
    func grantPoints(amount: Int) {
        Task {
            do {
                // 调用 Supabase 的 increment_credits 函数
                try await client.rpc("increment_credits", params: ["amount": amount])
                print("✅ [Gamification]积分增加成功: +\(amount)")
            } catch {
                print("❌ [Gamification]积分增加失败: \(error)")
            }
        }
    }
}
