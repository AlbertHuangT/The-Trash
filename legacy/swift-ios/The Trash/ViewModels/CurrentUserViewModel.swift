//
//  CurrentUserViewModel.swift
//  The Trash
//
//  Extracted from LeaderboardView.swift
//

import SwiftUI
import Supabase
import Combine

@MainActor
class CurrentUserViewModel: ObservableObject {
    @Published var myProfile: UserProfile?

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30

    struct UserProfile: Decodable {
        let username: String?
        let credits: Int
    }

    func fetchMyScore(forceRefresh: Bool = false) async {
        if !forceRefresh,
           myProfile != nil,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }

        guard let uid = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        do {
            let profile: UserProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select("username, credits")
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            self.myProfile = profile
            self.lastFetchTime = Date()
        } catch {
            if !Task.isCancelled {
                print("❌ Failed to fetch my score: \(error)")
            }
        }
    }
}
