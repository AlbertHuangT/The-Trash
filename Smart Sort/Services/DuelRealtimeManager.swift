//
//  DuelRealtimeManager.swift
//  Smart Sort
//
//  Manages the optional Supabase Realtime side-channel for 1v1 duel.
//  Ready/finished truth now lives in server state; Realtime is only a best-effort
//  auxiliary channel for lightweight live signals while both players are online.
//

import Foundation
import Supabase

@MainActor
class DuelRealtimeManager {
    private var channel: RealtimeChannelV2?
    private let client = SupabaseManager.shared.client

    private var myUserId: String = ""

    // MARK: - Connect

    func connect(channelName: String, myId: UUID, opponentId _: UUID) async {
        // Ensure stale subscriptions/channels are removed before reconnecting.
        await disconnect()

        myUserId = myId.uuidString

        let ch = client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = false
        }
        self.channel = ch

        do {
            try await ch.subscribeWithError()
        } catch {
            print("❌ [DuelRT] Failed to subscribe: \(error)")
        }
    }

    // MARK: - Send Events

    func sendReady() async {
        let payload = DuelPlayerReady(userId: myUserId)
        do {
            try await channel?.broadcast(event: "player_ready", message: payload)
        } catch {
            print("❌ [DuelRT] Failed to send ready: \(error)")
        }
    }

    func sendAnswerSubmitted(questionIndex: Int, isCorrect: Bool) async {
        let payload = DuelAnswerSubmitted(
            userId: myUserId,
            questionIndex: questionIndex,
            isCorrect: isCorrect
        )
        do {
            try await channel?.broadcast(event: "answer_submitted", message: payload)
        } catch {
            print("❌ [DuelRT] Failed to send answer: \(error)")
        }
    }

    // MARK: - Cleanup

    func disconnect() async {
        if let ch = channel {
            await client.realtimeV2.removeChannel(ch)
        }
        channel = nil
    }
}
