//
//  FeedbackService.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import Foundation
import UIKit
import Supabase

protocol FeedbackSubmitting: AnyObject {
    func submitFeedback(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        correctedName: String,
        userId: UUID?
    ) async throws
}

// Data structure definition
struct FeedbackRecord: Encodable {
    let user_id: UUID?
    let predicted_label: String
    let predicted_category: String
    let user_correction: String
    let user_comment: String
    let image_path: String
}

@MainActor
class FeedbackService: FeedbackSubmitting {
    static let shared = FeedbackService()
    
    // Get client instance
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    func submitFeedback(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        correctedName: String,
        userId: UUID?
    ) async throws {
        
        LogManager.shared.log("Start submitting feedback...", level: .info, category: "Feedback")
        
        // 1. Image processing
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(
                domain: "FeedbackService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Image processing failed"]
            )
        }
        
        // 2. Generate path
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "uploads/\(fileName)"
        
        let fileOptions = FileOptions(
            cacheControl: "3600",
            contentType: "image/jpeg",
            upsert: false
        )
        
        // Fix: upload method updated
        // Old usage: .upload(path: filePath, file: imageData, ...)
        // New usage: .upload(filePath, data: imageData, ...)
        _ = try await client.storage
            .from("feedback_images")
            .upload(
                filePath,           // First parameter is path, no label needed
                data: imageData,    // Second parameter renamed to data
                options: fileOptions
            )
        
        LogManager.shared.log("Image uploaded successfully", level: .info, category: "Feedback")
        
        // 3. Write to database
        let record = FeedbackRecord(
            user_id: userId,
            predicted_label: predictedLabel,
            predicted_category: predictedCategory,
            user_correction: correctedName,
            user_comment: "",
            image_path: filePath
        )
        
        try await client
            .from("feedback_logs")
            .insert(record)
            .execute()
            
        LogManager.shared.log("Database write successful", level: .info, category: "Feedback")
    }
}
