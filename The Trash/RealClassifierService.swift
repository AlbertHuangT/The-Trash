//
//  RealClassifierService.swift
//  The Trash
//
//  Created by Albert Huang on 1/20/26.
//

import CoreML
import Vision
import UIKit
import SwiftUI
import Accelerate // Math-CS: 用于高性能向量计算 (DSP)

// 1. 定义知识库的数据结构 (对应 JSON)
struct TrashItem: Decodable {
    let label: String
    let category: String
    let embedding: [Float]
}

class RealClassifierService: TrashClassifierService {
    
    // 视觉模型 (The Eye)
    private let model: VNCoreMLModel?
    // 知识库 (The Brain)
    private var knowledgeBase: [TrashItem] = []
    
    init() {
        // ------------------------------------------------------------------
        // A. 加载知识库 (trash_knowledge.json)
        // ------------------------------------------------------------------
        if let url = Bundle.main.url(forResource: "trash_knowledge", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                self.knowledgeBase = try JSONDecoder().decode([TrashItem].self, from: data)
                print("✅ [System] 成功加载知识库: \(self.knowledgeBase.count) 个物体向量")
            } catch {
                print("❌ [Error] JSON 解析失败: \(error)")
            }
        } else {
            print("❌ [Error] 严重错误: 找不到 trash_knowledge.json 文件！请确保它在 Copy Bundle Resources 中。")
        }
        
        // ------------------------------------------------------------------
        // B. 加载视觉模型 (MobileCLIPImage)
        // ------------------------------------------------------------------
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // 使用 NPU 加速
            
