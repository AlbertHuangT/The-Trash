//
//  ArenaRouter.swift
//  The Trash
//
//  Handles deep link routing for arena challenges.
//

import Foundation
import Combine

@MainActor
class ArenaRouter: ObservableObject {
    static let shared = ArenaRouter()
    private init() {}

    @Published var pendingChallengeId: UUID?

    func handleDeepLink(url: URL) -> Bool {
        // thetrash://challenge/{challenge_id}
        guard url.scheme == "thetrash",
              url.host == "challenge",
              let idString = url.pathComponents.dropFirst().first,
              let challengeId = UUID(uuidString: idString) else {
            return false
        }

        pendingChallengeId = challengeId
        return true
    }

    func clearPending() {
        pendingChallengeId = nil
    }
}
