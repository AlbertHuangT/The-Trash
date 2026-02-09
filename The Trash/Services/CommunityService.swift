//
//  CommunityService.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import Foundation
import Supabase
import Combine

// MARK: - RPC Parameter Structs (Sendable for safe cross-actor usage)

private struct NearbyEventsParams: Sendable {
    let p_latitude: Double
    let p_longitude: Double
    let p_max_distance_km: Double
    let p_category: String?
    let p_only_joined_communities: Bool
    let p_sort_by: String
}

private struct CreateCommunityParams: Sendable {
    let p_id: String
    let p_name: String
    let p_city: String
    let p_state: String
    let p_description: String?
    let p_latitude: Double?
    let p_longitude: Double?
}

extension CreateCommunityParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_id, forKey: .p_id)
        try container.encode(p_name, forKey: .p_name)
        try container.encode(p_city, forKey: .p_city)
        try container.encode(p_state, forKey: .p_state)
        try container.encodeIfPresent(p_description, forKey: .p_description)
        try container.encodeIfPresent(p_latitude, forKey: .p_latitude)
        try container.encodeIfPresent(p_longitude, forKey: .p_longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_id, p_name, p_city, p_state, p_description, p_latitude, p_longitude
    }
}

private struct CreateEventParams: Sendable {
    let p_title: String
    let p_description: String
    let p_category: String
    let p_event_date: String
    let p_location: String
    let p_latitude: Double
    let p_longitude: Double
    let p_max_participants: Int
    let p_community_id: String?
    let p_icon_name: String
}

extension CreateEventParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_title, forKey: .p_title)
        try container.encode(p_description, forKey: .p_description)
        try container.encode(p_category, forKey: .p_category)
        try container.encode(p_event_date, forKey: .p_event_date)
        try container.encode(p_location, forKey: .p_location)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_max_participants, forKey: .p_max_participants)
        try container.encodeIfPresent(p_community_id, forKey: .p_community_id)
        try container.encode(p_icon_name, forKey: .p_icon_name)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_title, p_description, p_category, p_event_date, p_location
        case p_latitude, p_longitude, p_max_participants, p_community_id, p_icon_name
    }
}

extension NearbyEventsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_max_distance_km, forKey: .p_max_distance_km)
        try container.encodeIfPresent(p_category, forKey: .p_category)
        try container.encode(p_only_joined_communities, forKey: .p_only_joined_communities)
        try container.encode(p_sort_by, forKey: .p_sort_by)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_latitude, p_longitude, p_max_distance_km, p_category, p_only_joined_communities, p_sort_by
    }
}

private struct LocationParams: Sendable {
    let p_city: String
    let p_state: String
    let p_latitude: Double
    let p_longitude: Double
}

extension LocationParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_city, forKey: .p_city)
        try container.encode(p_state, forKey: .p_state)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case p_city, p_state, p_latitude, p_longitude
    }
}

// MARK: - Admin RPC Parameter Structs

private struct UpdateCommunityInfoParams: Sendable {
    let p_community_id: String
    let p_description: String?
    let p_welcome_message: String?
    let p_rules: String?
    let p_requires_approval: Bool?
}

extension UpdateCommunityInfoParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encodeIfPresent(p_description, forKey: .p_description)
        try container.encodeIfPresent(p_welcome_message, forKey: .p_welcome_message)
        try container.encodeIfPresent(p_rules, forKey: .p_rules)
        try container.encodeIfPresent(p_requires_approval, forKey: .p_requires_approval)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_description, p_welcome_message, p_rules, p_requires_approval
    }
}

private struct ReviewApplicationParams: Sendable {
    let p_application_id: String
    let p_approve: Bool
    let p_rejection_reason: String?
}

extension ReviewApplicationParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_application_id, forKey: .p_application_id)
        try container.encode(p_approve, forKey: .p_approve)
        try container.encodeIfPresent(p_rejection_reason, forKey: .p_rejection_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_application_id, p_approve, p_rejection_reason
    }
}

