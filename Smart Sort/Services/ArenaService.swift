//
//  ArenaService.swift
//  Smart Sort
//
//  Singleton service for all Arena RPC calls (Duel, Daily, Streak).
//

import Foundation
import Supabase

@MainActor
class ArenaService {
    static let shared = ArenaService()
    private init() {}

    private let client = SupabaseManager.shared.client

    // MARK: - Duel

    func createChallenge(opponentId: UUID) async throws -> CreateChallengeResponse {
        return try await client
            .rpc("create_arena_challenge", params: ["p_opponent_id": opponentId.uuidString])
            .execute()
            .value
    }

    func acceptChallenge(challengeId: UUID) async throws -> AcceptChallengeResponse {
        return try await client
            .rpc("accept_arena_challenge", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    func declineChallenge(challengeId: UUID) async throws {
        try await client
            .rpc("decline_arena_challenge", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
    }

    func submitDuelAnswer(
        challengeId: UUID,
        questionIndex: Int,
        selectedCategory: String,
        answerTimeMs: Int
    ) async throws -> DuelAnswerResponse {
        let params = SubmitDuelAnswerParams(
            p_challenge_id: challengeId.uuidString,
            p_question_index: questionIndex,
            p_selected_category: selectedCategory,
            p_answer_time_ms: answerTimeMs
        )
        return try await client
            .rpc("submit_duel_answer", params: params)
            .execute()
            .value
    }

    func completeChallenge(challengeId: UUID) async throws -> CompleteChallengeResponse {
        return try await client
            .rpc("complete_arena_challenge", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    func markDuelReady(challengeId: UUID) async throws -> DuelStateResponse {
        try await client
            .rpc("mark_duel_ready", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    func getDuelState(challengeId: UUID) async throws -> DuelStateResponse {
        try await client
            .rpc("get_duel_state", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }

    func getMyChallenges(status: String? = nil) async throws -> [ArenaChallenge] {
        if let status = status {
            let json: [ArenaChallenge] = try await client
                .rpc("get_my_challenges", params: ["p_status": status])
                .execute()
                .value
            return json
        } else {
            let json: [ArenaChallenge] = try await client
                .rpc("get_my_challenges")
                .execute()
                .value
            return json
        }
    }

    func getChallengeQuestions(challengeId: UUID) async throws -> AcceptChallengeResponse {
        return try await client
            .rpc("get_challenge_questions", params: ["p_challenge_id": challengeId.uuidString])
            .execute()
            .value
    }
}
