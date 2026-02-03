//
//  TrashModels.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import Foundation
import SwiftUI

// 1. 修改结构体：加上 ", Equatable"
// 这样 Swift 就能自动比较两个垃圾结果是否相同
struct TrashAnalysisResult: Identifiable, Equatable {
    let id = UUID()
    let itemName: String
    let category: String
    let confidence: Double
    let actionTip: String
    let color: Color
}

// 2. 修改枚举：加上 ": Equatable"
// 这样 .animation 就能监听状态变化了
enum AppState: Equatable {
    case idle
    case analyzing
    case finished(TrashAnalysisResult)
}
