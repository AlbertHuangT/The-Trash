//
//  TrashModels.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI

// 1. 垃圾分析结果
struct TrashAnalysisResult: Identifiable, Equatable {
    let id = UUID()
    let itemName: String
    let category: String
    let confidence: Double
    let actionTip: String
    let color: Color
}

// 2. App 运行状态 (统一在这里定义)
// 注意：移除了 TrashViewModel.swift 里的重复定义
enum AppState: Equatable {
    case idle
    case analyzing
    case finished(TrashAnalysisResult)
    // ✨ 新增：Tinder 交互需要的状态
    case collectingFeedback(TrashAnalysisResult)
    case error(String)
}
