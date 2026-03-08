//
//  CurrentUserViewModel.swift
//  Smart Sort
//
//  Extracted from LeaderboardView.swift
//

import SwiftUI
import Supabase
import Combine

@MainActor
class CurrentUserViewModel: ObservableObject {
    @Published var myProfile: UserProfileDTO?
    @Published var equippedAchievementIcon: String?

    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30
    private let client = SupabaseManager.shared.client

    func fetchMyScore(forceRefresh: Bool = false) async {
        if !forceRefresh,
           myProfile != nil,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return
        }

        guard SupabaseManager.shared.client.auth.currentUser?.id != nil else { return }

        do {
            let profile: UserProfileDTO = try await client
                .rpc("get_my_profile")
                .single()
                .execute()
                .value

            self.myProfile = profile
            self.lastFetchTime = Date()

            if let achievementId = profile.selectedAchievementId {
                await fetchEquippedAchievementIcon(achievementId)
            } else {
                self.equippedAchievementIcon = nil
            }
        } catch {
            if !Task.isCancelled {
                print("❌ Failed to fetch my score: \(error)")
            }
        }
    }

    private func fetchEquippedAchievementIcon(_ achievementId: UUID) async {
        do {
            struct AchievementIconDTO: Decodable {
                let iconName: String

                enum CodingKeys: String, CodingKey {
                    case iconName = "icon_name"
                }
            }

            let info: AchievementIconDTO = try await client
                .from("achievements")
                .select("icon_name")
                .eq("id", value: achievementId)
                .single()
                .execute()
                .value

            self.equippedAchievementIcon = info.iconName
        } catch {
            self.equippedAchievementIcon = nil
        }
    }
}
