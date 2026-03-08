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
    func submitConfirmedQuizCandidate(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        userId: UUID?
    ) async throws
}

// Data structure definition
struct FeedbackRecord: Encodable {
    let user_id: UUID
    let predicted_label: String
    let predicted_category: String
    let user_correction: String
    let user_comment: String
    let image_path: String
}

struct QuizQuestionCandidateRecord: Encodable {
    let user_id: UUID
    let image_path: String
    let predicted_label: String
    let predicted_category: String
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
        let authUserId = try requireLinkedIdentity(
            errorDomain: "FeedbackService",
            errorCode: -2,
            message: "Link an email or phone before submitting feedback."
        )

        if let userId, userId != authUserId {
            LogManager.shared.log(
                "Ignoring mismatched feedback user id \(userId) in favor of current auth user \(authUserId)",
                level: .warning,
                category: "Feedback"
            )
        }

        LogManager.shared.log("Start submitting feedback...", level: .info, category: "Feedback")

        let filePath = try await uploadImage(
            image,
            bucket: "feedback_images",
            pathPrefix: "\(authUserId.uuidString.lowercased())/feedback"
        )

        LogManager.shared.log("Image uploaded successfully", level: .info, category: "Feedback")

        let record = FeedbackRecord(
            user_id: authUserId,
            predicted_label: predictedLabel,
            predicted_category: predictedCategory,
            user_correction: correctedName.trimmingCharacters(in: .whitespacesAndNewlines),
            user_comment: "",
            image_path: filePath
        )

        do {
            try await client
                .from("feedback_logs")
                .insert(record)
                .execute()

            LogManager.shared.log("Database write successful", level: .info, category: "Feedback")
        } catch {
            await cleanupUploadedObject(bucket: "feedback_images", path: filePath)
            throw error
        }
    }

    func submitConfirmedQuizCandidate(
        image: UIImage,
        predictedLabel: String,
        predictedCategory: String,
        userId: UUID?
    ) async throws {
        let authUserId = try requireLinkedIdentity(
            errorDomain: "FeedbackService",
            errorCode: -3,
            message: "Link an email or phone before submitting quiz candidates."
        )

        if let userId, userId != authUserId {
            LogManager.shared.log(
                "Ignoring mismatched quiz candidate user id \(userId) in favor of current auth user \(authUserId)",
                level: .warning,
                category: "Feedback"
            )
        }

        let filePath = try await uploadImage(
            image,
            bucket: "quiz-candidate-images",
            pathPrefix: "\(authUserId.uuidString.lowercased())/verified"
        )

        let record = QuizQuestionCandidateRecord(
            user_id: authUserId,
            image_path: filePath,
            predicted_label: predictedLabel,
            predicted_category: predictedCategory
        )

        do {
            try await client
                .from("quiz_question_candidates")
                .insert(record)
                .execute()
        } catch {
            await cleanupUploadedObject(bucket: "quiz-candidate-images", path: filePath)
            throw error
        }
    }

    private func requireLinkedIdentity(
        errorDomain: String,
        errorCode: Int,
        message: String
    ) throws -> UUID {
        guard let user = client.auth.currentUser else {
            throw NSError(
                domain: errorDomain,
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }

        let hasLinkedIdentity = !(user.email?.isEmpty ?? true) || !(user.phone?.isEmpty ?? true)
        guard hasLinkedIdentity else {
            throw NSError(
                domain: errorDomain,
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        return user.id
    }

    private func uploadImage(
        _ image: UIImage,
        bucket: String,
        pathPrefix: String
    ) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(
                domain: "FeedbackService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Image processing failed"]
            )
        }

        let filePath = "\(pathPrefix)/\(UUID().uuidString).jpg"
        let fileOptions = FileOptions(
            cacheControl: "3600",
            contentType: "image/jpeg",
            upsert: false
        )

        _ = try await client.storage
            .from(bucket)
            .upload(filePath, data: imageData, options: fileOptions)

        return filePath
    }

    private func cleanupUploadedObject(bucket: String, path: String) async {
        do {
            _ = try await client.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            LogManager.shared.log(
                "Failed to clean up orphaned upload \(bucket)/\(path): \(error)",
                level: .warning,
                category: "Feedback"
            )
        }
    }
}