private struct RemoveMemberParams: Sendable {
    let p_community_id: String
    let p_user_id: String
    let p_reason: String?
}

extension RemoveMemberParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encode(p_user_id, forKey: .p_user_id)
        try container.encodeIfPresent(p_reason, forKey: .p_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_user_id, p_reason
    }
}

private struct GrantCreditsParams: Sendable {
    let p_event_id: String
    let p_user_ids: [String]
    let p_credits_per_user: Int
    let p_reason: String
}

extension GrantCreditsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_event_id, forKey: .p_event_id)
        try container.encode(p_user_ids, forKey: .p_user_ids)
        try container.encode(p_credits_per_user, forKey: .p_credits_per_user)
        try container.encode(p_reason, forKey: .p_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_event_id, p_user_ids, p_credits_per_user, p_reason
    }
}

private struct GetAdminLogsParams: Sendable {
    let p_community_id: String
    let p_limit: Int
}

extension GetAdminLogsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encode(p_limit, forKey: .p_limit)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_limit
    }
}

// MARK: - Nonisolated RPC Helpers

/// Helper to call RPC for nearby events outside of @MainActor context
private func fetchNearbyEventsRPC(
    client: SupabaseClient,
    latitude: Double,
    longitude: Double,
    maxDistanceKm: Double,
    category: String?,
    onlyJoinedCommunities: Bool,
    sortBy: String
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

/// Helper to call RPC for updating location outside of @MainActor context
private func updateLocationRPC(
    client: SupabaseClient,
    city: String,
    state: String,
    latitude: Double,
    longitude: Double
) async throws -> APIResult {
    let params = LocationParams(
        p_city: city,
        p_state: state,
        p_latitude: latitude,
        p_longitude: longitude
    )
    return try await client
        .rpc("update_user_location", params: params)
        .execute()
        .value
}

private struct SimpleCommunity: Codable, Sendable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude
        case memberCount = "member_count"
    }
}

// MARK: - Community Service

@MainActor
class CommunityService: ObservableObject {
    static let shared = CommunityService()
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Community Methods
    
    /// 获取指定城市的社区列表
    func getCommunitiesByCity(_ city: String) async -> [CommunityResponse] {
        do {
            let response: [CommunityResponse] = try await client
                .rpc("get_communities_by_city", params: ["p_city": city])
                .execute()
                .value
            return response
        } catch {
            print("❌ Get communities error: \(error)")
            // 🔥 Fix: Expose error to UI
            self.errorMessage = "Failed to load communities: \(error.localizedDescription)"
            return []
        }
    }
    
    /// 获取用户已加入的社区
    func getMyCommunities() async -> [MyCommunityResponse] {
        do {
            let response: [MyCommunityResponse] = try await client
                .rpc("get_my_communities")
                .execute()
                .value
            return response
        } catch {
            print("❌ Get my communities error: \(error)")
            self.errorMessage = "Failed to load your communities."
            return []
        }
    }
    
    /// 加入社区（支持审批流程）
    func joinCommunity(_ communityId: String, message: String? = nil) async -> JoinCommunityResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result: JoinCommunityResult = try await client
                .rpc("apply_to_join_community", params: ["p_community_id": communityId])
                .execute()
                .value

