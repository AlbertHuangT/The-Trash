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
import Accelerate

// 1. 定义知识库的数据结构 (Revised for robustness)
struct TrashItem: Decodable {
    let label: String
    let category: String
    let embedding: [Float]

    // Custom coding keys or init(from:) not strictly needed if JSON matches,
    // but made robust against missing keys via optional chaining in usage if needed.
    // Ideally, if essential fields are missing, we should just fail that item, not the whole batch.
    // For now, we rely on the standard Decodable but catch errors at the batch level.
}

// 🚀 优化：预计算并缓存归一化后的向量
private struct NormalizedTrashItem {
    let label: String
    let category: String
    let normalizedEmbedding: [Float]
}

class RealClassifierService: TrashClassifierService {
    static let shared = RealClassifierService()
    static let confidenceThreshold: Float = 0.10


    // 视觉模型 (The Eye)
    private var model: VNCoreMLModel?

    // 线程安全锁
    private let accessQueue = DispatchQueue(label: "com.trash.knowledgeBase", attributes: .concurrent)

    // 🚀 优化：使用预归一化的向量缓存
    private var _normalizedKnowledgeBase: [NormalizedTrashItem] = []

    // 线程安全的状态标志
    private var _isModelReady = false
    private var _isKnowledgeBaseReady = false
    private var _initializationError: String? = nil


    // 线程安全的访问入口
    private var normalizedKnowledgeBase: [NormalizedTrashItem] {
        get { accessQueue.sync { _normalizedKnowledgeBase } }
        set { accessQueue.async(flags: .barrier) { self._normalizedKnowledgeBase = newValue } }
    }

    private var isModelReady: Bool {
        get { accessQueue.sync { _isModelReady } }
        set { accessQueue.async(flags: .barrier) { self._isModelReady = newValue } }
    }

    private var isKnowledgeBaseReady: Bool {
        get { accessQueue.sync { _isKnowledgeBaseReady } }
        set { accessQueue.async(flags: .barrier) { self._isKnowledgeBaseReady = newValue } }
    }

    // Exposed ready state
    var initializationError: String? {
        accessQueue.sync { _initializationError }
    }


    var isReady: Bool {
        accessQueue.sync { _isModelReady && _isKnowledgeBaseReady }
    }

    private init() {
        // 🚀 优化：并行加载模型和知识库
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupModel()
            self?.warmupModel() // 🚀 预热模型
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadKnowledgeBase()
            group.leave()
        }

        // 完成后打印状态
        group.notify(queue: .main) {
            print("🚀 [System] AI 系统完全就绪")
        }
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // 使用 NPU 加速