            // ⚠️ 如果你的模型文件叫 MobileCLIPImage.mlpackage，类名就是 MobileCLIPImage
            // 如果报错 "Cannot find type..."，请检查你的文件名
            let coreModel = try MobileCLIPImage(configuration: config)
            self.model = try VNCoreMLModel(for: coreModel.model)
            print("✅ [System] MobileCLIP S2 视觉系统就绪")
        } catch {
            print("❌ [Error] 模型加载失败: \(error)")
            self.model = nil
        }
    }
    
    // MARK: - Classification Logic
    
    func classifyImage(image: UIImage, completion: @escaping (TrashAnalysisResult) -> Void) {
        guard let model = self.model, let ciImage = CIImage(image: image) else {
            print("⚠️ [Warning] 模型未初始化或图片无效")
            return
        }
        
        // MobileCLIP S2 训练时使用的是 CenterCrop
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            
            // 1. 获取图片向量 (Image Embedding)
            if let results = request.results as? [VNCoreMLFeatureValueObservation],
               let featureValue = results.first?.featureValue,
               let multiArray = featureValue.multiArrayValue {
                
                // 2. 将 MultiArray 转为高性能 Float 数组
                let imageEmbedding = self.convertMultiArray(multiArray)
                
                // 🔍 DEBUG: 打印 Top 5 (上帝视角)
                self.debugTopMatches(imageVector: imageEmbedding)
                
                // 3. 寻找最佳匹配
                if let bestMatch = self.findBestMatch(imageVector: imageEmbedding) {
                    
                    let result = TrashAnalysisResult(
                        itemName: bestMatch.item.label.capitalized,
                        category: bestMatch.item.category,
                        confidence: Double(bestMatch.score), // 这里的 score 是余弦相似度
                        actionTip: self.getTipForCategory(bestMatch.item.category),
                        color: self.getColorForCategory(bestMatch.item.category)
                    )
                    completion(result)
                    
                } else {
                    // 4. 兜底逻辑 (未达到阈值)
                    print("⚠️ [Result] 没有任何物体超过阈值 (0.15)")
                    let failResult = TrashAnalysisResult(
                        itemName: "Unknown Object",
                        category: "Try Closer",
                        confidence: 0.0,
                        actionTip: "I can't recognize this clearly. Try moving closer or improving lighting.",
                        color: .orange
                    )
                    completion(failResult)
                }
            }
        }
        
        // 图片预处理设置
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
        
        // 在后台线程执行推理，不阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [Error] Vision 请求失败: \(error)")
            }
        }
    }
    
    // MARK: - Math Kernels (Math-CS Core)
    
    // 寻找余弦相似度最高的物体
    private func findBestMatch(imageVector: [Float]) -> (item: TrashItem, score: Float)? {
        var bestScore: Float = -1.0
        var bestItem: TrashItem?
        
        // 1. 归一化图片向量 (Normalize Image Vector)
        // Cosine Similarity = (A . B) / (|A| * |B|)
        // 我们的 Text Vector 在 Colab 里已经归一化了 (|B|=1)，所以只要归一化 A，然后算点积即可
        let imageNorm = sqrt(imageVector.reduce(0) { $0 + $1 * $1 })
        let normalizedImage = imageVector.map { $0 / imageNorm }
        
        // 2. 遍历知识库计算点积
        for item in knowledgeBase {
            var score: Float = 0.0
            // vDSP_dotpr 是 Apple 提供的硬件加速点积函数，比 for 循环快 10 倍
            vDSP_dotpr(normalizedImage, 1, item.embedding, 1, &score, vDSP_Length(normalizedImage.count))
            
            if score > bestScore {
                bestScore = score
                bestItem = item
            }
        }
        
        // 3. 阈值判断 (Thresholding)
        // MobileCLIP 的分数通常在 0.2 - 0.3 之间就算很好了
        // 如果使用了 Ensemble (多提示词平均)，分数会更稳，但绝对值可能依然不高
        if bestScore < 0.10 { return nil }
        
        if let item = bestItem {
            return (item, bestScore)
        }
        return nil
    }
    
    // 辅助工具：MultiArray -> [Float]
    private func convertMultiArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var array = [Float](repeating: 0, count: count)
        // 直接内存指针拷贝，性能最高
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            array[i] = ptr[i]
        }
        return array
    }
    
    // MARK: - Debugging (上帝视角)
    
    private func debugTopMatches(imageVector: [Float]) {
        print("\n-------- 🧠 AI 思考过程 (Top 5) --------")
        
        let imageNorm = sqrt(imageVector.reduce(0) { $0 + $1 * $1 })
        let normalizedImage = imageVector.map { $0 / imageNorm }
        
        var allScores: [(name: String, score: Float)] = []
        
        for item in knowledgeBase {
            var score: Float = 0.0
            vDSP_dotpr(normalizedImage, 1, item.embedding, 1, &score, vDSP_Length(normalizedImage.count))
            allScores.append((item.label, score))
        }
        
        // 排序并取前 5
        let top5 = allScores.sorted { $0.score > $1.score }.prefix(5)
        
        for (index, match) in top5.enumerated() {
            // 打印格式：#1 Label -> Score
            print("👉 #\(index + 1) [\(match.name)] 得分: \(match.score)")
        }
        print("---------------------------------------\n")
    }
    
    // MARK: - UI Logic
    
    private func getColorForCategory(_ category: String) -> Color {
        if category == "IGNORE" { return .gray.opacity(0.5) }
        if category.contains("Blue") { return .blue }
        if category.contains("Green") { return .green }
        if category.contains("Black") { return .gray }
        if category.contains("HAZARDOUS") { return .red }
        return .orange
    }
    
    private func getTipForCategory(_ category: String) -> String {
        if category == "IGNORE" { return "please point at trash." }
        if category.contains("Blue") { return "Empty liquids. Flatten boxes. Check for CRV!" }
        if category.contains("Green") { return "Food scraps & soiled paper only." }
        if category.contains("Black") { return "Wrappers & styrofoam go here." }
        if category.contains("HAZARDOUS") { return "Do NOT bin! Take to E-waste center." }
        return "Check local guidelines."
    }
}