            if !result.success {
                errorMessage = result.message
            }
            return result
        } catch {
            print("❌ Join community error: \(error)")
            errorMessage = "Failed to join community"
            return JoinCommunityResult(success: false, message: "Failed to join community", requiresApproval: false)
        }
    }
    
    /// 离开社区
    func leaveCommunity(_ communityId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("leave_community", params: ["p_community_id": communityId])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Leave community error: \(error)")
            errorMessage = "Failed to leave community"
            return false
        }
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
    ) async -> [EventResponse] {
        do {
            return try await fetchNearbyEventsRPC(
                client: client,
                latitude: latitude,
                longitude: longitude,
                maxDistanceKm: maxDistanceKm,
                category: category,
                onlyJoinedCommunities: onlyJoinedCommunities,
                sortBy: sortBy
            )
        } catch {
            print("❌ Get nearby events error: \(error)")
            // Not setting global error here as it might be part of a larger dashboard
            return []
        }
    }
    
    /// 报名活动
    func registerForEvent(_ eventId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("register_for_event", params: ["p_event_id": eventId.uuidString])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Register for event error: \(error)")
            errorMessage = "Failed to register for event"
            return false
        }
    }
    
    /// 取消报名
    func cancelEventRegistration(_ eventId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await client
                .rpc("cancel_event_registration", params: ["p_event_id": eventId.uuidString])
                .execute()
                .value
            
            if !result.success {
                errorMessage = result.message
            }
            return result.success
        } catch {
            print("❌ Cancel registration error: \(error)")
            errorMessage = "Failed to cancel registration"
            return false
        }
    }
    
    /// 获取用户已报名的活动
    func getMyRegistrations() async -> [MyRegistrationResponse] {
        do {
            let response: [MyRegistrationResponse] = try await client
                .rpc("get_my_registrations")
                .execute()
                .value
            return response
        } catch {
            print("❌ Get my registrations error: \(error)")
            self.errorMessage = "Failed to load registrations."
            return []
        }
    }
    
    // MARK: - Location Methods
    
    /// 更新用户位置
    func updateUserLocation(city: String, state: String, latitude: Double, longitude: Double) async -> Bool {
        do {
            let result = try await updateLocationRPC(
                client: client,
                city: city,
                state: state,
                latitude: latitude,
                longitude: longitude
            )
            return result.success
        } catch {
            print("❌ Update location error: \(error)")
            return false
        }
    }
    
    // MARK: - Direct Table Access (for communities list)
    
    /// 获取指定社区的活动（包括过去和将来的）
    func getCommunityEvents(communityId: String) async -> [EventResponse] {
        do {
            let response: [EventResponse] = try await client
                .rpc("get_community_events", params: ["p_community_id": communityId])
                .execute()
                .value
            return response
        } catch {
            print("❌ Get community events error: \(error)")
            self.errorMessage = "Failed to load community events."
            return []
        }
    }
    
    /// 获取所有社区列表
    func getAllCommunities() async -> [CommunityResponse] {
        do {
            let communities: [SimpleCommunity] = try await client
                .from("communities")
                .select()
                .eq("is_active", value: true)
                .order("member_count", ascending: false)
                .execute()
                .value
            
            return communities.map {
                CommunityResponse(
                    id: $0.id,
                    name: $0.name,
                    city: $0.city,
                    state: $0.state,
                    description: $0.description,
                    memberCount: $0.memberCount,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    isMember: nil
                )
            }
        } catch {
            print("❌ Get all communities error: \(error)")
            self.errorMessage = "Failed to load all communities."
            return []
        }
    }
    
    // MARK: - Create Content Methods
    
    /// 检查用户是否可以创建社区（最多3个）
    func canCreateCommunity() async -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        do {
            let result: CanCreateResult = try await client
                .rpc("can_user_create_community")
                .execute()
                .value
            
            return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
        } catch {
            print("❌ Check create community error: \(error)")
            return (false, 0, 3, "Failed to check limit")
        }
    }
    
    /// 检查用户是否可以创建活动（每周最多7个）
    func canCreateEvent() async -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        do {
            let result: CanCreateResult = try await client
                .rpc("can_user_create_event")
                .execute()
                .value
            
            return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
        } catch {
            print("❌ Check create event error: \(error)")
            return (false, 0, 7, "Failed to check limit")
        }
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
    ) async -> (success: Bool, message: String, communityId: String?) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await createCommunityRPC(
                client: client,
                id: id,
                name: name,
                city: city,
                state: state,
                description: description,
                latitude: latitude,
                longitude: longitude
            )
            
            if !result.success {
                errorMessage = result.message
            }
            return (result.success, result.message, result.success ? id : nil)
        } catch {
            print("❌ Create community error: \(error)")
            errorMessage = "Failed to create community"
            return (false, "Failed to create community: \(error.localizedDescription)", nil)
        }
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
        communityId: String? = nil,  // nil = 个人活动
        iconName: String = "calendar"
    ) async -> (success: Bool, message: String, eventId: UUID?) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result: APIResult = try await createEventRPC(
                client: client,
                title: title,
                description: description,
                category: category,
                eventDate: eventDate,
                location: location,
                latitude: latitude,
                longitude: longitude,
                maxParticipants: maxParticipants,
                communityId: communityId,
                iconName: iconName
            )
            
            if !result.success {
                errorMessage = result.message
            }
            return (result.success, result.message, nil)
        } catch {
            print("❌ Create event error: \(error)")
            errorMessage = "Failed to create event"
            return (false, "Failed to create event: \(error.localizedDescription)", nil)
        }
    }

    // MARK: - Admin Methods

    /// Check if current user is admin of a community
    func isAdmin(communityId: String) async -> Bool {
        do {
            let result: Bool = try await client
                .rpc("is_community_admin", params: ["p_community_id": communityId])
                .execute()
                .value
            return result
        } catch {
            print("❌ Check admin error: \(error)")
            return false
        }
    }

    /// Get pending join applications (admin only)
    func getPendingApplications(communityId: String) async -> [JoinApplicationResponse] {
        do {
            let applications: [JoinApplicationResponse] = try await client
                .rpc("get_pending_applications", params: ["p_community_id": communityId])
                .execute()
                .value
            return applications
        } catch {
            print("❌ Get applications error: \(error)")
            return []
        }
    }

    /// Review a join application (admin only)
    func reviewApplication(
        applicationId: UUID,
        approve: Bool,
        rejectionReason: String? = nil
    ) async -> APIResult {
        do {
            let params = ReviewApplicationParams(
                p_application_id: applicationId.uuidString,
                p_approve: approve,
                p_rejection_reason: rejectionReason
            )
            let result: APIResult = try await reviewApplicationRPC(client: client, params: params)
            return result
        } catch {
            print("❌ Review application error: \(error)")
            return APIResult(success: false, message: "Operation failed")
        }
    }

    /// Update community info (admin only)
    func updateCommunityInfo(
        communityId: String,
        description: String? = nil,
        welcomeMessage: String? = nil,
        rules: String? = nil,
        requiresApproval: Bool? = nil
    ) async -> APIResult {
        do {
            let params = UpdateCommunityInfoParams(
                p_community_id: communityId,
                p_description: description,
                p_welcome_message: welcomeMessage,
                p_rules: rules,
                p_requires_approval: requiresApproval
            )
            let result: APIResult = try await updateCommunityInfoRPC(client: client, params: params)
            return result
        } catch {
            print("❌ Update community error: \(error)")
            return APIResult(success: false, message: "Update failed")
        }
    }

    /// Get community members list (admin only)
    func getCommunityMembersAdmin(communityId: String) async -> [CommunityMemberResponse] {
        do {
            let members: [CommunityMemberResponse] = try await client
                .rpc("get_community_members_admin", params: ["p_community_id": communityId])
                .execute()
                .value
            return members
        } catch {
            print("❌ Get members error: \(error)")
            return []
        }
    }

    /// Remove a member from community (admin only)
    func removeMember(communityId: String, userId: UUID, reason: String? = nil) async -> APIResult {
        do {
            let params = RemoveMemberParams(
                p_community_id: communityId,
                p_user_id: userId.uuidString,
                p_reason: reason
            )
            let result: APIResult = try await removeMemberRPC(client: client, params: params)
            return result
        } catch {
            print("❌ Remove member error: \(error)")
            return APIResult(success: false, message: "Remove failed")
        }
    }

    /// Grant credits to event participants (admin only)
    func grantEventCredits(
        eventId: UUID,
        userIds: [UUID],
        creditsPerUser: Int,
        reason: String
    ) async -> GrantCreditsResult {
        do {
            let params = GrantCreditsParams(
                p_event_id: eventId.uuidString,
                p_user_ids: userIds.map { $0.uuidString },
                p_credits_per_user: creditsPerUser,
                p_reason: reason
            )
            let result: GrantCreditsResult = try await grantCreditsRPC(client: client, params: params)
            return result
        } catch {
            print("❌ Grant credits error: \(error)")
            return GrantCreditsResult(success: false, message: "Grant failed", grantedCount: 0)
        }
    }

    /// Get admin action logs (admin only)
    func getAdminLogs(communityId: String, limit: Int = 50) async -> [AdminActionLogResponse] {
        do {
            let params = GetAdminLogsParams(p_community_id: communityId, p_limit: limit)
            let logs: [AdminActionLogResponse] = try await client
                .rpc("get_admin_action_logs", params: params)
                .execute()
                .value
            return logs
        } catch {
            print("❌ Get admin logs error: \(error)")
            return []
        }
    }

    /// Get event participants
    func getEventParticipants(eventId: UUID) async -> [EventParticipantResponse] {
        do {
            let participants: [EventParticipantResponse] = try await client
                .rpc("get_event_participants", params: ["p_event_id": eventId.uuidString])
                .execute()
                .value
            return participants
        } catch {
            print("❌ Get event participants error: \(error)")
            self.errorMessage = "Failed to load participants."
            return []
        }
    }

    /// Get community settings (for admin edit view)
    func getCommunitySettings(communityId: String) async -> CommunitySettingsResponse? {
        do {
            let response: CommunitySettingsResponse = try await client
                .from("communities")
                .select("id, description, welcome_message, rules, requires_approval")
                .eq("id", value: communityId)
                .single()
                .execute()
                .value
            return response
        } catch {
            print("❌ Get community settings error: \(error)")
            return nil
        }
    }
}