            let coreModel = try MobileCLIPImage(configuration: config)
            self.model = try VNCoreMLModel(for: coreModel.model)
            self.isModelReady = true
            print("✅ [System] MobileCLIP S2 视觉系统就绪")
        } catch {
            print("❌ [Error] 模型加载失败: \(error)")
            // 🔥 Fix: Set error state
            accessQueue.async(flags: .barrier) {
                self._initializationError = "Failed to load AI Model: \(error.localizedDescription)"
            }
        }
    }

    // 🚀 新增：模型预热 - 用一张小图运行一次，让 NPU 预加载
    private func warmupModel() {
        guard let model = self.model else { return }

        // 创建一个 224x224 的空白图片进行预热（使用线程安全的 UIGraphicsImageRenderer）
        let size = CGSize(width: 224, height: 224)
        let renderer = UIGraphicsImageRenderer(size: size)
        let warmupImage = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        guard let cgImage = warmupImage.cgImage else { return }
        let ciImage = CIImage(cgImage: cgImage)

        let request = VNCoreMLRequest(model: model) { _, _ in }
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)

        try? handler.perform([request])
        print("🔥 [System] 模型预热完成")
    }

    private func loadKnowledgeBase() {
        guard let url = Bundle.main.url(forResource: "trash_knowledge", withExtension: "json") else {
            print("❌ [Error] 严重错误: 找不到 trash_knowledge.json 文件！")
            accessQueue.async(flags: .barrier) {
                self._initializationError = "Missing trash_knowledge.json in app bundle."
            }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([TrashItem].self, from: data)

            // 🚀 优化：预计算归一化向量
            var normalized: [NormalizedTrashItem] = []
            normalized.reserveCapacity(items.count)

            for item in items {
                let norm = sqrt(item.embedding.reduce(0) { $0 + $1 * $1 })
                if norm > 1e-6 {
                    let normalizedEmb = item.embedding.map { $0 / norm }
                    normalized.append(NormalizedTrashItem(
                        label: item.label,
                        category: item.category,
                        normalizedEmbedding: normalizedEmb
                    ))
                }
            }

            guard !normalized.isEmpty else {
                accessQueue.async(flags: .barrier) {
                    self._initializationError = "Knowledge base is empty after normalization."
                }
                return
            }

            self.normalizedKnowledgeBase = normalized
            self.isKnowledgeBaseReady = true
            print("✅ [System] 成功加载知识库: \(normalized.count) 个预归一化向量")
        } catch {
            print("❌ [Error] JSON 解析失败: \(error)")
            // 🔥 Fix: Set error state
            accessQueue.async(flags: .barrier) {
                self._initializationError = "Failed to load Knowledge Base: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Classification Logic

    func classifyImage(image: UIImage) async -> TrashAnalysisResult {
        // Check for initialization error first
        if let initError = self.initializationError {
            return TrashAnalysisResult(
                itemName: "System Error",
                category: "Error",
                confidence: 0.0,
                actionTip: initError,
                color: .red
            )
        }

        if !isReady {
            print("⚠️ 系统尚未准备就绪")
            return TrashAnalysisResult(
                itemName: "AI Warming Up...",
                category: "Please Wait",
                confidence: 0.0,
                actionTip: "The AI brain is waking up. This usually takes 2-3 seconds. Please tap 'Retake' to try again.",
                color: .gray
            )
        }

        guard let model = self.model,
              let ciImage = image.ciImage ?? (image.cgImage.map { CIImage(cgImage: $0) }) else {
            return TrashAnalysisResult(
                itemName: "Image Error",
                category: "Retry",
                confidence: 0.0,
                actionTip: "Could not process image data.",
                color: .red
            )
        }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self else {
                    continuation.resume(returning: TrashAnalysisResult(
                        itemName: "Analysis Failed", category: "Error",
                        confidence: 0.0, actionTip: "Service unavailable.", color: .red
                    ))
                    return
                }

                if let error = error {
                    print("❌ [Error] Vision request error: \(error)")
                    continuation.resume(returning: TrashAnalysisResult(
                        itemName: "Analysis Failed", category: "Error",
                        confidence: 0.0, actionTip: "Vision processing error. Please try again.", color: .red
                    ))
                    return
                }

                if let results = request.results as? [VNCoreMLFeatureValueObservation],
                   let featureValue = results.first?.featureValue,
                   let multiArray = featureValue.multiArrayValue {

                    let imageEmbedding = self.convertMultiArray(multiArray)
                    let bestMatch = self.findBestMatchOptimized(imageVector: imageEmbedding)

                    if let match = bestMatch {
                        continuation.resume(returning: TrashAnalysisResult(
                            itemName: match.label.capitalized,
                            category: match.category,
                            confidence: Double(match.score),
                            actionTip: self.getTipForCategory(match.category),
                            color: self.getColorForCategory(match.category)
                        ))
                    } else {
                        continuation.resume(returning: TrashAnalysisResult(
                            itemName: "Unknown Object", category: "Try Closer",
                            confidence: 0.0,
                            actionTip: "I can't recognize this clearly. Try moving closer or improving lighting.",
                            color: .orange
                        ))
                    }
                } else {
                    continuation.resume(returning: TrashAnalysisResult(
                        itemName: "Processing Error", category: "Retry",
                        confidence: 0.0,
                        actionTip: "Could not extract features from image. Please try again.",
                        color: .orange
                    ))
                }
            }

            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)

            DispatchQueue.global(qos: .userInteractive).async {
                autoreleasepool {
                    do {
                        try handler.perform([request])
                    } catch {
                        print("❌ [Error] Vision 请求失败: \(error)")
                        continuation.resume(returning: TrashAnalysisResult(
                            itemName: "Analysis Failed", category: "Error",
                            confidence: 0.0,
                            actionTip: "Vision request failed. Please try again.",
                            color: .red
                        ))
                    }
                }
            }
        }
    }

    // MARK: - 🚀 优化后的向量匹配

    private func findBestMatchOptimized(imageVector: [Float]) -> (label: String, category: String, score: Float)? {
        let currentKnowledge = self.normalizedKnowledgeBase
        guard !currentKnowledge.isEmpty else { return nil }

        // 计算输入向量的模长
        var sumOfSquares: Float = 0
        vDSP_dotpr(imageVector, 1, imageVector, 1, &sumOfSquares, vDSP_Length(imageVector.count))
        let imageNorm = sqrt(sumOfSquares)

        if imageNorm < 1e-6 {
            print("⚠️ [Warning] Detected zero vector input")
            return nil
        }

        // 🚀 优化：使用 vDSP 批量归一化
        var normalizedImage = [Float](repeating: 0, count: imageVector.count)
        var normValue = imageNorm
        vDSP_vsdiv(imageVector, 1, &normValue, &normalizedImage, 1, vDSP_Length(imageVector.count))

        // 🚀 优化：使用并行计算找最佳匹配
        var bestScore: Float = -1
        var bestIndex = -1

        // 使用 vDSP 批量计算点积
        var bestScore: Float = -1
        var bestIndex = -1

        #if DEBUG
        // 在首次遍历中收集 top-5，避免双重计算
        var topScores: [(index: Int, score: Float)] = []
        #endif

        for (index, item) in currentKnowledge.enumerated() {
            guard item.normalizedEmbedding.count == normalizedImage.count else { continue }

            var score: Float = 0
            vDSP_dotpr(normalizedImage, 1, item.normalizedEmbedding, 1, &score, vDSP_Length(normalizedImage.count))

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }

            #if DEBUG
            // 维护一个最多 5 个元素的有序数组
            if topScores.count < 5 {
                topScores.append((index, score))
                topScores.sort { $0.score > $1.score }
            } else if score > topScores.last!.score {
                topScores[4] = (index, score)
                topScores.sort { $0.score > $1.score }
            }
            #endif
        }

        #if DEBUG
        print("\n-------- 🧠 AI 思考过程 (Top 5) --------")
        for (rank, match) in topScores.enumerated() {
            print("👉 #\(rank + 1) [\(currentKnowledge[match.index].label)] 得分: \(match.score)")
        }
        print("---------------------------------------\n")
        #endif

        if bestIndex >= 0 && bestScore >= RealClassifierService.confidenceThreshold {
            let best = currentKnowledge[bestIndex]
            return (best.label, best.category, bestScore)
        }

        return nil
    }

    private func convertMultiArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count

        // 🔥 Fix: Safe conversion handling different data types
        if multiArray.dataType == .float32 {
            let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            return Array(buffer)
        } else if multiArray.dataType == .double {
            let ptr = multiArray.dataPointer.bindMemory(to: Double.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            return buffer.map { Float($0) }
        } else {
            // Fallback for other less common types (e.g. Float16) - slow but safe
            var array = [Float](repeating: 0, count: count)
            for i in 0..<count {
                array[i] = multiArray[i].floatValue
            }
            return array
        }
    }

    // MARK: - UI Logic

    private func getColorForCategory(_ category: String) -> Color {
        switch category {
        case _ where category == "IGNORE": return .gray.opacity(0.5)
        case _ where category.contains("Blue"): return .blue
        case _ where category.contains("Green"): return .green
        case _ where category.contains("Black"): return .gray
        case _ where category.contains("HAZARDOUS"): return .red
        case _ where category.contains("Recyclable"): return .blue
        case _ where category.contains("Compostable"): return .green
        case _ where category.contains("Landfill"): return .gray
        case _ where category.contains("Hazardous"): return .red
        default: return .orange
        }
    }

    private func getTipForCategory(_ category: String) -> String {
        switch category {
        case _ where category == "IGNORE": return "Please point at trash."
        case _ where category.contains("Blue"), _ where category.contains("Recyclable"):
            return "♻️ Empty liquids. Flatten boxes. Check for CRV!"
        case _ where category.contains("Green"), _ where category.contains("Compostable"):
            return "🌱 Food scraps & soiled paper only."
        case _ where category.contains("Black"), _ where category.contains("Landfill"):
            return "🗑️ Wrappers & styrofoam go here."
        case _ where category.contains("HAZARDOUS"), _ where category.contains("Hazardous"):
            return "⚠️ Do NOT bin! Take to E-waste center."
        default: return "📋 Check local guidelines."
        }
    }
}
