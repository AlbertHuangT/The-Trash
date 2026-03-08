//
//  AchievementService.swift
//  Smart Sort
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
    @Published var communityMembers: [CommunityMemberForGrant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Achievement unlock notification
    @Published var lastGrantedAchievement: AchievementGrantResult?

    private let client = SupabaseManager.shared.client

    // MARK: - Fetch my earned achievements

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

    // MARK: - Fetch community achievements (for admins)

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

    // MARK: - Create achievement (Admin)

    func createAchievement(communityId: String, name: String, description: String, iconName: String, rarity: AchievementRarity = .common) async -> Bool {
        do {
            let _: UUID = try await client
                .rpc(
                    "create_community_achievement",
                    params: [
                        "p_community_id": communityId,
                        "p_name": name,
                        "p_description": description,
                        "p_icon_name": iconName,
                        "p_rarity": rarity.rawValue,
                    ]
                )
                .execute()
                .value

            await fetchCommunityAchievements(communityId: communityId)
            return true
        } catch {
            print("Error creating achievement: \(error)")
            errorMessage = "Failed to create achievement: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Grant achievement to user (Admin)

    func grantAchievement(userId: UUID, achievementId: UUID, communityId: String) async -> Bool {
        do {
            _ = try await client
                .rpc(
                    "grant_community_achievement",
                    params: [
                        "p_user_id": userId.uuidString,
                        "p_achievement_id": achievementId.uuidString,
                        "p_community_id": communityId,
                    ]
                )
                .execute()

            return true
        } catch {
            print("Error granting achievement: \(error)")
            errorMessage = "Failed to grant achievement: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Equip / Unequip

    func equipAchievement(achievementId: UUID) async -> Bool {
        do {
            try await client
                .rpc("set_primary_achievement", params: AchievementEquipParams(achievement_id: achievementId))
                .execute()

            await fetchMyAchievements()
            return true
        } catch {
            print("Error equipping achievement: \(error)")
            errorMessage = "Failed to equip achievement: \(error.localizedDescription)"
            return false
        }
    }

    func unequipAchievement() async -> Bool {
        do {
            // Pass NULL to set_primary_achievement to unequip
            try await client
                .rpc("set_primary_achievement", params: AchievementEquipParams(achievement_id: nil))
                .execute()

            await fetchMyAchievements()
            return true
        } catch {
            print("Error unequipping achievement: \(error)")
            errorMessage = "Failed to unequip achievement: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - System Auto-Grant

    /// Check and auto-grant system achievements
    func checkAndGrant(triggerKey: String) async {
        do {


            let result: AchievementGrantResult = try await client
                .rpc("check_and_grant_achievement", params: ["p_trigger_key": triggerKey])
                .execute()
                .value

            if result.granted {
                print("🏆 Achievement unlocked: \(result.name ?? "Unknown")")
                self.lastGrantedAchievement = result
                // Refresh the achievement list
                await fetchMyAchievements()
            }
        } catch {
            print("Error checking achievement \(triggerKey): \(error)")
        }
    }

    // MARK: - Community Members for Grant UI

    func fetchCommunityMembersForGrant(communityId: String, achievementId: UUID) async {
        isLoading = true
        do {


            let members: [CommunityMemberForGrant] = try await client
                .rpc("get_community_members_for_grant", params: ["p_community_id": communityId, "p_achievement_id": achievementId.uuidString])
                .execute()
                .value

            self.communityMembers = members
            self.isLoading = false
        } catch {
            print("Error fetching community members: \(error)")
            errorMessage = "Failed to load members: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    /// Clear the notification
    func dismissGrantNotification() {
        lastGrantedAchievement = nil
    }
}
