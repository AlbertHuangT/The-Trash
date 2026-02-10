//
//  DuelRealtimeManager.swift
//  The Trash
//
//  Manages Supabase Realtime channel for 1v1 duel:
//  - Broadcast events: player_ready, answer_submitted, player_finished
//  - Presence for online status tracking
//

import Foundation
import Supabase
import Combine

struct DuelPresenceUser: Identifiable, Codable {
    let id: String
    let username: String
}

@MainActor
class DuelRealtimeManager: ObservableObject {
    @Published var opponentReady = false
    @Published var myReady = false
    @Published var bothReady = false

    @Published var opponentProgress: Int = 0 // questions answered
    @Published var opponentCorrect: Int = 0
    @Published var opponentFinished = false
    @Published var opponentDisconnected = false

    private var channel: RealtimeChannelV2?
    private var broadcastTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private let client = SupabaseManager.shared.client

    private var myUserId: String = ""
    private var opponentUserId: String = ""

    // MARK: - Connect

    func connect(channelName: String, myId: UUID, opponentId: UUID) async {
        myUserId = myId.uuidString
        opponentUserId = opponentId.uuidString

        // Reset state
        opponentReady = false
        myReady = false
        bothReady = false
        opponentProgress = 0
        opponentCorrect = 0
        opponentFinished = false
        opponentDisconnected = false

        let ch = client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = false
        }
        self.channel = ch

        // Listen to broadcasts
        broadcastTask = Task { [weak self] in
            guard let self = self else { return }

            let readyStream = ch.broadcastStream(event: "player_ready")
            let answerStream = ch.broadcastStream(event: "answer_submitted")
            let finishedStream = ch.broadcastStream(event: "player_finished")

            // Process events concurrently
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await message in readyStream {
                        if let payload = try? message["payload"]?.decode(as: DuelPlayerReady.self) {
                            await MainActor.run {
                                if payload.userId == self.opponentUserId {
                                    self.opponentReady = true
                                    self.checkBothReady()
                                }
                            }
                        }
                    }
                }

                group.addTask {
                    for await message in answerStream {
                        if let payload = try? message["payload"]?.decode(as: DuelAnswerSubmitted.self) {
                            await MainActor.run {
                                if payload.userId == self.opponentUserId {
                                    self.opponentProgress = payload.questionIndex + 1
                                    if payload.isCorrect {
                                        self.opponentCorrect += 1
                                    }
                                }
                            }
                        }
                    }
                }

                group.addTask {
                    for await message in finishedStream {
                        if let payload = try? message["payload"]?.decode(as: DuelPlayerFinished.self) {
                            await MainActor.run {
                                if payload.userId == self.opponentUserId {
                                    self.opponentFinished = true
                                }
                            }
                        }
                    }
                }
            }
        }

        do {
            try await ch.subscribeWithError()
        } catch {
            print("❌ [DuelRT] Failed to subscribe: \(error)")
        }
    }

    private func checkBothReady() {
        if myReady && opponentReady {
            bothReady = true
        }
    }

    // MARK: - Send Events

    func sendReady() async {
        myReady = true
        checkBothReady()

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

    func sendFinished(totalCorrect: Int, totalScore: Int) async {
        let payload = DuelPlayerFinished(
            userId: myUserId,
            totalCorrect: totalCorrect,
            totalScore: totalScore
        )
        do {
            try await channel?.broadcast(event: "player_finished", message: payload)
        } catch {
            print("❌ [DuelRT] Failed to send finished: \(error)")
        }
    }

    // MARK: - Cleanup

    func disconnect() async {
        broadcastTask?.cancel()
        presenceTask?.cancel()

        if let ch = channel {
            await client.realtimeV2.removeChannel(ch)
        }
        channel = nil
    }
}
