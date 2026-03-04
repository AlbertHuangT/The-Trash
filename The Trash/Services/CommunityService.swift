//
//  CommunityService.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import Foundation
import Supabase

// MARK: - Community Service

@MainActor
class CommunityService {
    static let shared = CommunityService()

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Community Methods

    /// 获取指定城市的社区列表
    func getCommunitiesByCity(_ city: String) async throws -> [CommunityResponse] {
        return try await client
            .rpc("get_communities_by_city", params: ["p_city": city])
            .execute()
            .value
    }

    /// 获取用户已加入的社区
    func getMyCommunities() async throws -> [MyCommunityResponse] {
        return try await client
            .rpc("get_my_communities")
            .execute()
            .value
    }

    /// 加入社区（支持审批流程）
    func joinCommunity(_ communityId: String, message: String? = nil) async throws -> JoinCommunityResult {
        let params = JoinCommunityParams(
            p_community_id: communityId,
            p_message: message
        )
        return try await client
            .rpc("apply_to_join_community", params: params)
            .execute()
            .value
    }

    /// 离开社区
    func leaveCommunity(_ communityId: String) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("leave_community", params: ["p_community_id": communityId])
            .execute()
            .value
        return result.success
    }

    // MARK: - Event Methods

    /// 获取附近活动
    func getNearbyEvents(
        latitude: Double,
        longitude: Double,
        maxDistanceKm: Double = 50,
        category: String? = nil,
        onlyJoinedCommunities: Bool = false,
        sortBy: String = "date"
    ) async throws -> [EventResponse] {
        let params = NearbyEventsParams(
            p_latitude: latitude,
            p_longitude: longitude,
            p_max_distance_km: maxDistanceKm,
            p_category: category,
            p_only_joined_communities: onlyJoinedCommunities,
            p_sort_by: sortBy
        )
        return try await client
            .rpc("get_nearby_events", params: params)
            .execute()
            .value
    }

    /// 报名活动
    func registerForEvent(_ eventId: UUID) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("register_for_event", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return result.success
    }

    /// 取消报名
    func cancelEventRegistration(_ eventId: UUID) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("cancel_event_registration", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return result.success
    }

    /// 获取用户已报名的活动
    func getMyRegistrations() async throws -> [MyRegistrationResponse] {
        return try await client
            .rpc("get_my_registrations")
            .execute()
            .value
    }

    // MARK: - Location Methods

    /// 更新用户位置
    func updateUserLocation(city: String, state: String, latitude: Double, longitude: Double) async throws -> Bool {
        let params = LocationParams(
            p_city: city,
            p_state: state,
            p_latitude: latitude,
            p_longitude: longitude
        )
        let result: APIResult = try await client
            .rpc("update_user_location", params: params)
            .execute()
            .value
        return result.success
    }

    // MARK: - Direct Table Access (for communities list)

    /// 获取指定社区的活动（包括过去和将来的）
    func getCommunityEvents(communityId: String) async throws -> [EventResponse] {
        return try await client
            .rpc("get_community_events", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    /// 获取所有社区列表
    func getAllCommunities() async throws -> [CommunityResponse] {
        return try await client
            .from("communities")
            .select("id, name, city, state, description, member_count, latitude, longitude")
            .eq("is_active", value: true)
            .order("member_count", ascending: false)
            .execute()
            .value
    }

    // MARK: - Create Content Methods

    /// 检查用户是否可以创建社区（最多3个）
    func canCreateCommunity() async throws -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        let result: CanCreateResult = try await client
            .rpc("can_user_create_community")
            .execute()
            .value
        return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
    }

    /// 检查用户是否可以创建活动（每周最多7个）
    func canCreateEvent() async throws -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        let result: CanCreateResult = try await client
            .rpc("can_user_create_event")
            .execute()
            .value
        return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
    }

    /// 创建社区
    func createCommunity(
        id: String,
        name: String,
        city: String,
        state: String,
        description: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> (success: Bool, message: String, communityId: String?) {
        let params = CreateCommunityParams(
            p_id: id,
            p_name: name,
            p_city: city,
            p_state: state,
            p_description: description,
            p_latitude: latitude,
            p_longitude: longitude
        )
        let result: APIResult = try await client
            .rpc("create_community", params: params)
            .execute()
            .value
        return (result.success, result.message, result.success ? id : nil)
    }

    /// 创建活动（社区或个人）
    func createEvent(
        title: String,
        description: String,
        category: String,
        eventDate: Date,
        location: String,
        latitude: Double,
        longitude: Double,
        maxParticipants: Int = 50,
        communityId: String? = nil,
        iconName: String = "calendar"
    ) async throws -> (success: Bool, message: String, eventId: UUID?) {
        let params = CreateEventParams(
            p_title: title,
            p_description: description,
            p_category: category,
            p_event_date: ISO8601DateFormatter().string(from: eventDate),
            p_location: location,
            p_latitude: latitude,
            p_longitude: longitude,
            p_max_participants: maxParticipants,
            p_community_id: communityId,
            p_icon_name: iconName
        )
        let result: APIResult = try await client
            .rpc("create_event", params: params)
            .execute()
            .value
        return (result.success, result.message, result.eventId)
    }

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

    /// Grant credits to event participants (admin only)
    func grantEventCredits(
        eventId: UUID,
        userIds: [UUID],
        creditsPerUser: Int,
        reason: String
    ) async throws -> GrantCreditsResult {
        let params = GrantCreditsParams(
            p_event_id: eventId.uuidString,
            p_user_ids: userIds.map { $0.uuidString },
            p_credits_per_user: creditsPerUser,
            p_reason: reason
        )
        return try await client
            .rpc("grant_event_credits", params: params)
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

    /// Get event participants
    func getEventParticipants(eventId: UUID) async throws -> [EventParticipantResponse] {
        return try await client
            .rpc("get_event_participants", params: ["p_event_id": eventId.uuidString])
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
