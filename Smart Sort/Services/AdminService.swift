//
//  AdminService.swift
//  Smart Sort
//

import Foundation
import Supabase

@MainActor
final class AdminService {
    static let shared = AdminService()

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Admin Methods

    /// Check if current user is admin of a community
    func isAdmin(communityId: String) async throws -> Bool {
        return try await client
            .rpc("is_community_admin", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Get pending join applications (admin only)
    func getPendingApplications(communityId: String) async throws -> [JoinApplicationResponse] {
        return try await client
            .rpc("get_pending_applications", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Review a join application (admin only)
    func reviewApplication(
        applicationId: UUID,
        approve: Bool,
        rejectionReason: String? = nil
    ) async throws -> APIResult {
        let params = ReviewApplicationParams(
            p_application_id: applicationId.uuidString,
            p_approve: approve,
            p_rejection_reason: rejectionReason
        )
        return try await client
            .rpc("review_join_application", params: params)
            .execute()
            .value
    }

    /// Update community info (admin only)
    func updateCommunityInfo(
        communityId: String,
        description: String? = nil,
        welcomeMessage: String? = nil,
        rules: String? = nil,
        requiresApproval: Bool? = nil
    ) async throws -> APIResult {
        let params = UpdateCommunityInfoParams(
            p_community_id: communityId,
            p_description: description,
            p_welcome_message: welcomeMessage,
            p_rules: rules,
            p_requires_approval: requiresApproval
        )
        return try await client
            .rpc("update_community_info", params: params)
            .execute()
            .value
    }

    /// Get community members list (admin only)
    func getCommunityMembersAdmin(communityId: String) async throws -> [CommunityMemberResponse] {
        return try await client
            .rpc("get_community_members_admin", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// Remove a member from community (admin only)
    func removeMember(communityId: String, userId: UUID, reason: String? = nil) async throws -> APIResult {
        let params = RemoveMemberParams(
            p_community_id: communityId,
            p_user_id: userId.uuidString,
            p_reason: reason
        )
        return try await client
            .rpc("remove_community_member", params: params)
            .execute()
            .value
    }

    /// Get admin action logs (admin only)
    func getAdminLogs(communityId: String, limit: Int = 50) async throws -> [AdminActionLogResponse] {
        let params = GetAdminLogsParams(p_community_id: communityId, p_limit: limit)
        return try await client
            .rpc("get_admin_action_logs", params: params)
            .execute()
            .value
    }

    /// Get community settings (for admin edit view)
    func getCommunitySettings(communityId: String) async throws -> CommunitySettingsResponse? {
        return try await client
            .from("communities")
            .select("id, description, welcome_message, rules, requires_approval")
            .eq("id", value: communityId)
            .single()
            .execute()
            .value
    }
}
