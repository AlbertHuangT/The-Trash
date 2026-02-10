//
//  DailyChallengeModels.swift
//  The Trash
//

import Foundation

// MARK: - Daily Challenge Response

struct DailyChallengeResponse: Codable {
    let challengeId: UUID
    let challengeDate: String
    let alreadyPlayed: Bool
    let questions: [QuizQuestion]

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case challengeDate = "challenge_date"
        case alreadyPlayed = "already_played"
        case questions
    }
}

// MARK: - Daily Challenge Submit Response

struct DailyChallengeSubmitResponse: Codable {
    let resultId: UUID
    let pointsAwarded: Int

    enum CodingKeys: String, CodingKey {
        case resultId = "result_id"
        case pointsAwarded = "points_awarded"
    }
}

// MARK: - Daily Challenge Submit Params

struct DailyChallengeSubmitParams: Sendable {
    let p_score: Int
    let p_correct_count: Int
    let p_time_seconds: Double
    let p_max_combo: Int
}

extension DailyChallengeSubmitParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_score, forKey: .p_score)
        try container.encode(p_correct_count, forKey: .p_correct_count)
        try container.encode(p_time_seconds, forKey: .p_time_seconds)
        try container.encode(p_max_combo, forKey: .p_max_combo)
    }

    private enum CodingKeys: String, CodingKey {
        case p_score, p_correct_count, p_time_seconds, p_max_combo
    }
}

// MARK: - Daily Leaderboard Entry

struct DailyLeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: UUID
    let displayName: String
    let score: Int
    let correctCount: Int
    let timeSeconds: Double
    let maxCombo: Int

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case displayName = "display_name"
        case score
        case correctCount = "correct_count"
        case timeSeconds = "time_seconds"
        case maxCombo = "max_combo"
    }
}
