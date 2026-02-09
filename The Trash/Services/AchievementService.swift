//
//  AchievementService.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import Foundation
import Combine
import Supabase

@MainActor
class AchievementService: ObservableObject {
    static let shared = AchievementService()

    @Published var myAchievements: [UserAchievement] = []
    @Published var communityAchievements: [Achievement] = []
    @Published var officialAchievements: [Achievement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.shared.client

    // Fetch my earned achievements
    func fetchMyAchievements() async {
        isLoading = true
        errorMessage = nil

        do {
            let achievements: [UserAchievement] = try await client
                .rpc("get_my_achievements")
                .execute()
                .value

            self.myAchievements = achievements
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load achievements: \(error.localizedDescription)"
            self.isLoading = false
            print("Error fetching my achievements: \(error)")
        }
    }

    // Fetch available achievements for a community (for admins to see/grant)
    func fetchCommunityAchievements(communityId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let achievements: [Achievement] = try await client
                .from("achievements")
                .select()
                .eq("community_id", value: communityId)
                .execute()
                .value

            self.communityAchievements = achievements
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load community achievements: \(error.localizedDescription)"
            self.isLoading = false
            print("Error fetching community achievements: \(error)")
        }
    }

    // Create a new achievement for a community (Admin only)
    func createAchievement(communityId: String, name: String, description: String, iconName: String) async -> Bool {
        do {
            let newItem = Achievement(
                id: UUID(),
                name: name,
                description: description,
                iconName: iconName,
                communityId: UUID(uuidString: communityId),
                isHidden: false
            )

            try await client
                .from("achievements")
                .insert(newItem)
                .execute()

            // Refresh list
            await fetchCommunityAchievements(communityId: communityId)
            return true
        } catch {
            print("Error creating achievement: \(error)")
            errorMessage = "Failed to create achievement: \(error.localizedDescription)"
            return false
        }
    }

    // Grant an achievement to a user (Admin only)
    func grantAchievement(userId: UUID, achievementId: UUID, communityId: String) async -> Bool {
        guard let communityUUID = UUID(uuidString: communityId) else {
            errorMessage = "Invalid community ID"
            return false
        }

        do {
            let params = AchievementGrantParams(
                user_id: userId,
                achievement_id: achievementId,
                community_id: communityUUID
            )

            try await client
                .from("user_achievements")
                .insert(params)
                .execute()

            return true
        } catch {
            print("Error granting achievement: \(error)")
            errorMessage = "Failed to grant achievement: \(error.localizedDescription)"
            return false
        }
    }

    // Equip (set as primary) an achievement
    func equipAchievement(achievementId: UUID) async -> Bool {
        do {
            try await client
                .rpc("set_primary_achievement", params: AchievementEquipParams(achievement_id: achievementId))
                .execute()

            // Refresh my list
            await fetchMyAchievements()
            return true
        } catch {
            print("Error equipping achievement: \(error)")
            errorMessage = "Failed to equip achievement: \(error.localizedDescription)"
            return false
        }
    }
}
