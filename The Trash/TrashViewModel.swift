//
//  TrashViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI
import Combine

// --- 1. 修改协议：加上 image 参数 ---
// 规定：所有分类服务必须接收一张图片
protocol TrashClassifierService {
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void)
}

// --- 2. 修改 Mock 服务：适配协议 ---
class MockClassifierService: TrashClassifierService {
    // 这里也必须加上 image: UIImage，尽管我们在假代码里并不真的用它
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        // 模拟思考 1.5 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let mockData = [
                TrashAnalysisResult(itemName: "测试-压扁易拉罐", category: "可回收物", confidence: 0.98, actionTip: "请倒空液体，压扁投放。", color: .blue),
                TrashAnalysisResult(itemName: "测试-脏披萨盒", category: "干垃圾", confidence: 0.85, actionTip: "受污染的纸张无法回收。", color: .gray)
            ]
            completion(mockData.randomElement()!)
        }
    }
}

class TrashViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    
    private let classifier: TrashClassifierService
    
    // 初始化时，你可以传入 RealClassifierService() 来切换成真 AI
    init(classifier: TrashClassifierService = MockClassifierService()) {
        self.classifier = classifier
    }
    
    // --- 3. 修改调用逻辑 ---
    // 现在的 analyzeImage 需要接收一张图片了
    func analyzeImage(image: UIImage) {
        self.appState = .analyzing
        
        // 把图片传给 Service
        classifier.classifyImage(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.appState = .finished(result)
            }
        }
    }
    
    func reset() {
        self.appState = .idle
    }
}
