//
//  DuelModels.swift
//  The Trash
//

import Foundation

// MARK: - Challenge

struct ArenaChallenge: Codable, Identifiable {
    let id: UUID
    let challengerId: UUID
    let opponentId: UUID
    let status: String
    let challengerScore: Int?
    let opponentScore: Int?
    let winnerId: UUID?
    let channelName: String?
    let createdAt: String
    let expiresAt: String?
    let startedAt: String?
    let completedAt: String?
    let challengerName: String?
    let opponentName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case status
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case winnerId = "winner_id"
        case channelName = "channel_name"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case challengerName = "challenger_name"
        case opponentName = "opponent_name"
    }
}

// MARK: - Create Challenge Response

struct CreateChallengeResponse: Codable {
    let challengeId: UUID
    let channelName: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case channelName = "channel_name"
        case status
    }
}

// MARK: - Accept Challenge Response

struct AcceptChallengeResponse: Codable {
    let challengeId: UUID
    let channelName: String
    let questions: [QuizQuestion]
    let challengerId: UUID
    let opponentId: UUID

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case channelName = "channel_name"
        case questions
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
    }
}

// MARK: - Submit Answer Response

struct DuelAnswerResponse: Codable {
    let isCorrect: Bool
    let correctCategory: String
    let questionIndex: Int

    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case correctCategory = "correct_category"
        case questionIndex = "question_index"
    }
}

// MARK: - Complete Challenge Response

struct CompleteChallengeResponse: Codable {
    let challengeId: UUID
    let challengerScore: Int
    let opponentScore: Int
    let winnerId: UUID?
    let challengerPoints: Int?
    let opponentPoints: Int?
    let alreadyCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case winnerId = "winner_id"
        case challengerPoints = "challenger_points"
        case opponentPoints = "opponent_points"
        case alreadyCompleted = "already_completed"
    }
}

// MARK: - Submit Duel Answer Params

struct SubmitDuelAnswerParams: Sendable {
    let p_challenge_id: String
    let p_question_index: Int
    let p_selected_category: String
    let p_answer_time_ms: Int
}

extension SubmitDuelAnswerParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_challenge_id, forKey: .p_challenge_id)
        try container.encode(p_question_index, forKey: .p_question_index)
        try container.encode(p_selected_category, forKey: .p_selected_category)
        try container.encode(p_answer_time_ms, forKey: .p_answer_time_ms)
    }

    private enum CodingKeys: String, CodingKey {
        case p_challenge_id, p_question_index, p_selected_category, p_answer_time_ms
    }
}

// MARK: - Realtime Events

struct DuelPlayerReady: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct DuelAnswerSubmitted: Codable {
    let userId: String
    let questionIndex: Int
    let isCorrect: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case questionIndex = "question_index"
        case isCorrect = "is_correct"
    }
}

struct DuelPlayerFinished: Codable {
    let userId: String
    let totalCorrect: Int
    let totalScore: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalCorrect = "total_correct"
        case totalScore = "total_score"
    }
}