// MARK: - Nonisolated RPC Helpers for Create Operations

private func createCommunityRPC(
    client: SupabaseClient,
    id: String,
    name: String,
    city: String,
    state: String,
    description: String?,
    latitude: Double?,
    longitude: Double?
) async throws -> APIResult {
    let params = CreateCommunityParams(
        p_id: id,
        p_name: name,
        p_city: city,
        p_state: state,
        p_description: description,
        p_latitude: latitude,
        p_longitude: longitude
    )
    return try await client
        .rpc("create_community", params: params)
        .execute()
        .value
}

private func createEventRPC(
    client: SupabaseClient,
    title: String,
    description: String,
    category: String,
    eventDate: Date,
    location: String,
    latitude: Double,
    longitude: Double,
    maxParticipants: Int,
    communityId: String?,
    iconName: String
) async throws -> APIResult {
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
    return try await client
        .rpc("create_event", params: params)
        .execute()
        .value
}

// MARK: - Nonisolated RPC Helpers for Admin Operations

private func reviewApplicationRPC(client: SupabaseClient, params: ReviewApplicationParams) async throws -> APIResult {
    return try await client
        .rpc("review_join_application", params: params)
        .execute()
        .value
}

private func updateCommunityInfoRPC(client: SupabaseClient, params: UpdateCommunityInfoParams) async throws -> APIResult {
    return try await client
        .rpc("update_community_info", params: params)
        .execute()
        .value
}

private func removeMemberRPC(client: SupabaseClient, params: RemoveMemberParams) async throws -> APIResult {
    return try await client
        .rpc("remove_community_member", params: params)
        .execute()
        .value
}

private func grantCreditsRPC(client: SupabaseClient, params: GrantCreditsParams) async throws -> GrantCreditsResult {
    return try await client
        .rpc("grant_event_credits", params: params)
        .execute()
        .value
}
